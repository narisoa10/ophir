// Phase 2.3A Step 1: Disconnect / Delete lifecycle RPCs, disconnected gates,
// frozen canonical authority, duplicate resolutions, manual Operations and
// Operations integrity.

import { assert, assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import {
  applyAllMigrations,
  applyMigration,
  listMigrations,
  readMigration,
  type Sql,
  withDatabase,
} from "./harness.ts";
import {
  applyTransactions,
  createPlaidItem,
  createUser,
  link,
  operationFor,
  projectionState,
  resolveDuplicate,
  reverseResolution,
  runAllProjectionJobs,
  syncAccounts,
  type TransactionInput,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const LIFECYCLE_MIGRATION = "20261003150000_plaid_item_disconnect_delete_lifecycle.sql";
const REMOVE_CLEANUP_MIGRATION = "20260810130000_plaid_remove_item_local_cleanup.sql";

type Role = "anon" | "authenticated" | "service_role";

async function asRole<T>(sql: Sql, role: Role, userId: string | null, body: (tx: Sql) => Promise<T>): Promise<T> {
  return await sql.begin(async (tx) => {
    if (userId !== null) {
      await tx`select set_config('request.jwt.claim.sub', ${userId}, true)`;
    }
    await tx.unsafe(`set local role ${role}`);
    return await body(tx as unknown as Sql);
  }) as T;
}

async function assertSqlState(promise: () => Promise<unknown>, code: string, message?: string): Promise<void> {
  const error = await assertRejects(promise) as { code?: string; message?: string };
  assertEquals(error.code, code, error.message);
  if (message !== undefined) {
    assertEquals(error.message, message);
  }
}

async function disconnect(sql: Sql, userId: string, itemId: string): Promise<Record<string, unknown>> {
  const [row] = await sql`select public.plaid_disconnect_item_local(${userId}::uuid, ${itemId}::uuid) as r`;
  return row.r as Record<string, unknown>;
}

async function deleteItem(sql: Sql, userId: string, itemId: string): Promise<Record<string, unknown>> {
  const [row] = await sql`select public.plaid_delete_item_local(${userId}::uuid, ${itemId}::uuid) as r`;
  return row.r as Record<string, unknown>;
}

async function utcDate(sql: Sql, offsetDays: number): Promise<string> {
  const [row] = await sql`select ((now() at time zone 'UTC')::date + ${offsetDays}::int)::text as d`;
  return row.d;
}

function txn(
  transactionId: string,
  plaidAccountId: string,
  amount: number,
  date: string,
  extra: Partial<TransactionInput> = {},
): TransactionInput {
  return { transactionId, plaidAccountId, amount, date, name: `Merchant ${transactionId}`, ...extra };
}

interface Connection {
  itemId: string;
  externalId: string;
  accountId: string;
  plaidAccountId: string;
}

async function connection(sql: Sql, userId: string, label: string): Promise<Connection> {
  const externalId = `item-${label}`;
  const plaidAccountId = `${label}-acct`;
  const itemId = await createPlaidItem(sql, userId, externalId);
  const accounts = await syncAccounts(sql, userId, itemId, [{ plaidAccountId, name: `Card ${label}` }]);
  return { itemId, externalId, accountId: accounts[plaidAccountId], plaidAccountId };
}

async function itemCounts(sql: Sql, itemId: string): Promise<Record<string, number>> {
  const [row] = await sql`
    select
      (select count(*)::int from public.plaid_items where id = ${itemId}::uuid) as items,
      (select count(*)::int from public.accounts where plaid_item_id = ${itemId}::uuid) as accounts,
      (select count(*)::int from public.plaid_transactions where plaid_item_id = ${itemId}::uuid) as raw,
      (select count(*)::int from public.plaid_transaction_operation_projections
        where plaid_item_id = ${itemId}::uuid) as projections,
      (select count(*)::int from public.plaid_transaction_operation_projections
        where plaid_item_id = ${itemId}::uuid and operation_id is not null) as projected,
      (select count(*)::int from public.plaid_transaction_sync_jobs where plaid_item_id = ${itemId}::uuid) as sync_jobs,
      (select count(*)::int from public.plaid_transaction_sync_leases where plaid_item_id = ${itemId}::uuid) as sync_leases,
      (select count(*)::int from public.plaid_transaction_projection_jobs
        where plaid_item_id = ${itemId}::uuid) as projection_jobs,
      (select count(*)::int from public.institutions where plaid_item_id = ${itemId}::uuid) as institutions`;
  return row as unknown as Record<string, number>;
}

async function plaidOperationsOn(sql: Sql, accountId: string): Promise<number> {
  const [row] = await sql`
    select count(*)::int as n from public.operations
    where source = 'plaid' and from_account_id = ${accountId}::uuid`;
  return row.n;
}

async function memberships(sql: Sql, userId: string): Promise<Record<string, unknown>[]> {
  return [
    ...(await sql`
    select id::text as id, canonical_account_id::text as canonical_id, account_id::text as account_id,
           role, unlinked_at is null as active, linked_at, unlinked_at
    from public.plaid_canonical_financial_account_members
    where user_id = ${userId}::uuid
    order by linked_at, role, id`),
  ];
}

async function enqueueProjection(sql: Sql, userId: string, itemId: string): Promise<void> {
  await sql`select public.plaid_enqueue_transaction_projection_job(${userId}::uuid, ${itemId}::uuid)`;
}

async function projectionSnapshot(sql: Sql, itemId: string): Promise<Record<string, unknown>[]> {
  return [
    ...(await sql`
    select projection.plaid_transaction_id, projection.state, projection.suppressed_reason,
           projection.operation_id::text as operation_id, operations.archived_at is not null as archived
    from public.plaid_transaction_operation_projections projection
    left join public.operations on operations.id = projection.operation_id
    where projection.plaid_item_id = ${itemId}::uuid
    order by projection.plaid_transaction_id`),
  ];
}

async function suppressed(sql: Sql, itemId: string, transactionId: string): Promise<void> {
  assertEquals(await projectionState(sql, itemId, transactionId), {
    state: "suppressed",
    suppressed_reason: "canonical_secondary",
  }, transactionId);
  assertEquals(await operationFor(sql, itemId, transactionId), null, transactionId);
}

async function ambiguous(sql: Sql, itemId: string, transactionId: string): Promise<void> {
  assertEquals(await projectionState(sql, itemId, transactionId), {
    state: "suppressed",
    suppressed_reason: "canonical_handoff_ambiguous",
  }, transactionId);
  assertEquals(await operationFor(sql, itemId, transactionId), null, transactionId);
}

async function projected(sql: Sql, itemId: string, transactionId: string): Promise<string> {
  const state = await projectionState(sql, itemId, transactionId);
  assertEquals(state, { state: "posted_projected", suppressed_reason: null }, transactionId);
  const operationId = await operationFor(sql, itemId, transactionId);
  assert(operationId !== null, `${transactionId} must have an Operation`);
  return operationId;
}

// ---------------------------------------------------------------------------
// Disconnect
// ---------------------------------------------------------------------------

Deno.test("disconnect: owner success, foreign isolation, history kept, token deleted, idempotent", options, async () => {
  await withDatabase("p23a_disconnect", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "owner");
    const stranger = await createUser(sql, "stranger");
    const conn = await connection(sql, owner, "disc");
    const day = await utcDate(sql, -2);
    await applyTransactions(sql, owner, conn.itemId, {
      added: [txn("d-1", conn.plaidAccountId, 10, day), txn("d-2", conn.plaidAccountId, 20, day)],
    });
    await runAllProjectionJobs(sql);
    await sql`select public.plaid_enqueue_transaction_sync_job(${conn.externalId})`;
    await sql`select public.plaid_acquire_transactions_sync_lease(
      ${owner}::uuid, ${conn.itemId}::uuid, gen_random_uuid(), 60)`;
    const [{ secret_id, status }] = await sql`
      select access_token_secret_id::text as secret_id, status
      from public.plaid_items where id = ${conn.itemId}::uuid`;
    const before = await itemCounts(sql, conn.itemId);
    assertEquals(before.sync_jobs, 1);
    assertEquals(before.sync_leases, 1);
    assertEquals(before.projected, 2);

    assertEquals(await disconnect(sql, stranger, conn.itemId), { status: "not_found" });
    assertEquals(await disconnect(sql, owner, crypto.randomUUID()), { status: "not_found" });
    assertEquals(await itemCounts(sql, conn.itemId), before);

    const result = await disconnect(sql, owner, conn.itemId);
    assertEquals(result, {
      status: "disconnected",
      canonical_authorities_frozen: 0,
      vault_secrets_deleted: 1,
      survivor_items_enqueued: 0,
    });

    const [item] = await sql`
      select disconnected_at, access_token_secret_id, status
      from public.plaid_items where id = ${conn.itemId}::uuid`;
    assert(item.disconnected_at !== null);
    assertEquals(item.access_token_secret_id, null);
    assertEquals(item.status, status);
    const [{ secrets }] = await sql`
      select count(*)::int as secrets from vault.secrets where id = ${secret_id}::uuid`;
    assertEquals(secrets, 0);

    const after = await itemCounts(sql, conn.itemId);
    assertEquals(after, { ...before, sync_jobs: 0, sync_leases: 0 });
    assertEquals(await plaidOperationsOn(sql, conn.accountId), 2);

    const repeat = await disconnect(sql, owner, conn.itemId);
    assertEquals(repeat.status, "already_disconnected");
    assertEquals(new Date(repeat.disconnected_at as string).getTime(), new Date(item.disconnected_at).getTime());
    assertEquals(await itemCounts(sql, conn.itemId), after);
  });
});

Deno.test("disconnect: sync, health and token gates refuse a disconnected Item", options, async () => {
  await withDatabase("p23a_gates", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "gates");
    const conn = await connection(sql, owner, "gated");
    const live = await connection(sql, owner, "live");
    const day = await utcDate(sql, -1);
    await applyTransactions(sql, owner, conn.itemId, { added: [txn("g-1", conn.plaidAccountId, 5, day)] });
    await runAllProjectionJobs(sql);
    await disconnect(sql, owner, conn.itemId);

    assertEquals((await sql`select public.plaid_enqueue_transaction_sync_job(${conn.externalId}) as r`)[0].r, {
      status: "ignored",
    });
    assertEquals((await itemCounts(sql, conn.itemId)).sync_jobs, 0);

    const [healthBefore] = await sql`
      select status, status_reason, health_observed_at, pending_disconnect_at, consent_expires_at
      from public.plaid_items where id = ${conn.itemId}::uuid`;
    const [observation] = await sql`
      select public.plaid_record_item_status_observation(
        ${conn.itemId}::uuid, now(), 'login_required', 'login_required', false, null, false) as r`;
    assertEquals(observation.r, {
      applied: false,
      previous_status: "active",
      status: "active",
      plaid_item_id: conn.externalId,
    });
    assertEquals(
      (await sql`select public.plaid_set_item_access_deadline(${conn.externalId}, 'pending_disconnect', now()) as r`)[0]
        .r,
      { status: "ignored" },
    );
    const [healthAfter] = await sql`
      select status, status_reason, health_observed_at, pending_disconnect_at, consent_expires_at
      from public.plaid_items where id = ${conn.itemId}::uuid`;
    assertEquals(healthAfter, healthBefore);

    const listed = await sql`select connection_id::text as id from public.plaid_list_items_for_health_reconcile(10)`;
    assertEquals(listed.map((row) => row.id), [live.itemId]);

    await assertSqlState(
      () => sql`select public.plaid_get_access_token_for_item(${owner}::uuid, ${conn.itemId}::uuid)`,
      "22023",
      "plaid_item_not_found",
    );

    const rawBefore = (await itemCounts(sql, conn.itemId)).raw;
    const [{ cursor }] = await sql`
      select transactions_cursor as cursor from public.plaid_items where id = ${conn.itemId}::uuid`;
    await assertSqlState(
      () =>
        sql`
        select public.plaid_apply_transactions_sync_batch(
          ${owner}::uuid, ${conn.itemId}::uuid, ${cursor}::text, 'cursor-after-disconnect', true,
          ${sql.json([txn("g-late", conn.plaidAccountId, 3, day)].map((t) => ({
          transaction_id: t.transactionId,
          plaid_account_id: t.plaidAccountId,
          amount: t.amount.toFixed(2),
          date: t.date,
          pending: false,
          iso_currency_code: "CAD",
          name: t.name,
        })))}::jsonb, '[]'::jsonb, '[]'::jsonb)`,
      "22023",
      "plaid_item_disconnected",
    );
    assertEquals((await itemCounts(sql, conn.itemId)).raw, rawBefore);

    await assertSqlState(
      () => sql`update public.plaid_items set disconnected_at = null where id = ${conn.itemId}::uuid`,
      "23514",
    );

    const rows = await asRole(sql, "authenticated", owner, (tx) =>
      tx`select * from public.plaid_list_connection_health()`);
    const byId = Object.fromEntries(rows.map((row) => [row.connection_id, row]));
    assertEquals(Object.keys(byId[conn.itemId]).sort(), [
      "connection_id",
      "consent_expires_at",
      "disconnected_at",
      "pending_disconnect_at",
      "status",
      "status_changed_at",
      "status_reason",
    ]);
    assert(byId[conn.itemId].disconnected_at !== null);
    assertEquals(byId[live.itemId].disconnected_at, null);
  });
});

