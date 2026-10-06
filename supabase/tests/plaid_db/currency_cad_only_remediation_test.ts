// CAD-only remediation and invariants
// (20261005130000_cad_only_remediation_and_constraints.sql). Legacy product USD
// becomes CAD with the same amounts; Plaid USD is kept as reported but its
// accounts can never be included in finances; anything unexpected aborts.

import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  applyAllMigrations,
  applyMigration,
  listMigrations,
  type Sql,
  withDatabase,
} from "./harness.ts";
import {
  applyTransactions,
  createManualOperation,
  createPlaidItem,
  createUser,
  operationFor,
  projectionState,
  runAllProjectionJobs,
  syncAccounts,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const CURRENCY_MIGRATION = "20261005120000_cad_only_product_currency.sql";
const REMEDIATION_MIGRATION = "20261005130000_cad_only_remediation_and_constraints.sql";

async function applyMigrationsBefore(sql: Sql, name: string): Promise<void> {
  for (const migration of listMigrations()) {
    if (migration >= name) {
      return;
    }
    await applyMigration(sql, migration);
  }
}

async function asAuthenticated<T>(sql: Sql, userId: string, body: (tx: Sql) => Promise<T>): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${userId}, true)`;
    await tx.unsafe("set local role authenticated");
    return await body(tx as unknown as Sql);
  }) as T;
}

async function createBudget(
  sql: Sql,
  userId: string,
  currency: string,
): Promise<void> {
  const [setup] = await sql`
    insert into public.budget_setups (user_id) values (${userId}::uuid)
    returning id::text as id`;
  await sql`
    insert into public.budget_income_sources (
      setup_id, user_id, name, amount, currency_code, frequency
    )
    values (
      ${setup.id}::uuid, ${userId}::uuid, 'Salary', 5000.00, ${currency}, 'monthly'
    )`;
  await sql`
    insert into public.budget_obligations (
      setup_id, user_id, obligation_type, amount, currency_code, frequency
    )
    values
      (${setup.id}::uuid, ${userId}::uuid, 'living_expense', 1200.00, ${currency}, 'monthly'),
      (${setup.id}::uuid, ${userId}::uuid, 'living_expense', 89.99, ${currency}, 'monthly')`;
}

async function productState(sql: Sql, userId: string) {
  const [profile] = await sql`
    select currency_code from public.profiles where id = ${userId}::uuid`;
  const budget = await sql`
    select 'income' as kind, amount::text as amount, currency_code
    from public.budget_income_sources where user_id = ${userId}::uuid
    union all
    select 'obligation', amount::text, currency_code
    from public.budget_obligations where user_id = ${userId}::uuid
    order by 1, 2`;
  const manual = await sql`
    select amount::text as amount, currency_code
    from public.operations where user_id = ${userId}::uuid and source = 'manual'`;
  return {
    profile: profile.currency_code,
    budget: budget.map((row) => ({ ...row })),
    manual: manual.map((row) => ({ ...row })),
  };
}

async function externalState(sql: Sql, itemId: string) {
  const accounts = await sql`
    select plaid_account_id, currency_code, current_balance::text as balance
    from public.accounts where plaid_item_id = ${itemId}::uuid
    order by plaid_account_id`;
  const raw = await sql`
    select transaction_id, amount::text as amount, iso_currency_code
    from public.plaid_transactions where plaid_item_id = ${itemId}::uuid
    order by transaction_id`;
  const operations = await sql`
    select operation.id::text as id, operation.amount::text as amount, operation.currency_code
    from public.operations operation
    join public.accounts account
      on account.id = coalesce(operation.from_account_id, operation.to_account_id)
    where account.plaid_item_id = ${itemId}::uuid
    order by operation.amount`;
  return {
    accounts: accounts.map((row) => ({ ...row })),
    raw: raw.map((row) => ({ ...row })),
    operations: operations.map((row) => ({ ...row })),
  };
}

async function inclusion(sql: Sql, accountId: string): Promise<boolean> {
  const [row] = await sql`
    select is_included_in_finances from public.accounts where id = ${accountId}::uuid`;
  return row.is_included_in_finances;
}

function rejectsCheck(promise: () => Promise<unknown>, constraint: string) {
  return assertRejects(promise, Error, `violates check constraint "${constraint}"`);
}

Deno.test("remediation relabels legacy product USD to CAD and keeps Plaid USD as reported", options, async () => {
  await withDatabase("currency_remediation", async (db) => {
    await applyMigrationsBefore(db.sql, CURRENCY_MIGRATION);

    const user = await createUser(db.sql, "currency-remediation");
    await createBudget(db.sql, user, "USD");
    await createManualOperation(db.sql, user);

    const item = await createPlaidItem(db.sql, user, `cur-rem-${crypto.randomUUID()}`);
    const accounts = await syncAccounts(db.sql, user, item, [
      { plaidAccountId: "cad", name: "CAD" },
      { plaidAccountId: "usd", name: "USD", currencyCode: "USD" },
    ]);
    const base = { date: "2026-09-01", name: "Shop" };
    await applyTransactions(db.sql, user, item, {
      added: [
        { ...base, transactionId: "t-cad", plaidAccountId: "cad", amount: 10 },
        { ...base, transactionId: "t-usd", plaidAccountId: "usd", amount: 30, isoCurrencyCode: "USD" },
        {
          ...base,
          transactionId: "t-usd-pending",
          plaidAccountId: "usd",
          amount: 7,
          isoCurrencyCode: "USD",
          pending: true,
        },
      ],
    });
    await runAllProjectionJobs(db.sql);
    assertEquals(await inclusion(db.sql, accounts["usd"]), true);

    const productBefore = await productState(db.sql, user);
    assertEquals(productBefore.profile, "USD");
    const externalBefore = await externalState(db.sql, item);
    assertEquals(externalBefore.operations.map((row) => row.currency_code), ["CAD", "USD"]);
    const usdOperation = await operationFor(db.sql, item, "t-usd");
    const pendingBefore = await projectionState(db.sql, item, "t-usd-pending");

    await applyMigration(db.sql, CURRENCY_MIGRATION);
    await applyMigration(db.sql, REMEDIATION_MIGRATION);
    await runAllProjectionJobs(db.sql);

    assertEquals(await productState(db.sql, user), {
      profile: "CAD",
      budget: productBefore.budget.map((row) => ({ ...row, currency_code: "CAD" })),
      manual: productBefore.manual,
    });
    assertEquals(await externalState(db.sql, item), externalBefore);
    assertEquals(await operationFor(db.sql, item, "t-usd"), usdOperation);
    assertEquals(await projectionState(db.sql, item, "t-usd"), {
      state: "posted_projected",
      suppressed_reason: null,
    });
    assertEquals(await projectionState(db.sql, item, "t-usd-pending"), pendingBefore);
    assertEquals(await inclusion(db.sql, accounts["usd"]), false);
    assertEquals(await inclusion(db.sql, accounts["cad"]), true);

    // A pending USD transaction that later posts stays out of Operations.
    await applyTransactions(db.sql, user, item, {
      added: [{
        ...base,
        transactionId: "t-usd-posted",
        plaidAccountId: "usd",
        amount: 7,
        isoCurrencyCode: "USD",
        pendingTransactionId: "t-usd-pending",
      }],
      removed: ["t-usd-pending"],
    });
    await runAllProjectionJobs(db.sql);
    assertEquals(await operationFor(db.sql, item, "t-usd-posted"), null);
    assertEquals(await projectionState(db.sql, item, "t-usd-posted"), {
      state: "suppressed",
      suppressed_reason: "unsupported_currency",
    });
  });
});

Deno.test("the database keeps product data CAD-only and external accounts out of finances", options, async () => {
  await withDatabase("currency_invariants", async (db) => {
    await applyAllMigrations(db.sql);
    await db.sql`grant select on table public.accounts to authenticated`;

    const user = await createUser(db.sql, "currency-invariants");
    await createBudget(db.sql, user, "CAD");
    const { accountId: wallet } = await createManualOperation(db.sql, user);

    await rejectsCheck(
      () => db.sql`update public.profiles set currency_code = 'USD' where id = ${user}::uuid`,
      "profiles_product_currency_check",
    );
    await rejectsCheck(
      () => db.sql`update public.budget_income_sources set currency_code = 'USD' where user_id = ${user}::uuid`,
      "budget_income_sources_product_currency_check",
    );
    await rejectsCheck(
      () => db.sql`update public.budget_obligations set currency_code = 'USD' where user_id = ${user}::uuid`,
      "budget_obligations_product_currency_check",
    );
    await rejectsCheck(
      () =>
        db.sql`
          insert into public.operations (
            user_id, from_account_id, type, amount, currency_code, occurred_at, category_id, source
          )
          values (
            ${user}::uuid, ${wallet}::uuid, 'expense', 12.50, 'USD', '2026-08-02',
            'expenseFoodGroceries', 'manual'
          )`,
      "operations_manual_product_currency_check",
    );

    const item = await createPlaidItem(db.sql, user, `cur-inv-${crypto.randomUUID()}`);
    const accounts = await syncAccounts(db.sql, user, item, [
      { plaidAccountId: "cad", name: "CAD" },
      { plaidAccountId: "usd", name: "USD", currencyCode: "USD" },
      { plaidAccountId: "btc", name: "BTC", currencyCode: null, unofficialCurrencyCode: "BTC" },
    ]);
    assertEquals(await inclusion(db.sql, accounts["cad"]), true);
    assertEquals(await inclusion(db.sql, accounts["usd"]), false);
    assertEquals(await inclusion(db.sql, accounts["btc"]), false);

    await applyTransactions(db.sql, user, item, {
      added: [{
        transactionId: "t-usd",
        plaidAccountId: "usd",
        amount: 30,
        date: "2026-09-02",
        name: "Shop",
        isoCurrencyCode: "USD",
      }],
    });
    await runAllProjectionJobs(db.sql);
    const [raw] = await db.sql`
      select iso_currency_code from public.plaid_transactions
      where plaid_item_id = ${item}::uuid and transaction_id = 't-usd'`;
    assertEquals(raw.iso_currency_code, "USD");

    // The user may still choose for a CAD account, but never include another currency.
    await asAuthenticated(db.sql, user, (tx) =>
      tx`update public.accounts set is_included_in_finances = false where id = ${accounts["cad"]}::uuid`);
    await asAuthenticated(db.sql, user, (tx) =>
      tx`update public.accounts set is_included_in_finances = true where id = ${accounts["cad"]}::uuid`);
    assertEquals(await inclusion(db.sql, accounts["cad"]), true);
    for (const plaidAccountId of ["usd", "btc"]) {
      await rejectsCheck(
        () =>
          asAuthenticated(db.sql, user, (tx) =>
            tx`update public.accounts set is_included_in_finances = true
               where id = ${accounts[plaidAccountId]}::uuid`),
        "accounts_financial_participation_currency_check",
      );
      assertEquals(await inclusion(db.sql, accounts[plaidAccountId]), false, plaidAccountId);
    }

    // Refresh: a USD account stays excluded; an account Plaid now reports in
    // another currency is excluded without failing the sync.
    await syncAccounts(db.sql, user, item, [
      { plaidAccountId: "cad", name: "CAD", currencyCode: "USD" },
      { plaidAccountId: "usd", name: "USD", currencyCode: "USD" },
      { plaidAccountId: "btc", name: "BTC", currencyCode: null, unofficialCurrencyCode: "BTC" },
    ]);
    assertEquals(await inclusion(db.sql, accounts["cad"]), false);
    assertEquals(await inclusion(db.sql, accounts["usd"]), false);

    // Reconnecting the same bank as a new Item creates the USD account excluded.
    const reconnected = await createPlaidItem(db.sql, user, `cur-inv-re-${crypto.randomUUID()}`);
    const again = await syncAccounts(db.sql, user, reconnected, [
      { plaidAccountId: "usd-again", name: "USD", currencyCode: "USD" },
    ]);
    assertEquals(await inclusion(db.sql, again["usd-again"]), false);
  });
});

Deno.test("remediation aborts without changes on currency data it cannot attribute", options, async () => {
  await withDatabase("currency_remediation_guards", async (db) => {
    await applyMigrationsBefore(db.sql, REMEDIATION_MIGRATION);

    const legacy = await createUser(db.sql, "currency-guard-legacy");
    await db.sql`update public.profiles set currency_code = 'USD' where id = ${legacy}::uuid`;
    await createBudget(db.sql, legacy, "USD");
    const legacyBefore = await productState(db.sql, legacy);

    const other = await createUser(db.sql, "currency-guard-other");
    const assertAborts = async (message: string) => {
      await assertRejects(() => applyMigration(db.sql, REMEDIATION_MIGRATION), Error, message);
      assertEquals(await productState(db.sql, legacy), legacyBefore);
      const [applied] = await db.sql`
        select count(*)::int as count from supabase_migrations.schema_migrations
        where version = ${REMEDIATION_MIGRATION.split("_")[0]}`;
      assertEquals(applied.count, 0);
    };

    await db.sql`update public.profiles set currency_code = 'EUR' where id = ${other}::uuid`;
    await assertAborts("a profile has a currency other than");
    await db.sql`update public.profiles set currency_code = 'CAD' where id = ${other}::uuid`;

    await createBudget(db.sql, other, "USD");
    await assertAborts("a budget item has a currency not inherited");
    await db.sql`delete from public.budget_income_sources where user_id = ${other}::uuid`;
    await db.sql`delete from public.budget_obligations where user_id = ${other}::uuid`;

    const { operationId } = await createManualOperation(db.sql, other);
    await db.sql`update public.operations set currency_code = 'USD' where id = ${operationId}::uuid`;
    await assertAborts("a manual Operation is not in CAD");
    await db.sql`update public.operations set currency_code = 'CAD' where id = ${operationId}::uuid`;

    await applyMigration(db.sql, REMEDIATION_MIGRATION);
    assertEquals((await productState(db.sql, legacy)).profile, "CAD");
  });
});
