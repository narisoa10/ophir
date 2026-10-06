// CAD-only product currency (20261005120000_cad_only_product_currency.sql).
// New profiles are CAD; only CAD Plaid transactions become Operations; raw
// Plaid currencies are kept; the migration changes no existing row.

import { assertEquals } from "jsr:@std/assert@1";
import {
  applyAllMigrations,
  applyMigration,
  listMigrations,
  type Sql,
  withDatabase,
} from "./harness.ts";
import {
  applyTransactions,
  createPlaidItem,
  createUser,
  operationFor,
  projectionState,
  runAllProjectionJobs,
  syncAccounts,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const CURRENCY_MIGRATION = "20261005120000_cad_only_product_currency.sql";

async function applyMigrationsBefore(sql: Sql, name: string): Promise<void> {
  for (const migration of listMigrations()) {
    if (migration >= name) {
      return;
    }
    await applyMigration(sql, migration);
  }
}

async function profileCurrency(sql: Sql, userId: string): Promise<string> {
  const [row] = await sql`
    select currency_code from public.profiles where id = ${userId}::uuid`;
  return row.currency_code;
}

async function operationCurrency(sql: Sql, operationId: string): Promise<string> {
  const [row] = await sql`
    select currency_code from public.operations where id = ${operationId}::uuid`;
  return row.currency_code;
}

async function operationCount(sql: Sql, userId: string): Promise<number> {
  const [row] = await sql`
    select count(*)::int as count from public.operations where user_id = ${userId}::uuid`;
  return row.count;
}

Deno.test("product currency is CAD and a new profile gets it from the column default", options, async () => {
  await withDatabase("currency_profile", async (db) => {
    await applyAllMigrations(db.sql);

    const [product] = await db.sql`select public.product_currency_code() as code`;
    assertEquals(product.code, "CAD");

    const [column] = await db.sql`
      select column_default from information_schema.columns
      where table_schema = 'public' and table_name = 'profiles' and column_name = 'currency_code'`;
    assertEquals(column.column_default, "product_currency_code()");

    const user = await createUser(db.sql, "currency-new");
    assertEquals(await profileCurrency(db.sql, user), "CAD");
  });
});

Deno.test("the migration changes no existing profile or operation currency", options, async () => {
  await withDatabase("currency_existing", async (db) => {
    await applyMigrationsBefore(db.sql, CURRENCY_MIGRATION);

    const user = await createUser(db.sql, "currency-legacy");
    assertEquals(await profileCurrency(db.sql, user), "USD");

    const item = await createPlaidItem(db.sql, user, `cur-legacy-${crypto.randomUUID()}`);
    await syncAccounts(db.sql, user, item, [
      { plaidAccountId: "legacy-usd", name: "USD", currencyCode: "USD" },
    ]);
    await applyTransactions(db.sql, user, item, {
      added: [{
        transactionId: "legacy-usd-1",
        plaidAccountId: "legacy-usd",
        amount: 30,
        date: "2026-09-01",
        name: "Legacy",
        isoCurrencyCode: "USD",
      }],
    });
    await runAllProjectionJobs(db.sql);
    const legacyOperation = (await operationFor(db.sql, item, "legacy-usd-1"))!;
    assertEquals(await operationCurrency(db.sql, legacyOperation), "USD");

    await applyMigration(db.sql, CURRENCY_MIGRATION);
    await runAllProjectionJobs(db.sql);

    assertEquals(await profileCurrency(db.sql, user), "USD");
    assertEquals(await operationFor(db.sql, item, "legacy-usd-1"), legacyOperation);
    assertEquals(await operationCurrency(db.sql, legacyOperation), "USD");
    assertEquals(await projectionState(db.sql, item, "legacy-usd-1"), {
      state: "posted_projected",
      suppressed_reason: null,
    });
  });
});

Deno.test("only CAD Plaid transactions become Operations; other currencies keep their raw identity", options, async () => {
  await withDatabase("currency_plaid", async (db) => {
    await applyAllMigrations(db.sql);

    const user = await createUser(db.sql, "currency-plaid");
    const item = await createPlaidItem(db.sql, user, `cur-plaid-${crypto.randomUUID()}`);
    const accounts = await syncAccounts(db.sql, user, item, [
      { plaidAccountId: "cad", name: "CAD" },
      { plaidAccountId: "usd", name: "USD", currencyCode: "USD" },
      { plaidAccountId: "btc", name: "BTC", currencyCode: null, unofficialCurrencyCode: "BTC" },
    ]);
    const base = { date: "2026-09-02", name: "Shop" };
    await applyTransactions(db.sql, user, item, {
      added: [
        { ...base, transactionId: "t-cad", plaidAccountId: "cad", amount: 10 },
        { ...base, transactionId: "t-cad-usd", plaidAccountId: "cad", amount: 11, isoCurrencyCode: "USD" },
        { ...base, transactionId: "t-usd", plaidAccountId: "usd", amount: 12, isoCurrencyCode: "USD" },
        { ...base, transactionId: "t-usd-zero", plaidAccountId: "usd", amount: 0, isoCurrencyCode: "USD" },
        {
          ...base,
          transactionId: "t-btc",
          plaidAccountId: "btc",
          amount: 13,
          isoCurrencyCode: null,
          unofficialCurrencyCode: "BTC",
        },
      ],
    });

    await runAllProjectionJobs(db.sql);

    const cadOperation = await operationFor(db.sql, item, "t-cad");
    assertEquals(cadOperation === null, false);
    assertEquals(await operationCurrency(db.sql, cadOperation!), "CAD");
    assertEquals(await projectionState(db.sql, item, "t-cad"), {
      state: "posted_projected",
      suppressed_reason: null,
    });

    for (const transactionId of ["t-cad-usd", "t-usd", "t-usd-zero", "t-btc"]) {
      assertEquals(await operationFor(db.sql, item, transactionId), null, transactionId);
      assertEquals(await projectionState(db.sql, item, transactionId), {
        state: "suppressed",
        suppressed_reason: "unsupported_currency",
      }, transactionId);
    }
    assertEquals(await operationCount(db.sql, user), 1);

    const raw = await db.sql`
      select transaction_id, iso_currency_code, unofficial_currency_code
      from public.plaid_transactions
      where plaid_item_id = ${item}::uuid and transaction_id in ('t-cad-usd', 't-usd', 't-btc')
      order by transaction_id`;
    assertEquals(raw.map((row) => ({ ...row })), [
      { transaction_id: "t-btc", iso_currency_code: null, unofficial_currency_code: "BTC" },
      { transaction_id: "t-cad-usd", iso_currency_code: "USD", unofficial_currency_code: null },
      { transaction_id: "t-usd", iso_currency_code: "USD", unofficial_currency_code: null },
    ]);

    const accountRows = await db.sql`
      select id::text as id, currency_code, unofficial_currency_code
      from public.accounts
      where id in (${accounts["usd"]}::uuid, ${accounts["btc"]}::uuid)
      order by name`;
    assertEquals(accountRows.map((row) => ({ ...row })), [
      { id: accounts["btc"], currency_code: null, unofficial_currency_code: "BTC" },
      { id: accounts["usd"], currency_code: "USD", unofficial_currency_code: null },
    ]);

    // Later syncs converge to the same state instead of failing or materializing.
    await applyTransactions(db.sql, user, item, {
      modified: [
        { ...base, transactionId: "t-usd", plaidAccountId: "usd", amount: 14, isoCurrencyCode: "USD" },
      ],
    });
    await runAllProjectionJobs(db.sql);

    assertEquals(await operationFor(db.sql, item, "t-usd"), null);
    assertEquals(await projectionState(db.sql, item, "t-usd"), {
      state: "suppressed",
      suppressed_reason: "unsupported_currency",
    });
    assertEquals(await operationCount(db.sql, user), 1);
  });
});
