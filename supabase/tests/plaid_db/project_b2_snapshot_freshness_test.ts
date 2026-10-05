// Project B / B2 (M1): snapshot freshness. plaid_items.accounts_observed_at is the
// Item watermark written by the 10-argument plaid_persist_accounts_sync; the
// 9-argument overload is the temporary rollout path that only works at NULL.

import { assert, assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import { applyAllMigrations, applyMigration, listMigrations, type Sql, withDatabase } from "./harness.ts";
import { applyTransactions, createPlaidItem, createUser, link, runAllProjectionJobs } from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const M1 = "20261005100000_plaid_accounts_snapshot_freshness.sql";
const NEW_SIGNATURE =
  "public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb,timestamptz)";
const LEGACY_SIGNATURE =
  "public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)";

// Observation times (request start) and balance times are deliberately different.
const O0 = "2026-09-20T10:00:00.000Z";
const O1 = "2026-09-21T10:00:00.000Z";
const O2 = "2026-09-22T10:00:00.000Z";
const O3 = "2026-09-23T10:00:00.000Z";
const F0 = "2026-09-25T00:00:00Z";
const F1 = "2026-09-26T00:00:00Z";
const F2 = "2026-09-27T00:00:00Z";
const F3 = "2026-09-28T00:00:00Z";

const SUPERSEDED = "plaid_accounts_snapshot_superseded";
const INVALID_OBSERVED = "invalid_accounts_observed_at";

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

function snapshotAccount(plaidAccountId: string, balance: string, name = `Card ${plaidAccountId}`) {
  return {
    plaid_account_id: plaidAccountId,
    name,
    mask: "1234",
    plaid_type: "depository",
    plaid_subtype: "checking",
    currency_code: "CAD",
    current_balance: balance,
    available_balance: balance,
    persistent_account_id: null,
  };
}

function snapshot(plaidAccountIds: string[], balance: string) {
  return plaidAccountIds.map((plaidAccountId) => snapshotAccount(plaidAccountId, balance));
}

function persist(
  sql: Sql,
  userId: string,
  itemId: string,
  accounts: unknown[],
  fetchedAt: string,
  observedAt: string | null,
  institutionName = "Fresh Bank",
) {
  // ::text first: a timestamptz-typed parameter goes through a JS Date (milliseconds).
  return sql`
    select public.plaid_persist_accounts_sync(
      ${userId}::uuid, ${itemId}::uuid, 'ins_fresh', ${institutionName},
      null, null, null, ${fetchedAt}::timestamptz, ${sql.json(accounts as never)}::jsonb,
      ${observedAt}::text::timestamptz
    ) as synced`;
}

// observedExpr is SQL evaluated in the caller's transaction (deterministic now()).
function persistAt(sql: Sql, userId: string, itemId: string, accounts: unknown[], observedExpr: string) {
  return sql.unsafe(
    `select public.plaid_persist_accounts_sync(
       $1::uuid, $2::uuid, 'ins_fresh', 'Fresh Bank', null, null, null,
       $3::timestamptz, $4::text::jsonb, ${observedExpr}) as synced`,
    [userId, itemId, F1, JSON.stringify(accounts)],
  );
}

function persistLegacy(
  sql: Sql,
  userId: string,
  itemId: string,
  accounts: unknown[],
  fetchedAt: string,
  institutionName = "Legacy Bank",
) {
  return sql`
    select public.plaid_persist_accounts_sync(
      ${userId}::uuid, ${itemId}::uuid, 'ins_fresh', ${institutionName},
      null, null, null, ${fetchedAt}::timestamptz, ${sql.json(accounts as never)}::jsonb
    ) as synced`;
}

async function persistOk(
  sql: Sql,
  userId: string,
  itemId: string,
  accounts: unknown[],
  fetchedAt: string,
  observedAt: string,
  institutionName?: string,
): Promise<number> {
  const [row] = await persist(sql, userId, itemId, accounts, fetchedAt, observedAt, institutionName);
  return row.synced;
}

interface AccountRow {
  id: string;
  name: string;
  balance: string | null;
  available: string | null;
  fetched: string | null;
  missing: string | null;
  included: boolean;
  updated: string;
  item: string | null;
}

async function accountsOf(sql: Sql, itemId: string): Promise<Record<string, AccountRow>> {
  const rows = await sql`
    select plaid_account_id, id::text as id, name, current_balance::text as balance,
           available_balance::text as available,
           to_char(balance_fetched_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as fetched,
           to_char(plaid_missing_since at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as missing,
           is_included_in_finances as included, updated_at::text as updated,
           plaid_item_id::text as item
    from public.accounts
    where plaid_item_id = ${itemId}::uuid`;
  return Object.fromEntries(rows.map((row) => [row.plaid_account_id, row as unknown as AccountRow]));
}

function missingOf(accounts: Record<string, AccountRow>): Record<string, string | null> {
  return Object.fromEntries(Object.entries(accounts).map(([key, row]) => [key, row.missing]));
}

async function watermarkOf(sql: Sql, itemId: string): Promise<string | null> {
  const [row] = await sql`
    select to_char(accounts_observed_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as observed
    from public.plaid_items where id = ${itemId}::uuid`;
  return row.observed;
}

// Every row a snapshot may touch: the Item, its institution and its accounts.
async function itemState(sql: Sql, itemId: string) {
  const [item] = await sql`
    select to_jsonb(plaid_items.*)::text as row from public.plaid_items where id = ${itemId}::uuid`;
  const institutions = await sql`
    select to_jsonb(institutions.*)::text as row from public.institutions
    where plaid_item_id = ${itemId}::uuid order by id`;
  const accounts = await sql`
    select to_jsonb(accounts.*)::text as row from public.accounts
    where plaid_item_id = ${itemId}::uuid order by id`;
  return { item: item.row, institutions: institutions.map((r) => r.row), accounts: accounts.map((r) => r.row) };
}

async function institutionName(sql: Sql, itemId: string): Promise<string | null> {
  const [row] = await sql`select name from public.institutions where plaid_item_id = ${itemId}::uuid`;
  return row?.name ?? null;
}

async function accountCount(sql: Sql, userId: string): Promise<number> {
  const [{ count }] = await sql`select count(*)::int as count from public.accounts where user_id = ${userId}::uuid`;
  return count;
}

interface ItemFixture {
  userId: string;
  itemId: string;
  ids: Record<string, string>;
}

// Item with accounts A, B and C (balance 100.00). watermarked: persisted through
// the 10-argument RPC at O0; otherwise through the legacy path (watermark NULL).
async function itemABC(sql: Sql, label: string, watermarked: boolean, userId?: string): Promise<ItemFixture> {
  const owner = userId ?? await createUser(sql, label);
  const itemId = await createPlaidItem(sql, owner, `item-${label}`);
  const names = ["a", "b", "c"].map((suffix) => `${label}-${suffix}`);
  if (watermarked) {
    assertEquals(await persistOk(sql, owner, itemId, snapshot(names, "100.00"), F0, O0), 3);
    assertEquals(await watermarkOf(sql, itemId), O0);
  } else {
    const [row] = await persistLegacy(sql, owner, itemId, snapshot(names, "100.00"), F0);
    assertEquals(row.synced, 3);
    assertEquals(await watermarkOf(sql, itemId), null);
  }
  const accounts = await accountsOf(sql, itemId);
  return {
    userId: owner,
    itemId,
    ids: Object.fromEntries(Object.entries(accounts).map(([key, row]) => [key, row.id])),
  };
}

// ---------------------------------------------------------------------------
// Contract
// ---------------------------------------------------------------------------

Deno.test("B2 contract: watermark column, both overloads, grants and comments", options, async () => {
  await withDatabase("b2_contract", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;

    const [column] = await sql`
      select data_type, is_nullable, column_default,
             col_description('public.plaid_items'::regclass, ordinal_position::int) as comment
      from information_schema.columns
      where table_schema = 'public' and table_name = 'plaid_items' and column_name = 'accounts_observed_at'`;
    assertEquals([column.data_type, column.is_nullable, column.column_default], [
      "timestamp with time zone",
      "YES",
      null,
    ]);
    assert(column.comment.includes("Authoritative observation watermark"), column.comment);
    assert(column.comment.includes("Not a balance time, not a database update time and not a lifecycle"));
    const [{ indexes }] = await sql`
      select count(*)::int as indexes
      from pg_index i
      join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any (i.indkey)
      where i.indrelid = 'public.plaid_items'::regclass and a.attname = 'accounts_observed_at'`;
    assertEquals(indexes, 0);

    const definitions = await sql`
      select p.oid::regprocedure::text as signature, pg_get_function_result(p.oid) as result,
             p.prosecdef, p.proconfig, p.pronargdefaults, obj_description(p.oid, 'pg_proc') as comment
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'plaid_persist_accounts_sync'
      order by p.pronargs`;
    assertEquals(definitions.length, 2);
    for (const definition of definitions) {
      assertEquals(definition.result, "integer");
      assertEquals(definition.prosecdef, true);
      assertEquals(definition.proconfig, ['search_path=""']);
      assertEquals(definition.pronargdefaults, 0);
    }
    assert(definitions[0].comment.startsWith("Temporary B2 rollout compatibility"), definitions[0].comment);
    assert(definitions[0].comment.includes("dropped by M2"));
    assert(definitions[1].comment.includes("p_accounts_observed_at"), definitions[1].comment);

    for (const signature of [NEW_SIGNATURE, LEGACY_SIGNATURE]) {
      const [privileges] = await sql`
        select has_function_privilege('service_role', ${signature}, 'EXECUTE') as service,
               has_function_privilege('authenticated', ${signature}, 'EXECUTE') as auth,
               has_function_privilege('anon', ${signature}, 'EXECUTE') as anon,
               has_function_privilege('public', ${signature}, 'EXECUTE') as public`;
      assertEquals(privileges, { service: true, auth: false, anon: false, public: false }, signature);
    }
    const [columnPrivileges] = await sql`
      select has_column_privilege('authenticated', 'public.plaid_items', 'accounts_observed_at', 'UPDATE') as auth_update,
             has_column_privilege('anon', 'public.plaid_items', 'accounts_observed_at', 'UPDATE') as anon_update,
             has_column_privilege('anon', 'public.plaid_items', 'accounts_observed_at', 'SELECT') as anon_select`;
    assertEquals(columnPrivileges, { auth_update: false, anon_update: false, anon_select: false });

    const f = await itemABC(sql, "b2c", false);
    await assertSqlState(
      () => asRole(sql, "authenticated", f.userId, (tx) => persist(tx, f.userId, f.itemId, [], F1, O1)),
      "42501",
    );
    await assertSqlState(
      () => asRole(sql, "anon", null, (tx) => persist(tx, f.userId, f.itemId, [], F1, O1)),
      "42501",
    );
    assertEquals(await watermarkOf(sql, f.itemId), null);
  });
});

