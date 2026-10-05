// Project B / B1: Plaid account presence (accounts.plaid_missing_since) reconciled
// inside plaid_persist_accounts_sync.

import { assert, assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import { applyAllMigrations, type Sql, withDatabase } from "./harness.ts";
import {
  applyTransactions,
  createPlaidItem,
  createUser,
  link,
  runAllProjectionJobs,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const SIGNATURE = "public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)";
const T0 = "2026-10-01T10:00:00Z";
const T1 = "2026-10-02T10:00:00Z";
const T2 = "2026-10-03T10:00:00Z";
const T3 = "2026-10-04T10:00:00Z";

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

// Supabase grants table privileges to authenticated by default; RLS decides.
async function grantAccountsSelectToAuthenticated(sql: Sql): Promise<void> {
  await sql`grant select on table public.accounts to authenticated`;
}

async function assertSqlState(promise: () => Promise<unknown>, code: string, message?: string): Promise<void> {
  const error = await assertRejects(promise) as { code?: string; message?: string; constraint_name?: string };
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

function persist(sql: Sql, userId: string, itemId: string, accounts: unknown[], fetchedAt: string) {
  return sql`
    select public.plaid_persist_accounts_sync(
      ${userId}::uuid, ${itemId}::uuid, 'ins_presence', 'Presence Bank',
      null, null, null, ${fetchedAt}::timestamptz, ${sql.json(accounts as never)}::jsonb
    ) as synced`;
}

async function persistOk(sql: Sql, userId: string, itemId: string, accounts: unknown[], fetchedAt: string): Promise<number> {
  const [row] = await persist(sql, userId, itemId, accounts, fetchedAt);
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

async function accountCount(sql: Sql, userId: string): Promise<number> {
  const [{ count }] = await sql`select count(*)::int as count from public.accounts where user_id = ${userId}::uuid`;
  return count;
}

interface ItemFixture {
  userId: string;
  itemId: string;
  ids: Record<string, string>;
}

// Item with accounts A, B and C persisted at T0 with balance 100.00.
async function itemABC(sql: Sql, label: string, userId?: string): Promise<ItemFixture> {
  const owner = userId ?? await createUser(sql, label);
  const itemId = await createPlaidItem(sql, owner, `item-${label}`);
  const names = ["a", "b", "c"].map((suffix) => `${label}-${suffix}`);
  assertEquals(await persistOk(sql, owner, itemId, snapshot(names, "100.00"), T0), 3);
  const accounts = await accountsOf(sql, itemId);
  return {
    userId: owner,
    itemId,
    ids: Object.fromEntries(Object.entries(accounts).map(([key, row]) => [key, row.id])),
  };
}

Deno.test("T1: A+B+C -> A+C marks only B missing; B keeps its row, id and balance", options, async () => {
  await withDatabase("b1_t1", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t1");
    const before = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(before), { "t1-a": null, "t1-b": null, "t1-c": null });

    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["t1-a", "t1-c"], "150.00"), T1), 2);

    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "t1-a": null, "t1-b": T1, "t1-c": null });
    assertEquals(after["t1-b"].id, f.ids["t1-b"]);
    assertEquals([after["t1-b"].balance, after["t1-b"].available, after["t1-b"].fetched], ["100.00", "100.00", T0]);
    assertEquals([after["t1-a"].balance, after["t1-c"].balance], ["150.00", "150.00"]);
    assertEquals(await accountCount(sql, f.userId), 3);
  });
});

Deno.test("T1b: A+B+C -> A marks B and C missing", options, async () => {
  await withDatabase("b1_t1b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t1b");

    assertEquals(await persistOk(sql, f.userId, f.itemId, snapshot(["t1b-a"], "150.00"), T1), 1);

    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "t1b-a": null, "t1b-b": T1, "t1b-c": T1 });
  });
});