// ---------------------------------------------------------------------------
// Suppression gate equivalence (no frozen authority)
// ---------------------------------------------------------------------------

async function equivalenceScenario(sql: Sql): Promise<Record<string, unknown>[]> {
  const user = await createUser(sql, "equivalence");
  const a = await connection(sql, user, "eq-a");
  const b = await connection(sql, user, "eq-b");
  const c = await connection(sql, user, "eq-c");

  await applyTransactions(sql, user, b.itemId, { added: [txn("pre-b", b.plaidAccountId, 10, "2026-09-01")] });
  await runAllProjectionJobs(sql);
  await link(sql, user, a.accountId, b.accountId, a.accountId);

  for (const conn of [a, b]) {
    const p = conn === a ? "a" : "b";
    await applyTransactions(sql, user, conn.itemId, {
      added: [
        txn(`${p}-posted`, conn.plaidAccountId, 12, "2026-09-02"),
        txn(`${p}-zero`, conn.plaidAccountId, 0, "2026-09-02"),
        txn(`${p}-pending`, conn.plaidAccountId, 5, "2026-09-03", { pending: true }),
        txn(`${p}-removed`, conn.plaidAccountId, 8, "2026-09-03"),
        txn(`${p}-income`, conn.plaidAccountId, -40, "2026-09-04"),
      ],
    });
    await applyTransactions(sql, user, conn.itemId, { removed: [`${p}-removed`] });
  }
  await applyTransactions(sql, user, b.itemId, {
    modified: [txn("pre-b", b.plaidAccountId, 11, "2026-09-01")],
  });
  await applyTransactions(sql, user, c.itemId, { added: [txn("c-posted", c.plaidAccountId, 3, "2026-09-02")] });
  await runAllProjectionJobs(sql);

  for (const conn of [a, b]) {
    const p = conn === a ? "a" : "b";
    await applyTransactions(sql, user, conn.itemId, {
      added: [txn(`${p}-settled`, conn.plaidAccountId, 5, "2026-09-05", { pendingTransactionId: `${p}-pending` })],
      removed: [`${p}-pending`],
    });
  }
  await runAllProjectionJobs(sql);
  for (const conn of [a, b, c]) {
    await enqueueProjection(sql, user, conn.itemId);
  }
  await runAllProjectionJobs(sql);

  return [
    ...(await sql`
    select items.plaid_item_id as item, projection.plaid_transaction_id, projection.state,
           projection.suppressed_reason, projection.operation_id is not null as has_operation,
           operations.archived_at is not null as archived, operations.amount::text as amount
    from public.plaid_transaction_operation_projections projection
    join public.plaid_items items on items.id = projection.plaid_item_id
    left join public.operations on operations.id = projection.operation_id
    order by 1, 2`),
  ];
}

Deno.test("suppression gate without frozen authority matches the previous behavior", options, async () => {
  let previous: Record<string, unknown>[] = [];
  await withDatabase("p23a_equiv_old", async (db) => {
    // Later migrations build on the lifecycle schema (plaid_items.disconnected_at).
    for (const name of listMigrations().filter((name) => name < LIFECYCLE_MIGRATION)) {
      await applyMigration(db.sql, name);
    }
    previous = await equivalenceScenario(db.sql);
  });
  await withDatabase("p23a_equiv_new", async (db) => {
    await applyAllMigrations(db.sql);
    const current = await equivalenceScenario(db.sql);
    assertEquals(current, previous);
    const suppressedRows = current.filter((row) => row.suppressed_reason === "canonical_secondary");
    assert(suppressedRows.length >= 3, "scenario must exercise the secondary gate");
    assert(suppressedRows.every((row) => row.item === "item-eq-b"));
  });
});

// ---------------------------------------------------------------------------
// Canonical handoff boundary
// ---------------------------------------------------------------------------

interface Pair {
  user: string;
  a: Connection;
  b: Connection;
}

async function linkedPair(sql: Sql, label: string): Promise<Pair> {
  const user = await createUser(sql, label);
  const a = await connection(sql, user, `${label}-a`);
  const b = await connection(sql, user, `${label}-b`);
  await link(sql, user, a.accountId, b.accountId, a.accountId);
  return { user, a, b };
}

async function rerunProjections(sql: Sql, userId: string, itemIds: string[]): Promise<void> {
  for (const itemId of itemIds) {
    await enqueueProjection(sql, userId, itemId);
  }
  await runAllProjectionJobs(sql);
}

// Approved contract change: after a Disconnect of the authoritative representation, a
// new survivor transaction is canonical_handoff_ambiguous until Delete; it no longer
// materializes automatically.
Deno.test("frozen authority: existing suppression is sticky, every later arrival is ambiguous, Delete releases all exactly once", options, async () => {
  await withDatabase("p23a_frozen", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await linkedPair(sql, "frozen");
    const today = await utcDate(sql, 0);
    const tomorrow = await utcDate(sql, 1);
    const yesterday = await utcDate(sql, -1);
    const older = await utcDate(sql, -3);
    const muchOlder = await utcDate(sql, -30);

    await applyTransactions(sql, user, a.itemId, {
      added: [
        txn("a-old", a.plaidAccountId, 20, older),
        txn("a-today", a.plaidAccountId, 9, today),
        txn("a-pend", a.plaidAccountId, 7, today, { pending: true }),
      ],
    });
    await applyTransactions(sql, user, b.itemId, {
      added: [
        txn("b-old", b.plaidAccountId, 20, older),
        txn("b-pend", b.plaidAccountId, 7, today, { pending: true }),
      ],
    });
    await runAllProjectionJobs(sql);
    // Immediately before the Disconnect, dated on the Disconnect day.
    await applyTransactions(sql, user, b.itemId, { added: [txn("b-just-before", b.plaidAccountId, 9, today)] });
    await runAllProjectionJobs(sql);
    // Stored before the Disconnect but not yet reconciled: classified conservatively.
    await applyTransactions(sql, user, b.itemId, { added: [txn("b-unreconciled", b.plaidAccountId, 4, yesterday)] });

    await projected(sql, a.itemId, "a-old");
    await projected(sql, a.itemId, "a-today");
    await suppressed(sql, b.itemId, "b-old");
    await suppressed(sql, b.itemId, "b-just-before");
    assertEquals((await projectionState(sql, b.itemId, "b-pend")).state, "raw_pending");
    const aHistory = await projectionSnapshot(sql, a.itemId);
    const membersBefore = await memberships(sql, user);

    assertEquals(await disconnect(sql, user, a.itemId), {
      status: "disconnected",
      canonical_authorities_frozen: 1,
      vault_secrets_deleted: 1,
      survivor_items_enqueued: 1,
    });
    assertEquals(await memberships(sql, user), membersBefore, "Disconnect keeps memberships and roles");

    await runAllProjectionJobs(sql);
    await suppressed(sql, b.itemId, "b-old");
    await suppressed(sql, b.itemId, "b-just-before");
    await ambiguous(sql, b.itemId, "b-unreconciled");
    assertEquals(await projectionSnapshot(sql, a.itemId), aHistory);

    // After the Disconnect: neither date nor arrival time releases anything.
    await applyTransactions(sql, user, b.itemId, {
      added: [
        txn("b-same-day", b.plaidAccountId, 11, today),
        txn("b-old-late", b.plaidAccountId, 13, muchOlder),
        txn("b-future", b.plaidAccountId, 14, tomorrow),
        txn("b-settled", b.plaidAccountId, 7, today, { pendingTransactionId: "b-pend" }),
        txn("b-pend-2", b.plaidAccountId, 3, today, { pending: true }),
      ],
      removed: ["b-pend"],
    });
    await runAllProjectionJobs(sql);
    await applyTransactions(sql, user, b.itemId, {
      added: [txn("b-settled-2", b.plaidAccountId, 3, tomorrow, { pendingTransactionId: "b-pend-2" })],
      removed: ["b-pend-2"],
    });
    await runAllProjectionJobs(sql);

    for (const id of ["b-same-day", "b-old-late", "b-future", "b-settled", "b-settled-2", "b-unreconciled"]) {
      await ambiguous(sql, b.itemId, id);
    }
    await suppressed(sql, b.itemId, "b-old");
    await suppressed(sql, b.itemId, "b-just-before");
    assertEquals((await projectionState(sql, b.itemId, "b-pend")).state, "removed_inactive");
    assertEquals((await projectionState(sql, b.itemId, "b-pend-2")).state, "removed_inactive");
    const [link1] = await sql`
      select settled.replaced_pending_projection_id = pending.id as linked
      from public.plaid_transaction_operation_projections settled
      join public.plaid_transaction_operation_projections pending
        on pending.plaid_item_id = settled.plaid_item_id and pending.plaid_transaction_id = 'b-pend'
      where settled.plaid_item_id = ${b.itemId}::uuid and settled.plaid_transaction_id = 'b-settled'`;
    assertEquals(link1.linked, true, "pending -> posted provenance is preserved");
    assertEquals(await plaidOperationsOn(sql, b.accountId), 0);
    assertEquals((await projectionState(sql, a.itemId, "a-pend")).state, "raw_pending");
    assertEquals(await projectionSnapshot(sql, a.itemId), aHistory);

    // Repeated reconcile / materialize before Delete is a no-op.
    const bFrozen = await projectionSnapshot(sql, b.itemId);
    for (let round = 0; round < 2; round++) {
      await rerunProjections(sql, user, [a.itemId, b.itemId]);
      assertEquals(await projectionSnapshot(sql, b.itemId), bFrozen);
      assertEquals(await projectionSnapshot(sql, a.itemId), aHistory);
    }

    // Delete of the frozen authority releases both classes exactly once.
    const result = await deleteItem(sql, user, a.itemId);
    assertEquals(result.status, "deleted");
    assertEquals(result.operations_deleted, 2);
    assertEquals(result.canonical_memberships_deleted, 2);
    assertEquals(result.canonical_accounts_deleted, 1);
    assertEquals(result.authority_promotions, 0);
    assertEquals(result.survivor_items_enqueued, 1);
    await runAllProjectionJobs(sql);

    const released = [
      "b-old",
      "b-just-before",
      "b-unreconciled",
      "b-same-day",
      "b-old-late",
      "b-future",
      "b-settled",
      "b-settled-2",
    ];
    for (const id of released) {
      await projected(sql, b.itemId, id);
    }
    const [{ operations, distinct_transactions }] = await sql`
      select count(*)::int as operations, count(distinct projection.plaid_transaction_id)::int as distinct_transactions
      from public.operations
      join public.plaid_transaction_operation_projections projection on projection.operation_id = operations.id
      where operations.user_id = ${user}::uuid`;
    assertEquals([operations, distinct_transactions], [released.length, released.length]);
    assertEquals(await plaidOperationsOn(sql, b.accountId), released.length);

    const bReleased = await projectionSnapshot(sql, b.itemId);
    for (let round = 0; round < 2; round++) {
      await rerunProjections(sql, user, [b.itemId]);
      assertEquals(await projectionSnapshot(sql, b.itemId), bReleased);
    }
    assertEquals(await deleteItem(sql, user, a.itemId), { status: "not_found" });
    await rerunProjections(sql, user, [b.itemId]);
    assertEquals(await projectionSnapshot(sql, b.itemId), bReleased);
  });
});