// ---------------------------------------------------------------------------
// Future guard (deterministic now(): every call runs inside one transaction)
// ---------------------------------------------------------------------------

Deno.test("B2 future guard: NULL refused, exactly now()+1 minute accepted, +1 microsecond refused", options, async () => {
  await withDatabase("b2_future", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2f", false);
    const before = await itemState(sql, f.itemId);

    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], F1, null), "22023", INVALID_OBSERVED);
    await assertSqlState(
      () => sql.begin((tx) => persistAt(tx as unknown as Sql, f.userId, f.itemId, [], "now() + interval '1 minute 0.000001 second'")),
      "22023",
      INVALID_OBSERVED,
    );
    await assertSqlState(
      () => sql.begin((tx) => persistAt(tx as unknown as Sql, f.userId, f.itemId, [], "now() + interval '1 hour'")),
      "22023",
      INVALID_OBSERVED,
    );
    assertEquals(await itemState(sql, f.itemId), before);

    const exact = await sql.begin(async (tx) => {
      const [row] = await persistAt(tx as unknown as Sql, f.userId, f.itemId, snapshot(["b2f-a"], "5.00"), "now() + interval '1 minute'");
      const [check] = await tx`
        select accounts_observed_at = now() + interval '1 minute' as exact
        from public.plaid_items where id = ${f.itemId}::uuid`;
      return { synced: row.synced, exact: check.exact };
    });
    assertEquals(exact, { synced: 1, exact: true });
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2f-a": null, "b2f-b": F1, "b2f-c": F1 });
  });
});