Deno.test("T2: an accepted empty snapshot marks every account of the Item missing and deletes nothing", options, async () => {
  await withDatabase("b1_t2", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t2");

    assertEquals(await persistOk(sql, f.userId, f.itemId, [], T1), 0);

    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "t2-a": T1, "t2-b": T1, "t2-c": T1 });
    assertEquals(await accountCount(sql, f.userId), 3);
    for (const [key, row] of Object.entries(after)) {
      assertEquals(row.id, f.ids[key]);
      assertEquals([row.balance, row.available, row.fetched, row.item], ["100.00", "100.00", T0, f.itemId]);
    }
  });
});

Deno.test("T3: A+B+C -> A+C -> A+B+C returns B on the same row with fresh data", options, async () => {
  await withDatabase("b1_t3", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t3");
    await persistOk(sql, f.userId, f.itemId, snapshot(["t3-a", "t3-c"], "150.00"), T1);

    const returning = [
      snapshotAccount("t3-a", "200.00"),
      snapshotAccount("t3-b", "275.50", "Card renamed"),
      snapshotAccount("t3-c", "200.00"),
    ];
    assertEquals(await persistOk(sql, f.userId, f.itemId, returning, T2), 3);

    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "t3-a": null, "t3-b": null, "t3-c": null });
    assertEquals(after["t3-b"].id, f.ids["t3-b"]);
    assertEquals([after["t3-b"].name, after["t3-b"].balance, after["t3-b"].fetched], ["Card renamed", "275.50", T2]);
    assertEquals(await accountCount(sql, f.userId), 3);
  });
});

Deno.test("T4: repeated absence keeps the first plaid_missing_since and does not rewrite the row", options, async () => {
  await withDatabase("b1_t4", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t4");
    await persistOk(sql, f.userId, f.itemId, snapshot(["t4-a", "t4-c"], "150.00"), T1);
    const first = (await accountsOf(sql, f.itemId))["t4-b"];
    assertEquals(first.missing, T1);

    await persistOk(sql, f.userId, f.itemId, snapshot(["t4-a", "t4-c"], "160.00"), T2);
    await persistOk(sql, f.userId, f.itemId, [], T3);

    const later = await accountsOf(sql, f.itemId);
    assertEquals(later["t4-b"], first);
    assertEquals(missingOf(later), { "t4-a": T3, "t4-b": T1, "t4-c": T3 });
  });
});

Deno.test("T5: is_included_in_finances survives missing and return for both values", options, async () => {
  await withDatabase("b1_t5", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t5");
    await grantAccountsSelectToAuthenticated(sql);
    // The user's own write path: column grant + RLS for authenticated.
    await asRole(sql, "authenticated", f.userId, (tx) =>
      tx`update public.accounts set is_included_in_finances = false where id = ${f.ids["t5-b"]}::uuid`);

    await persistOk(sql, f.userId, f.itemId, [], T1);
    let state = await accountsOf(sql, f.itemId);
    assertEquals([state["t5-a"].included, state["t5-b"].included, state["t5-c"].included], [true, false, true]);

    await persistOk(sql, f.userId, f.itemId, snapshot(["t5-a", "t5-b", "t5-c"], "120.00"), T2);
    state = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(state), { "t5-a": null, "t5-b": null, "t5-c": null });
    assertEquals([state["t5-a"].included, state["t5-b"].included, state["t5-c"].included], [true, false, true]);
  });
});

Deno.test("T6: Plaid transactions and Operations stay attached to a missing and returning account", options, async () => {
  await withDatabase("b1_t6", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t6");
    await applyTransactions(sql, f.userId, f.itemId, {
      added: [{ transactionId: "t6-tx", plaidAccountId: "t6-b", amount: 12.5, date: "2026-09-30", name: "Grocer" }],
    });
    await runAllProjectionJobs(sql);

    const history = async () => {
      const [row] = await sql`
        select
          (select count(*)::int from public.plaid_transactions
            where account_id = ${f.ids["t6-b"]}::uuid and transaction_id = 't6-tx') as raw,
          (select count(*)::int from public.operations
            where source = 'plaid' and from_account_id = ${f.ids["t6-b"]}::uuid
              and archived_at is null) as operations`;
      return row;
    };
    assertEquals(await history(), { raw: 1, operations: 1 });

    await persistOk(sql, f.userId, f.itemId, snapshot(["t6-a", "t6-c"], "150.00"), T1);
    assertEquals(await history(), { raw: 1, operations: 1 });
    assertEquals((await accountsOf(sql, f.itemId))["t6-b"].missing, T1);

    await persistOk(sql, f.userId, f.itemId, snapshot(["t6-a", "t6-b", "t6-c"], "150.00"), T2);
    assertEquals(await history(), { raw: 1, operations: 1 });
    assertEquals((await accountsOf(sql, f.itemId))["t6-b"].id, f.ids["t6-b"]);
  });
});

