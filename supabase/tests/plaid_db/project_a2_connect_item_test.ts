// Project A / A2: atomic Plaid connection RPC plaid_connect_item.

import { assert, assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import { applyAllMigrations, type Sql, withDatabase } from "./harness.ts";
import { createPlaidItem, createUser, syncAccounts } from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const SIGNATURE = "public.plaid_connect_item(uuid,text,text,text,text,text,text,text,text,timestamptz,jsonb)";
const LEGACY_SIGNATURE = "public.plaid_persist_sandbox_item(uuid,text,text)";

type Role = "anon" | "authenticated" | "service_role";

interface AccountInput {
  plaid_account_id: string;
  name: string;
  mask?: string | null;
  plaid_type?: string;
  plaid_subtype?: string | null;
  currency_code?: string | null;
  official_name?: string | null;
  current_balance?: string | null;
  persistent_account_id?: string | null;
}

interface ConnectArgs {
  userId: string;
  environment?: string | null;
  itemId: string | null;
  accessToken?: string | null;
  institutionId?: string | null;
  institutionName?: string | null;
  logo?: string | null;
  accounts: unknown;
}

function account(plaidAccountId: string, name: string, extra: Partial<AccountInput> = {}): AccountInput {
  return {
    plaid_account_id: plaidAccountId,
    name,
    mask: "0000",
    plaid_type: "depository",
    plaid_subtype: "checking",
    currency_code: "CAD",
    current_balance: "100.00",
    ...extra,
  };
}

function tokenFor(itemId: string | null): string {
  return `access-sandbox-a2-${itemId}`;
}

function connect(sql: Sql, args: ConnectArgs) {
  const accessToken = args.accessToken === undefined ? tokenFor(args.itemId) : args.accessToken;
  return sql`
    select public.plaid_connect_item(
      ${args.userId}::uuid,
      ${args.environment === undefined ? "sandbox" : args.environment}::text,
      ${args.itemId}::text,
      ${accessToken}::text,
      ${args.institutionId === undefined ? "ins_plaid_db" : args.institutionId}::text,
      ${args.institutionName === undefined ? "Plaid DB Bank" : args.institutionName}::text,
      ${args.logo === undefined ? "bG9nbw==" : args.logo}::text,
      null::text,
      null::text,
      now(),
      ${sql.json(args.accounts as never)}::jsonb
    ) as r`;
}

async function connectResult(sql: Sql, args: ConnectArgs): Promise<Record<string, unknown>> {
  const [row] = await connect(sql, args);
  return row.r as Record<string, unknown>;
}

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

async function counts(sql: Sql): Promise<Record<string, number>> {
  const [row] = await sql`
    select
      (select count(*)::int from vault.secrets) as secrets,
      (select count(*)::int from public.plaid_items) as items,
      (select count(*)::int from public.institutions) as institutions,
      (select count(*)::int from public.accounts) as accounts,
      (select count(*)::int from public.plaid_transaction_sync_jobs) as sync_jobs`;
  return row as unknown as Record<string, number>;
}

function assertNoSecrets(result: unknown, ...secrets: string[]): void {
  const text = JSON.stringify(result);
  for (const secret of secrets) {
    assert(!text.includes(secret), `result leaked ${secret}: ${text}`);
  }
  for (const key of ["access_token", "secret", "plaid_item_id", "user_id"]) {
    assert(!text.includes(key), `result exposes ${key}: ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Definition, grants, unauthenticated callers
// ---------------------------------------------------------------------------

Deno.test("a2 definition: security definer, empty search_path, no dynamic SQL, service_role only", options, async () => {
  await withDatabase("a2_definition", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const [definition] = await sql`
      select pg_get_function_identity_arguments(p.oid) as args,
             pg_get_function_result(p.oid) as result,
             p.prosrc, p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'plaid_connect_item'`;
    assertEquals(
      definition.args,
      "p_user_id uuid, p_plaid_environment text, p_plaid_item_id text, p_access_token text, " +
        "p_plaid_institution_id text, p_institution_name text, p_logo_base64 text, p_primary_color text, " +
        "p_url text, p_balance_fetched_at timestamp with time zone, p_accounts jsonb",
    );
    assertEquals(definition.result, "jsonb");
    assertEquals(definition.prosecdef, true);
    assertEquals(definition.proconfig, ['search_path=""']);
    const source = String(definition.prosrc).toLowerCase();
    assert(!/\bexecute\b/.test(source), "no dynamic SQL");
    assert(!source.includes("raise notice") && !source.includes("raise log"), "no logging of inputs");

    const [privileges] = await sql`
      select has_function_privilege('service_role', ${SIGNATURE}, 'EXECUTE') as service,
             has_function_privilege('authenticated', ${SIGNATURE}, 'EXECUTE') as auth,
             has_function_privilege('anon', ${SIGNATURE}, 'EXECUTE') as anon,
             has_function_privilege('public', ${SIGNATURE}, 'EXECUTE') as public`;
    assertEquals(privileges, { service: true, auth: false, anon: false, public: false });
  });
});

Deno.test("a2 unauthenticated and end-user callers are rejected; nothing is written", options, async () => {
  await withDatabase("a2_roles", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-role");
    const before = await counts(sql);
    const call = (tx: Sql) => connect(tx, { userId: user, itemId: "item-role", accounts: [account("role-1", "Chequing")] });

    await assertSqlState(() => asRole(sql, "anon", null, call), "42501");
    await assertSqlState(() => asRole(sql, "authenticated", user, call), "42501");
    assertEquals(await counts(sql), before);

    const result = await asRole(sql, "service_role", null, async (tx) => (await call(tx))[0].r as Record<string, unknown>);
    assertEquals(result.outcome, "created");
  });
});

// ---------------------------------------------------------------------------
// Input validation
// ---------------------------------------------------------------------------

Deno.test("a2 invalid identity and inputs are rejected before any write", options, async () => {
  await withDatabase("a2_inputs", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-inputs");
    const accounts = [account("in-1", "Chequing")];
    const before = await counts(sql);

    await assertSqlState(() => connect(sql, { userId: crypto.randomUUID(), itemId: "item-x", accounts }), "22023", "user_not_found");
    await assertSqlState(() => connect(sql, { userId: user, itemId: "  ", accounts }), "22023", "invalid_input");
    await assertSqlState(() => connect(sql, { userId: user, itemId: null, accounts }), "22023", "invalid_input");
    await assertSqlState(() => connect(sql, { userId: user, itemId: "item-x", accessToken: " ", accounts }), "22023", "invalid_input");
    await assertSqlState(() => connect(sql, { userId: user, itemId: "item-x", accessToken: null, accounts }), "22023", "invalid_input");
    await assertSqlState(() => connect(sql, { userId: user, itemId: "item-x", environment: null, accounts }), "22023", "invalid_input");
    await assertSqlState(
      () => connect(sql, { userId: user, itemId: "item-x", environment: "production", accounts }),
      "22023",
      "unsupported_plaid_environment",
    );
    await assertSqlState(
      () =>
        sql`select public.plaid_connect_item(
          null::uuid, 'sandbox', 'item-x', 'access-sandbox-x', null, null, null, null, null, now(), '[]'::jsonb)`,
      "22023",
      "invalid_input",
    );
    assertEquals(await counts(sql), before);
  });
});

Deno.test("a2 malformed account snapshots roll back completely, Vault included", options, async () => {
  await withDatabase("a2_malformed", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-malformed");
    const before = await counts(sql);
    const cases: [unknown, string][] = [
      [[], "accounts_required"],
      [{ plaid_account_id: "m-1" }, "accounts_required"],
      [null, "accounts_required"],
      [["not-an-object"], "invalid_plaid_account_payload"],
      [[account("m-1", "Chequing"), { ...account("m-2", "Savings"), name: " " }], "invalid_plaid_account_payload"],
      [[account("m-1", "Chequing", { plaid_type: " " })], "invalid_plaid_account_payload"],
      [[account("m-1", "Chequing", { currency_code: null })], "invalid_plaid_account_payload"],
      [[account("m-1", "Chequing", { currency_code: "CADX" })], "invalid_plaid_account_payload"],
      [[account("m-1", "Chequing"), account(" m-1 ", "Savings")], "invalid_plaid_account_payload"],
    ];
    for (const [accounts, message] of cases) {
      await assertSqlState(() => connect(sql, { userId: user, itemId: "item-malformed", accounts }), "22023", message);
    }
    assertEquals(await counts(sql), before);
  });
});

// ---------------------------------------------------------------------------
// Created
// ---------------------------------------------------------------------------

Deno.test("a2 created: secret, item, institution, the full account set and one sync job in one call", options, async () => {
  await withDatabase("a2_created", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-created");
    const before = await counts(sql);
    const accounts = [
      account("cr-1", "Chequing", { persistent_account_id: "pai-1", official_name: "Everyday Chequing" }),
      account("cr-2", "Savings", { plaid_subtype: "savings", mask: null }),
      account("cr-3", "Visa", { plaid_type: "credit", plaid_subtype: "credit card", current_balance: null }),
    ];

    const result = await connectResult(sql, { userId: user, itemId: "item-created", accounts });

    assertEquals(Object.keys(result).sort(), ["accounts_persisted", "connection_id", "decisions", "institution_persisted", "outcome"]);
    assertEquals(result.outcome, "created");
    assertEquals(result.accounts_persisted, 3);
    assertEquals(result.institution_persisted, true);
    assertEquals(result.decisions, [
      { index: 0, decision: "new" },
      { index: 1, decision: "new" },
      { index: 2, decision: "new" },
    ]);
    assertNoSecrets(result, tokenFor("item-created"), "item-created");
    const connectionId = String(result.connection_id);

    const after = await counts(sql);
    assertEquals(after, {
      secrets: before.secrets + 1,
      items: before.items + 1,
      institutions: before.institutions + 1,
      accounts: before.accounts + 3,
      sync_jobs: before.sync_jobs + 1,
    });

    const [item] = await sql`
      select items.user_id::text as user_id, items.plaid_environment, items.plaid_item_id,
             items.disconnected_at, items.status, secrets.secret
      from public.plaid_items items
      join vault.secrets secrets on secrets.id = items.access_token_secret_id
      where items.id = ${connectionId}::uuid`;
    assertEquals(item, {
      user_id: user,
      plaid_environment: "sandbox",
      plaid_item_id: "item-created",
      disconnected_at: null,
      status: "active",
      secret: tokenFor("item-created"),
    });

    const [institution] = await sql`
      select id::text as id, user_id::text as user_id, plaid_institution_id, name, logo_base64
      from public.institutions where plaid_item_id = ${connectionId}::uuid`;
    assertEquals(
      { ...institution, id: undefined },
      { id: undefined, user_id: user, plaid_institution_id: "ins_plaid_db", name: "Plaid DB Bank", logo_base64: "bG9nbw==" },
    );

    const stored = await sql`
      select plaid_account_id, name, official_name, mask, plaid_type, plaid_subtype, currency_code,
             current_balance::text as current_balance, persistent_account_id,
             institution_id::text as institution_id, balance_fetched_at is not null as fetched
      from public.accounts
      where plaid_item_id = ${connectionId}::uuid and user_id = ${user}::uuid
      order by plaid_account_id`;
    assertEquals([...stored], [
      {
        plaid_account_id: "cr-1",
        name: "Chequing",
        official_name: "Everyday Chequing",
        mask: "0000",
        plaid_type: "depository",
        plaid_subtype: "checking",
        currency_code: "CAD",
        current_balance: "100.00",
        persistent_account_id: "pai-1",
        institution_id: institution.id,
        fetched: true,
      },
      {
        plaid_account_id: "cr-2",
        name: "Savings",
        official_name: null,
        mask: null,
        plaid_type: "depository",
        plaid_subtype: "savings",
        currency_code: "CAD",
        current_balance: "100.00",
        persistent_account_id: null,
        institution_id: institution.id,
        fetched: true,
      },
      {
        plaid_account_id: "cr-3",
        name: "Visa",
        official_name: null,
        mask: "0000",
        plaid_type: "credit",
        plaid_subtype: "credit card",
        currency_code: "CAD",
        current_balance: null,
        persistent_account_id: null,
        institution_id: institution.id,
        fetched: true,
      },
    ]);

    const [job] = await sql`
      select user_id::text as user_id, status, attempt_count, rerun_requested, lease_token, last_error_code,
             next_attempt_at <= now() as due
      from public.plaid_transaction_sync_jobs where plaid_item_id = ${connectionId}::uuid`;
    assertEquals(job, {
      user_id: user,
      status: "pending",
      attempt_count: 0,
      rerun_requested: false,
      lease_token: null,
      last_error_code: null,
      due: true,
    });
  });
});

Deno.test("a2 institution metadata is optional: missing name or optional fields never fail the connection", options, async () => {
  await withDatabase("a2_institution", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-institution");

    const bare = await connectResult(sql, {
      userId: user,
      itemId: "item-no-institution",
      institutionId: null,
      institutionName: null,
      logo: null,
      accounts: [account("ni-1", "Chequing")],
    });
    assertEquals(bare.outcome, "created");
    assertEquals(bare.institution_persisted, false);
    const [bareRows] = await sql`
      select (select count(*)::int from public.institutions where plaid_item_id = ${String(bare.connection_id)}::uuid) as institutions,
             (select count(*)::int from public.accounts
               where plaid_item_id = ${String(bare.connection_id)}::uuid and institution_id is null) as accounts,
             (select count(*)::int from public.plaid_transaction_sync_jobs
               where plaid_item_id = ${String(bare.connection_id)}::uuid) as jobs`;
    assertEquals(bareRows, { institutions: 0, accounts: 1, jobs: 1 });

    const minimal = await connectResult(sql, {
      userId: user,
      itemId: "item-minimal-institution",
      institutionId: "ins_minimal",
      institutionName: "Minimal Bank",
      logo: " ",
      accounts: [account("mi-1", "Chequing")],
    });
    assertEquals(minimal.outcome, "created");
    assertEquals(minimal.institution_persisted, true);
    const [institution] = await sql`
      select plaid_institution_id, name, logo_base64, primary_color, url
      from public.institutions where plaid_item_id = ${String(minimal.connection_id)}::uuid`;
    assertEquals(institution, {
      plaid_institution_id: "ins_minimal",
      name: "Minimal Bank",
      logo_base64: null,
      primary_color: null,
      url: null,
    });
  });
});

// ---------------------------------------------------------------------------
// Idempotent existing Item (AD5)
// ---------------------------------------------------------------------------

Deno.test("a2 replay of the same Item is idempotent: no new secret, item, accounts or sync job", options, async () => {
  await withDatabase("a2_replay", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-replay");
    const accounts = [account("rp-1", "Chequing"), account("rp-2", "Savings", { plaid_subtype: "savings" })];
    const first = await connectResult(sql, { userId: user, itemId: "item-replay", accounts });
    assertEquals(first.outcome, "created");
    const afterFirst = await counts(sql);
    const [jobBefore] = await sql`
      select requested_at::text as requested_at, status from public.plaid_transaction_sync_jobs
      where plaid_item_id = ${String(first.connection_id)}::uuid`;

    for (
      const replay of [
        { accessToken: tokenFor("item-replay") },
        { accessToken: "access-sandbox-a2-a-different-token" },
        { accounts: [account("rp-1", "Chequing")] },
      ]
    ) {
      const result = await connectResult(sql, { userId: user, itemId: " item-replay ", accounts, ...replay });
      assertEquals(result, { outcome: "idempotent_existing", connection_id: first.connection_id });
      assertNoSecrets(result, tokenFor("item-replay"), "access-sandbox-a2-a-different-token");
    }

    assertEquals(await counts(sql), afterFirst);
    const [jobAfter] = await sql`
      select requested_at::text as requested_at, status from public.plaid_transaction_sync_jobs
      where plaid_item_id = ${String(first.connection_id)}::uuid`;
    assertEquals(jobAfter, jobBefore);
    const [{ secret }] = await sql`
      select secrets.secret from public.plaid_items items
      join vault.secrets secrets on secrets.id = items.access_token_secret_id
      where items.id = ${String(first.connection_id)}::uuid`;
    assertEquals(secret, tokenFor("item-replay"));
  });
});

Deno.test("a2 an Item of the same user created by the legacy path is also idempotent", options, async () => {
  await withDatabase("a2_replay_legacy", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-replay-legacy");
    const legacyId = await createPlaidItem(sql, user, "item-legacy");
    const before = await counts(sql);
    const result = await connectResult(sql, { userId: user, itemId: "item-legacy", accounts: [account("lg-1", "Chequing")] });
    assertEquals(result, { outcome: "idempotent_existing", connection_id: legacyId });
    assertEquals(await counts(sql), before);
  });
});

Deno.test("a2 a disconnected Item of the same user is refused, not reused; nothing is written", options, async () => {
  await withDatabase("a2_disconnected_item", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-disconnected");
    const created = await connectResult(sql, { userId: user, itemId: "item-disc", accounts: [account("dc-1", "Chequing")] });
    await sql`select public.plaid_disconnect_item_local(${user}::uuid, ${String(created.connection_id)}::uuid)`;
    const before = await counts(sql);
    await assertSqlState(
      () => connect(sql, { userId: user, itemId: "item-disc", accounts: [account("dc-1", "Chequing")] }),
      "22023",
      "plaid_item_disconnected",
    );
    assertEquals(await counts(sql), before);
  });
});

// ---------------------------------------------------------------------------
// Duplicate check over the full snapshot (AD1, AD2)
// ---------------------------------------------------------------------------

async function existingConnection(sql: Sql, userId: string, label: string, accounts: AccountInput[], institutionId = "ins_plaid_db") {
  return await connectResult(sql, { userId, itemId: `item-${label}`, institutionId, accounts });
}

Deno.test("a2 strong duplicate blocks the whole connection; nothing is written", options, async () => {
  await withDatabase("a2_strong", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-strong");
    await existingConnection(sql, user, "strong-old", [account("old-1", "Chequing", { mask: "1111" })]);
    const before = await counts(sql);

    // Same name, mask, type and subtype on a new Item of the same bank: strong.
    const blocked = await connectResult(sql, {
      userId: user,
      itemId: "item-strong-new",
      accounts: [account("new-0", "Savings", { mask: "9999", plaid_subtype: "savings" }), account("new-1", "Chequing", { mask: "1111" })],
    });
    assertEquals(blocked, {
      outcome: "strong_duplicate",
      decisions: [{ index: 0, decision: "new" }, { index: 1, decision: "duplicate" }],
    });
    assertNoSecrets(blocked, tokenFor("item-strong-new"), "item-strong-new");

    // The incoming name also matches a stored official name.
    const official = await connectResult(sql, {
      userId: user,
      itemId: "item-strong-official",
      accounts: [account("new-2", "Everyday", { mask: "2222", official_name: "Everyday Chequing Plus" })],
    });
    assertEquals(official.outcome, "created");
    const viaOfficial = await connectResult(sql, {
      userId: user,
      itemId: "item-strong-official-2",
      accounts: [account("new-3", "Everyday Chequing Plus", { mask: "2222" })],
    });
    assertEquals(viaOfficial, { outcome: "strong_duplicate", decisions: [{ index: 0, decision: "duplicate" }] });

    assertEquals((await counts(sql)).secrets, before.secrets + 1);
    assertEquals((await counts(sql)).items, before.items + 1);
  });
});

Deno.test("a2 strong duplicate by plaid_account_id, also under another institution, blocks", options, async () => {
  await withDatabase("a2_strong_id", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-strong-id");
    await existingConnection(sql, user, "id-old", [account("shared-acct", "Chequing")], "ins_other_bank");
    const before = await counts(sql);
    const blocked = await connectResult(sql, {
      userId: user,
      itemId: "item-id-new",
      accounts: [account("shared-acct", "Renamed", { mask: "4321", plaid_type: "credit" })],
    });
    assertEquals(blocked, { outcome: "strong_duplicate", decisions: [{ index: 0, decision: "duplicate" }] });
    assertEquals(await counts(sql), before);
    const [owner] = await sql`
      select plaid_items.plaid_item_id from public.accounts
      join public.plaid_items on plaid_items.id = accounts.plaid_item_id
      where accounts.plaid_account_id = 'shared-acct'`;
    assertEquals(owner.plaid_item_id, "item-id-old", "the existing account is not re-homed");
  });
});

Deno.test("a2 strong match on a disconnected Item blocks as disconnected_existing", options, async () => {
  await withDatabase("a2_strong_disconnected", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-strong-disc");
    const old = await existingConnection(sql, user, "sd-old", [account("sd-1", "Chequing", { mask: "5555" })]);
    await sql`select public.plaid_disconnect_item_local(${user}::uuid, ${String(old.connection_id)}::uuid)`;
    const before = await counts(sql);
    const blocked = await connectResult(sql, {
      userId: user,
      itemId: "item-sd-new",
      accounts: [account("sd-new-1", "Chequing", { mask: "5555" })],
    });
    assertEquals(blocked, { outcome: "strong_duplicate", decisions: [{ index: 0, decision: "disconnected_existing" }] });
    assertEquals(await counts(sql), before);
  });
});

Deno.test("a2 ambiguous matches do not block and are reported per account", options, async () => {
  await withDatabase("a2_ambiguous", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-ambiguous");
    await existingConnection(sql, user, "amb-old", [
      account("amb-old-1", "Chequing", { mask: "1111" }),
      account("amb-old-2", "Savings", { mask: null, plaid_subtype: "savings" }),
      account("amb-old-3", "Visa", { mask: "3333", plaid_type: "credit", plaid_subtype: "credit card" }),
    ]);

    const result = await connectResult(sql, {
      userId: user,
      itemId: "item-amb-new",
      accounts: [
        // Different mask, no type conflict: ambiguous.
        account("amb-1", "Chequing", { mask: "9999" }),
        // Stored mask is null: ambiguous.
        account("amb-2", "Savings", { mask: "2222", plaid_subtype: "savings" }),
        // Same mask, subtype conflict: ambiguous.
        account("amb-3", "Visa", { mask: "3333", plaid_type: "credit", plaid_subtype: "charge card" }),
        // Different mask and type conflict: none.
        account("amb-4", "Chequing", { mask: "8888", plaid_type: "credit" }),
        // Different name: none.
        account("amb-5", "Brokerage", { mask: "1111" }),
      ],
    });
    assertEquals(result.outcome, "created");
    assertEquals(result.accounts_persisted, 5);
    assertEquals(result.decisions, [
      { index: 0, decision: "ambiguous" },
      { index: 1, decision: "ambiguous" },
      { index: 2, decision: "ambiguous" },
      { index: 3, decision: "new" },
      { index: 4, decision: "new" },
    ]);
    const [{ n }] = await sql`
      select count(*)::int as n from public.accounts where plaid_item_id = ${String(result.connection_id)}::uuid`;
    assertEquals(n, 5);
  });
});

Deno.test("a2 accounts of other institutions and other users are outside the duplicate pool", options, async () => {
  await withDatabase("a2_pool", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-pool");
    const stranger = await createUser(sql, "a2-pool-stranger");
    await existingConnection(sql, user, "pool-other-bank", [account("pool-1", "Chequing", { mask: "1111" })], "ins_other_bank");
    await existingConnection(sql, stranger, "pool-stranger", [account("pool-2", "Chequing", { mask: "1111" })]);
    // A legacy Item whose accounts came through plaid_persist_accounts_sync is part of the pool.
    const legacyId = await createPlaidItem(sql, user, "item-pool-legacy");
    await syncAccounts(sql, user, legacyId, [{ plaidAccountId: "pool-3", name: "Savings", mask: "7777" }]);

    const result = await connectResult(sql, {
      userId: user,
      itemId: "item-pool-new",
      accounts: [account("pool-new-1", "Chequing", { mask: "1111" })],
    });
    assertEquals(result.outcome, "created");
    assertEquals(result.decisions, [{ index: 0, decision: "new" }]);

    const blocked = await connectResult(sql, {
      userId: user,
      itemId: "item-pool-new-2",
      accounts: [account("pool-new-2", "Savings", { mask: "7777" })],
    });
    assertEquals(blocked.outcome, "strong_duplicate");
  });
});

// ---------------------------------------------------------------------------
// Cross-user isolation
// ---------------------------------------------------------------------------

Deno.test("a2 cross-user: another user's Item is never returned or reused", options, async () => {
  await withDatabase("a2_cross_user", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const owner = await createUser(sql, "a2-owner");
    const stranger = await createUser(sql, "a2-stranger");
    const owned = await connectResult(sql, { userId: owner, itemId: "item-owned", accounts: [account("own-1", "Chequing")] });
    const before = await counts(sql);

    const error = await assertRejects(() =>
      connect(sql, { userId: stranger, itemId: "item-owned", accounts: [account("str-1", "Chequing")] })
    ) as { code?: string; message?: string };
    assertEquals(error.code, "23505");
    assertEquals(error.message, "plaid_item_conflict");
    assert(!String(error.message).includes(String(owned.connection_id)));
    assertEquals(await counts(sql), before);

    const [ownerItem] = await sql`
      select user_id::text as user_id from public.plaid_items where id = ${String(owned.connection_id)}::uuid`;
    assertEquals(ownerItem.user_id, owner);
  });
});

// ---------------------------------------------------------------------------
// Transaction rollback
// ---------------------------------------------------------------------------

Deno.test("a2 account persistence failure rolls everything back, Vault included", options, async () => {
  await withDatabase("a2_persist_failure", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-persist-failure");
    const before = await counts(sql);
    // Passes validation; fails at the numeric(14,2) cast after the secret and Item rows exist.
    await assertSqlState(
      () =>
        connect(sql, {
          userId: user,
          itemId: "item-persist-failure",
          accounts: [account("pf-1", "Chequing"), account("pf-2", "Savings", { current_balance: "1e20" })],
        }),
      "22003",
    );
    assertEquals(await counts(sql), before);
    const [{ n }] = await sql`select count(*)::int as n from vault.secrets where secret = ${tokenFor("item-persist-failure")}`;
    assertEquals(n, 0);

    // Nothing was left behind: the same Item connects once the snapshot is valid.
    const ok = await connectResult(sql, {
      userId: user,
      itemId: "item-persist-failure",
      accounts: [account("pf-1", "Chequing"), account("pf-2", "Savings")],
    });
    assertEquals(ok.outcome, "created");
    assertEquals(ok.decisions, [{ index: 0, decision: "new" }, { index: 1, decision: "new" }]);
  });
});

Deno.test("a2 initial sync enqueue failure rolls everything back, Vault included", options, async () => {
  await withDatabase("a2_queue_failure", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-queue-failure");
    // Test-only fault injection in the throwaway database.
    await sql.unsafe(`
      create function public.a2_test_fail_sync_job() returns trigger language plpgsql as $$
      begin
          raise exception 'a2_test_sync_job_failure';
      end;
      $$;
      create trigger a2_test_fail_sync_job
      before insert on public.plaid_transaction_sync_jobs
      for each row execute function public.a2_test_fail_sync_job();
    `);
    const before = await counts(sql);
    await assertSqlState(
      () => connect(sql, { userId: user, itemId: "item-queue-failure", accounts: [account("qf-1", "Chequing")] }),
      "P0001",
      "a2_test_sync_job_failure",
    );
    assertEquals(await counts(sql), before);

    await sql.unsafe(`drop trigger a2_test_fail_sync_job on public.plaid_transaction_sync_jobs`);
    const retried = await connectResult(sql, { userId: user, itemId: "item-queue-failure", accounts: [account("qf-1", "Chequing")] });
    assertEquals(retried.outcome, "created");
    assertEquals((await counts(sql)).sync_jobs, before.sync_jobs + 1);
  });
});

// ---------------------------------------------------------------------------
// Concurrency (AD4): real concurrent sessions
// ---------------------------------------------------------------------------

async function waitForAdvisoryWait(observer: Sql, needle: string): Promise<void> {
  for (let attempt = 0; attempt < 400; attempt += 1) {
    const [{ waiting }] = await observer`
      select count(*)::int as waiting from pg_stat_activity
      where datname = current_database()
        and wait_event_type = 'Lock'
        and wait_event = 'advisory'
        and query like ${`%${needle}%`}`;
    if (waiting > 0) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`${needle} never waited on the advisory lock`);
}

// `holder` runs plaid_connect_item and keeps its transaction (and the user lock) open
// until released.
async function holdConnection(db: { connect(): Sql }, args: ConnectArgs) {
  const holder = db.connect();
  let release!: () => void;
  const mayRelease = new Promise<void>((resolve) => release = resolve);
  let held!: (result: Record<string, unknown>) => void;
  const isHeld = new Promise<Record<string, unknown>>((resolve) => held = resolve);
  const done = holder.begin(async (tx) => {
    held(await connectResult(tx as unknown as Sql, args));
    await mayRelease;
  });
  const result = await Promise.race([
    isHeld,
    done.then(() => {
      throw new Error("holder finished before holding the lock");
    }),
  ]);
  return { result, release, done };
}

Deno.test("a2 concurrency: the same Item from two sessions of one user creates exactly one Item", options, async () => {
  await withDatabase("a2_concurrent_replay", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const user = await createUser(sql, "a2-concurrent");
    const before = await counts(sql);
    const accounts = [account("cc-1", "Chequing"), account("cc-2", "Savings", { plaid_subtype: "savings" })];

    const first = await holdConnection(db, { userId: user, itemId: "item-concurrent", accounts });
    try {
      assertEquals(first.result.outcome, "created");
      const second = db.connect();
      await second.unsafe("set lock_timeout = '20s'");
      const secondCall = connectResult(second, { userId: user, itemId: "item-concurrent", accounts });
      await waitForAdvisoryWait(db.connect(), "plaid_connect_item");
      first.release();
      await first.done;
      const secondResult = await secondCall;
      assertEquals(secondResult, { outcome: "idempotent_existing", connection_id: first.result.connection_id });
    } finally {
      first.release();
    }

    assertEquals(await counts(sql), {
      secrets: before.secrets + 1,
      items: before.items + 1,
      institutions: before.institutions + 1,
      accounts: before.accounts + 2,
      sync_jobs: before.sync_jobs + 1,
    });
  });
});

Deno.test("a2 concurrency: a waiting session of the same user sees the committed accounts as duplicates", options, async () => {
  await withDatabase("a2_concurrent_duplicate", async (db) => {
    await applyAllMigrations(db.sql);
    const user = await createUser(db.sql, "a2-concurrent-dup");
    const first = await holdConnection(db, {
      userId: user,
      itemId: "item-dup-a",
      accounts: [account("dup-a-1", "Chequing", { mask: "1234" })],
    });
    try {
      const second = db.connect();
      await second.unsafe("set lock_timeout = '20s'");
      const secondCall = connectResult(second, {
        userId: user,
        itemId: "item-dup-b",
        accounts: [account("dup-b-1", "Chequing", { mask: "1234" })],
      });
      await waitForAdvisoryWait(db.connect(), "plaid_connect_item");
      first.release();
      await first.done;
      assertEquals(await secondCall, { outcome: "strong_duplicate", decisions: [{ index: 0, decision: "duplicate" }] });
    } finally {
      first.release();
    }
    const [{ n }] = await db.sql`select count(*)::int as n from public.plaid_items where user_id = ${user}::uuid`;
    assertEquals(n, 1);
  });
});

Deno.test("a2 concurrency: the lock is user-scoped; another user is not blocked", options, async () => {
  await withDatabase("a2_concurrent_scope", async (db) => {
    await applyAllMigrations(db.sql);
    const owner = await createUser(db.sql, "a2-scope-owner");
    const other = await createUser(db.sql, "a2-scope-other");
    const first = await holdConnection(db, { userId: owner, itemId: "item-scope-a", accounts: [account("sc-a", "Chequing")] });
    try {
      const otherSession = db.connect();
      // Any wait on the owner's lock would fail this call.
      await otherSession.unsafe("set lock_timeout = '2s'");
      const otherResult = await connectResult(otherSession, {
        userId: other,
        itemId: "item-scope-b",
        accounts: [account("sc-b", "Chequing")],
      });
      assertEquals(otherResult.outcome, "created");

      const [{ held }] = await db.connect()`
        select count(*)::int as held from pg_locks
        where locktype = 'advisory' and granted and classid = 872514004`;
      assertEquals(held, 1, "the owner's lock is still held while the other user committed");

      const sameUser = db.connect();
      await sameUser.unsafe("set lock_timeout = '500ms'");
      await assertSqlState(
        () => connect(sameUser, { userId: owner, itemId: "item-scope-c", accounts: [account("sc-c", "Savings")] }),
        "55P03",
      );
    } finally {
      first.release();
    }
    await first.done;
    assertNotEquals(first.result.connection_id, null);
  });
});

Deno.test("a2 concurrency: two users racing for one Item; the loser waits on the winner's insert and rolls back fully", options, async () => {
  await withDatabase("a2_concurrent_cross_user", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const userA = await createUser(sql, "a2-race-a");
    const userB = await createUser(sql, "a2-race-b");
    const [hashes] = await sql`
      select hashtext(${userA}::uuid::text) as a, hashtext(${userB}::uuid::text) as b`;
    assertNotEquals(hashes.a, hashes.b, "the two users must have distinct advisory keys");
    const before = await counts(sql);
    const tokenA = "access-sandbox-a2-race-token-a";
    const tokenB = "access-sandbox-a2-race-token-b";

    // T1: user A connects Item X and keeps its transaction open after the insert.
    const holder = db.connect();
    let release!: () => void;
    const mayRelease = new Promise<void>((resolve) => release = resolve);
    let held!: (value: { result: Record<string, unknown>; pid: number; xid: string }) => void;
    const isHeld = new Promise<{ result: Record<string, unknown>; pid: number; xid: string }>((resolve) => held = resolve);
    const t1Done = holder.begin(async (tx) => {
      const result = await connectResult(tx as unknown as Sql, {
        userId: userA,
        itemId: "item-race",
        accessToken: tokenA,
        accounts: [account("race-a-1", "Chequing"), account("race-a-2", "Savings", { plaid_subtype: "savings" })],
      });
      const [self] = await tx`
        select pg_backend_pid() as pid,
               (select transactionid::text from pg_locks
                 where pid = pg_backend_pid() and locktype = 'transactionid' and granted) as xid`;
      held({ result, pid: self.pid, xid: self.xid });
      await mayRelease;
    });

    try {
      const t1 = await Promise.race([
        isHeld,
        t1Done.then(() => {
          throw new Error("T1 finished before holding its transaction");
        }),
      ]);
      assertEquals(t1.result.outcome, "created");
      assert(t1.xid !== null, "T1 has a transaction id");

      // T2: user B, same external item_id, separate session.
      const t2Session = db.connect();
      await t2Session.unsafe("set lock_timeout = '20s'");
      const [{ pid: t2Pid }] = await t2Session`select pg_backend_pid() as pid`;
      const t2 = outcomeOf(connectResult(t2Session, {
        userId: userB,
        itemId: "item-race",
        accessToken: tokenB,
        accounts: [account("race-b-1", "Chequing")],
      }));

      const observer = db.connect();
      let wait: Record<string, unknown> | undefined;
      for (let attempt = 0; attempt < 400 && wait === undefined; attempt += 1) {
        const rows = await observer`
          select activity.wait_event_type, activity.wait_event,
                 activity.backend_xid is not null as t2_has_xid,
                 pg_blocking_pids(activity.pid) as blockers,
                 waiting.transactionid::text as waited_xid
          from pg_stat_activity activity
          join pg_locks waiting on waiting.pid = activity.pid and not waiting.granted
          where activity.pid = ${t2Pid}`;
        if (rows.length > 0) {
          wait = rows[0];
        } else {
          await new Promise((resolve) => setTimeout(resolve, 25));
        }
      }
      assert(wait !== undefined, "T2 never waited on a lock");
      // T2 waits on T1's transaction id (unique check of plaid_items), not on an advisory lock.
      assertEquals(wait, {
        wait_event_type: "Lock",
        wait_event: "transactionid",
        t2_has_xid: true,
        blockers: [t1.pid],
        waited_xid: t1.xid,
      });

      const [locks] = await observer`
        select
          (select count(*)::int from pg_locks
            where locktype = 'advisory' and granted and classid = 872514004
              and objid::bigint in ((${hashes.a}::int)::bigint & 4294967295, (${hashes.b}::int)::bigint & 4294967295)
              and pid in (${t1.pid}, ${t2Pid})) as advisory_granted,
          (select count(*)::int from pg_locks
            where locktype = 'advisory' and not granted and pid = ${t2Pid}) as advisory_waiting,
          (select count(*)::int from pg_locks
            where pid = ${t2Pid} and locktype = 'relation' and granted and mode = 'RowExclusiveLock'
              and relation = 'vault.secrets'::regclass) as t2_vault_write,
          (select count(*)::int from vault.secrets where secret = ${tokenB}) as t2_secret_visible`;
      // Both user locks are held at once; T2 already inserted its Vault secret (uncommitted).
      assertEquals(locks, { advisory_granted: 2, advisory_waiting: 0, t2_vault_write: 1, t2_secret_visible: 0 });

      release();
      await t1Done;

      const t2Outcome = await t2;
      assertEquals(t2Outcome.code, "23505", t2Outcome.message ?? undefined);
      assertEquals(t2Outcome.constraint, "plaid_items_environment_item_unique");
    } finally {
      release();
      await t1Done.catch(() => undefined);
    }

    const [state] = await sql`
      select
        (select count(*)::int from public.plaid_items
          where plaid_environment = 'sandbox' and plaid_item_id = 'item-race') as items_x,
        (select user_id::text from public.plaid_items
          where plaid_environment = 'sandbox' and plaid_item_id = 'item-race') as owner,
        (select count(*)::int from public.plaid_items where user_id = ${userB}::uuid) as items_b,
        (select count(*)::int from public.accounts where user_id = ${userB}::uuid) as accounts_b,
        (select count(*)::int from public.institutions where user_id = ${userB}::uuid) as institutions_b,
        (select count(*)::int from public.plaid_transaction_sync_jobs where user_id = ${userB}::uuid) as jobs_b,
        (select count(*)::int from vault.secrets where secret = ${tokenB}) as secrets_b,
        (select count(*)::int from vault.secrets where secret = ${tokenA}) as secrets_a,
        (select secrets.secret from public.plaid_items items
          join vault.secrets secrets on secrets.id = items.access_token_secret_id
          where items.plaid_item_id = 'item-race') as stored_token,
        (select count(*)::int from public.accounts accounts
          join public.plaid_items items on items.id = accounts.plaid_item_id
          where items.plaid_item_id = 'item-race' and accounts.user_id = ${userA}::uuid) as accounts_a,
        (select count(*)::int from public.institutions institutions
          join public.plaid_items items on items.id = institutions.plaid_item_id
          where items.plaid_item_id = 'item-race' and institutions.user_id = ${userA}::uuid) as institutions_a,
        (select count(*)::int from public.plaid_transaction_sync_jobs jobs
          join public.plaid_items items on items.id = jobs.plaid_item_id
          where items.plaid_item_id = 'item-race' and jobs.user_id = ${userA}::uuid
            and jobs.status = 'pending') as jobs_a`;
    assertEquals(state, {
      items_x: 1,
      owner: userA,
      items_b: 0,
      accounts_b: 0,
      institutions_b: 0,
      jobs_b: 0,
      secrets_b: 0,
      secrets_a: 1,
      stored_token: tokenA,
      accounts_a: 2,
      institutions_a: 1,
      jobs_a: 1,
    });
    assertEquals(await counts(sql), {
      secrets: before.secrets + 1,
      items: before.items + 1,
      institutions: before.institutions + 1,
      accounts: before.accounts + 2,
      sync_jobs: before.sync_jobs + 1,
    });
  });
});

function outcomeOf(promise: Promise<unknown>): Promise<{ code: string | null; message: string | null; constraint: string | null }> {
  return promise.then(
    () => ({ code: null, message: null, constraint: null }),
    (error: { code?: string; message?: string; constraint_name?: string }) => ({
      code: error.code ?? "unknown",
      message: error.message ?? null,
      constraint: error.constraint_name ?? null,
    }),
  );
}

// ---------------------------------------------------------------------------
// Rollback path stays
// ---------------------------------------------------------------------------

Deno.test("a2 the legacy plaid_persist_sandbox_item rollback path is unchanged and still works", options, async () => {
  await withDatabase("a2_legacy", async (db) => {
    await applyAllMigrations(db.sql);
    const sql = db.sql;
    const [definition] = await sql`
      select pg_get_function_identity_arguments(p.oid) as args, pg_get_function_result(p.oid) as result,
             p.prosecdef, p.proconfig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'plaid_persist_sandbox_item'`;
    assertEquals(definition, {
      args: "p_user_id uuid, p_plaid_item_id text, p_access_token text",
      result: "uuid",
      prosecdef: true,
      proconfig: ['search_path=""'],
    });
    const [privileges] = await sql`
      select has_function_privilege('service_role', ${LEGACY_SIGNATURE}, 'EXECUTE') as service,
             has_function_privilege('authenticated', ${LEGACY_SIGNATURE}, 'EXECUTE') as auth,
             has_function_privilege('anon', ${LEGACY_SIGNATURE}, 'EXECUTE') as anon`;
    assertEquals(privileges, { service: true, auth: false, anon: false });

    const user = await createUser(sql, "a2-legacy");
    const itemId = await createPlaidItem(sql, user, "item-legacy-path");
    const [{ n }] = await sql`select count(*)::int as n from public.plaid_items where id = ${itemId}::uuid`;
    assertEquals(n, 1);
  });
});