Deno.test("B2 future guard wins over stale and over a set watermark; NULL never becomes superseded", options, async () => {
  await withDatabase("b2_future_stale", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2fs", true);
    // A watermark further in the future than the allowance (only reachable by a superuser).
    await sql`update public.plaid_items set accounts_observed_at = now() + interval '2 hours' where id = ${f.itemId}::uuid`;
    const before = await itemState(sql, f.itemId);

    // Future (beyond 1 minute) and stale (before the watermark) at once: invalid first.
    await assertSqlState(
      () => sql.begin((tx) => persistAt(tx as unknown as Sql, f.userId, f.itemId, [], "now() + interval '1 hour'")),
      "22023",
      INVALID_OBSERVED,
    );
    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], F1, null), "22023", INVALID_OBSERVED);
    // Within the allowance but before the watermark: superseded.
    await assertSqlState(
      () => sql.begin((tx) => persistAt(tx as unknown as Sql, f.userId, f.itemId, [], "now() + interval '1 minute'")),
      "22023",
      SUPERSEDED,
    );
    assertEquals(await itemState(sql, f.itemId), before);
  });
});

Deno.test("B2 future guard runs before the Item lock", options, async () => {
  await withDatabase("b2_future_lock", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2fl", false);
    const holder = db.connect();
    const caller = db.connect();
    await caller.unsafe("set lock_timeout = '1s'");

    let release!: () => void;
    const mayRelease = new Promise<void>((resolve) => release = resolve);
    let held!: () => void;
    const isHeld = new Promise<void>((resolve) => held = resolve);
    const holderTx = holder.begin(async (tx) => {
      await tx`select 1 from public.plaid_items where id = ${f.itemId}::uuid for update`;
      held();
      await mayRelease;
    });
    try {
      await isHeld;
      await assertSqlState(
        () => caller.begin((tx) => persistAt(tx as unknown as Sql, f.userId, f.itemId, [], "now() + interval '2 minutes'")),
        "22023",
        INVALID_OBSERVED,
      );
      await assertSqlState(() => persist(caller, f.userId, f.itemId, [], F1, null), "22023", INVALID_OBSERVED);
      // Control: a valid call does wait for the Item lock.
      await assertSqlState(() => persist(caller, f.userId, f.itemId, [], F1, O1), "55P03");
    } finally {
      release();
      await holderTx;
    }
    assertEquals(await watermarkOf(sql, f.itemId), null);
  });
});

// ---------------------------------------------------------------------------
// Ordering against the watermark
// ---------------------------------------------------------------------------