Deno.test("handoff boundary: a same-day transaction the authoritative already held is not duplicated by the survivor", options, async () => {
  await withDatabase("p23a_boundary_dup", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await linkedPair(sql, "samedup");
    const today = await utcDate(sql, 0);

    // The authoritative representation received the event before the handoff;
    // the survivor's sync lags and delivers its copy only after the handoff.
    await applyTransactions(sql, user, a.itemId, {
      added: [txn("a-same", a.plaidAccountId, 15, today, { name: "Same Store" })],
    });
    await runAllProjectionJobs(sql);
    await projected(sql, a.itemId, "a-same");

    await disconnect(sql, user, a.itemId);
    await applyTransactions(sql, user, b.itemId, {
      added: [txn("b-same", b.plaidAccountId, 15, today, { name: "Same Store" })],
    });
    await runAllProjectionJobs(sql);

    assertEquals(
      await operationFor(sql, b.itemId, "b-same"),
      null,
      "b-same duplicates a-same, which the disconnected authoritative already materialized",
    );
  });
});

Deno.test("handoff: disconnecting the secondary does not materialize its suppressed history", options, async () => {
  await withDatabase("p23a_disc_secondary", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await linkedPair(sql, "sec");
    const older = await utcDate(sql, -3);
    const today = await utcDate(sql, 0);
    await applyTransactions(sql, user, a.itemId, { added: [txn("a-hist", a.plaidAccountId, 30, older)] });
    await applyTransactions(sql, user, b.itemId, {
      added: [txn("b-hist", b.plaidAccountId, 30, older), txn("b-hist-2", b.plaidAccountId, 31, today)],
    });
    await runAllProjectionJobs(sql);
    await suppressed(sql, b.itemId, "b-hist");

    const membersBefore = await memberships(sql, user);
    assertEquals(await disconnect(sql, user, b.itemId), {
      status: "disconnected",
      canonical_authorities_frozen: 0,
      vault_secrets_deleted: 1,
      survivor_items_enqueued: 1,
    });
    assertEquals(await memberships(sql, user), membersBefore);
    await rerunProjections(sql, user, [a.itemId, b.itemId]);
    await suppressed(sql, b.itemId, "b-hist");
    await suppressed(sql, b.itemId, "b-hist-2");
    assertEquals(await plaidOperationsOn(sql, b.accountId), 0);

    // The live authoritative pipeline is not frozen.
    await projected(sql, a.itemId, "a-hist");
    await applyTransactions(sql, user, a.itemId, { added: [txn("a-new", a.plaidAccountId, 4, today)] });
    await runAllProjectionJobs(sql);
    await projected(sql, a.itemId, "a-new");
    assertEquals(await plaidOperationsOn(sql, a.accountId), 2);
  });
});

async function linkedTriple(sql: Sql, label: string) {
  const user = await createUser(sql, label);
  const a = await connection(sql, user, `${label}-a`);
  const b = await connection(sql, user, `${label}-b`);
  const c = await connection(sql, user, `${label}-c`);
  await link(sql, user, a.accountId, b.accountId, a.accountId);
  await link(sql, user, a.accountId, c.accountId, a.accountId);
  return { user, a, b, c };
}

async function assertMembershipUniqueness(sql: Sql): Promise<void> {
  const [uniqueness] = await sql`
    select
      (select max(n)::int from (
        select count(*) as n from public.plaid_canonical_financial_account_members
        where unlinked_at is null and role = 'authoritative' group by canonical_account_id) per_canonical)
        as max_active_authorities,
      (select max(n)::int from (
        select count(*) as n from public.plaid_canonical_financial_account_members
        where unlinked_at is null group by account_id) per_account) as max_active_per_account`;
  assertEquals(uniqueness, { max_active_authorities: 1, max_active_per_account: 1 });
}

Deno.test("n>=2 survivors: Disconnect promotes nobody; Delete promotes the earliest-linked secondary and releases it once", options, async () => {
  await withDatabase("p23a_promotion", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b, c } = await linkedTriple(sql, "promo");
    const older = await utcDate(sql, -3);
    const today = await utcDate(sql, 0);
    await applyTransactions(sql, user, a.itemId, { added: [txn("a-hist", a.plaidAccountId, 5, older)] });
    await applyTransactions(sql, user, b.itemId, { added: [txn("b-hist", b.plaidAccountId, 5, older)] });
    await applyTransactions(sql, user, c.itemId, { added: [txn("c-hist", c.plaidAccountId, 5, older)] });
    await runAllProjectionJobs(sql);
    const membersBefore = await memberships(sql, user);

    const disconnected = await disconnect(sql, user, a.itemId);
    assertEquals(disconnected.canonical_authorities_frozen, 1);
    assertEquals(disconnected.survivor_items_enqueued, 2);
    assertEquals(await memberships(sql, user), membersBefore);

    await applyTransactions(sql, user, b.itemId, { added: [txn("b-new", b.plaidAccountId, 6, today)] });
    await applyTransactions(sql, user, c.itemId, { added: [txn("c-new", c.plaidAccountId, 6, today)] });
    await runAllProjectionJobs(sql);
    await suppressed(sql, b.itemId, "b-hist");
    await suppressed(sql, c.itemId, "c-hist");
    await ambiguous(sql, b.itemId, "b-new");
    await ambiguous(sql, c.itemId, "c-new");

    const result = await deleteItem(sql, user, a.itemId);
    assertEquals(result.authority_promotions, 1);
    assertEquals(result.canonical_memberships_deleted, 1);
    assertEquals(result.canonical_accounts_deleted, 0);
    assertEquals(result.survivor_items_enqueued, 2);

    const rows = await memberships(sql, user);
    assertEquals(rows.filter((row) => row.active).map((row) => [row.account_id, row.role]).sort(), [
      [b.accountId, "authoritative"],
      [c.accountId, "secondary"],
    ].sort());
    assertEquals(
      rows.filter((row) => row.account_id === b.accountId).map((row) => [row.role, row.active]),
      [["secondary", false], ["authoritative", true]],
    );
    await assertMembershipUniqueness(sql);

    await runAllProjectionJobs(sql);
    await projected(sql, b.itemId, "b-hist");
    await projected(sql, b.itemId, "b-new");
    await suppressed(sql, c.itemId, "c-hist");
    await suppressed(sql, c.itemId, "c-new");
    assertEquals(await plaidOperationsOn(sql, b.accountId), 2);
    assertEquals(await plaidOperationsOn(sql, c.accountId), 0);

    const snapshot = [await projectionSnapshot(sql, b.itemId), await projectionSnapshot(sql, c.itemId)];
    await rerunProjections(sql, user, [b.itemId, c.itemId]);
    assertEquals([await projectionSnapshot(sql, b.itemId), await projectionSnapshot(sql, c.itemId)], snapshot);

    // The new authority is live: later survivor data flows normally again.
    await applyTransactions(sql, user, b.itemId, { added: [txn("b-later", b.plaidAccountId, 7, today)] });
    await applyTransactions(sql, user, c.itemId, { added: [txn("c-later", c.plaidAccountId, 7, today)] });
    await runAllProjectionJobs(sql);
    await projected(sql, b.itemId, "b-later");
    await suppressed(sql, c.itemId, "c-later");
  });
});

Deno.test("n>=2 survivors: Delete prefers a connected secondary over a disconnected one", options, async () => {
  await withDatabase("p23a_promotion_live", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b, c } = await linkedTriple(sql, "live-first");
    const older = await utcDate(sql, -3);
    await applyTransactions(sql, user, b.itemId, { added: [txn("b-hist", b.plaidAccountId, 5, older)] });
    await applyTransactions(sql, user, c.itemId, { added: [txn("c-hist", c.plaidAccountId, 5, older)] });
    await runAllProjectionJobs(sql);

    await disconnect(sql, user, a.itemId);
    await disconnect(sql, user, b.itemId);
    assertEquals((await deleteItem(sql, user, a.itemId)).authority_promotions, 1);
    const [promoted] = await sql`
      select account_id::text as account_id from public.plaid_canonical_financial_account_members
      where user_id = ${user}::uuid and role = 'authoritative' and unlinked_at is null`;
    assertEquals(promoted.account_id, c.accountId, "B was linked earlier but is disconnected");
    await assertMembershipUniqueness(sql);

    await rerunProjections(sql, user, [b.itemId, c.itemId]);
    await projected(sql, c.itemId, "c-hist");
    await suppressed(sql, b.itemId, "b-hist");
  });
});

Deno.test("n>=2 survivors: equal linked_at promotes the lowest membership id", options, async () => {
  await withDatabase("p23a_promotion_tie", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a } = await linkedTriple(sql, "tie");
    await sql`
      update public.plaid_canonical_financial_account_members
      set linked_at = '2026-09-01T00:00:00Z'
      where user_id = ${user}::uuid`;
    const [expected] = await sql`
      select account_id::text as account_id from public.plaid_canonical_financial_account_members
      where user_id = ${user}::uuid and role = 'secondary'
      order by id limit 1`;

    await disconnect(sql, user, a.itemId);
    await deleteItem(sql, user, a.itemId);
    const [promoted] = await sql`
      select account_id::text as account_id from public.plaid_canonical_financial_account_members
      where user_id = ${user}::uuid and role = 'authoritative' and unlinked_at is null`;
    assertEquals(promoted.account_id, expected.account_id);
  });
});

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

Deno.test("delete: owner removes the connection and its Plaid-derived history; others untouched; idempotent", options, async () => {
  await withDatabase("p23a_delete", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "del-owner");
    const stranger = await createUser(sql, "del-stranger");
    const conn = await connection(sql, owner, "del");
    const other = await connection(sql, owner, "del-other");
    const strangerConn = await connection(sql, stranger, "del-stranger");
    const day = await utcDate(sql, -2);
    for (const [user, c] of [[owner, conn], [owner, other], [stranger, strangerConn]] as const) {
      await applyTransactions(sql, user, c.itemId, {
        added: [txn(`${c.externalId}-1`, c.plaidAccountId, 10, day), txn(`${c.externalId}-2`, c.plaidAccountId, 0, day)],
      });
    }
    await runAllProjectionJobs(sql);
    await sql`select public.plaid_enqueue_transaction_sync_job(${conn.externalId})`;
    await sql`select public.plaid_acquire_transactions_sync_lease(
      ${owner}::uuid, ${conn.itemId}::uuid, gen_random_uuid(), 60)`;
    await enqueueProjection(sql, owner, conn.itemId);
    const [{ secret_id }] = await sql`
      select access_token_secret_id::text as secret_id from public.plaid_items where id = ${conn.itemId}::uuid`;
    const before = await itemCounts(sql, conn.itemId);
    const otherBefore = await itemCounts(sql, other.itemId);
    const strangerBefore = await itemCounts(sql, strangerConn.itemId);

    assertEquals(await deleteItem(sql, stranger, conn.itemId), { status: "not_found" });
    assertEquals(await deleteItem(sql, owner, crypto.randomUUID()), { status: "not_found" });
    assertEquals(await deleteItem(sql, owner, strangerConn.itemId), { status: "not_found" });
    assertEquals(await itemCounts(sql, conn.itemId), before);

    const result = await deleteItem(sql, owner, conn.itemId);
    assertEquals(result, {
      status: "deleted",
      accounts_deleted: 1,
      raw_transactions_deleted: 2,
      projections_deleted: 2,
      operations_deleted: 1,
      manual_operations_detached: 0,
      duplicate_resolutions_deleted: 0,
      canonical_memberships_deleted: 0,
      canonical_accounts_deleted: 0,
      authority_promotions: 0,
      plaid_items_deleted: 1,
      vault_secrets_deleted: 1,
      survivor_items_enqueued: 0,
    });
    assertEquals(await itemCounts(sql, conn.itemId), {
      items: 0,
      accounts: 0,
      raw: 0,
      projections: 0,
      projected: 0,
      sync_jobs: 0,
      sync_leases: 0,
      projection_jobs: 0,
      institutions: 0,
    });
    const [{ secrets, operations }] = await sql`
      select (select count(*)::int from vault.secrets where id = ${secret_id}::uuid) as secrets,
             (select count(*)::int from public.operations where from_account_id = ${conn.accountId}::uuid) as operations`;
    assertEquals([secrets, operations], [0, 0]);
    assertEquals(await itemCounts(sql, other.itemId), otherBefore);
    assertEquals(await itemCounts(sql, strangerConn.itemId), strangerBefore);
    assertEquals(await plaidOperationsOn(sql, other.accountId), 1);

    assertEquals(await deleteItem(sql, owner, conn.itemId), { status: "not_found" });
  });
});

