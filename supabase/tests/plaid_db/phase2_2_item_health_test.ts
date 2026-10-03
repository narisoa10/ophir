// Phase 2.2: plaid_items health state, its service-role RPCs, the client health
// listing, and the plaid_items grants hardening.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  applyMigration,
  listMigrations,
  type Sql,
  type TestDatabase,
  withDatabase,
} from "./harness.ts";
import { applyTransactions, createPlaidItem, createUser, syncAccounts } from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const ITEM_HEALTH_MIGRATION = "20261003130000_plaid_item_health.sql";

const HEALTH_COLUMNS = [
  "connection_id",
  "status",
  "status_reason",
  "status_changed_at",
  "consent_expires_at",
  "pending_disconnect_at",
];

type Role = "anon" | "authenticated" | "service_role";
type Tx = Sql;

// The throwaway server has no Supabase default privileges; LIVE grants every
// public table to anon, authenticated and service_role. Reproduce that before
// the Phase 2.2 migration so its revokes are exercised against the real surface.
async function migrateWithSupabaseGrants(
  db: TestDatabase,
  beforeItemHealth?: (sql: Sql) => Promise<void>,
): Promise<void> {
  for (const name of listMigrations()) {
    if (name === ITEM_HEALTH_MIGRATION) {
      await db.sql`grant all on all tables in schema public to service_role`;
      await db.sql`grant all on table public.plaid_items to anon, authenticated`;
      if (beforeItemHealth) {
        await beforeItemHealth(db.sql);
      }
    }
    await applyMigration(db.sql, name);
  }
}

async function asRole<T>(
  sql: Sql,
  role: Role,
  userId: string | null,
  body: (tx: Tx) => Promise<T>,
): Promise<T> {
  return await sql.begin(async (tx) => {
    if (userId !== null) {
      await tx`select set_config('request.jwt.claim.sub', ${userId}, true)`;
    }
    await tx.unsafe(`set local role ${role}`);
    return await body(tx as unknown as Sql);
  }) as T;
}

async function assertSqlState(promise: () => Promise<unknown>, code: string): Promise<void> {
  const error = await assertRejects(promise) as { code?: string; message?: string };
  assertEquals(error.code, code, error.message);
}

interface Observation {
  observedAt: string;
  status: "active" | "login_required";
  reason?: string | null;
  fromItemGet?: boolean;
  consentExpiresAt?: string | null;
  clearPendingDisconnect?: boolean;
}

async function observe(
  sql: Sql,
  connectionId: string,
  observation: Observation,
): Promise<Record<string, unknown> | null> {
  // Text parameters: postgres.js serializes timestamptz params through Date (ms).
  const [row] = await sql`
    select public.plaid_record_item_status_observation(
      ${connectionId}::uuid,
      ${observation.observedAt}::text::timestamptz,
      ${observation.status},
      ${observation.reason ?? null}::text,
      ${observation.fromItemGet ?? false},
      ${observation.consentExpiresAt ?? null}::text::timestamptz,
      ${observation.clearPendingDisconnect ?? false}
    ) as r`;
  return row.r as Record<string, unknown> | null;
}

async function setDeadline(
  sql: Sql,
  externalItemId: string,
  kind: string,
  at: string,
): Promise<Record<string, unknown>> {
  const [row] = await sql`
    select public.plaid_set_item_access_deadline(
      ${externalItemId}, ${kind}, ${at}::text::timestamptz
    ) as r`;
  return row.r as Record<string, unknown>;
}

interface HealthRow {
  status: string;
  status_reason: string | null;
  status_changed_at: string;
  health_observed_at: string | null;
  consent_expires_at: string | null;
  pending_disconnect_at: string | null;
}

async function health(sql: Sql, connectionId: string): Promise<HealthRow> {
  const [row] = await sql`
    select status,
           status_reason,
           status_changed_at::text as status_changed_at,
           health_observed_at::text as health_observed_at,
           consent_expires_at::text as consent_expires_at,
           pending_disconnect_at::text as pending_disconnect_at
    from public.plaid_items
    where id = ${connectionId}::uuid`;
  return row as unknown as HealthRow;
}

function sameInstant(actual: string | null, expected: string | null): void {
  if (expected === null) {
    assertEquals(actual, null);
    return;
  }
  assert(actual !== null, `expected ${expected}, got null`);
  assertEquals(new Date(actual).getTime(), new Date(expected).getTime());
}