Deno.test("B2 ordering: equal and older are superseded and write nothing; newer applies and advances", options, async () => {
  await withDatabase("b2_order", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2o", true);
    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2o-a", "b2o-c"], "150.00"), F2, O2), 2);
    assertEquals(await watermarkOf(sql, f.itemId), O2);
    const before = await itemState(sql, f.itemId);

    // Every payload shape B1 would act on: return, absence, empty, new account, rename.
    const shapes: unknown[][] = [
      snapshot(["b2o-a", "b2o-b", "b2o-c"], "999.00"),
      snapshot(["b2o-a"], "999.00"),
      [],
      snapshot(["b2o-a", "b2o-c", "b2o-new"], "999.00"),
    ];
    for (const observed of [O2, O1, O0]) {
      for (const accounts of shapes) {
        await assertSqlState(
          () => persist(sql, f.userId, f.itemId, accounts, F3, observed, "Renamed Bank"),
          "22023",
          SUPERSEDED,
        );
      }
    }
    assertEquals(await itemState(sql, f.itemId), before);
    assertEquals(await institutionName(sql, f.itemId), "Fresh Bank");

    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2o-a", "b2o-b", "b2o-c"], "175.00"), F3, O3, "Newer Bank"), 3);
    assertEquals(await watermarkOf(sql, f.itemId), O3);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2o-a": null, "b2o-b": null, "b2o-c": null });
    assertEquals(await institutionName(sql, f.itemId), "Newer Bank");

    // One microsecond later than the watermark is newer.
    const [{ next }] = await sql`
      select to_char((accounts_observed_at + interval '1 microsecond') at time zone 'UTC',
                     'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') as next
      from public.plaid_items where id = ${f.itemId}::uuid`;
    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2o-a"], "1.00"), F3, next), 1);
  });
});

Deno.test("B2 superseded is decided before any write: no account lock is taken", options, async () => {
  await withDatabase("b2_no_write_lock", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2nw", true);
    const holder = db.connect();
    const caller = db.connect();
    await caller.unsafe("set lock_timeout = '1s'");

    let release!: () => void;
    const mayRelease = new Promise<void>((resolve) => release = resolve);
    let held!: () => void;
    const isHeld = new Promise<void>((resolve) => held = resolve);
    const holderTx = holder.begin(async (tx) => {
      await tx`select 1 from public.accounts where id = ${f.ids["b2nw-b"]}::uuid for update`;
      held();
      await mayRelease;
    });
    try {
      await isHeld;
      await assertSqlState(() => persist(caller, f.userId, f.itemId, [], F1, O0), "22023", SUPERSEDED);
      await assertSqlState(() => persistLegacy(caller, f.userId, f.itemId, [], F1), "22023", SUPERSEDED);
      // Control: an accepted snapshot needs the account row lock.
      await assertSqlState(() => persist(caller, f.userId, f.itemId, [], F1, O1), "55P03");
    } finally {
      release();
      await holderTx;
    }
    assertEquals(await watermarkOf(sql, f.itemId), O0);
  });
});

Deno.test("B2 superseded wins over an invalid payload (checked before the payload loop)", options, async () => {
  await withDatabase("b2_stale_invalid", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2si", true);
    const invalid = [snapshotAccount("b2si-a", "1.00"), { ...snapshotAccount("b2si-x", "1.00"), plaid_type: " " }];
    await assertSqlState(() => persist(sql, f.userId, f.itemId, invalid, F1, O0), "22023", SUPERSEDED);
    await assertSqlState(() => persistLegacy(sql, f.userId, f.itemId, invalid, F1), "22023", SUPERSEDED);
    await assertSqlState(() => persist(sql, f.userId, f.itemId, invalid, F1, O1), "22023", "invalid_plaid_account_payload");
    assertEquals(await watermarkOf(sql, f.itemId), O0);
  });
});

// ---------------------------------------------------------------------------
// B1 regression through the 10-argument RPC
// ---------------------------------------------------------------------------

Deno.test("B2/B1: newer snapshot reconciles presence; ids, balances and missing time follow B1", options, async () => {
  await withDatabase("b2_b1_presence", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2p", true);

    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2p-a", "b2p-c"], "150.00"), F1, O1), 2);
    let after = await accountsOf(sql, f.itemId);
    // plaid_missing_since is the balance time, never the observation time.
    assertEquals(missingOf(after), { "b2p-a": null, "b2p-b": F1, "b2p-c": null });
    assertEquals(after["b2p-b"].id, f.ids["b2p-b"]);
    assertEquals([after["b2p-b"].balance, after["b2p-b"].available, after["b2p-b"].fetched], ["100.00", "100.00", F0]);

    assertEquals(await persistOk(sql, f.userId, f.itemId, [], F2, O2), 0);
    after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "b2p-a": F2, "b2p-b": F1, "b2p-c": F2 });
    assertEquals(await accountCount(sql, f.userId), 3);

    const returning = [snapshotAccount("b2p-a", "200.00"), snapshotAccount("b2p-b", "275.50", "Card renamed"), snapshotAccount("b2p-c", "200.00")];
    assertEquals(await persistOk(sql, f.userId, f.itemId, returning, F3, O3), 3);
    after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "b2p-a": null, "b2p-b": null, "b2p-c": null });
    for (const [key, row] of Object.entries(after)) {
      assertEquals(row.id, f.ids[key]);
    }
    assertEquals([after["b2p-b"].name, after["b2p-b"].balance, after["b2p-b"].fetched], ["Card renamed", "275.50", F3]);
    assertEquals(await watermarkOf(sql, f.itemId), O3);
  });
});