Deno.test("delete after disconnect: survivor keeps its data and its hidden history materializes once", options, async () => {
  await withDatabase("p23a_delete_after", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await linkedPair(sql, "after");
    const older = await utcDate(sql, -3);
    const yesterday = await utcDate(sql, -1);
    const today = await utcDate(sql, 0);
    await applyTransactions(sql, user, a.itemId, {
      added: [txn("a-old", a.plaidAccountId, 20, older), txn("a-mid", a.plaidAccountId, 21, yesterday)],
    });
    await applyTransactions(sql, user, b.itemId, {
      added: [txn("b-old", b.plaidAccountId, 20, older), txn("b-mid", b.plaidAccountId, 21, yesterday)],
    });
    await runAllProjectionJobs(sql);
    await disconnect(sql, user, a.itemId);
    await applyTransactions(sql, user, b.itemId, {
      added: [txn("b-new", b.plaidAccountId, 22, today), txn("b-late", b.plaidAccountId, 23, yesterday)],
    });
    await runAllProjectionJobs(sql);
    await suppressed(sql, b.itemId, "b-old");
    await suppressed(sql, b.itemId, "b-mid");
    await ambiguous(sql, b.itemId, "b-new");
    await ambiguous(sql, b.itemId, "b-late");
    assertEquals(await plaidOperationsOn(sql, a.accountId), 2);
    assertEquals(await plaidOperationsOn(sql, b.accountId), 0);
    const bBefore = await itemCounts(sql, b.itemId);
    const [{ canonical_id }] = await sql`
      select canonical_account_id::text as canonical_id from public.plaid_canonical_financial_account_members
      where account_id = ${b.accountId}::uuid`;

    const result = await deleteItem(sql, user, a.itemId);
    assertEquals(result.status, "deleted");
    assertEquals(result.operations_deleted, 2);
    assertEquals(result.vault_secrets_deleted, 0);
    assertEquals(result.canonical_memberships_deleted, 2);
    assertEquals(result.canonical_accounts_deleted, 1);
    assertEquals(result.survivor_items_enqueued, 1);
    assertEquals((await itemCounts(sql, a.itemId)).items, 0);
    assertEquals((await itemCounts(sql, a.itemId)).raw, 0);
    const [{ canonicals, members }] = await sql`
      select (select count(*)::int from public.plaid_canonical_financial_accounts where id = ${canonical_id}::uuid) as canonicals,
             (select count(*)::int from public.plaid_canonical_financial_account_members
               where user_id = ${user}::uuid) as members`;
    assertEquals([canonicals, members], [0, 0]);
    assertEquals(await itemCounts(sql, b.itemId), { ...bBefore, projection_jobs: 1 });

    await runAllProjectionJobs(sql);
    for (const id of ["b-old", "b-mid", "b-new", "b-late"]) {
      await projected(sql, b.itemId, id);
    }
    const [{ operations, distinct_operations }] = await sql`
      select count(*)::int as operations, count(distinct id)::int as distinct_operations
      from public.operations where user_id = ${user}::uuid`;
    assertEquals([operations, distinct_operations], [4, 4]);

    await enqueueProjection(sql, user, b.itemId);
    await runAllProjectionJobs(sql);
    assertEquals(await plaidOperationsOn(sql, b.accountId), 4);
    assertEquals(await deleteItem(sql, user, a.itemId), { status: "not_found" });
  });
});

Deno.test("delete: duplicate resolutions in every shape are released without FK failure", options, async () => {
  await withDatabase("p23a_resolutions", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "res");
    const a = await connection(sql, user, "res-a");
    const b = await connection(sql, user, "res-b");
    const day = await utcDate(sql, -5);
    await applyTransactions(sql, user, a.itemId, {
      added: ["a-k1", "a-s1", "a-r1", "a-in1", "a-in2"].map((id, i) => txn(id, a.plaidAccountId, 10 + i, day)),
    });
    await applyTransactions(sql, user, b.itemId, {
      added: ["b-s1", "b-k1", "b-r1", "b-same1", "b-same2"].map((id, i) => txn(id, b.plaidAccountId, 10 + i, day)),
    });
    await runAllProjectionJobs(sql);
    await link(sql, user, a.accountId, b.accountId, a.accountId);
    const op = async (item: Connection, id: string) => (await operationFor(sql, item.itemId, id))!;

    await resolveDuplicate(sql, user, await op(a, "a-k1"), await op(b, "b-s1"));
    await resolveDuplicate(sql, user, await op(b, "b-k1"), await op(a, "a-s1"));
    const reversed = await resolveDuplicate(sql, user, await op(a, "a-r1"), await op(b, "b-r1"));
    await reverseResolution(sql, user, reversed.resolution_id as string);
    await resolveDuplicate(sql, user, await op(a, "a-in1"), await op(a, "a-in2"));
    const survivorOwn = await resolveDuplicate(sql, user, await op(b, "b-same1"), await op(b, "b-same2"));
    await runAllProjectionJobs(sql);

    const bOperations = Object.fromEntries(
      await Promise.all(["b-s1", "b-k1", "b-r1", "b-same1", "b-same2"].map(async (id) => [id, await op(b, id)])),
    );
    const archived = async (id: string) =>
      (await sql`select archived_at is not null as a from public.operations where id = ${bOperations[id]}::uuid`)[0].a;
    assertEquals(await archived("b-s1"), true);
    assertEquals(await archived("b-same2"), true);

    // Disconnect keeps resolutions and the memberships they were created under.
    const resolutionsBefore = [
      ...(await sql`select id, reversed_at from public.plaid_duplicate_operation_resolutions order by id`),
    ];
    await disconnect(sql, user, a.itemId);
    await runAllProjectionJobs(sql);
    assertEquals([
      ...(await sql`select id, reversed_at from public.plaid_duplicate_operation_resolutions order by id`),
    ], resolutionsBefore);
    assertEquals(await archived("b-s1"), true);

    const result = await deleteItem(sql, user, a.itemId);
    assertEquals(result.status, "deleted");
    assertEquals(result.duplicate_resolutions_deleted, 4);
    assertEquals(result.operations_deleted, 5);
    assertEquals(result.canonical_accounts_deleted, 0, "the survivor's own resolution keeps the canonical row");

    const remaining = await sql`
      select id::text as id, reversed_at is null as active from public.plaid_duplicate_operation_resolutions`;
    assertEquals([...remaining], [{ id: survivorOwn.resolution_id, active: true }]);
    const [{ members }] = await sql`
      select count(*)::int as members from public.plaid_canonical_financial_account_members`;
    assertEquals(members, 0);

    await runAllProjectionJobs(sql);
    for (const id of Object.keys(bOperations)) {
      assertEquals(await op(b, id), bOperations[id], `${id} must survive`);
    }
    assertEquals(await archived("b-s1"), false, "freeze ended with its resolution");
    assertEquals(await archived("b-k1"), false);
    assertEquals(await archived("b-r1"), false);
    assertEquals(await archived("b-same2"), true, "the survivor's own resolution still freezes it");
  });
});

Deno.test("delete: manual income and expense are detached, never deleted; the connection's Plaid history is removed", options, async () => {
  await withDatabase("p23a_manual", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "manual");
    const conn = await connection(sql, user, "manual");
    const other = await connection(sql, user, "manual-other");
    const day = await utcDate(sql, -2);
    await applyTransactions(sql, user, conn.itemId, { added: [txn("m-plaid", conn.plaidAccountId, 9, day)] });
    await applyTransactions(sql, user, other.itemId, { added: [txn("mo-plaid", other.plaidAccountId, 8, day)] });
    await runAllProjectionJobs(sql);
    const plaidOperation = await projected(sql, conn.itemId, "m-plaid");
    const otherOperation = await projected(sql, other.itemId, "mo-plaid");
    const [wallet] = await sql`
      insert into public.accounts (user_id, name, type, currency_code, icon_key, color_key)
      values (${user}::uuid, 'Wallet', 'cash', 'CAD', 'wallet', 'blue')
      returning id::text as id`;
    const manual = await sql`
      insert into public.operations (
        user_id, from_account_id, to_account_id, type, amount, currency_code, occurred_at, category_id, source
      )
      values
        (${user}::uuid, ${conn.accountId}::uuid, null, 'expense', 12.50, 'CAD', ${day}::date, 'expenseFoodGroceries', 'manual'),
        (${user}::uuid, ${conn.accountId}::uuid, null, 'income', 40.00, 'CAD', ${day}::date, 'incomeEmploymentSalary', 'manual'),
        (${user}::uuid, ${wallet.id}::uuid, null, 'expense', 3.00, 'CAD', ${day}::date, 'expenseFoodGroceries', 'manual')
      returning id::text as id`;

    const result = await deleteItem(sql, user, conn.itemId);
    assertEquals(result.status, "deleted");
    assertEquals(result.operations_deleted, 1);
    assertEquals(result.manual_operations_detached, 2);

    const kept = await sql`
      select id::text as id, type, from_account_id::text as from_account_id,
             to_account_id::text as to_account_id, amount::text as amount
      from public.operations
      where user_id = ${user}::uuid and source = 'manual'
      order by operations.amount`;
    assertEquals([...kept].map((row) => row.id).sort(), manual.map((row) => row.id).sort());
    assertEquals([...kept].map((row) => [row.type, row.from_account_id, row.to_account_id, row.amount]), [
      ["expense", wallet.id, null, "3.00"],
      ["expense", null, null, "12.50"],
      ["income", null, null, "40.00"],
    ]);
    const [{ gone, survivor }] = await sql`
      select (select count(*)::int from public.operations where id = ${plaidOperation}::uuid) as gone,
             (select count(*)::int from public.operations where id = ${otherOperation}::uuid) as survivor`;
    assertEquals([gone, survivor], [0, 1]);
    const counts = await itemCounts(sql, conn.itemId);
    assertEquals([counts.items, counts.accounts, counts.raw, counts.projections], [0, 0, 0, 0]);
    const otherCounts = await itemCounts(sql, other.itemId);
    assertEquals([otherCounts.items, otherCounts.accounts, otherCounts.raw, otherCounts.projected], [1, 1, 1, 1]);
  });
});

// ---------------------------------------------------------------------------
// Compatibility and grants
// ---------------------------------------------------------------------------

Deno.test("old plaid_remove_item_local_cleanup keeps its signature, grants, body and contract", options, async () => {
  await withDatabase("p23a_old_cleanup", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const [definition] = await sql`
      select pg_get_function_identity_arguments(p.oid) as args, pg_get_function_result(p.oid) as result,
             p.prosrc, p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'plaid_remove_item_local_cleanup'`;
    assertEquals(definition.args, "p_user_id uuid, p_connection_id uuid, p_access_token_secret_id uuid");
    assertEquals(definition.result, "jsonb");
    assertEquals(definition.prosecdef, true);
    assertEquals(definition.proconfig, ['search_path=""']);
    const text = readMigration(REMOVE_CLEANUP_MIGRATION);
    const start = text.indexOf("as $$") + "as $$".length;
    assertEquals(definition.prosrc, text.slice(start, text.indexOf("$$;", start)));

    const [privileges] = await sql`
      select
        has_function_privilege('service_role', 'public.plaid_remove_item_local_cleanup(uuid,uuid,uuid)', 'EXECUTE') as service,
        has_function_privilege('authenticated', 'public.plaid_remove_item_local_cleanup(uuid,uuid,uuid)', 'EXECUTE') as auth,
        has_function_privilege('anon', 'public.plaid_remove_item_local_cleanup(uuid,uuid,uuid)', 'EXECUTE') as anon`;
    assertEquals(privileges, { service: true, auth: false, anon: false });

    const user = await createUser(sql, "old-cleanup");
    const bare = await connection(sql, user, "old-bare");
    const [{ secret_id }] = await sql`
      select access_token_secret_id::text as secret_id from public.plaid_items where id = ${bare.itemId}::uuid`;
    const [cleanup] = await sql`
      select public.plaid_remove_item_local_cleanup(${user}::uuid, ${bare.itemId}::uuid, ${secret_id}::uuid) as r`;
    assertEquals(cleanup.r, { accounts_deleted: 1, plaid_items_deleted: 1, vault_secrets_deleted: 1 });

    // Unchanged pre-existing behavior: an Item with Operations still hits the FK.
    const busy = await connection(sql, user, "old-busy");
    await applyTransactions(sql, user, busy.itemId, {
      added: [txn("ob-1", busy.plaidAccountId, 9, await utcDate(sql, -1))],
    });
    await runAllProjectionJobs(sql);
    const [{ busy_secret }] = await sql`
      select access_token_secret_id::text as busy_secret from public.plaid_items where id = ${busy.itemId}::uuid`;
    await assertSqlState(
      () =>
        sql`select public.plaid_remove_item_local_cleanup(${user}::uuid, ${busy.itemId}::uuid, ${busy_secret}::uuid)`,
      "23503",
    );
    assertEquals((await itemCounts(sql, busy.itemId)).items, 1);
  });
});

