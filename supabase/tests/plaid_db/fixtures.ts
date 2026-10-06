// Fixture builders for the Plaid DB harness. Rows are created through the same
// RPCs the Plaid runtime uses, so their provenance (link_origin, timestamps,
// projection state) matches what production data looks like.

import type { Sql } from "./harness.ts";

export async function createUser(sql: Sql, label: string): Promise<string> {
  const [row] = await sql`
    insert into auth.users (email)
    values (${`${label}-${crypto.randomUUID()}@plaid-db.test`})
    returning id::text as id`;
  return row.id;
}

export async function createPlaidItem(
  sql: Sql,
  userId: string,
  externalItemId: string,
): Promise<string> {
  const [row] = await sql`
    select public.plaid_persist_sandbox_item(
      ${userId}::uuid, ${externalItemId}, ${`access-sandbox-${externalItemId}`}
    )::text as id`;
  return row.id;
}

export interface PlaidAccountInput {
  plaidAccountId: string;
  name: string;
  persistentAccountId?: string;
  mask?: string;
  currencyCode?: string | null;
  unofficialCurrencyCode?: string;
}

export async function syncAccounts(
  sql: Sql,
  userId: string,
  itemId: string,
  accounts: PlaidAccountInput[],
): Promise<Record<string, string>> {
  const payload = accounts.map((account) => ({
    plaid_account_id: account.plaidAccountId,
    name: account.name,
    mask: account.mask ?? "0000",
    plaid_type: "depository",
    plaid_subtype: "checking",
    currency_code: account.currencyCode === undefined ? "CAD" : account.currencyCode,
    unofficial_currency_code: account.unofficialCurrencyCode ?? null,
    current_balance: "100.00",
    available_balance: "100.00",
    persistent_account_id: account.persistentAccountId ?? null,
  }));

  await sql`
    select public.plaid_persist_accounts_sync(
      ${userId}::uuid, ${itemId}::uuid, 'ins_plaid_db', 'Plaid DB Bank',
      null, null, null, now(), ${sql.json(payload)}::jsonb
    )`;

  const rows = await sql`
    select plaid_account_id, id::text as id
    from public.accounts
    where user_id = ${userId}::uuid
      and plaid_item_id = ${itemId}::uuid`;
  return Object.fromEntries(rows.map((row) => [row.plaid_account_id, row.id]));
}

export interface TransactionInput {
  transactionId: string;
  plaidAccountId: string;
  amount: number;
  date: string;
  name: string;
  pending?: boolean;
  pendingTransactionId?: string;
  pfcPrimary?: string;
  pfcDetailed?: string;
  isoCurrencyCode?: string | null;
  unofficialCurrencyCode?: string;
}

function transactionPayload(transaction: TransactionInput) {
  return {
    transaction_id: transaction.transactionId,
    plaid_account_id: transaction.plaidAccountId,
    amount: transaction.amount.toFixed(2),
    date: transaction.date,
    pending: transaction.pending ?? false,
    ...(transaction.pendingTransactionId === undefined
      ? {}
      : { pending_transaction_id: transaction.pendingTransactionId }),
    iso_currency_code: transaction.isoCurrencyCode === undefined
      ? "CAD"
      : transaction.isoCurrencyCode,
    ...(transaction.unofficialCurrencyCode === undefined
      ? {}
      : { unofficial_currency_code: transaction.unofficialCurrencyCode }),
    name: transaction.name,
    merchant_name: transaction.name,
    personal_finance_category_primary: transaction.pfcPrimary ?? "FOOD_AND_DRINK",
    personal_finance_category_detailed: transaction.pfcDetailed ??
      "FOOD_AND_DRINK_GROCERIES",
    personal_finance_category_confidence_level: "VERY_HIGH",
    personal_finance_category_version: "v2",
  };
}

export async function applyTransactions(
  sql: Sql,
  userId: string,
  itemId: string,
  delta: {
    added?: TransactionInput[];
    modified?: TransactionInput[];
    removed?: string[];
  },
): Promise<void> {
  const [item] = await sql`
    select transactions_cursor
    from public.plaid_items
    where id = ${itemId}::uuid`;
  const added = (delta.added ?? []).map(transactionPayload);
  const modified = (delta.modified ?? []).map(transactionPayload);
  const removed = (delta.removed ?? []).map((id) => ({ transaction_id: id }));

  await sql`
    select public.plaid_apply_transactions_sync_batch(
      ${userId}::uuid, ${itemId}::uuid,
      ${item.transactions_cursor}::text, ${`cursor-${crypto.randomUUID()}`}::text,
      true,
      ${sql.json(added)}::jsonb, ${sql.json(modified)}::jsonb, ${sql.json(removed)}::jsonb
    )`;
}

async function runPhase(sql: Sql, statement: () => Promise<{ r: unknown }[]>) {
  for (let iteration = 0; iteration < 50; iteration++) {
    const [row] = await statement();
    const result = row.r as Record<string, unknown>;
    if (result.status !== "processed" && result.status !== undefined) {
      throw new Error(`projection phase returned ${JSON.stringify(result)}`);
    }
    if (result.has_more !== true) {
      return;
    }
  }
  throw new Error("projection phase did not converge");
}