Deno.test("B2/B1: is_included_in_finances and Plaid history survive accepted and superseded snapshots", options, async () => {
  await withDatabase("b2_b1_included_history", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2ih", true);
    await sql`grant select on table public.accounts to authenticated`;
    await asRole(sql, "authenticated", f.userId, (tx) =>
      tx`update public.accounts set is_included_in_finances = false where id = ${f.ids["b2ih-b"]}::uuid`);
    await applyTransactions(sql, f.userId, f.itemId, {
      added: [{ transactionId: "b2ih-tx", plaidAccountId: "b2ih-b", amount: 12.5, date: "2026-09-30", name: "Grocer" }],
    });
    await runAllProjectionJobs(sql);

    const history = async () => {
      const [row] = await sql`
        select
          (select count(*)::int from public.plaid_transactions
            where account_id = ${f.ids["b2ih-b"]}::uuid and transaction_id = 'b2ih-tx') as raw,
          (select count(*)::int from public.operations
            where source = 'plaid' and from_account_id = ${f.ids["b2ih-b"]}::uuid
              and archived_at is null) as operations`;
      return row;
    };
    const included = async () => {
      const state = await accountsOf(sql, f.itemId);
      return [state["b2ih-a"].included, state["b2ih-b"].included, state["b2ih-c"].included];
    };
    assertEquals(await history(), { raw: 1, operations: 1 });

    await persistOk(sql, f.userId, f.itemId, [], F1, O1);
    assertEquals(await included(), [true, false, true]);
    assertEquals(await history(), { raw: 1, operations: 1 });

    await assertSqlState(() => persist(sql, f.userId, f.itemId, snapshot(["b2ih-a"], "1.00"), F2, O0), "22023", SUPERSEDED);
    assertEquals(await included(), [true, false, true]);
    assertEquals(await history(), { raw: 1, operations: 1 });

    await persistOk(sql, f.userId, f.itemId, snapshot(["b2ih-a", "b2ih-b", "b2ih-c"], "120.00"), F2, O2);
    assertEquals(await included(), [true, false, true]);
    assertEquals(await history(), { raw: 1, operations: 1 });
    assertEquals((await accountsOf(sql, f.itemId))["b2ih-b"].id, f.ids["b2ih-b"]);
  });
});

Deno.test("B2/B1: other Items, other users and manual accounts are untouched; watermarks are per Item", options, async () => {
  await withDatabase("b2_b1_isolation", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2i", true);
    const sibling = await itemABC(sql, "b2is", true, f.userId);
    const stranger = await itemABC(sql, "b2ix", false);
    const [manual] = await sql`
      insert into public.accounts (user_id, name, type, currency_code, icon_key, color_key)
      values (${f.userId}::uuid, 'Wallet', 'cash', 'CAD', 'wallet', 'blue')
      returning id::text as id`;
    const manualRow = async () => {
      const [row] = await sql`select to_jsonb(accounts.*)::text as row from public.accounts where id = ${manual.id}::uuid`;
      return row.row;
    };
    const siblingBefore = await itemState(sql, sibling.itemId);
    const strangerBefore = await itemState(sql, stranger.itemId);
    const manualBefore = await manualRow();

    await persistOk(sql, f.userId, f.itemId, [], F1, O1);
    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], F2, O0), "22023", SUPERSEDED);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2i-a": F1, "b2i-b": F1, "b2i-c": F1 });
    assertEquals(await itemState(sql, sibling.itemId), siblingBefore);
    assertEquals(await itemState(sql, stranger.itemId), strangerBefore);
    assertEquals(await manualRow(), manualBefore);

    // A foreign user's Item is not found; its watermark stays NULL.
    await assertSqlState(() => persist(sql, f.userId, stranger.itemId, [], F2, O2), "22023", "plaid_item_not_found");
    assertEquals(await itemState(sql, stranger.itemId), strangerBefore);
    // The sibling's own watermark (O0) is independent of f's (O1).
    assertEquals(await watermarkOf(sql, sibling.itemId), O0);
    assertEquals(await persistOk(sql, f.userId, sibling.itemId, snapshot(["b2is-a"], "2.00"), F1, "2026-09-20T11:00:00.000Z"), 1);
  });
});

Deno.test("B2/B1: a disconnected Item refuses newer, stale and legacy snapshots without writes", options, async () => {
  await withDatabase("b2_b1_disconnected", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2d", true);
    const [{ r }] = await sql`select public.plaid_disconnect_item_local(${f.userId}::uuid, ${f.itemId}::uuid) as r`;
    assertEquals((r as Record<string, unknown>).status, "disconnected");
    const before = await itemState(sql, f.itemId);

    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], F1, O1), "22023", "plaid_item_disconnected");
    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], F1, O0), "22023", "plaid_item_disconnected");
    await assertSqlState(() => persistLegacy(sql, f.userId, f.itemId, [], F1), "22023", "plaid_item_disconnected");
    assertEquals(await itemState(sql, f.itemId), before);
  });
});