Deno.test("connected Items keep the previous production paths (old Edge compatibility)", options, async () => {
  await withDatabase("p23a_compat", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "compat");
    const conn = await connection(sql, user, "compat");
    const [item] = await sql`
      select disconnected_at, access_token_secret_id is not null as has_secret
      from public.plaid_items where id = ${conn.itemId}::uuid`;
    assertEquals(item, { disconnected_at: null, has_secret: true });

    assertEquals((await sql`select public.plaid_enqueue_transaction_sync_job(${conn.externalId}) as r`)[0].r, {
      status: "accepted",
    });
    assertEquals(
      ((await sql`
        select public.plaid_record_item_status_observation(
          ${conn.itemId}::uuid, now(), 'login_required', 'login_required', false, null, false) as r`)[0].r as {
          applied: boolean;
        }).applied,
      true,
    );
    assertEquals(
      ((await sql`select public.plaid_set_item_access_deadline(${conn.externalId}, 'pending_disconnect', now()) as r`)[0]
        .r as { status: string }).status,
      "applied",
    );
    assertEquals(
      (await sql`select connection_id::text as id from public.plaid_list_items_for_health_reconcile(10)`).map((row) =>
        row.id
      ),
      [conn.itemId],
    );
    assert(
      (await sql`select public.plaid_get_access_token_for_item(${user}::uuid, ${conn.itemId}::uuid) as t`)[0].t
        .startsWith("access-sandbox-"),
    );
    await applyTransactions(sql, user, conn.itemId, {
      added: [txn("cp-1", conn.plaidAccountId, 9, await utcDate(sql, -1))],
    });
    await runAllProjectionJobs(sql);
    await projected(sql, conn.itemId, "cp-1");
  });
});

Deno.test("lifecycle RPCs and helpers are service-role only", options, async () => {
  await withDatabase("p23a_grants", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const functions = [
      "public.plaid_disconnect_item_local(uuid,uuid)",
      "public.plaid_delete_item_local(uuid,uuid)",
      "public.plaid_lifecycle_recalculate_canonical_authority(uuid,uuid[])",
      "public.plaid_raw_canonical_suppressed(uuid,uuid)",
      "public.plaid_canonical_suppression_reason(uuid,uuid,text)",
    ];
    for (const fn of functions) {
      const [row] = await sql`
        select has_function_privilege('service_role', ${fn}, 'EXECUTE') as service,
               has_function_privilege('authenticated', ${fn}, 'EXECUTE') as auth,
               has_function_privilege('anon', ${fn}, 'EXECUTE') as anon`;
      assertEquals(row, { service: true, auth: false, anon: false }, fn);
    }
    const [health] = await sql`
      select has_function_privilege('authenticated', 'public.plaid_list_connection_health()', 'EXECUTE') as auth,
             has_function_privilege('anon', 'public.plaid_list_connection_health()', 'EXECUTE') as anon`;
    assertEquals(health, { auth: true, anon: false });

    const user = await createUser(sql, "grant-user");
    const conn = await connection(sql, user, "grant");
    for (const call of [
      (tx: Sql) => tx`select public.plaid_disconnect_item_local(${user}::uuid, ${conn.itemId}::uuid)`,
      (tx: Sql) => tx`select public.plaid_delete_item_local(${user}::uuid, ${conn.itemId}::uuid)`,
    ]) {
      await assertSqlState(() => asRole(sql, "authenticated", user, call), "42501");
      await assertSqlState(() => asRole(sql, "anon", null, call), "42501");
    }
    assertNotEquals((await itemCounts(sql, conn.itemId)).items, 0);
    const [{ result_columns }] = await sql`
      select pg_get_function_result('public.plaid_list_connection_health()'::regprocedure) as result_columns`;
    for (const forbidden of ["access_token", "secret", "cursor", "plaid_item_id", "user_id"]) {
      assert(!String(result_columns).includes(forbidden), `${forbidden} leaked: ${result_columns}`);
    }
  });
});

// ---------------------------------------------------------------------------
// Accounts snapshot gate: an in-flight /accounts/get refresh versus Disconnect
// ---------------------------------------------------------------------------

function refreshedSnapshot(plaidAccountId: string, balance: string): Record<string, unknown>[] {
  return [{
    plaid_account_id: plaidAccountId,
    name: "Card refreshed",
    mask: "9999",
    plaid_type: "depository",
    plaid_subtype: "checking",
    currency_code: "CAD",
    current_balance: balance,
    available_balance: balance,
    persistent_account_id: null,
  }];
}

function persistSnapshot(sql: Sql, userId: string, itemId: string, snapshot: Record<string, unknown>[]) {
  return sql`
    select public.plaid_persist_accounts_sync(
      ${userId}::uuid, ${itemId}::uuid, 'ins_refreshed', 'Refreshed Bank',
      null, null, null, now(), ${sql.json(snapshot as never)}::jsonb
    ) as synced`;
}

async function accountState(sql: Sql, itemId: string): Promise<Record<string, unknown>> {
  return {
    accounts: [
      ...(await sql`
      select id::text as id, name, mask, current_balance::text as current_balance,
             available_balance::text as available_balance, balance_fetched_at, updated_at,
             institution_id::text as institution_id
      from public.accounts where plaid_item_id = ${itemId}::uuid order by id`),
    ],
    institutions: [
      ...(await sql`
      select id::text as id, plaid_institution_id, name, updated_at
      from public.institutions where plaid_item_id = ${itemId}::uuid order by id`),
    ],
  };
}

// Test synchronization only: waits until another session is blocked on a lock.
async function waitForLockWait(observer: Sql, functionName: string): Promise<void> {
  for (let attempt = 0; attempt < 400; attempt += 1) {
    const [{ waiting }] = await observer`
      select count(*)::int as waiting from pg_stat_activity
      where datname = current_database()
        and wait_event_type = 'Lock'
        and query like ${`%${functionName}%`}`;
    if (waiting > 0) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`${functionName} never waited on a lock`);
}

Deno.test("snapshot gate: a snapshot fetched before Disconnect is refused after it; balances and history unchanged", options, async () => {
  await withDatabase("p23a_snapshot_gate", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "snapshot");
    const stranger = await createUser(sql, "snapshot-stranger");
    const conn = await connection(sql, owner, "snap");
    const day = await utcDate(sql, -1);
    await applyTransactions(sql, owner, conn.itemId, { added: [txn("s-1", conn.plaidAccountId, 15, day)] });
    await runAllProjectionJobs(sql);

    // The refresh read the token and fetched /accounts/get while the Item was connected.
    const [{ token }] = await sql`
      select public.plaid_get_access_token_for_item(${owner}::uuid, ${conn.itemId}::uuid) as token`;
    assert(String(token).startsWith("access-sandbox-"));
    const inFlight = refreshedSnapshot(conn.plaidAccountId, "555.55");

    assertEquals((await disconnect(sql, owner, conn.itemId)).status, "disconnected");
    const before = {
      state: await accountState(sql, conn.itemId),
      counts: await itemCounts(sql, conn.itemId),
      operations: await plaidOperationsOn(sql, conn.accountId),
    };

    await assertSqlState(() => persistSnapshot(sql, owner, conn.itemId, inFlight), "22023", "plaid_item_disconnected");
    await assertSqlState(() => persistSnapshot(sql, stranger, conn.itemId, inFlight), "22023", "plaid_item_not_found");

    assertEquals({
      state: await accountState(sql, conn.itemId),
      counts: await itemCounts(sql, conn.itemId),
      operations: await plaidOperationsOn(sql, conn.accountId),
    }, before);
    assertEquals((before.state.accounts as Record<string, unknown>[])[0].current_balance, "100.00");

    assertEquals((await deleteItem(sql, owner, conn.itemId)).status, "deleted");
    await assertSqlState(() => persistSnapshot(sql, owner, conn.itemId, inFlight), "22023", "plaid_item_not_found");
  });
});

Deno.test("snapshot gate: Disconnect committed first makes a waiting persist fail closed", options, async () => {
  await withDatabase("p23a_snapshot_race_a", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "race-a");
    const conn = await connection(sql, owner, "race-a");
    const before = await accountState(sql, conn.itemId);
    const refresher = db.connect();
    const observer = db.connect();

    let commitDisconnect!: () => void;
    const disconnectMayCommit = new Promise<void>((resolve) => commitDisconnect = resolve);
    let disconnectRan!: () => void;
    const disconnectHeld = new Promise<void>((resolve) => disconnectRan = resolve);
    const disconnectTx = sql.begin(async (tx) => {
      await tx`select public.plaid_disconnect_item_local(${owner}::uuid, ${conn.itemId}::uuid)`;
      disconnectRan();
      await disconnectMayCommit;
    });
    await disconnectHeld;

    const persist = persistSnapshot(refresher, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "777.77"))
      .then(() => null, (error: { code?: string; message?: string }) => error);
    await waitForLockWait(observer, "plaid_persist_accounts_sync");

    commitDisconnect();
    await disconnectTx;
    const error = await persist;
    assertEquals(error?.code, "22023");
    assertEquals(error?.message, "plaid_item_disconnected");
    assertEquals(await accountState(sql, conn.itemId), before);
  });
});

Deno.test("snapshot gate: a persist committed first is ordered before the waiting Disconnect", options, async () => {
  await withDatabase("p23a_snapshot_race_b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "race-b");
    const conn = await connection(sql, owner, "race-b");
    const refresher = db.connect();
    const observer = db.connect();

    let commitPersist!: () => void;
    const persistMayCommit = new Promise<void>((resolve) => commitPersist = resolve);
    let persistRan!: () => void;
    const persistHeld = new Promise<void>((resolve) => persistRan = resolve);
    const persistTx = refresher.begin(async (tx) => {
      await persistSnapshot(tx as unknown as Sql, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "888.88"));
      persistRan();
      await persistMayCommit;
    });
    await persistHeld;

    const disconnectCall = disconnect(sql, owner, conn.itemId);
    await waitForLockWait(observer, "plaid_disconnect_item_local");

    commitPersist();
    await persistTx;
    assertEquals((await disconnectCall).status, "disconnected");

    const after = await accountState(sql, conn.itemId);
    assertEquals((after.accounts as Record<string, unknown>[])[0].current_balance, "888.88");
    await assertSqlState(
      () => persistSnapshot(sql, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "999.99")),
      "22023",
      "plaid_item_disconnected",
    );
    assertEquals(await accountState(sql, conn.itemId), after);
  });
});