Deno.test("health columns default existing Items to active without touching Plaid data", options, async () => {
  await withDatabase("phase22_schema", async (db) => {
    let userId = "";
    let itemId = "";
    let before: Record<string, unknown> = {};

    await migrateWithSupabaseGrants(db, async (sql) => {
      userId = await createUser(sql, "existing");
      itemId = await createPlaidItem(sql, userId, "item-existing");
      await syncAccounts(sql, userId, itemId, [{ plaidAccountId: "ex-a1", name: "Checking" }]);
      await applyTransactions(sql, userId, itemId, {
        added: [{ transactionId: "ex-t1", plaidAccountId: "ex-a1", amount: 9.5, date: "2026-09-01", name: "Cafe" }],
      });
      [before] = await sql`
        select user_id::text, plaid_environment, plaid_item_id,
               access_token_secret_id::text, created_at::text,
               transactions_cursor, transactions_last_synced_at::text,
               transactions_initial_sync_completed_at::text
        from public.plaid_items where id = ${itemId}::uuid`;
    });

    const columns = await db.sql`
      select column_name, data_type, is_nullable, column_default
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'plaid_items'
        and column_name in (
          'status', 'status_reason', 'status_changed_at',
          'health_observed_at', 'consent_expires_at', 'pending_disconnect_at'
        )
      order by column_name`;
    const byName = Object.fromEntries(columns.map((column) => [column.column_name, column]));
    assertEquals(Object.keys(byName).length, 6);
    assertEquals(byName.status.data_type, "text");
    assertEquals(byName.status.is_nullable, "NO");
    assertEquals(byName.status.column_default, "'active'::text");
    assertEquals(byName.status_reason.data_type, "text");
    assertEquals(byName.status_reason.is_nullable, "YES");
    assertEquals(byName.status_changed_at.data_type, "timestamp with time zone");
    assertEquals(byName.status_changed_at.is_nullable, "NO");
    assertEquals(byName.status_changed_at.column_default, "now()");
    for (const name of ["health_observed_at", "consent_expires_at", "pending_disconnect_at"]) {
      assertEquals(byName[name].data_type, "timestamp with time zone");
      assertEquals(byName[name].is_nullable, "YES");
      assertEquals(byName[name].column_default, null);
    }

    const row = await health(db.sql, itemId);
    assertEquals(row.status, "active");
    assertEquals(row.status_reason, null);
    assert(row.status_changed_at !== null);
    assertEquals(row.health_observed_at, null);
    assertEquals(row.consent_expires_at, null);
    assertEquals(row.pending_disconnect_at, null);

    const [after] = await db.sql`
      select user_id::text, plaid_environment, plaid_item_id,
             access_token_secret_id::text, created_at::text,
             transactions_cursor, transactions_last_synced_at::text,
             transactions_initial_sync_completed_at::text
      from public.plaid_items where id = ${itemId}::uuid`;
    assertEquals(after, before);

    const [{ accounts }] = await db.sql`
      select count(*)::int as accounts from public.accounts where plaid_item_id = ${itemId}::uuid`;
    const [{ raw }] = await db.sql`
      select count(*)::int as raw from public.plaid_transactions where plaid_item_id = ${itemId}::uuid`;
    assertEquals(accounts, 1);
    assertEquals(raw, 1);
  });
});

Deno.test("health constraints reject invalid status combinations", options, async () => {
  await withDatabase("phase22_constraints", async (db) => {
    await migrateWithSupabaseGrants(db);
    const userId = await createUser(db.sql, "constraints");
    const itemId = await createPlaidItem(db.sql, userId, "item-constraints");

    const invalid: [string, string | null][] = [
      ["unknown", null],
      ["login_required", "unknown_reason"],
      ["active", "login_required"],
      ["login_required", null],
    ];
    for (const [status, reason] of invalid) {
      await assertSqlState(
        () =>
          db.sql`
          update public.plaid_items
          set status = ${status}, status_reason = ${reason}::text
          where id = ${itemId}::uuid`,
        "23514",
      );
    }

    for (const reason of ["login_required", "consent_expired", "permission_revoked"]) {
      await db.sql`
        update public.plaid_items
        set status = 'login_required', status_reason = ${reason}
        where id = ${itemId}::uuid`;
    }
    const row = await health(db.sql, itemId);
    assertEquals(row.status, "login_required");
    assertEquals(row.status_reason, "permission_revoked");
  });
});