Deno.test("T7: a disconnected Item refuses the snapshot and presence does not change", options, async () => {
  await withDatabase("b1_t7", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t7");
    await persistOk(sql, f.userId, f.itemId, snapshot(["t7-a", "t7-c"], "150.00"), T1);
    const [{ r }] = await sql`select public.plaid_disconnect_item_local(${f.userId}::uuid, ${f.itemId}::uuid) as r`;
    assertEquals((r as Record<string, unknown>).status, "disconnected");
    const before = await accountsOf(sql, f.itemId);

    await assertSqlState(() => persist(sql, f.userId, f.itemId, [], T2), "22023", "plaid_item_disconnected");
    await assertSqlState(
      () => persist(sql, f.userId, f.itemId, snapshot(["t7-b"], "1.00"), T2),
      "22023",
      "plaid_item_disconnected",
    );

    assertEquals(await accountsOf(sql, f.itemId), before);
    assertEquals(missingOf(before), { "t7-a": null, "t7-b": T1, "t7-c": null });
  });
});

Deno.test("T7b: a rejected snapshot (invalid payload) changes no presence", options, async () => {
  await withDatabase("b1_t7b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t7b");
    const before = await accountsOf(sql, f.itemId);

    const invalid = [snapshotAccount("t7b-a", "1.00"), { ...snapshotAccount("t7b-x", "1.00"), plaid_type: " " }];
    await assertSqlState(
      () => persist(sql, f.userId, f.itemId, invalid, T1),
      "22023",
      "invalid_plaid_account_payload",
    );
    await assertSqlState(
      () =>
        sql`select public.plaid_persist_accounts_sync(
          ${f.userId}::uuid, ${f.itemId}::uuid, 'ins', 'Bank', null, null, null,
          ${T1}::timestamptz, '{"accounts": []}'::jsonb)`,
      "22023",
      "accounts_required",
    );

    assertEquals(await accountsOf(sql, f.itemId), before);
  });
});

Deno.test("T8: other Items of the same user and other users are untouched", options, async () => {
  await withDatabase("b1_t8", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t8");
    const sibling = await itemABC(sql, "t8s", f.userId);
    const stranger = await itemABC(sql, "t8x");
    const siblingBefore = await accountsOf(sql, sibling.itemId);
    const strangerBefore = await accountsOf(sql, stranger.itemId);

    await persistOk(sql, f.userId, f.itemId, [], T1);
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "t8-a": T1, "t8-b": T1, "t8-c": T1 });
    assertEquals(await accountsOf(sql, sibling.itemId), siblingBefore);
    assertEquals(await accountsOf(sql, stranger.itemId), strangerBefore);

    // A foreign user cannot reconcile someone else's Item.
    await assertSqlState(() => persist(sql, f.userId, stranger.itemId, [], T2), "22023", "plaid_item_not_found");
    assertEquals(await accountsOf(sql, stranger.itemId), strangerBefore);
  });
});

Deno.test("T8b: account churn A -> D leaves A missing and inserts D as a new row (no merge)", options, async () => {
  await withDatabase("b1_t8b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t8b");

    await persistOk(sql, f.userId, f.itemId, snapshot(["t8b-b", "t8b-c", "t8b-d"], "150.00"), T1);

    const after = await accountsOf(sql, f.itemId);
    assertEquals(missingOf(after), { "t8b-a": T1, "t8b-b": null, "t8b-c": null, "t8b-d": null });
    assertEquals(after["t8b-a"].id, f.ids["t8b-a"]);
    assert(!Object.values(f.ids).includes(after["t8b-d"].id));
    assertEquals(await accountCount(sql, f.userId), 4);
  });
});