Deno.test("snapshot gate: connected Items persist as before; signature and grants unchanged", options, async () => {
  await withDatabase("p23a_snapshot_compat", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "snap-compat");
    const conn = await connection(sql, owner, "snap-compat");
    const other = await connection(sql, owner, "snap-other");
    await disconnect(sql, owner, other.itemId);

    const [{ synced }] = await persistSnapshot(sql, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "321.09"));
    assertEquals(synced, 1);
    const state = await accountState(sql, conn.itemId);
    const [account] = state.accounts as Record<string, unknown>[];
    assertEquals(account.current_balance, "321.09");
    assertEquals(account.name, "Card refreshed");
    assertEquals((state.institutions as Record<string, unknown>[])[0].name, "Refreshed Bank");

    const [definition] = await sql`
      select pg_get_function_identity_arguments(p.oid) as args, pg_get_function_result(p.oid) as result,
             p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'plaid_persist_accounts_sync'`;
    assertEquals(
      definition.args,
      "p_user_id uuid, p_connection_id uuid, p_plaid_institution_id text, p_institution_name text, " +
        "p_logo_base64 text, p_primary_color text, p_url text, p_balance_fetched_at timestamp with time zone, " +
        "p_accounts jsonb",
    );
    assertEquals(definition.result, "integer");
    assertEquals(definition.prosecdef, true);
    assertEquals(definition.proconfig, ['search_path=""']);
    const signature = "public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)";
    const [privileges] = await sql`
      select has_function_privilege('service_role', ${signature}, 'EXECUTE') as service,
             has_function_privilege('authenticated', ${signature}, 'EXECUTE') as auth,
             has_function_privilege('anon', ${signature}, 'EXECUTE') as anon`;
    assertEquals(privileges, { service: true, auth: false, anon: false });
  });
});

// ---------------------------------------------------------------------------
// Lock order: accounts persist versus lifecycle of a canonically linked Item
// ---------------------------------------------------------------------------

const DEADLOCK = "40P01";

interface Outcome {
  value: unknown;
  code: string | null;
  message: string | null;
}

function outcome(promise: Promise<unknown>): Promise<Outcome> {
  return promise.then(
    (value) => ({ value, code: null, message: null }),
    (error: { code?: string; message?: string }) => ({
      value: null,
      code: error.code ?? "unknown",
      message: error.message ?? null,
    }),
  );
}

// Session with a bounded lock wait, so a broken lock order fails the test instead of hanging it.
async function boundedSession(db: { connect(): Sql }): Promise<Sql> {
  const session = db.connect();
  await session.unsafe("set lock_timeout = '20s'");
  return session;
}

// Test synchronization only: `hold` keeps a row lock while `first` and then `second`
// start and block on locks; the row is released only after both are observed waiting.
async function raceBehindHeldRow(
  db: { connect(): Sql },
  hold: (tx: Sql) => Promise<unknown>,
  first: { needle: string; run: (session: Sql) => Promise<unknown> },
  second: { needle: string; run: (session: Sql) => Promise<unknown> },
): Promise<{ first: Outcome; second: Outcome }> {
  const holder = db.connect();
  const firstSession = await boundedSession(db);
  const secondSession = await boundedSession(db);
  const observer = db.connect();

  let release!: () => void;
  const mayRelease = new Promise<void>((resolve) => release = resolve);
  let held!: () => void;
  const isHeld = new Promise<void>((resolve) => held = resolve);
  const holderTx = holder.begin(async (tx) => {
    await hold(tx as unknown as Sql);
    held();
    await mayRelease;
  });
  try {
    await isHeld;
    const firstOutcome = outcome(first.run(firstSession));
    await waitForLockWait(observer, first.needle);
    const secondOutcome = outcome(second.run(secondSession));
    await waitForLockWait(observer, second.needle);
    release();
    await holderTx;
    return { first: await firstOutcome, second: await secondOutcome };
  } finally {
    release();
    await holderTx.catch(() => undefined);
  }
}

function assertNoDeadlock(result: { first: Outcome; second: Outcome }): void {
  assertNotEquals(result.first.code, DEADLOCK, result.first.message ?? undefined);
  assertNotEquals(result.second.code, DEADLOCK, result.second.message ?? undefined);
}

interface CanonicalTwins {
  user: string;
  itemA: string;
  itemB: string;
  a: Record<string, string>;
  b: Record<string, string>;
  // plaid_account_id of Item A's accounts by account id order.
  lo: string;
  hi: string;
}

// Two Items of the same bank: A1 ~ B1 and A2 ~ B2, B authoritative.
async function canonicalTwins(sql: Sql, label: string): Promise<CanonicalTwins> {
  const user = await createUser(sql, label);
  const itemA = await createPlaidItem(sql, user, `item-${label}-a`);
  const itemB = await createPlaidItem(sql, user, `item-${label}-b`);
  const a = await syncAccounts(sql, user, itemA, [
    { plaidAccountId: `${label}-a1`, name: "A1" },
    { plaidAccountId: `${label}-a2`, name: "A2" },
  ]);
  const b = await syncAccounts(sql, user, itemB, [
    { plaidAccountId: `${label}-b1`, name: "B1" },
    { plaidAccountId: `${label}-b2`, name: "B2" },
  ]);
  await link(sql, user, a[`${label}-a1`], b[`${label}-b1`], b[`${label}-b1`]);
  await link(sql, user, a[`${label}-a2`], b[`${label}-b2`], b[`${label}-b2`]);
  const [lo, hi] = a[`${label}-a1`] < a[`${label}-a2`]
    ? [`${label}-a1`, `${label}-a2`]
    : [`${label}-a2`, `${label}-a1`];
  return { user, itemA, itemB, a, b, lo, hi };
}

function snapshotOf(plaidAccountIds: string[], balance: string): Record<string, unknown>[] {
  return plaidAccountIds.flatMap((plaidAccountId) => refreshedSnapshot(plaidAccountId, balance));
}

async function balances(sql: Sql, itemId: string): Promise<Record<string, string>> {
  const rows = await sql`
    select plaid_account_id, current_balance::text as balance
    from public.accounts where plaid_item_id = ${itemId}::uuid`;
  return Object.fromEntries(rows.map((row) => [row.plaid_account_id, row.balance]));
}

async function activeMemberships(sql: Sql, userId: string): Promise<number> {
  const [{ count }] = await sql`
    select count(*)::int as count from public.plaid_canonical_financial_account_members
    where user_id = ${userId}::uuid and unlinked_at is null`;
  return count;
}

const holdAccount = (accountId: string) => (tx: Sql) =>
  tx`select 1 from public.accounts where id = ${accountId}::uuid for update`;

// Payload [hi, lo] is against account id order: before the id-ordered pre-lock the
// persist took hi, the lifecycle took lo (id order) and each then waited for the other.
function reverseOrderPersist(twins: CanonicalTwins, balance: string) {
  return {
    needle: "plaid_persist_accounts_sync",
    run: (session: Sql) => persistSnapshot(session, twins.user, twins.itemA, snapshotOf([twins.hi, twins.lo], balance)),
  };
}