Deno.test("B2 atomicity: a failure after the first write leaves accounts, institution and watermark unchanged", options, async () => {
  await withDatabase("b2_atomic", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2a", true);
    const before = await itemState(sql, f.itemId);

    // Validation passes; the numeric cast fails inside the account upsert loop,
    // after the institution upsert has run.
    const failing = [snapshotAccount("b2a-a", "1.00"), { ...snapshotAccount("b2a-b", "1.00"), current_balance: "abc" }];
    await assertSqlState(() => persist(sql, f.userId, f.itemId, failing, F1, O1, "Half Bank"), "22P02");
    const invalid = [{ ...snapshotAccount("b2a-a", "1.00"), currency_code: "CADX" }];
    await assertSqlState(() => persist(sql, f.userId, f.itemId, invalid, F1, O1), "22023", "invalid_plaid_account_payload");
    await assertSqlState(
      () =>
        sql`select public.plaid_persist_accounts_sync(
          ${f.userId}::uuid, ${f.itemId}::uuid, 'ins', 'Bank', null, null, null,
          ${F1}::timestamptz, '{"accounts": []}'::jsonb, ${O1}::timestamptz)`,
      "22023",
      "accounts_required",
    );
    assertEquals(await itemState(sql, f.itemId), before);

    // A caller transaction that rolls back takes the watermark with it.
    let applied = false;
    await sql.begin(async (tx) => {
      await persist(tx as unknown as Sql, f.userId, f.itemId, [], F1, O2);
      applied = (await watermarkOf(tx as unknown as Sql, f.itemId)) === O2;
      throw new RollbackSignal();
    }).catch((error) => {
      if (!(error instanceof RollbackSignal)) throw error;
    });
    assert(applied);
    assertEquals(await itemState(sql, f.itemId), before);

    // The same newer snapshot still applies afterwards.
    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2a-a"], "1.00"), F1, O1), 1);
    assertEquals(await watermarkOf(sql, f.itemId), O1);
  });
});

// ---------------------------------------------------------------------------
// Legacy (9-argument) rollout path
// ---------------------------------------------------------------------------

Deno.test("B2 legacy: at NULL it applies B1 semantics and never writes the watermark", options, async () => {
  await withDatabase("b2_legacy_null", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2l", false);

    const [absent] = await persistLegacy(sql, f.userId, f.itemId, snapshot(["b2l-a", "b2l-c"], "150.00"), F1);
    assertEquals(absent.synced, 2);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2l-a": null, "b2l-b": F1, "b2l-c": null });
    assertEquals(await watermarkOf(sql, f.itemId), null);

    const [empty] = await persistLegacy(sql, f.userId, f.itemId, [], F2);
    assertEquals(empty.synced, 0);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2l-a": F2, "b2l-b": F1, "b2l-c": F2 });

    const [back] = await persistLegacy(sql, f.userId, f.itemId, snapshot(["b2l-a", "b2l-b", "b2l-c"], "175.00"), F3);
    assertEquals(back.synced, 3);
    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "b2l-a": null, "b2l-b": null, "b2l-c": null });
    for (const [key, row] of Object.entries(after)) {
      assertEquals(row.id, f.ids[key]);
      assertEquals(row.fetched, F3);
    }
    assertEquals(await watermarkOf(sql, f.itemId), null);
    // A null balance time keeps the B1 fallback and still writes no watermark.
    await persistLegacy(sql, f.userId, f.itemId, snapshot(["b2l-a"], "1.00"), null as unknown as string);
    assertEquals(await watermarkOf(sql, f.itemId), null);
  });
});

Deno.test("B2 legacy: once a watermark exists every legacy snapshot is superseded with no writes", options, async () => {
  await withDatabase("b2_legacy_after", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2la", false);
    await persistOk(sql, f.userId, f.itemId, snapshot(["b2la-a", "b2la-c"], "150.00"), F1, O1);
    assertEquals(await watermarkOf(sql, f.itemId), O1);
    const before = await itemState(sql, f.itemId);

    // Even a balance time far after the watermark proves nothing about observation.
    for (const accounts of [snapshot(["b2la-a", "b2la-b", "b2la-c"], "999.00"), snapshot(["b2la-a"], "999.00"), []]) {
      await assertSqlState(
        () => persistLegacy(sql, f.userId, f.itemId, accounts, "2026-12-31T00:00:00Z", "Legacy Renamed"),
        "22023",
        SUPERSEDED,
      );
    }
    assertEquals(await itemState(sql, f.itemId), before);
    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2la-a"], "1.00"), F2, O2), 1);
  });
});

// ---------------------------------------------------------------------------
// Two-session concurrency
// ---------------------------------------------------------------------------

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

async function boundedSession(db: { connect(): Sql }): Promise<Sql> {
  const session = db.connect();
  await session.unsafe("set lock_timeout = '20s'");
  return session;
}

class RollbackSignal extends Error {}

// Runs body in a transaction that stays open until commit() or rollback().
function holdOpen<T>(session: Sql, body: (tx: Sql) => Promise<T>) {
  let decide!: (commit: boolean) => void;
  const decided = new Promise<boolean>((resolve) => decide = resolve);
  let applied!: (value: T) => void;
  let failed!: (error: unknown) => void;
  const ran = new Promise<T>((resolve, reject) => {
    applied = resolve;
    failed = reject;
  });
  const done = session.begin(async (tx) => {
    let value: T;
    try {
      value = await body(tx as unknown as Sql);
    } catch (error) {
      failed(error);
      throw error;
    }
    applied(value);
    if (!(await decided)) {
      throw new RollbackSignal();
    }
  }).catch((error) => {
    if (!(error instanceof RollbackSignal)) throw error;
  });
  return { ran, done, commit: () => decide(true), rollback: () => decide(false) };
}

interface Race {
  first: (tx: Sql) => Promise<unknown>;
  second: (session: Sql) => Promise<unknown>;
  commitFirst?: boolean;
}