Deno.test("status observations apply monotonically by observed_at", options, async () => {
  await withDatabase("phase22_monotonic", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const userId = await createUser(sql, "monotonic");
    const itemId = await createPlaidItem(sql, userId, "item-monotonic");
    const initial = await health(sql, itemId);

    const first = await observe(sql, itemId, {
      observedAt: "2026-10-03T10:00:00Z",
      status: "login_required",
      reason: "login_required",
    });
    assertEquals(first, {
      applied: true,
      previous_status: "active",
      status: "login_required",
      plaid_item_id: "item-monotonic",
    });
    const afterFirst = await health(sql, itemId);
    assertEquals(afterFirst.status, "login_required");
    assertEquals(afterFirst.status_reason, "login_required");
    sameInstant(afterFirst.health_observed_at, "2026-10-03T10:00:00Z");
    assert(afterFirst.status_changed_at !== initial.status_changed_at, "status change must move status_changed_at");

    for (const observedAt of ["2026-10-03T09:00:00Z", "2026-10-03T10:00:00Z"]) {
      const ignored = await observe(sql, itemId, { observedAt, status: "active" });
      assertEquals(ignored, {
        applied: false,
        previous_status: "login_required",
        status: "login_required",
        plaid_item_id: "item-monotonic",
      });
      assertEquals(await health(sql, itemId), afterFirst);
    }

    const reasonOnly = await observe(sql, itemId, {
      observedAt: "2026-10-03T11:00:00Z",
      status: "login_required",
      reason: "consent_expired",
    });
    assertEquals(reasonOnly?.applied, true);
    const afterReason = await health(sql, itemId);
    assertEquals(afterReason.status_reason, "consent_expired");
    sameInstant(afterReason.health_observed_at, "2026-10-03T11:00:00Z");
    assertEquals(afterReason.status_changed_at, afterFirst.status_changed_at);

    const repeat = await observe(sql, itemId, {
      observedAt: "2026-10-03T12:00:00Z",
      status: "login_required",
      reason: "consent_expired",
    });
    assertEquals(repeat?.applied, true);
    const afterRepeat = await health(sql, itemId);
    sameInstant(afterRepeat.health_observed_at, "2026-10-03T12:00:00Z");
    assertEquals(afterRepeat.status_changed_at, afterFirst.status_changed_at);

    const healed = await observe(sql, itemId, { observedAt: "2026-10-03T13:00:00Z", status: "active" });
    assertEquals(healed, {
      applied: true,
      previous_status: "login_required",
      status: "active",
      plaid_item_id: "item-monotonic",
    });
    const afterHealed = await health(sql, itemId);
    assertEquals(afterHealed.status, "active");
    assertEquals(afterHealed.status_reason, null);
    assert(afterHealed.status_changed_at !== afterFirst.status_changed_at);

    assertEquals(
      await observe(sql, crypto.randomUUID(), { observedAt: "2026-10-03T14:00:00Z", status: "active" }),
      null,
    );
    await assertSqlState(
      () => observe(sql, itemId, { observedAt: "2026-10-03T14:00:00Z", status: "active", reason: "login_required" }),
      "22023",
    );
    await assertSqlState(
      () => observe(sql, itemId, { observedAt: "2026-10-03T14:00:00Z", status: "login_required" }),
      "22023",
    );
    await assertSqlState(
      () =>
        observe(sql, itemId, {
          observedAt: "2026-10-03T14:00:00Z",
          status: "login_required",
          reason: "login_required",
          consentExpiresAt: "2026-12-01T00:00:00Z",
        }),
      "22023",
    );
    assertEquals(await health(sql, itemId), afterHealed);
  });
});