Deno.test("lock order: reverse payload persist vs Disconnect of the canonical twin Item does not deadlock", options, async () => {
  await withDatabase("p23a_lock_rev_disconnect", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const twins = await canonicalTwins(sql, "rev-disc");

    const result = await raceBehindHeldRow(db, holdAccount(twins.a[twins.hi]), reverseOrderPersist(twins, "201.00"), {
      needle: "plaid_disconnect_item_local",
      run: (session) => disconnect(session, twins.user, twins.itemB),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals((result.second.value as Record<string, unknown>).status, "disconnected");
    assertEquals(await balances(sql, twins.itemA), { [twins.lo]: "201.00", [twins.hi]: "201.00" });
    assertEquals(Object.values(await balances(sql, twins.itemB)), ["100.00", "100.00"]);
    const [items] = await sql`
      select (select disconnected_at is null from public.plaid_items where id = ${twins.itemA}::uuid) as a_connected,
             (select disconnected_at is not null from public.plaid_items where id = ${twins.itemB}::uuid) as b_disconnected`;
    assertEquals(items, { a_connected: true, b_disconnected: true });
    assertEquals(await activeMemberships(sql, twins.user), 4);
    await assertSqlState(
      () => persistSnapshot(sql, twins.user, twins.itemB, snapshotOf(Object.keys(twins.b), "999.99")),
      "22023",
      "plaid_item_disconnected",
    );
  });
});

Deno.test("lock order: reverse payload persist vs Delete of the active canonical twin Item does not deadlock", options, async () => {
  await withDatabase("p23a_lock_rev_delete", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const twins = await canonicalTwins(sql, "rev-del");

    const result = await raceBehindHeldRow(db, holdAccount(twins.a[twins.hi]), reverseOrderPersist(twins, "202.00"), {
      needle: "plaid_delete_item_local",
      run: (session) => deleteItem(session, twins.user, twins.itemB),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals((result.second.value as Record<string, unknown>).status, "deleted");
    assertEquals(await balances(sql, twins.itemA), { [twins.lo]: "202.00", [twins.hi]: "202.00" });
    const counts = await itemCounts(sql, twins.itemB);
    assertEquals([counts.items, counts.accounts], [0, 0]);
    assertEquals(await activeMemberships(sql, twins.user), 0);
  });
});

Deno.test("lock order: reverse payload persist vs Delete of a disconnected canonical twin Item does not deadlock; late persist cannot revive it", options, async () => {
  await withDatabase("p23a_lock_rev_delete_disc", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const twins = await canonicalTwins(sql, "rev-deld");
    assertEquals((await disconnect(sql, twins.user, twins.itemB)).status, "disconnected");

    const result = await raceBehindHeldRow(db, holdAccount(twins.a[twins.hi]), reverseOrderPersist(twins, "203.00"), {
      needle: "plaid_delete_item_local",
      run: (session) => deleteItem(session, twins.user, twins.itemB),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals((result.second.value as Record<string, unknown>).status, "deleted");
    assertEquals(await balances(sql, twins.itemA), { [twins.lo]: "203.00", [twins.hi]: "203.00" });
    assertEquals(await activeMemberships(sql, twins.user), 0);

    await assertSqlState(
      () => persistSnapshot(sql, twins.user, twins.itemB, snapshotOf(Object.keys(twins.b), "999.99")),
      "22023",
      "plaid_item_not_found",
    );
    const [{ revived }] = await sql`
      select count(*)::int as revived from public.accounts
      where user_id = ${twins.user}::uuid and plaid_account_id = any(${Object.keys(twins.b)}::text[])`;
    assertEquals(revived, 0);
  });
});

Deno.test("lock order: payload already in account id order keeps plain blocking (control)", options, async () => {
  await withDatabase("p23a_lock_fwd_control", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const twins = await canonicalTwins(sql, "fwd");

    const result = await raceBehindHeldRow(db, holdAccount(twins.a[twins.hi]), {
      needle: "plaid_persist_accounts_sync",
      run: (session) => persistSnapshot(session, twins.user, twins.itemA, snapshotOf([twins.lo, twins.hi], "204.00")),
    }, {
      needle: "plaid_disconnect_item_local",
      run: (session) => disconnect(session, twins.user, twins.itemB),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals(await balances(sql, twins.itemA), { [twins.lo]: "204.00", [twins.hi]: "204.00" });
  });
});

// The lifecycle of B holds A1 (canonical member) and then enqueues a projection job for
// survivor Item A; the INSERT's FK check takes KEY SHARE on plaid_items A while the
// persist of A holds its Item lock and waits for A1.
async function survivorWithoutProjectionJob(sql: Sql, label: string) {
  const user = await createUser(sql, label);
  const a = await connection(sql, user, `${label}-a`);
  const b = await connection(sql, user, `${label}-b`);
  await link(sql, user, a.accountId, b.accountId, b.accountId);
  const [{ jobs }] = await sql`
    select count(*)::int as jobs from public.plaid_transaction_projection_jobs
    where plaid_item_id = ${a.itemId}::uuid`;
  assertEquals(jobs, 0);
  return { user, a, b };
}

async function projectionJobs(sql: Sql, itemId: string): Promise<number> {
  const [{ jobs }] = await sql`
    select count(*)::int as jobs from public.plaid_transaction_projection_jobs
    where plaid_item_id = ${itemId}::uuid`;
  return jobs;
}

Deno.test("lock order: Disconnect enqueueing the survivor Item does not deadlock with its persist (FK KEY SHARE)", options, async () => {
  await withDatabase("p23a_lock_fk_disconnect", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await survivorWithoutProjectionJob(sql, "fk-disc");

    // Disconnect stops at the token delete, after its account locks and before the enqueue.
    const result = await raceBehindHeldRow(db, (tx) =>
      tx`select 1 from vault.secrets
         where id = (select access_token_secret_id from public.plaid_items where id = ${b.itemId}::uuid)
         for update`, {
      needle: "plaid_disconnect_item_local",
      run: (session) => disconnect(session, user, b.itemId),
    }, {
      needle: "plaid_persist_accounts_sync",
      run: (session) => persistSnapshot(session, user, a.itemId, refreshedSnapshot(a.plaidAccountId, "301.00")),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals((result.first.value as Record<string, unknown>).survivor_items_enqueued, 1);
    assertEquals(await projectionJobs(sql, a.itemId), 1);
    assertEquals(await balances(sql, a.itemId), { [a.plaidAccountId]: "301.00" });
  });
});

Deno.test("lock order: Delete enqueueing the survivor Item does not deadlock with its persist (FK KEY SHARE)", options, async () => {
  await withDatabase("p23a_lock_fk_delete", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const { user, a, b } = await survivorWithoutProjectionJob(sql, "fk-del");

    // Delete stops at the membership delete, after its account locks and before the enqueue.
    const result = await raceBehindHeldRow(db, (tx) =>
      tx`select 1 from public.plaid_canonical_financial_account_members
         where account_id = ${b.accountId}::uuid for update`, {
      needle: "plaid_delete_item_local",
      run: (session) => deleteItem(session, user, b.itemId),
    }, {
      needle: "plaid_persist_accounts_sync",
      run: (session) => persistSnapshot(session, user, a.itemId, refreshedSnapshot(a.plaidAccountId, "302.00")),
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals((result.first.value as Record<string, unknown>).status, "deleted");
    assertEquals((result.first.value as Record<string, unknown>).survivor_items_enqueued, 1);
    assertEquals(await projectionJobs(sql, a.itemId), 1);
    assertEquals(await balances(sql, a.itemId), { [a.plaidAccountId]: "302.00" });
  });
});

// Test synchronization only: returns once `pending` settled or `functionName` waits on a lock.
async function settledOrLockWait(observer: Sql, pending: Promise<unknown>, functionName: string): Promise<void> {
  let settled = false;
  pending.finally(() => settled = true);
  for (let attempt = 0; attempt < 400; attempt += 1) {
    if (settled) {
      return;
    }
    const [{ waiting }] = await observer`
      select count(*)::int as waiting from pg_stat_activity
      where datname = current_database()
        and wait_event_type = 'Lock'
        and query like ${`%${functionName}%`}`;
    if (waiting > 0) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`${functionName} neither finished nor waited on a lock`);
}

// An authenticated client writes manual expenses on two accounts of the Item in one
// transaction (account hi, then lo). Each FK check takes KEY SHARE on its account.
// A FOR UPDATE pre-lock takes lo, waits for hi, and the second write then waits for
// lo; the FOR NO KEY UPDATE pre-lock does not conflict with KEY SHARE.
Deno.test("lock order: persist vs an Operation write referencing two accounts of the Item does not deadlock (FK KEY SHARE)", options, async () => {
  await withDatabase("p23a_lock_fk_operations", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    await sql`grant select, insert, update, delete on table public.operations to authenticated`;
    const user = await createUser(sql, "fk-ops");
    const itemId = await createPlaidItem(sql, user, "item-fk-ops");
    const accounts = await syncAccounts(sql, user, itemId, [
      { plaidAccountId: "fk-ops-1", name: "O1" },
      { plaidAccountId: "fk-ops-2", name: "O2" },
    ]);
    const [lo, hi] = accounts["fk-ops-1"] < accounts["fk-ops-2"]
      ? ["fk-ops-1", "fk-ops-2"]
      : ["fk-ops-2", "fk-ops-1"];
    const day = await utcDate(sql, -1);
    const writer = await boundedSession(db);
    const refresher = await boundedSession(db);
    const observer = db.connect();

    const manualExpense = (tx: Sql, accountId: string) =>
      tx`
        insert into public.operations (
          user_id, from_account_id, type, amount, currency_code, occurred_at, category_id, source
        )
        values (${user}::uuid, ${accountId}::uuid, 'expense', 5.00, 'CAD', ${day}::date, 'expenseFoodGroceries', 'manual')`;

    let mayContinue!: () => void;
    const continued = new Promise<void>((resolve) => mayContinue = resolve);
    let firstWritten!: () => void;
    const isFirstWritten = new Promise<void>((resolve) => firstWritten = resolve);
    const write = outcome(writer.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub', ${user}, true)`;
      await tx.unsafe("set local role authenticated");
      await manualExpense(tx as unknown as Sql, accounts[hi]);
      firstWritten();
      await continued;
      await manualExpense(tx as unknown as Sql, accounts[lo]);
    }));
    await Promise.race([isFirstWritten, write]);

    const persist = outcome(persistSnapshot(refresher, user, itemId, snapshotOf([lo, hi], "501.00")));
    await settledOrLockWait(observer, persist, "plaid_persist_accounts_sync");
    mayContinue();
    const result = { first: await write, second: await persist };

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    assertEquals(await balances(sql, itemId), { [lo]: "501.00", [hi]: "501.00" });
    const [{ manual }] = await sql`
      select count(*)::int as manual from public.operations
      where user_id = ${user}::uuid and source = 'manual'
        and from_account_id = any(${[accounts[lo], accounts[hi]]}::uuid[])`;
    assertEquals(manual, 2);
  });
});

Deno.test("lock order: reverse payload persist vs materialize of the same Item does not deadlock", options, async () => {
  await withDatabase("p23a_lock_rev_materialize", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "rev-mat");
    const itemId = await createPlaidItem(sql, user, "item-rev-mat");
    const accounts = await syncAccounts(sql, user, itemId, [
      { plaidAccountId: "rev-mat-1", name: "M1" },
      { plaidAccountId: "rev-mat-2", name: "M2" },
    ]);
    const [lo, hi] = accounts["rev-mat-1"] < accounts["rev-mat-2"]
      ? ["rev-mat-1", "rev-mat-2"]
      : ["rev-mat-2", "rev-mat-1"];
    const day = await utcDate(sql, -1);
    await applyTransactions(sql, user, itemId, {
      added: [txn("m-1", "rev-mat-1", 11, day), txn("m-2", "rev-mat-2", 12, day)],
    });
    const [job] = await sql`
      select connection_id::text as item_id, lease_token::text as lease_token
      from public.plaid_claim_transaction_projection_jobs(5, 600)`;
    assertEquals(job.item_id, itemId);
    await sql`
      select public.plaid_reconcile_transaction_operation_projections(
        ${user}::uuid, ${itemId}::uuid, ${job.lease_token}::uuid, 250)`;

    const result = await raceBehindHeldRow(db, holdAccount(accounts[hi]), {
      needle: "plaid_persist_accounts_sync",
      run: (session) => persistSnapshot(session, user, itemId, snapshotOf([hi, lo], "401.00")),
    }, {
      needle: "plaid_materialize_transaction_operations",
      run: (session) =>
        session`select public.plaid_materialize_transaction_operations(
          ${user}::uuid, ${itemId}::uuid, ${job.lease_token}::uuid, 100) as r`,
    });

    assertNoDeadlock(result);
    assertEquals([result.first.code, result.second.code], [null, null]);
    const [{ r }] = result.second.value as { r: Record<string, unknown> }[];
    assertEquals(r.materialized, 2);
    assertEquals(await balances(sql, itemId), { [lo]: "401.00", [hi]: "401.00" });
  });
});

Deno.test("snapshot gate: Delete committed first makes a waiting persist fail closed without reviving data", options, async () => {
  await withDatabase("p23a_snapshot_delete_a", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "del-race-a");
    const conn = await connection(sql, owner, "del-race-a");
    const refresher = await boundedSession(db);
    const observer = db.connect();

    let commitDelete!: () => void;
    const deleteMayCommit = new Promise<void>((resolve) => commitDelete = resolve);
    let deleteRan!: () => void;
    const deleteHeld = new Promise<void>((resolve) => deleteRan = resolve);
    const deleteTx = sql.begin(async (tx) => {
      await tx`select public.plaid_delete_item_local(${owner}::uuid, ${conn.itemId}::uuid)`;
      deleteRan();
      await deleteMayCommit;
    });
    await deleteHeld;

    const persist = outcome(persistSnapshot(refresher, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "777.77")));
    await waitForLockWait(observer, "plaid_persist_accounts_sync");

    commitDelete();
    await deleteTx;
    const result = await persist;
    assertEquals([result.code, result.message], ["22023", "plaid_item_not_found"]);
    const [counts] = await sql`
      select (select count(*)::int from public.plaid_items where id = ${conn.itemId}::uuid) as items,
             (select count(*)::int from public.accounts
               where user_id = ${owner}::uuid and plaid_account_id = ${conn.plaidAccountId}) as accounts,
             (select count(*)::int from public.institutions where plaid_item_id = ${conn.itemId}::uuid) as institutions`;
    assertEquals(counts, { items: 0, accounts: 0, institutions: 0 });
  });
});

Deno.test("snapshot gate: a persist committed first is ordered before the waiting Delete", options, async () => {
  await withDatabase("p23a_snapshot_delete_b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "del-race-b");
    const conn = await connection(sql, owner, "del-race-b");
    const refresher = db.connect();
    const observer = db.connect();

    let commitPersist!: () => void;
    const persistMayCommit = new Promise<void>((resolve) => commitPersist = resolve);
    let persistRan!: () => void;
    const persistHeld = new Promise<void>((resolve) => persistRan = resolve);
    const persistTx = refresher.begin(async (tx) => {
      await persistSnapshot(tx as unknown as Sql, owner, conn.itemId, refreshedSnapshot(conn.plaidAccountId, "888.88"));
      persistRan();
      await persistMayCommit;
    });
    await persistHeld;

    const deleteCall = outcome(deleteItem(await boundedSession(db), owner, conn.itemId));
    await waitForLockWait(observer, "plaid_delete_item_local");

    commitPersist();
    await persistTx;
    const deleted = await deleteCall;
    assertEquals(deleted.code, null);
    assertEquals((deleted.value as Record<string, unknown>).status, "deleted");
    assertEquals((await itemCounts(sql, conn.itemId)).accounts, 0);
  });
});

Deno.test("persist pre-lock: empty, duplicate, new and invalid payload accounts keep the previous behavior", options, async () => {
  await withDatabase("p23a_prelock_payloads", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "prelock");
    const conn = await connection(sql, owner, "prelock");

    assertEquals((await persistSnapshot(sql, owner, conn.itemId, []))[0].synced, 0);

    const duplicate = [...refreshedSnapshot(conn.plaidAccountId, "10.00"), ...refreshedSnapshot(conn.plaidAccountId, "20.00")];
    assertEquals((await persistSnapshot(sql, owner, conn.itemId, duplicate))[0].synced, 2);
    assertEquals(await balances(sql, conn.itemId), { [conn.plaidAccountId]: "20.00" });

    const withNew = [...refreshedSnapshot(conn.plaidAccountId, "30.00"), ...refreshedSnapshot("prelock-new", "40.00")];
    assertEquals((await persistSnapshot(sql, owner, conn.itemId, withNew))[0].synced, 2);
    assertEquals(await balances(sql, conn.itemId), { [conn.plaidAccountId]: "30.00", "prelock-new": "40.00" });

    for (const plaidAccountId of [null, "", "   "]) {
      const invalid = [{ ...refreshedSnapshot(conn.plaidAccountId, "50.00")[0], plaid_account_id: plaidAccountId }];
      await assertSqlState(
        () => persistSnapshot(sql, owner, conn.itemId, invalid),
        "22023",
        "invalid_plaid_account_payload",
      );
    }
    assertEquals(await balances(sql, conn.itemId), { [conn.plaidAccountId]: "30.00", "prelock-new": "40.00" });
  });
});

// ---------------------------------------------------------------------------
// Operations integrity (20261003160000): manual Operations are income or expense
// only; every referenced account belongs to the Operation's user.
// ---------------------------------------------------------------------------

const INTEGRITY_MIGRATION = "20261003160000_operations_manual_integrity.sql";
const CHECK_VIOLATION = "23514";
const FK_VIOLATION = "23503";

async function assertViolation(promise: () => Promise<unknown>, code: string, constraint: string): Promise<void> {
  const error = await assertRejects(promise) as { code?: string; constraint_name?: string; message?: string };
  assertEquals([error.code, error.constraint_name], [code, constraint], error.message);
}

// Supabase grants table privileges to authenticated by default; RLS decides.
async function grantOperationsToAuthenticated(sql: Sql): Promise<void> {
  await sql`grant select, insert, update, delete on table public.operations to authenticated`;
}