// first applies and holds the Item lock; second starts and must wait on it.
async function race(db: { connect(): Sql }, { first, second, commitFirst = true }: Race): Promise<Outcome> {
  const firstSession = await boundedSession(db);
  const secondSession = await boundedSession(db);
  const observer = db.connect();
  const held = holdOpen(firstSession, first);
  try {
    await held.ran;
    const waiting = outcome(second(secondSession));
    await waitForLockWait(observer, "plaid_persist_accounts_sync");
    if (commitFirst) held.commit();
    else held.rollback();
    await held.done;
    return await waiting;
  } finally {
    held.rollback();
    await held.done.catch(() => undefined);
  }
}

Deno.test("B2 concurrency A: the older snapshot locks first; the newer waits, applies and wins", options, async () => {
  await withDatabase("b2_race_a", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2ra", true);

    const result = await race(db, {
      first: (tx) => persist(tx, f.userId, f.itemId, snapshot(["b2ra-a"], "111.00"), F1, O1, "Older Bank"),
      second: (s) => persist(s, f.userId, f.itemId, snapshot(["b2ra-a", "b2ra-b", "b2ra-c", "b2ra-d"], "222.00"), F2, O2, "Newer Bank"),
    });

    assertEquals(result.code, null, result.message ?? undefined);
    assertEquals(await watermarkOf(sql, f.itemId), O2);
    assertEquals(await institutionName(sql, f.itemId), "Newer Bank");
    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "b2ra-a": null, "b2ra-b": null, "b2ra-c": null, "b2ra-d": null });
    assertEquals(Object.values(after).map((row) => row.balance), ["222.00", "222.00", "222.00", "222.00"]);
    assertEquals(await accountCount(sql, f.userId), 4);
  });
});

Deno.test("B2 concurrency B: the newer snapshot locks first; the older waits and is superseded with no writes", options, async () => {
  await withDatabase("b2_race_b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2rb", true);

    const result = await race(db, {
      first: (tx) => persist(tx, f.userId, f.itemId, snapshot(["b2rb-a", "b2rb-c"], "222.00"), F2, O2, "Newer Bank"),
      second: (s) => persist(s, f.userId, f.itemId, snapshot(["b2rb-a", "b2rb-b", "b2rb-c", "b2rb-d"], "111.00"), F1, O1, "Older Bank"),
    });

    assertEquals([result.code, result.message], ["22023", SUPERSEDED]);
    assertEquals(await watermarkOf(sql, f.itemId), O2);
    assertEquals(await institutionName(sql, f.itemId), "Newer Bank");
    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "b2rb-a": null, "b2rb-b": F2, "b2rb-c": null });
    assertEquals([after["b2rb-a"].balance, after["b2rb-b"].balance, after["b2rb-c"].balance], ["222.00", "100.00", "222.00"]);
    assertEquals(await accountCount(sql, f.userId), 3);
  });
});

Deno.test("B2 concurrency: a legacy snapshot waiting behind a watermarked one is superseded", options, async () => {
  await withDatabase("b2_race_legacy_after", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2rl", false);

    const result = await race(db, {
      first: (tx) => persist(tx, f.userId, f.itemId, snapshot(["b2rl-a", "b2rl-c"], "222.00"), F1, O1, "Newer Bank"),
      second: (s) => persistLegacy(s, f.userId, f.itemId, snapshot(["b2rl-a", "b2rl-b", "b2rl-c"], "333.00"), F3),
    });

    assertEquals([result.code, result.message], ["22023", SUPERSEDED]);
    assertEquals(await watermarkOf(sql, f.itemId), O1);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2rl-a": null, "b2rl-b": F1, "b2rl-c": null });
    assertEquals(await institutionName(sql, f.itemId), "Newer Bank");
  });
});

Deno.test("B2 concurrency: a legacy snapshot at NULL commits first; the waiting new one applies and sets the watermark", options, async () => {
  await withDatabase("b2_race_legacy_first", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2rn", false);

    const result = await race(db, {
      first: (tx) => persistLegacy(tx, f.userId, f.itemId, snapshot(["b2rn-a"], "111.00"), F1),
      second: (s) => persist(s, f.userId, f.itemId, snapshot(["b2rn-a", "b2rn-b", "b2rn-c"], "222.00"), F2, O2, "Newer Bank"),
    });

    assertEquals(result.code, null, result.message ?? undefined);
    assertEquals(await watermarkOf(sql, f.itemId), O2);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2rn-a": null, "b2rn-b": null, "b2rn-c": null });
    assertEquals(await institutionName(sql, f.itemId), "Newer Bank");
  });
});

Deno.test("B2 concurrency: a newer snapshot that rolls back does not supersede the waiting older one", options, async () => {
  await withDatabase("b2_race_rollback", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "b2rr", true);

    const result = await race(db, {
      first: (tx) => persist(tx, f.userId, f.itemId, [], F3, O3, "Rolled Back Bank"),
      second: (s) => persist(s, f.userId, f.itemId, snapshot(["b2rr-a", "b2rr-b"], "222.00"), F1, O1, "Older Bank"),
      commitFirst: false,
    });

    assertEquals(result.code, null, result.message ?? undefined);
    assertEquals(await watermarkOf(sql, f.itemId), O1);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "b2rr-a": null, "b2rr-b": null, "b2rr-c": F1 });
    assertEquals(await institutionName(sql, f.itemId), "Older Bank");
  });
});