// Drains every claimable projection job through reconcile → PFC → materialize →
// source sync, the same phase order as plaid-process-transaction-projection-jobs.
export async function runAllProjectionJobs(sql: Sql): Promise<void> {
  for (let round = 0; round < 20; round++) {
    const jobs = await sql`
      select connection_id::text as item_id, user_id::text as user_id,
             lease_token::text as lease_token,
             claimed_requested_at::text as claimed_requested_at
      from public.plaid_claim_transaction_projection_jobs(5, 600)`;
    if (jobs.length === 0) {
      return;
    }
    for (const job of jobs) {
      const args = [job.user_id, job.item_id, job.lease_token] as const;
      await runPhase(sql, () =>
        sql`
        select public.plaid_reconcile_transaction_operation_projections(
          ${args[0]}::uuid, ${args[1]}::uuid, ${args[2]}::uuid, 250) as r`);
      await runPhase(sql, () =>
        sql`
        select public.plaid_apply_pfc_category_mapping_for_item_with_lease(
          ${args[0]}::uuid, ${args[1]}::uuid, ${args[2]}::uuid, 250) as r`);
      await runPhase(sql, () =>
        sql`
        select public.plaid_materialize_transaction_operations(
          ${args[0]}::uuid, ${args[1]}::uuid, ${args[2]}::uuid, 100) as r`);
      await runPhase(sql, () =>
        sql`
        select public.plaid_sync_materialized_transaction_operations(
          ${args[0]}::uuid, ${args[1]}::uuid, ${args[2]}::uuid, 250) as r`);
      // Text parameter: postgres.js serializes timestamptz params through Date (ms).
      const [completion] = await sql`
        select public.plaid_complete_transaction_projection_job(
          ${job.item_id}::uuid, ${job.lease_token}::uuid,
          ${job.claimed_requested_at}::text::timestamptz
        ) as r`;
      const status = (completion.r as { status: string }).status;
      if (status !== "completed" && status !== "rerun_scheduled") {
        throw new Error(`projection job completion returned ${status}`);
      }
    }
  }
  throw new Error("projection jobs did not drain");
}

export async function operationFor(
  sql: Sql,
  itemId: string,
  transactionId: string,
): Promise<string | null> {
  const [row] = await sql`
    select operation_id::text as id
    from public.plaid_transaction_operation_projections
    where plaid_item_id = ${itemId}::uuid
      and plaid_transaction_id = ${transactionId}`;
  return row?.id ?? null;
}

export async function projectionState(
  sql: Sql,
  itemId: string,
  transactionId: string,
): Promise<{ state: string; suppressed_reason: string | null }> {
  const [row] = await sql`
    select state, suppressed_reason
    from public.plaid_transaction_operation_projections
    where plaid_item_id = ${itemId}::uuid
      and plaid_transaction_id = ${transactionId}`;
  return row as unknown as { state: string; suppressed_reason: string | null };
}

export async function createManualOperation(
  sql: Sql,
  userId: string,
): Promise<{ accountId: string; operationId: string }> {
  const [account] = await sql`
    insert into public.accounts (user_id, name, type, currency_code, icon_key, color_key)
    values (${userId}::uuid, 'Wallet', 'cash', 'CAD', 'wallet', 'blue')
    returning id::text as id`;
  const [operation] = await sql`
    insert into public.operations (
      user_id, from_account_id, type, amount, currency_code, occurred_at, category_id, source
    )
    values (
      ${userId}::uuid, ${account.id}::uuid, 'expense', 12.50, 'CAD', '2026-08-02',
      'expenseFoodGroceries', 'manual'
    )
    returning id::text as id`;
  return { accountId: account.id, operationId: operation.id };
}

export async function link(
  sql: Sql,
  userId: string,
  accountA: string,
  accountB: string,
  authoritative: string,
): Promise<Record<string, unknown>> {
  const [row] = await sql`
    select public.plaid_link_canonical_financial_accounts(
      ${userId}::uuid, ${accountA}::uuid, ${accountB}::uuid, ${authoritative}::uuid
    ) as r`;
  return row.r as Record<string, unknown>;
}

export async function resolveDuplicate(
  sql: Sql,
  userId: string,
  kept: string,
  suppressed: string,
): Promise<Record<string, unknown>> {
  const [row] = await sql`
    select public.plaid_resolve_duplicate_operations(
      ${userId}::uuid, ${kept}::uuid, ${suppressed}::uuid
    ) as r`;
  return row.r as Record<string, unknown>;
}

export async function reverseResolution(
  sql: Sql,
  userId: string,
  resolutionId: string,
): Promise<Record<string, unknown>> {
  const [row] = await sql`
    select public.plaid_reverse_duplicate_operation_resolution(
      ${userId}::uuid, ${resolutionId}::uuid
    ) as r`;
  return row.r as Record<string, unknown>;
}

export async function overrideCategory(
  sql: Sql,
  userId: string,
  operationId: string,
  categoryId: string,
): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${userId}, true)`;
    await tx`
      select public.plaid_override_operation_category(${operationId}::uuid, ${categoryId})`;
  });
}

export async function operationRow(
  sql: Sql,
  operationId: string,
): Promise<Record<string, unknown>> {
  const [row] = await sql`
    select source, archived_at is not null as archived, category_id, category_overridden,
           amount::text as amount
    from public.operations
    where id = ${operationId}::uuid`;
  return row as unknown as Record<string, unknown>;
}