Deno.test("consent_expires_at follows /item/get observations only", options, async () => {
  await withDatabase("phase22_consent", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const userId = await createUser(sql, "consent");
    const itemId = await createPlaidItem(sql, userId, "item-consent");

    await observe(sql, itemId, {
      observedAt: "2026-10-03T10:00:00Z",
      status: "active",
      fromItemGet: true,
      consentExpiresAt: "2026-12-01T00:00:00Z",
    });
    sameInstant((await health(sql, itemId)).consent_expires_at, "2026-12-01T00:00:00Z");

    await observe(sql, itemId, {
      observedAt: "2026-10-03T11:00:00Z",
      status: "login_required",
      reason: "login_required",
    });
    const afterSyncError = await health(sql, itemId);
    assertEquals(afterSyncError.status, "login_required");
    sameInstant(afterSyncError.consent_expires_at, "2026-12-01T00:00:00Z");

    await observe(sql, itemId, {
      observedAt: "2026-10-03T12:00:00Z",
      status: "active",
      fromItemGet: true,
      consentExpiresAt: null,
    });
    assertEquals((await health(sql, itemId)).consent_expires_at, null);
  });
});

Deno.test("access deadlines keep one meaning per timestamp", options, async () => {
  await withDatabase("phase22_deadlines", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const userId = await createUser(sql, "deadlines");
    const itemId = await createPlaidItem(sql, userId, "item-deadlines");

    assertEquals(await setDeadline(sql, "item-deadlines", "pending_disconnect", "2026-10-10T00:00:00Z"), {
      status: "applied",
      connection_id: itemId,
    });
    let row = await health(sql, itemId);
    sameInstant(row.pending_disconnect_at, "2026-10-10T00:00:00Z");
    assertEquals(row.consent_expires_at, null);
    assertEquals(row.status, "active");
    assertEquals(row.health_observed_at, null);

    await setDeadline(sql, " item-deadlines ", "consent_expiration", "2026-11-01T00:00:00Z");
    row = await health(sql, itemId);
    sameInstant(row.consent_expires_at, "2026-11-01T00:00:00Z");
    sameInstant(row.pending_disconnect_at, "2026-10-10T00:00:00Z");

    await setDeadline(sql, "item-deadlines", "pending_disconnect", "2026-10-10T00:00:00Z");
    await setDeadline(sql, "item-deadlines", "consent_expiration", "2026-11-01T00:00:00Z");
    assertEquals(await health(sql, itemId), row);

    assertEquals(await setDeadline(sql, "item-unknown", "pending_disconnect", "2026-10-10T00:00:00Z"), {
      status: "ignored",
    });
    await assertSqlState(
      () => setDeadline(sql, "item-deadlines", "status", "2026-10-10T00:00:00Z"),
      "22023",
    );

    await observe(sql, itemId, {
      observedAt: "2026-10-03T10:00:00Z",
      status: "active",
      fromItemGet: true,
      consentExpiresAt: "2026-11-02T00:00:00Z",
    });
    await observe(sql, itemId, {
      observedAt: "2026-10-03T11:00:00Z",
      status: "login_required",
      reason: "login_required",
    });
    row = await health(sql, itemId);
    sameInstant(row.pending_disconnect_at, "2026-10-10T00:00:00Z");
    sameInstant(row.consent_expires_at, "2026-11-02T00:00:00Z");

    await observe(sql, itemId, {
      observedAt: "2026-10-03T12:00:00Z",
      status: "active",
      fromItemGet: true,
      consentExpiresAt: null,
      clearPendingDisconnect: true,
    });
    row = await health(sql, itemId);
    assertEquals(row.pending_disconnect_at, null);
    assertEquals(row.consent_expires_at, null);
    assertEquals(row.status, "active");
  });
});

Deno.test("webhook resolution and reconcile listing expose only connection and owner", options, async () => {
  await withDatabase("phase22_resolve", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const userId = await createUser(sql, "resolve");
    const observed = await createPlaidItem(sql, userId, "item-observed");
    const neverObserved = await createPlaidItem(sql, userId, "item-never-observed");
    await observe(sql, observed, { observedAt: "2026-10-03T10:00:00Z", status: "active" });

    await asRole(sql, "service_role", null, async (tx) => {
      const resolved = await tx`
        select * from public.plaid_resolve_item_connection(' item-observed ')`;
      assertEquals(resolved.length, 1);
      assertEquals(Object.keys(resolved[0]).sort(), ["connection_id", "user_id"]);
      assertEquals(resolved[0].connection_id, observed);
      assertEquals(resolved[0].user_id, userId);
      assertEquals((await tx`select * from public.plaid_resolve_item_connection('item-unknown')`).length, 0);

      const listed = await tx`select * from public.plaid_list_items_for_health_reconcile(10)`;
      assertEquals(listed.map((row) => row.connection_id), [neverObserved, observed]);
      assertEquals(Object.keys(listed[0]).sort(), ["connection_id", "user_id"]);
      assertEquals(
        (await tx`select * from public.plaid_list_items_for_health_reconcile(1)`).map((row) => row.connection_id),
        [neverObserved],
      );
    });
    await assertSqlState(
      () => sql`select * from public.plaid_list_items_for_health_reconcile(0)`,
      "22023",
    );
  });
});