Deno.test("B2 concurrency: watermarked persist vs Disconnect of a canonical twin does not deadlock", options, async () => {
  await withDatabase("b2_race_deadlock", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "b2dl");
    const itemA = await createPlaidItem(sql, user, "item-b2dl-a");
    const itemB = await createPlaidItem(sql, user, "item-b2dl-b");
    await persistOk(sql, user, itemA, snapshot(["b2dl-a1", "b2dl-a2"], "100.00"), F0, O0);
    await persistOk(sql, user, itemB, snapshot(["b2dl-b1", "b2dl-b2"], "100.00"), F0, O0);
    const a = Object.fromEntries(Object.entries(await accountsOf(sql, itemA)).map(([k, v]) => [k, v.id]));
    const b = Object.fromEntries(Object.entries(await accountsOf(sql, itemB)).map(([k, v]) => [k, v.id]));
    await link(sql, user, a["b2dl-a1"], b["b2dl-b1"], b["b2dl-b1"]);
    await link(sql, user, a["b2dl-a2"], b["b2dl-b2"], b["b2dl-b2"]);
    const [lo, hi] = a["b2dl-a1"] < a["b2dl-a2"] ? ["b2dl-a1", "b2dl-a2"] : ["b2dl-a2", "b2dl-a1"];

    const holder = db.connect();
    const persistSession = await boundedSession(db);
    const disconnectSession = await boundedSession(db);
    const observer = db.connect();
    let release!: () => void;
    const mayRelease = new Promise<void>((resolve) => release = resolve);
    let held!: () => void;
    const isHeld = new Promise<void>((resolve) => held = resolve);
    const holderTx = holder.begin(async (tx) => {
      await tx`select 1 from public.accounts where id = ${a[hi]}::uuid for update`;
      held();
      await mayRelease;
    });
    let results: Outcome[];
    try {
      await isHeld;
      const persisted = outcome(persist(persistSession, user, itemA, snapshot([hi], "205.00"), F1, O1));
      await waitForLockWait(observer, "plaid_persist_accounts_sync");
      const disconnected = outcome(
        disconnectSession`select public.plaid_disconnect_item_local(${user}::uuid, ${itemB}::uuid) as r`,
      );
      await waitForLockWait(observer, "plaid_disconnect_item_local");
      release();
      await holderTx;
      results = [await persisted, await disconnected];
    } finally {
      release();
      await holderTx.catch(() => undefined);
    }

    assertNotEquals(results[0].code, "40P01", results[0].message ?? undefined);
    assertNotEquals(results[1].code, "40P01", results[1].message ?? undefined);
    assertEquals(results.map((result) => result.code), [null, null]);
    assertEquals(missingOf(await accountsOf(sql, itemA)), { [lo]: F1, [hi]: null });
    assertEquals(await watermarkOf(sql, itemA), O1);
  });
});

// ---------------------------------------------------------------------------
// Applying M1 on a B1 database
// ---------------------------------------------------------------------------

Deno.test("B2 migration: M1 on a B1 database keeps every row, leaves watermarks NULL and keeps legacy callers working", options, async () => {
  await withDatabase("b2_upgrade", async (db) => {
    const sql = db.sql;
    const migrations = listMigrations();
    assert(migrations.includes(M1));
    for (const name of migrations.filter((name) => name < M1)) {
      await applyMigration(sql, name);
    }
    // B1 state: B is missing since F1.
    const userId = await createUser(sql, "b2u");
    const itemId = await createPlaidItem(sql, userId, "item-b2u");
    await persistLegacy(sql, userId, itemId, snapshot(["b2u-a", "b2u-b", "b2u-c"], "100.00"), F0);
    await persistLegacy(sql, userId, itemId, snapshot(["b2u-a", "b2u-c"], "100.00"), F1);
    const f = { userId, itemId };
    assertEquals(missingOf(await accountsOf(sql, itemId)), { "b2u-a": null, "b2u-b": F1, "b2u-c": null });
    const accountsBefore = await accountsOf(sql, f.itemId);
    const [itemBefore] = await sql`select to_jsonb(plaid_items.*) as row from public.plaid_items where id = ${f.itemId}::uuid`;

    await applyMigration(sql, M1);
    for (const name of migrations.filter((name) => name > M1)) {
      await applyMigration(sql, name);
    }

    assertEquals(await accountsOf(sql, f.itemId), accountsBefore);
    const [itemAfter] = await sql`select to_jsonb(plaid_items.*) as row from public.plaid_items where id = ${f.itemId}::uuid`;
    assertEquals(itemAfter.row, { ...itemBefore.row, accounts_observed_at: null });

    const [legacy] = await persistLegacy(sql, f.userId, f.itemId, snapshot(["b2u-a"], "150.00"), F2);
    assertEquals(legacy.synced, 1);
    assertEquals(await watermarkOf(sql, f.itemId), null);
    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["b2u-a", "b2u-b"], "175.00"), F3, O1), 2);
    assertEquals(await watermarkOf(sql, f.itemId), O1);
    await assertSqlState(() => persistLegacy(sql, f.userId, f.itemId, [], F3), "22023", SUPERSEDED);
  });
});