Deno.test("T9: manual accounts are never marked missing and cannot be", options, async () => {
  await withDatabase("b1_t9", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t9");
    const [manual] = await sql`
      insert into public.accounts (user_id, name, type, currency_code, icon_key, color_key)
      values (${f.userId}::uuid, 'Wallet', 'cash', 'CAD', 'wallet', 'blue')
      returning id::text as id, updated_at::text as updated`;

    await persistOk(sql, f.userId, f.itemId, [], T1);

    const [after] = await sql`
      select plaid_missing_since, updated_at::text as updated from public.accounts where id = ${manual.id}::uuid`;
    assertEquals(after, { plaid_missing_since: null, updated: manual.updated });

    const error = await assertRejects(() =>
      sql`update public.accounts set plaid_missing_since = now() where id = ${manual.id}::uuid`
    ) as { code?: string; constraint_name?: string };
    assertEquals([error.code, error.constraint_name], ["23514", "accounts_plaid_missing_since_plaid_only_check"]);
  });
});

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

Deno.test("T10: concurrent snapshots of one Item serialize without duplicates", options, async () => {
  await withDatabase("b1_t10", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t10");
    const holder = db.connect();
    const first = await boundedSession(db);
    const second = await boundedSession(db);
    const observer = db.connect();

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
      const a = outcome(persist(first, f.userId, f.itemId, snapshot(["t10-a", "t10-c"], "150.00"), T1));
      await waitForLockWait(observer, "plaid_persist_accounts_sync");
      const b = outcome(persist(second, f.userId, f.itemId, snapshot(["t10-a", "t10-b", "t10-c", "t10-d"], "175.00"), T2));
      for (let attempt = 0; attempt < 400; attempt += 1) {
        const [{ waiting }] = await observer`
          select count(*)::int as waiting from pg_stat_activity
          where datname = current_database() and wait_event_type = 'Lock'
            and query like '%plaid_persist_accounts_sync%'`;
        if (waiting >= 2) break;
        await new Promise((resolve) => setTimeout(resolve, 25));
      }
      release();
      await holderTx;
      const results = [await a, await b];
      assertEquals(results.map((result) => result.code), [null, null]);
    } finally {
      release();
      await holderTx.catch(() => undefined);
    }

    const after = await accountsOf(sql, f.itemId);
    assertEquals(Object.keys(after).sort(), ["t10-a", "t10-b", "t10-c", "t10-d"]);
    assertEquals(await accountCount(sql, f.userId), 4);
    const [{ duplicates }] = await sql`
      select count(*)::int as duplicates from (
        select plaid_account_id from public.accounts where user_id = ${f.userId}::uuid
        group by plaid_account_id having count(*) > 1) d`;
    assertEquals(duplicates, 0);
    // Each snapshot left a consistent presence set: either A+C (B, D missing) or A+B+C+D.
    const missing = missingOf(after);
    assert(
      JSON.stringify(missing) === JSON.stringify({ "t10-a": null, "t10-b": null, "t10-c": null, "t10-d": null }) ||
        (missing["t10-b"] === T1 && missing["t10-d"] === T1 && missing["t10-a"] === null),
      JSON.stringify(missing),
    );
  });
});

