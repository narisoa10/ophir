// Stage A–E behaviour on a database built from the full migration history.
// Runs only Stage A–E runtime entry points (persist, link, apply batch,
// projection phases, resolve/reverse, category override) and asserts their
// contracts, so a later migration that breaks A–E fails here.

import { assertEquals } from "jsr:@std/assert@1";
import { applyAllMigrations, type Sql, withDatabase } from "./harness.ts";
import {
  applyTransactions,
  createManualOperation,
  createPlaidItem,
  createUser,
  link,
  operationFor,
  operationRow,
  overrideCategory,
  projectionState,
  resolveDuplicate,
  reverseResolution,
  runAllProjectionJobs,
  syncAccounts,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

type Trace = Map<string, unknown>;

async function outcome(promise: Promise<unknown>): Promise<unknown> {
  try {
    const value = await promise;
    return { ok: (value as Record<string, unknown>)?.status ?? true };
  } catch (error) {
    const failure = error as Error & { code?: string };
    return { error: failure.message, code: failure.code };
  }
}

async function membershipTopology(sql: Sql, userId: string) {
  return await sql`
    select a.plaid_account_id, m.role, m.link_origin
    from public.plaid_canonical_financial_account_members m
    join public.accounts a on a.id = m.account_id
    where m.user_id = ${userId}::uuid
    order by a.plaid_account_id`;
}

async function runStageAEScenario(sql: Sql): Promise<Trace> {
  const trace: [string, unknown][] = [];
  const user = await createUser(sql, "scenario");
  const item1 = await createPlaidItem(sql, user, `scn-item-1-${crypto.randomUUID()}`);
  const item2 = await createPlaidItem(sql, user, `scn-item-2-${crypto.randomUUID()}`);

  // Stage B: persist + PAI first-wins; persist never creates memberships.
  const a = await syncAccounts(sql, user, item1, [
    { plaidAccountId: "s-a1", name: "A1", persistentAccountId: "pai-a" },
    { plaidAccountId: "s-a2", name: "A2" },
    { plaidAccountId: "s-a3", name: "A3", persistentAccountId: "pai-c" },
    { plaidAccountId: "s-a4", name: "A4" },
  ]);
  const b = await syncAccounts(sql, user, item2, [
    { plaidAccountId: "s-b1", name: "B1", persistentAccountId: "pai-a" },
    { plaidAccountId: "s-b2", name: "B2" },
  ]);
  trace.push(["members_after_persist", (await membershipTopology(sql, user)).length]);

  await syncAccounts(sql, user, item1, [
    { plaidAccountId: "s-a1", name: "A1", persistentAccountId: "pai-z" },
    { plaidAccountId: "s-a2", name: "A2", persistentAccountId: "pai-late" },
  ]);
  const pai = await sql`
    select plaid_account_id, persistent_account_id
    from public.accounts
    where user_id = ${user}::uuid and plaid_account_id in ('s-a1', 's-a2')
    order by 1`;
  trace.push(["pai_first_wins", pai]);
  trace.push(["members_after_resync", (await membershipTopology(sql, user)).length]);

  // Stage C: M1 (PAI evidence), M4, M1 (user confirmed), M2, M5, PAI conflict.
  trace.push(["link_m1_pai", await outcome(link(sql, user, a["s-a1"], b["s-b1"], a["s-a1"]))]);
  trace.push(["link_m4", await outcome(link(sql, user, a["s-a1"], b["s-b1"], a["s-a1"]))]);
  trace.push(["link_m1_user", await outcome(link(sql, user, a["s-a4"], b["s-b2"], a["s-a4"]))]);
  trace.push(["link_pai_conflict", await outcome(link(sql, user, a["s-a3"], b["s-b1"], a["s-a3"]))]);
  trace.push(["link_m5", await outcome(link(sql, user, a["s-a1"], b["s-b2"], a["s-a1"]))]);
  trace.push(["topology", await membershipTopology(sql, user)]);

  // Stage D: secondary raw rows are suppressed, authoritative ones projected.
  await applyTransactions(sql, user, item1, {
    added: [
      { transactionId: "s-d1", plaidAccountId: "s-a4", amount: 20, date: "2026-08-05", name: "Dup" },
      { transactionId: "s-d2", plaidAccountId: "s-a4", amount: 20, date: "2026-08-05", name: "Dup" },
      { transactionId: "s-r1", plaidAccountId: "s-a1", amount: 7, date: "2026-08-06", name: "Removed" },
      { transactionId: "s-o1", plaidAccountId: "s-a3", amount: 9, date: "2026-08-06", name: "Override" },
    ],
  });
  await applyTransactions(sql, user, item2, {
    added: [
      { transactionId: "s-s1", plaidAccountId: "s-b2", amount: 20, date: "2026-08-05", name: "Dup" },
    ],
  });
  await runAllProjectionJobs(sql);
  for (
    const [itemId, txn] of [[item1, "s-d1"], [item1, "s-d2"], [item1, "s-r1"], [item1, "s-o1"], [
      item2,
      "s-s1",
    ]]
  ) {
    trace.push([`projection_${txn}`, await projectionState(sql, itemId, txn)]);
    trace.push([`has_operation_${txn}`, (await operationFor(sql, itemId, txn)) !== null]);
  }

  // Stage E: resolve freezes the suppressed operation, reverse unfreezes sync.
  const kept = (await operationFor(sql, item1, "s-d1"))!;
  const suppressed = (await operationFor(sql, item1, "s-d2"))!;
  const resolution = await resolveDuplicate(sql, user, kept, suppressed);
  trace.push(["resolve", resolution.status]);
  trace.push(["resolve_again", await outcome(resolveDuplicate(sql, user, kept, suppressed))]);
  trace.push(["suppressed_after_resolve", await operationRow(sql, suppressed)]);

  await applyTransactions(sql, user, item1, {
    modified: [
      { transactionId: "s-d2", plaidAccountId: "s-a4", amount: 25, date: "2026-08-05", name: "Dup" },
    ],
  });
  await runAllProjectionJobs(sql);
  trace.push(["suppressed_frozen_during_resolution", await operationRow(sql, suppressed)]);

  const resolutionId = resolution.resolution_id as string;
  trace.push(["reverse", await outcome(reverseResolution(sql, user, resolutionId))]);
  trace.push(["reverse_again", await outcome(reverseResolution(sql, user, resolutionId))]);
  await applyTransactions(sql, user, item1, {
    modified: [
      { transactionId: "s-d2", plaidAccountId: "s-a4", amount: 26, date: "2026-08-05", name: "Dup" },
    ],
  });
  await runAllProjectionJobs(sql);
  trace.push(["suppressed_after_reverse_sync", await operationRow(sql, suppressed)]);

  // Category override survives a later PFC change of the raw row.
  const overridden = (await operationFor(sql, item1, "s-o1"))!;
  await overrideCategory(sql, user, overridden, "expenseHousingRent");
  await applyTransactions(sql, user, item1, {
    modified: [
      {
        transactionId: "s-o1",
        plaidAccountId: "s-a3",
        amount: 10,
        date: "2026-08-06",
        name: "Override",
        pfcPrimary: "GENERAL_MERCHANDISE",
        pfcDetailed: "GENERAL_MERCHANDISE_SUPERSTORES",
      },
    ],
  });
  await runAllProjectionJobs(sql);
  trace.push(["override_preserved", await operationRow(sql, overridden)]);

  // A removed raw transaction archives its materialized operation.
  const removed = (await operationFor(sql, item1, "s-r1"))!;
  await applyTransactions(sql, user, item1, { removed: ["s-r1"] });
  await runAllProjectionJobs(sql);
  trace.push(["removed_archived", (await operationRow(sql, removed)).archived]);

  const manual = await createManualOperation(sql, user);
  trace.push(["manual", await operationRow(sql, manual.operationId)]);

  // Stage A–E value contracts.
  trace.push([
    "sync_bootstrap_rejected",
    await outcome(sql`
      insert into public.plaid_canonical_financial_account_members
        (user_id, canonical_account_id, account_id, role, link_origin)
      select user_id, canonical_account_id, ${a["s-a2"]}::uuid, 'secondary', 'sync_bootstrap'
      from public.plaid_canonical_financial_account_members
      where account_id = ${a["s-a1"]}::uuid`),
  ]);
  trace.push([
    "internal_transfer_source_rejected",
    await outcome(sql`
      update public.operations set source = 'plaid_internal_transfer'
      where id = ${kept}::uuid`),
  ]);

  return new Map(trace.map(([key, value]) => [key, JSON.parse(JSON.stringify(value))]));
}

Deno.test("Stage A–E behaviour holds on the full migration history", options, async () => {
  await withDatabase("stage_ae", async (db) => {
    await applyAllMigrations(db.sql);
    const trace = await runStageAEScenario(db.sql);

    assertEquals(trace.get("members_after_persist"), 0);
    assertEquals(trace.get("pai_first_wins"), [
      { plaid_account_id: "s-a1", persistent_account_id: "pai-a" },
      { plaid_account_id: "s-a2", persistent_account_id: "pai-late" },
    ]);
    assertEquals(trace.get("members_after_resync"), 0);

    assertEquals(trace.get("link_m1_pai"), { ok: "created" });
    assertEquals(trace.get("link_m4"), { ok: "already_linked" });
    assertEquals(trace.get("link_m1_user"), { ok: "created" });
    assertEquals(
      (trace.get("link_pai_conflict") as { error: string }).error,
      "persistent_account_identity_conflict",
    );
    assertEquals((trace.get("link_m5") as { error: string }).error, "canonical_conflict");

    assertEquals(trace.get("projection_s-s1"), {
      state: "suppressed",
      suppressed_reason: "canonical_secondary",
    });
    assertEquals(trace.get("has_operation_s-s1"), false);
    for (const txn of ["s-d1", "s-d2", "s-r1", "s-o1"]) {
      assertEquals(trace.get(`has_operation_${txn}`), true, txn);
    }

    assertEquals(trace.get("resolve"), "resolved");
    assertEquals((trace.get("suppressed_frozen_during_resolution") as { amount: string }).amount, "20.00");
    assertEquals((trace.get("suppressed_after_reverse_sync") as { amount: string }).amount, "26.00");
    assertEquals(
      (trace.get("override_preserved") as { category_id: string }).category_id,
      "expenseHousingRent",
    );
    assertEquals(trace.get("removed_archived"), true);
    assertEquals((trace.get("manual") as { source: string }).source, "manual");

    assertEquals((trace.get("sync_bootstrap_rejected") as { code: string }).code, "23514");
    assertEquals((trace.get("internal_transfer_source_rejected") as { code: string }).code, "23514");
  });
});
