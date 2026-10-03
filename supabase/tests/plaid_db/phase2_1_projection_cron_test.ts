// Phase 2.1: the projection worker is scheduled by pg_cron exactly like the
// sync worker, and a projection job enqueued without a new sync batch drains
// through the existing projection phases.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
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
  runAllProjectionJobs,
  syncAccounts,
} from "./fixtures.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

const PROJECTION_MIGRATION = "20261003120000_schedule_plaid_transaction_projection_worker.sql";
const PROJECTION_JOB = "ophir-process-plaid-transaction-projection-jobs";
const SYNC_JOB = "ophir-process-plaid-transaction-sync-jobs";
const PROJECTION_PATH = "/functions/v1/plaid-process-transaction-projection-jobs";
const SYNC_PATH = "/functions/v1/plaid-process-transaction-sync-jobs";
const SHIM_SECRET_PLACEHOLDER = "plaid-db-local-placeholder";

interface CronRow {
  jobname: string;
  schedule: string;
  active: boolean;
  command: string;
}

async function plaidTransactionCronJobs(sql: Sql): Promise<CronRow[]> {
  const rows = await sql`
    select jobname, schedule, active, command
    from cron.job
    where jobname like 'ophir-process-plaid-transaction-%'
    order by jobname`;
  return rows as unknown as CronRow[];
}

async function applyAllMigrationsExcept(sql: Sql, excluded: string): Promise<void> {
  for (const name of listMigrations()) {
    if (name !== excluded) {
      await applyMigration(sql, name);
    }
  }
}

Deno.test("projection worker cron is registered once next to the sync worker cron", options, async () => {
  await withDatabase("phase21_cron", async (db) => {
    assert(listMigrations().includes(PROJECTION_MIGRATION));
    await applyAllMigrations(db.sql);

    const jobs = await plaidTransactionCronJobs(db.sql);
    assertEquals(jobs.map((job) => job.jobname), [PROJECTION_JOB, SYNC_JOB]);

    const projection = jobs.find((job) => job.jobname === PROJECTION_JOB)!;
    assertEquals(projection.schedule, "* * * * *");
    assertEquals(projection.active, true);
    assert(projection.command.includes(PROJECTION_PATH));
    assert(!projection.command.includes(SYNC_PATH));
    assert(projection.command.includes("'x-ophir-internal-secret'"));
    assert(projection.command.includes("'ophir_internal_worker_secret'"));
    assert(projection.command.includes("'ophir_worker_project_url'"));
    assert(!projection.command.includes(SHIM_SECRET_PLACEHOLDER));

    const sync = jobs.find((job) => job.jobname === SYNC_JOB)!;
    assertEquals(sync.schedule, "* * * * *");
    assertEquals(sync.active, true);
    assert(sync.command.includes(SYNC_PATH));
    assert(!sync.command.includes(PROJECTION_PATH));

    const [{ total }] = await db.sql`select count(*)::int as total from cron.job`;
    await applyMigration(db.sql, PROJECTION_MIGRATION);
    assertEquals(
      (await plaidTransactionCronJobs(db.sql)).map((job) => job.jobname),
      [PROJECTION_JOB, SYNC_JOB],
    );
    const [{ total: totalAfterReapply }] = await db.sql`select count(*)::int as total from cron.job`;
    assertEquals(totalAfterReapply, total);
  });
});

for (const secretName of ["ophir_worker_project_url", "ophir_internal_worker_secret"]) {
  Deno.test(`projection cron migration fails closed without ${secretName}`, options, async () => {
    await withDatabase("phase21_fail_closed", async (db) => {
      await applyAllMigrationsExcept(db.sql, PROJECTION_MIGRATION);
      await db.sql`delete from vault.secrets where name = ${secretName}`;

      await assertRejects(
        () => applyMigration(db.sql, PROJECTION_MIGRATION),
        Error,
        `${secretName}_missing`,
      );

      const jobs = await plaidTransactionCronJobs(db.sql);
      assertEquals(jobs.map((job) => job.jobname), [SYNC_JOB]);
      const [applied] = await db.sql`
        select count(*)::int as n
        from supabase_migrations.schema_migrations
        where version = ${PROJECTION_MIGRATION.split("_")[0]}`;
      assertEquals(applied.n, 0);
    });
  });
}

Deno.test("projection job enqueued without a new sync batch materializes once", options, async () => {
  await withDatabase("phase21_direct_enqueue", async (db) => {
    const sql = db.sql;
    await applyAllMigrations(sql);

    const userId = await createUser(sql, "direct-enqueue");
    const itemId = await createPlaidItem(sql, userId, "item-direct-enqueue");
    await syncAccounts(sql, userId, itemId, [{ plaidAccountId: "de-a1", name: "Checking" }]);
    await applyTransactions(sql, userId, itemId, {
      added: [
        { transactionId: "de-t1", plaidAccountId: "de-a1", amount: 12.5, date: "2026-09-01", name: "Grocer" },
        { transactionId: "de-t2", plaidAccountId: "de-a1", amount: -40, date: "2026-09-02", name: "Refund" },
      ],
    });

    // Drop the wakeup the batch enqueued, so only the direct enqueue below can drive projection.
    await sql`delete from public.plaid_transaction_projection_jobs where plaid_item_id = ${itemId}::uuid`;
    await runAllProjectionJobs(sql);
    assertEquals(await operationFor(sql, itemId, "de-t1"), null);
    assertEquals(await operationFor(sql, itemId, "de-t2"), null);

    const [enqueued] = await sql`
      select public.plaid_enqueue_transaction_projection_job(${userId}::uuid, ${itemId}::uuid) as r`;
    assertEquals((enqueued.r as { status: string }).status, "accepted");
    await runAllProjectionJobs(sql);

    const pairs = async () =>
      await sql`
        select projection.plaid_transaction_id, projection.operation_id::text as operation_id
        from public.plaid_transaction_operation_projections projection
        where projection.plaid_item_id = ${itemId}::uuid
        order by projection.plaid_transaction_id`;
    const plaidOperationCount = async () => {
      const [row] = await sql`
        select count(*)::int as n
        from public.operations operation
        join public.accounts account on account.id = operation.from_account_id
        where account.plaid_item_id = ${itemId}::uuid
          and operation.source = 'plaid'`;
      return row.n as number;
    };

    const firstPairs = await pairs();
    assertEquals(firstPairs.length, 2);
    for (const pair of firstPairs) {
      assert(pair.operation_id !== null, `${pair.plaid_transaction_id} not materialized`);
    }
    assertEquals(await plaidOperationCount(), 2);
    const [{ jobs }] = await sql`
      select count(*)::int as jobs
      from public.plaid_transaction_projection_jobs
      where plaid_item_id = ${itemId}::uuid`;
    assertEquals(jobs, 0);

    await sql`select public.plaid_enqueue_transaction_projection_job(${userId}::uuid, ${itemId}::uuid)`;
    await runAllProjectionJobs(sql);
    assertEquals(await pairs(), firstPairs);
    assertEquals(await plaidOperationCount(), 2);
  });
});