Deno.test("connection health listing returns only the caller's rows without secrets", options, async () => {
  await withDatabase("phase22_ownership", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const alice = await createUser(sql, "alice");
    const bob = await createUser(sql, "bob");
    const aliceFirst = await createPlaidItem(sql, alice, "item-alice-1");
    const aliceSecond = await createPlaidItem(sql, alice, "item-alice-2");
    const bobItem = await createPlaidItem(sql, bob, "item-bob");
    await observe(sql, aliceSecond, {
      observedAt: "2026-10-03T10:00:00Z",
      status: "login_required",
      reason: "permission_revoked",
    });

    const aliceRows = await asRole(sql, "authenticated", alice, (tx) =>
      tx`select * from public.plaid_list_connection_health()`);
    assertEquals(aliceRows.map((row) => row.connection_id).sort(), [aliceFirst, aliceSecond].sort());
    for (const row of aliceRows) {
      assertEquals(Object.keys(row).sort(), [...HEALTH_COLUMNS].sort());
    }
    const revoked = aliceRows.find((row) => row.connection_id === aliceSecond)!;
    assertEquals(revoked.status, "login_required");
    assertEquals(revoked.status_reason, "permission_revoked");

    const bobRows = await asRole(sql, "authenticated", bob, (tx) =>
      tx`select * from public.plaid_list_connection_health()`);
    assertEquals(bobRows.map((row) => row.connection_id), [bobItem]);

    const anonymousRows = await asRole(sql, "authenticated", null, (tx) =>
      tx`select * from public.plaid_list_connection_health()`);
    assertEquals(anonymousRows.length, 0);

    const [{ result_columns }] = await sql`
      select pg_get_function_result('public.plaid_list_connection_health()'::regprocedure) as result_columns`;
    for (const forbidden of ["access_token", "secret", "cursor", "plaid_item_id", "user_id"]) {
      assert(!String(result_columns).includes(forbidden), `${forbidden} leaked: ${result_columns}`);
    }
  });
});