Deno.test("T10b: absent accounts are pre-locked in id order; persist vs Disconnect of a canonical twin does not deadlock", options, async () => {
  await withDatabase("b1_t10b", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "t10b");
    const itemA = await createPlaidItem(sql, user, "item-t10b-a");
    const itemB = await createPlaidItem(sql, user, "item-t10b-b");
    await persistOk(sql, user, itemA, snapshot(["t10b-a1", "t10b-a2"], "100.00"), T0);
    await persistOk(sql, user, itemB, snapshot(["t10b-b1", "t10b-b2"], "100.00"), T0);
    const a = Object.fromEntries(Object.entries(await accountsOf(sql, itemA)).map(([k, v]) => [k, v.id]));
    const b = Object.fromEntries(Object.entries(await accountsOf(sql, itemB)).map(([k, v]) => [k, v.id]));
    await link(sql, user, a["t10b-a1"], b["t10b-b1"], b["t10b-b1"]);
    await link(sql, user, a["t10b-a2"], b["t10b-b2"], b["t10b-b2"]);
    const [lo, hi] = a["t10b-a1"] < a["t10b-a2"] ? ["t10b-a1", "t10b-a2"] : ["t10b-a2", "t10b-a1"];

    // hi is held; the persist keeps hi and drops lo (absent). Disconnect of B locks
    // Item A's member accounts lo then hi. Without the id-ordered pre-lock of absent
    // rows the persist would hold hi and wait for lo while Disconnect holds lo.
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
      const persisted = outcome(persist(persistSession, user, itemA, snapshot([hi], "205.00"), T1));
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
    const after = await accountsOf(sql, itemA);
    assertEquals(missingOf(after), { [lo]: T1, [hi]: null });
    assertEquals([after[lo].balance, after[hi].balance], ["100.00", "205.00"]);
  });
});

Deno.test("T11: RPC contract unchanged; authenticated cannot write presence", options, async () => {
  await withDatabase("b1_t11", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const f = await itemABC(sql, "t11");
    await grantAccountsSelectToAuthenticated(sql);

    const [definition] = await sql`
      select pg_get_function_identity_arguments(p.oid) as args, pg_get_function_result(p.oid) as result,
             p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where p.oid = ${SIGNATURE}::regprocedure`;
    assertEquals(
      definition.args,
      "p_user_id uuid, p_connection_id uuid, p_plaid_institution_id text, p_institution_name text, " +
        "p_logo_base64 text, p_primary_color text, p_url text, p_balance_fetched_at timestamp with time zone, " +
        "p_accounts jsonb",
    );
    assertEquals(definition.result, "integer");
    assertEquals(definition.prosecdef, true);
    assertEquals(definition.proconfig, ['search_path=""']);
    const [privileges] = await sql`
      select has_function_privilege('service_role', ${SIGNATURE}, 'EXECUTE') as service,
             has_function_privilege('authenticated', ${SIGNATURE}, 'EXECUTE') as auth,
             has_function_privilege('anon', ${SIGNATURE}, 'EXECUTE') as anon,
             has_function_privilege('public', ${SIGNATURE}, 'EXECUTE') as public,
             has_column_privilege('authenticated', 'public.accounts', 'plaid_missing_since', 'UPDATE') as auth_update,
             has_column_privilege('anon', 'public.accounts', 'plaid_missing_since', 'UPDATE') as anon_update,
             has_column_privilege('authenticated', 'public.accounts', 'plaid_missing_since', 'SELECT') as auth_select`;
    assertEquals(privileges, {
      service: true,
      auth: false,
      anon: false,
      public: false,
      auth_update: false,
      anon_update: false,
      auth_select: true,
    });

    await assertSqlState(
      () => asRole(sql, "authenticated", f.userId, (tx) => persist(tx, f.userId, f.itemId, [], T1)),
      "42501",
    );
    await assertSqlState(
      () =>
        asRole(sql, "authenticated", f.userId, (tx) =>
          tx`update public.accounts set plaid_missing_since = now() where id = ${f.ids["t11-b"]}::uuid`),
      "42501",
    );
    assertEquals(missingOf(await accountsOf(sql, f.itemId)), { "t11-a": null, "t11-b": null, "t11-c": null });

    // The owner reads presence through the existing select policy.
    await persistOk(sql, f.userId, f.itemId, snapshot(["t11-a", "t11-c"], "150.00"), T1);
    const visible = await asRole(sql, "authenticated", f.userId, (tx) =>
      tx`select plaid_account_id, plaid_missing_since is not null as missing
         from public.accounts where plaid_item_id = ${f.itemId}::uuid order by plaid_account_id`);
    assertEquals(visible.map((row) => [row.plaid_account_id, row.missing]), [
      ["t11-a", false],
      ["t11-b", true],
      ["t11-c", false],
    ]);
  });
});