async function manualAccount(sql: Sql, userId: string, name: string): Promise<string> {
  const [row] = await sql`
    insert into public.accounts (user_id, name, type, currency_code, icon_key, color_key)
    values (${userId}::uuid, ${name}, 'cash', 'CAD', 'wallet', 'blue')
    returning id::text as id`;
  return row.id;
}

interface OperationInput {
  userId: string;
  type: "income" | "expense" | "transfer";
  from?: string | null;
  to?: string | null;
  source?: "manual" | "plaid";
}

function insertOperation(sql: Sql, input: OperationInput) {
  const category = input.type === "transfer"
    ? null
    : input.type === "income"
    ? "incomeEmploymentSalary"
    : "expenseFoodGroceries";
  return sql`
    insert into public.operations (
      user_id, from_account_id, to_account_id, type, amount, currency_code, occurred_at, category_id, source
    )
    values (
      ${input.userId}::uuid, ${input.from ?? null}::uuid, ${input.to ?? null}::uuid, ${input.type},
      10.00, 'CAD', '2026-10-01', ${category}, ${input.source ?? "manual"}
    )
    returning id::text as id`;
}

Deno.test("integrity: constraints replace the single-column account FKs with the same delete semantics", options, async () => {
  await withDatabase("p23a_ops_constraints", async (db) => {
    await applyAllMigrations(db.sql);
    const rows = await db.sql`
      select conname, convalidated, pg_get_constraintdef(oid) as def
      from pg_constraint
      where conrelid = 'public.operations'::regclass
        and conname in (
          'operations_manual_income_expense_check', 'operations_from_account_user_fkey',
          'operations_to_account_user_fkey', 'operations_account_id_fkey', 'operations_to_account_id_fkey',
          'operations_type_check', 'operations_transfer_check'
        )`;
    const byName = Object.fromEntries(rows.map((row) => [row.conname, row]));

    assertEquals(Object.keys(byName).sort(), [
      "operations_from_account_user_fkey",
      "operations_manual_income_expense_check",
      "operations_to_account_user_fkey",
      "operations_transfer_check",
      "operations_type_check",
    ]);
    assertEquals(
      byName.operations_from_account_user_fkey.def,
      "FOREIGN KEY (from_account_id, user_id) REFERENCES accounts(id, user_id) ON DELETE RESTRICT",
    );
    assertEquals(
      byName.operations_to_account_user_fkey.def,
      "FOREIGN KEY (to_account_id, user_id) REFERENCES accounts(id, user_id) ON DELETE RESTRICT",
    );
    assertEquals(
      byName.operations_manual_income_expense_check.def,
      "CHECK (((source <> 'manual'::text) OR ((type = ANY (ARRAY['income'::text, 'expense'::text])) AND (to_account_id IS NULL))))",
    );
    for (const name of ["operations_manual_income_expense_check", "operations_from_account_user_fkey", "operations_to_account_user_fkey"]) {
      assertEquals(byName[name].convalidated, true, name);
    }
    assertEquals(
      byName.operations_type_check.def,
      "CHECK ((type = ANY (ARRAY['expense'::text, 'income'::text, 'transfer'::text])))",
    );
  });
});

Deno.test("integrity: manual income and expense are allowed; a manual transfer is rejected on insert and on update", options, async () => {
  await withDatabase("p23a_ops_manual", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    await grantOperationsToAuthenticated(sql);
    const user = await createUser(sql, "ops-manual");
    const cash = await manualAccount(sql, user, "Cash");
    const savings = await manualAccount(sql, user, "Savings");

    const allowed = await asRole(sql, "authenticated", user, async (tx) => [
      ...(await insertOperation(tx, { userId: user, type: "income" })),
      ...(await insertOperation(tx, { userId: user, type: "expense" })),
      ...(await insertOperation(tx, { userId: user, type: "expense", from: cash })),
    ]);
    assertEquals(allowed.length, 3);

    // from <> to and no category: operations_transfer_check alone would accept it.
    await assertViolation(
      () => asRole(sql, "authenticated", user, (tx) => insertOperation(tx, { userId: user, type: "transfer", from: cash, to: savings })),
      CHECK_VIOLATION,
      "operations_manual_income_expense_check",
    );
    await assertViolation(
      () => insertOperation(sql, { userId: user, type: "transfer", from: cash, to: savings }),
      CHECK_VIOLATION,
      "operations_manual_income_expense_check",
    );

    const expenseId = allowed[2].id;
    await assertViolation(
      () =>
        asRole(sql, "authenticated", user, (tx) =>
          tx`
            update public.operations
            set type = 'transfer', category_id = null, to_account_id = ${savings}::uuid
            where id = ${expenseId}::uuid`),
      CHECK_VIOLATION,
      "operations_manual_income_expense_check",
    );

    const switched = await asRole(sql, "authenticated", user, (tx) =>
      tx`
        update public.operations
        set type = 'income', category_id = 'incomeEmploymentSalary'
        where id = ${expenseId}::uuid
        returning type, from_account_id::text as from_account_id, to_account_id`);
    assertEquals([...switched], [{ type: "income", from_account_id: cash, to_account_id: null }]);

    const [{ transfers }] = await sql`
      select count(*)::int as transfers from public.operations where type = 'transfer'`;
    assertEquals(transfers, 0);
  });
});

Deno.test("integrity: a system transfer between accounts of one user remains representable", options, async () => {
  await withDatabase("p23a_ops_system_transfer", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "ops-system");
    const stranger = await createUser(sql, "ops-system-stranger");
    const cash = await manualAccount(sql, user, "Cash");
    const savings = await manualAccount(sql, user, "Savings");
    const foreign = await manualAccount(sql, stranger, "Foreign");

    const [row] = await insertOperation(sql, { userId: user, type: "transfer", from: cash, to: savings, source: "plaid" });
    const [stored] = await sql`
      select type, source, from_account_id::text as from_account_id, to_account_id::text as to_account_id
      from public.operations where id = ${row.id}::uuid`;
    assertEquals(stored, { type: "transfer", source: "plaid", from_account_id: cash, to_account_id: savings });

    // The general transfer rules still apply to system rows.
    await assertViolation(
      () => insertOperation(sql, { userId: user, type: "transfer", from: cash, to: cash, source: "plaid" }),
      CHECK_VIOLATION,
      "operations_transfer_check",
    );
    await assertViolation(
      () => insertOperation(sql, { userId: user, type: "transfer", from: cash, to: foreign, source: "plaid" }),
      FK_VIOLATION,
      "operations_to_account_user_fkey",
    );
  });
});

Deno.test("integrity: an account reference must belong to the Operation's user", options, async () => {
  await withDatabase("p23a_ops_ownership", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    await grantOperationsToAuthenticated(sql);
    const user = await createUser(sql, "ops-owner");
    const stranger = await createUser(sql, "ops-stranger");
    const own = await manualAccount(sql, user, "Own");
    const foreign = await manualAccount(sql, stranger, "Foreign");

    const [ownRow] = await asRole(sql, "authenticated", user, (tx) => insertOperation(tx, { userId: user, type: "expense", from: own }));
    const [nullRow] = await asRole(sql, "authenticated", user, (tx) => insertOperation(tx, { userId: user, type: "income", from: null }));
    const [stored] = await sql`
      select (select from_account_id::text from public.operations where id = ${ownRow.id}::uuid) as own_from,
             (select from_account_id from public.operations where id = ${nullRow.id}::uuid) as null_from`;
    assertEquals(stored, { own_from: own, null_from: null });

    await assertViolation(
      () => asRole(sql, "authenticated", user, (tx) => insertOperation(tx, { userId: user, type: "expense", from: foreign })),
      FK_VIOLATION,
      "operations_from_account_user_fkey",
    );
    await assertViolation(
      () =>
        asRole(sql, "authenticated", user, (tx) =>
          tx`update public.operations set from_account_id = ${foreign}::uuid where id = ${nullRow.id}::uuid`),
      FK_VIOLATION,
      "operations_from_account_user_fkey",
    );
    // A privileged writer is held to the same rule.
    await assertViolation(
      () => insertOperation(sql, { userId: user, type: "expense", from: foreign, source: "plaid" }),
      FK_VIOLATION,
      "operations_from_account_user_fkey",
    );
    await assertViolation(
      () => insertOperation(sql, { userId: user, type: "transfer", from: own, to: foreign, source: "plaid" }),
      FK_VIOLATION,
      "operations_to_account_user_fkey",
    );

    // ON DELETE RESTRICT is unchanged: a referenced account cannot be deleted.
    await assertViolation(
      () => sql`delete from public.accounts where id = ${own}::uuid`,
      FK_VIOLATION,
      "operations_from_account_user_fkey",
    );
    const [{ accounts }] = await sql`select count(*)::int as accounts from public.accounts where id = ${own}::uuid`;
    assertEquals(accounts, 1);
  });
});

Deno.test("integrity: Plaid materialization and source sync write Operations on the user's own account", options, async () => {
  await withDatabase("p23a_ops_materialize", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "ops-mat");
    const conn = await connection(sql, user, "ops-mat");
    const transaction = txn("ops-mat-1", conn.plaidAccountId, 21, await utcDate(sql, -1));

    await applyTransactions(sql, user, conn.itemId, { added: [transaction] });
    await runAllProjectionJobs(sql);
    const operationId = await projected(sql, conn.itemId, "ops-mat-1");
    const read = async () => {
      const [row] = await sql`
        select user_id::text as user_id, from_account_id::text as from_account_id,
               to_account_id, type, source, amount::text as amount
        from public.operations where id = ${operationId}::uuid`;
      return row;
    };
    assertEquals(await read(), {
      user_id: user,
      from_account_id: conn.accountId,
      to_account_id: null,
      type: "expense",
      source: "plaid",
      amount: "21.00",
    });

    await applyTransactions(sql, user, conn.itemId, { modified: [{ ...transaction, amount: 34 }] });
    await runAllProjectionJobs(sql);
    assertEquals((await read()).amount, "34.00");
  });
});

Deno.test("integrity: the migration refuses an existing manual transfer or cross-user reference and changes nothing", options, async () => {
  await withDatabase("p23a_ops_migration_gate", async (db) => {
    const sql = db.sql;
    for (const name of listMigrations().filter((migration) => migration < INTEGRITY_MIGRATION)) {
      await applyMigration(sql, name);
    }
    const user = await createUser(sql, "ops-gate");
    const stranger = await createUser(sql, "ops-gate-stranger");
    const cash = await manualAccount(sql, user, "Cash");
    const savings = await manualAccount(sql, user, "Savings");
    const foreign = await manualAccount(sql, stranger, "Foreign");

    const constraints = async () =>
      (await sql`
        select conname from pg_constraint
        where conrelid = 'public.operations'::regclass and contype in ('c', 'f')
        order by conname`).map((row) => row.conname);
    const before = await constraints();
    assert(before.includes("operations_account_id_fkey"));
    assert(before.includes("operations_to_account_id_fkey"));

    const [legacy] = await insertOperation(sql, { userId: user, type: "transfer", from: cash, to: savings });
    const legacyFailure = await assertRejects(() => applyMigration(sql, INTEGRITY_MIGRATION)) as { code?: string };
    assertEquals(legacyFailure.code, CHECK_VIOLATION);
    assertEquals(await constraints(), before);
    await sql`delete from public.operations where id = ${legacy.id}::uuid`;

    const [crossUser] = await insertOperation(sql, { userId: user, type: "expense", from: foreign });
    const crossFailure = await assertRejects(() => applyMigration(sql, INTEGRITY_MIGRATION)) as { code?: string };
    assertEquals(crossFailure.code, FK_VIOLATION);
    assertEquals(await constraints(), before);
    await sql`delete from public.operations where id = ${crossUser.id}::uuid`;

    const [{ applied }] = await sql`
      select count(*)::int as applied from supabase_migrations.schema_migrations
      where version = ${INTEGRITY_MIGRATION.split("_")[0]}`;
    assertEquals(applied, 0);
    await applyMigration(sql, INTEGRITY_MIGRATION);
    const after = await constraints();
    assert(after.includes("operations_manual_income_expense_check"));
    assert(!after.includes("operations_account_id_fkey"));
    assert(!after.includes("operations_to_account_id_fkey"));
  });
});