Deno.test("plaid_items grants allow only own SELECT for clients", options, async () => {
  await withDatabase("phase22_grants", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const alice = await createUser(sql, "grants-alice");
    const bob = await createUser(sql, "grants-bob");
    const aliceItem = await createPlaidItem(sql, alice, "item-grants-alice");
    await createPlaidItem(sql, bob, "item-grants-bob");
    const [{ secret_id }] = await sql`
      select access_token_secret_id::text as secret_id from public.plaid_items where id = ${aliceItem}::uuid`;

    const visible = await asRole(sql, "authenticated", alice, (tx) =>
      tx`select id::text as id, status from public.plaid_items`);
    assertEquals([...visible], [{ id: aliceItem, status: "active" }]);
    const listed = await asRole(sql, "authenticated", alice, (tx) =>
      tx`select connection_id from public.plaid_list_connection_health()`);
    assertEquals(listed.map((row) => row.connection_id), [aliceItem]);

    const writes: Record<string, (tx: Tx) => Promise<unknown>> = {
      insert: (tx) =>
        tx`
        insert into public.plaid_items (user_id, plaid_environment, plaid_item_id, access_token_secret_id)
        values (${alice}::uuid, 'sandbox', 'item-forged', ${secret_id}::uuid)`,
      update: (tx) => tx`update public.plaid_items set status_changed_at = now() where id = ${aliceItem}::uuid`,
      delete: (tx) => tx`delete from public.plaid_items where id = ${aliceItem}::uuid`,
      truncate: (tx) => tx`truncate public.plaid_items cascade`,
    };
    for (const write of Object.values(writes)) {
      await assertSqlState(() => asRole(sql, "authenticated", alice, write), "42501");
      await assertSqlState(() => asRole(sql, "anon", null, write), "42501");
    }
    await assertSqlState(
      () => asRole(sql, "anon", null, (tx) => tx`select id from public.plaid_items`),
      "42501",
    );
    await assertSqlState(
      () => asRole(sql, "anon", null, (tx) => tx`select * from public.plaid_list_connection_health()`),
      "42501",
    );

    const serviceOnly: ((tx: Tx) => Promise<unknown>)[] = [
      (tx) =>
        tx`
        select public.plaid_record_item_status_observation(
          ${aliceItem}::uuid, now(), 'active', null, false, null, false)`,
      (tx) => tx`select public.plaid_set_item_access_deadline('item-grants-alice', 'pending_disconnect', now())`,
      (tx) => tx`select * from public.plaid_resolve_item_connection('item-grants-alice')`,
      (tx) => tx`select * from public.plaid_list_items_for_health_reconcile(10)`,
    ];
    for (const call of serviceOnly) {
      await assertSqlState(() => asRole(sql, "authenticated", alice, call), "42501");
      await assertSqlState(() => asRole(sql, "anon", null, call), "42501");
    }

    const [{ count }] = await sql`select count(*)::int as count from public.plaid_items`;
    assertEquals(count, 2);
    assertEquals((await health(sql, aliceItem)).health_observed_at, null);

    const [privileges] = await sql`
      select
        has_table_privilege('authenticated', 'public.plaid_items', 'SELECT') as auth_select,
        has_table_privilege('authenticated', 'public.plaid_items', 'INSERT,UPDATE,DELETE,TRUNCATE') as auth_write,
        has_table_privilege('authenticated', 'public.plaid_items', 'REFERENCES') as auth_references,
        has_table_privilege('authenticated', 'public.plaid_items', 'TRIGGER') as auth_trigger,
        has_table_privilege('anon', 'public.plaid_items', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') as anon_any,
        has_table_privilege('service_role', 'public.plaid_items', 'SELECT') as service_select`;
    assertEquals(privileges, {
      auth_select: true,
      auth_write: false,
      auth_references: false,
      auth_trigger: false,
      anon_any: false,
      service_select: true,
    });
  });
});

Deno.test("existing service-role production paths keep working after the revoke", options, async () => {
  await withDatabase("phase22_production_paths", async (db) => {
    await migrateWithSupabaseGrants(db);
    const sql = db.sql;
    const userId = await createUser(sql, "production");

    await asRole(sql, "service_role", null, async (tx) => {
      const txSql = tx;
      const syncedItem = await createPlaidItem(txSql, userId, "item-production-sync");
      const accounts = await syncAccounts(txSql, userId, syncedItem, [
        { plaidAccountId: "pp-a1", name: "Checking" },
      ]);
      assertEquals(Object.keys(accounts), ["pp-a1"]);
      await applyTransactions(txSql, userId, syncedItem, {
        added: [{ transactionId: "pp-t1", plaidAccountId: "pp-a1", amount: 4.25, date: "2026-09-03", name: "Bakery" }],
      });
      const [item] = await tx`
        select transactions_cursor, status from public.plaid_items where id = ${syncedItem}::uuid`;
      assert(item.transactions_cursor !== null, "sync batch must advance the cursor");
      assertEquals(item.status, "active");
      const [{ raw }] = await tx`
        select count(*)::int as raw from public.plaid_transactions where plaid_item_id = ${syncedItem}::uuid`;
      assertEquals(raw, 1);

      const removedItem = await createPlaidItem(txSql, userId, "item-production-remove");
      await syncAccounts(txSql, userId, removedItem, [{ plaidAccountId: "pr-a1", name: "Savings" }]);
      const [{ secret_id }] = await tx`
        select access_token_secret_id::text as secret_id
        from public.plaid_items where id = ${removedItem}::uuid`;
      const [cleanup] = await tx`
        select public.plaid_remove_item_local_cleanup(
          ${userId}::uuid, ${removedItem}::uuid, ${secret_id}::uuid) as r`;
      assertEquals(cleanup.r, { accounts_deleted: 1, plaid_items_deleted: 1, vault_secrets_deleted: 1 });
      const remaining = await tx`select id::text as id from public.plaid_items`;
      assertEquals(remaining.map((row) => row.id), [syncedItem]);
    });
  });
});
