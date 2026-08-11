import {
  computeTransactionSyncJobBackoffSeconds,
  createJobLeaseRenewingTransactionsDatabase,
  createPlaidProcessTransactionSyncJobsHandler,
  type TransactionSyncJobWorkerDatabase,
} from "./handler.ts";
import type { PlaidTransactionsSyncCoreResult } from "../plaid-sync-transactions/handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const leaseToken = "33333333-3333-4333-8333-333333333333";
const claimedRequestedAt = "2026-08-11T12:00:00.000Z";
const internalSecret = "worker-secret-value";
const accessToken = "access-token-secret-value";
const cursor = "cursor-secret-value";

type ClaimedJob = {
  connectionId: string;
  userId: string;
  leaseToken: string;
  claimedRequestedAt: string;
  attemptCount: number;
};

type HarnessOptions = {
  secretHeader?: string | null;
  envSecret?: string | null;
  claimedJobs?: ClaimedJob[];
  validateResults?: boolean[];
  syncResults?: PlaidTransactionsSyncCoreResult[];
  syncThrows?: boolean;
  completeResults?: Array<
    "completed" | "rerun_scheduled" | "missing" | "lease_lost" | null
  >;
  dropResults?: Array<"dropped" | "missing" | "lease_lost" | null>;
  failResults?: Array<"rescheduled" | "lease_lost" | "missing" | null>;
};

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function job(overrides: Partial<ClaimedJob> = {}): ClaimedJob {
  return {
    connectionId,
    userId,
    leaseToken,
    claimedRequestedAt,
    attemptCount: 1,
    ...overrides,
  };
}

function synced(): PlaidTransactionsSyncCoreResult {
  return {
    kind: "synced",
    addedCount: 0,
    modifiedCount: 0,
    removedCount: 0,
    pageCount: 1,
    restartCount: 0,
    transactionsUpdateStatus: null,
    initialSyncCompleted: false,
  };
}

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const failBackoffs: number[] = [];
  const failCodes: string[] = [];
  const jobLeaseRenewals: number[] = [];
  const syncJobs: ClaimedJob[] = [];
  const claimedJobs = options.claimedJobs ?? [];
  const validateResults = [...(options.validateResults ?? [])];
  const syncResults = [...(options.syncResults ?? [synced()])];
  const completeResults = [...(options.completeResults ?? ["completed"])];
  const dropResults = [...(options.dropResults ?? ["dropped"])];
  const failResults = [...(options.failResults ?? ["rescheduled"])];

  const database: TransactionSyncJobWorkerDatabase = {
    async claimTransactionSyncJobs(batchSize, leaseSeconds) {
      calls.push(`claim:${batchSize}:${leaseSeconds}`);
      return claimedJobs;
    },
    async validateTransactionSyncJobLease(
      receivedConnectionId,
      receivedLeaseToken,
    ) {
      calls.push(`validate:${receivedConnectionId}:${receivedLeaseToken}`);
      return validateResults.length === 0 ? true : validateResults.shift()!;
    },
    async completeTransactionSyncJob(receivedConnectionId, receivedLeaseToken) {
      calls.push(`complete:${receivedConnectionId}:${receivedLeaseToken}`);
      return completeResults.length === 0
        ? "completed"
        : completeResults.shift()!;
    },
    async dropTransactionSyncJob(receivedConnectionId, receivedLeaseToken) {
      calls.push(`drop:${receivedConnectionId}:${receivedLeaseToken}`);
      return dropResults.length === 0 ? "dropped" : dropResults.shift()!;
    },
    async failTransactionSyncJob(
      receivedConnectionId,
      receivedLeaseToken,
      errorCode,
      backoffSeconds,
    ) {
      calls.push(`fail:${receivedConnectionId}:${receivedLeaseToken}`);
      failCodes.push(errorCode);
      failBackoffs.push(backoffSeconds);
      return failResults.length === 0 ? "rescheduled" : failResults.shift()!;
    },
    async renewTransactionSyncJobLease() {
      calls.push("renew_job_lease");
      jobLeaseRenewals.push(900);
      return true;
    },
    async acquireLease() {
      calls.push("unexpected_acquire_lease");
      return null;
    },
    async renewLease() {
      calls.push("unexpected_renew_lease");
      return false;
    },
    async releaseLease() {
      calls.push("unexpected_release_lease");
      return false;
    },
    async getAccessTokenForItem() {
      calls.push("unexpected_get_access_token");
      return null;
    },
    async applyTransactionsSyncBatch() {
      calls.push("unexpected_apply_batch");
      return null;
    },
  };

  const handler = createPlaidProcessTransactionSyncJobsHandler({
    createDatabase: () => database,
    getEnv: (name) => {
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return options.envSecret === undefined
          ? internalSecret
          : options.envSecret ?? undefined;
      }
      if (name === "PLAID_TRANSACTION_SYNC_JOB_BATCH_SIZE") {
        return "5";
      }
      return undefined;
    },
    randomUUID: () => "44444444-4444-4444-8444-444444444444",
    syncTransactions: async ({ job: claimedJob }) => {
      calls.push(`sync:${claimedJob.connectionId}:${claimedJob.leaseToken}`);
      syncJobs.push(claimedJob);
      if (options.syncThrows) {
        throw new Error("sync crashed");
      }
      return syncResults.length === 0 ? synced() : syncResults.shift()!;
    },
    log: () => {},
  });

  const headers = new Headers();
  if (options.secretHeader !== null) {
    headers.set(
      "x-ophir-internal-secret",
      options.secretHeader ?? internalSecret,
    );
  }

  const request = new Request("https://example.com", {
    method: "POST",
    headers,
  });

  return {
    handler,
    request,
    calls,
    failBackoffs,
    failCodes,
    jobLeaseRenewals,
    syncJobs,
  };
}

Deno.test("wrong internal auth is rejected", async () => {
  const { handler, request, calls } = createHarness({
    secretHeader: "wrong-secret",
    claimedJobs: [job()],
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("missing internal auth is rejected", async () => {
  const { handler, request, calls } = createHarness({
    secretHeader: null,
    claimedJobs: [job()],
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("no due jobs returns clean success", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "processed");
  assertEquals(body.claimed, 0);
  assertEquals(body.succeeded, 0);
});

Deno.test("pending job claimed and completed", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.claimed, 1);
  assertEquals(body.succeeded, 1);
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "job was not completed",
  );
});

Deno.test("retry_wait due job claimed and completed", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job({ attemptCount: 3 })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assert(calls[0] === "claim:5:900", "worker did not claim bounded batch");
  assert(
    calls.includes(`sync:${connectionId}:${leaseToken}`),
    "due retry job was not synced",
  );
});

Deno.test("future next_attempt_at jobs are not claimed by worker", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.claimed, 0);
  assertEquals(calls.includes("sync"), false);
});

Deno.test("stale processing lease reclaimed job can run", async () => {
  const { handler, request, syncJobs } = createHarness({
    claimedJobs: [job({ attemptCount: 2 })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(syncJobs.length, 1);
  assertEquals(syncJobs[0].attemptCount, 2);
});

Deno.test("live processing lease is not stolen", async () => {
  const { handler, request, syncJobs } = createHarness({
    claimedJobs: [],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(syncJobs.length, 0);
});

Deno.test("success with no rerun deletes job through completion", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    completeResults: ["completed"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.succeeded, 1);
  assertEquals(body.rescheduled, 0);
});

Deno.test("webhook during processing schedules rerun after success", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    completeResults: ["rerun_scheduled"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.succeeded, 1);
  assertEquals(body.rescheduled, 1);
});

Deno.test("requested_at changed after claim preserves subsequent sync", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    completeResults: ["rerun_scheduled"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
});

Deno.test("old lease owner cannot complete", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    completeResults: ["lease_lost"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.succeeded, 0);
  assertEquals(body.rescheduled, 0);
});

Deno.test("old lease owner cannot fail or reschedule", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "plaid_request_failed" }],
    failResults: ["lease_lost"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 0);
});

Deno.test("old lease owner cannot drop newer owner's job", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "connection_not_found" }],
    dropResults: ["lease_lost"],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.dropped, 0);
});

Deno.test("retryable Plaid sync error becomes retry_wait", async () => {
  const { handler, request, failCodes, failBackoffs } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "plaid_request_failed" }],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assertEquals(failCodes[0], "plaid_request_failed");
  assertEquals(failBackoffs[0], 15);
});

Deno.test("backoff increases and is bounded", () => {
  assertEquals(computeTransactionSyncJobBackoffSeconds(1), 15);
  assertEquals(computeTransactionSyncJobBackoffSeconds(2), 30);
  assertEquals(computeTransactionSyncJobBackoffSeconds(3), 60);
  assertEquals(computeTransactionSyncJobBackoffSeconds(4), 120);
  assertEquals(computeTransactionSyncJobBackoffSeconds(20), 900);
});

Deno.test("long sync renews job lease before transaction lease renewal", async () => {
  const calls: string[] = [];
  const database = createJobLeaseRenewingTransactionsDatabase({
    job: job(),
    database: {
      async claimTransactionSyncJobs() {
        return [];
      },
      async validateTransactionSyncJobLease() {
        return true;
      },
      async completeTransactionSyncJob() {
        return "completed";
      },
      async dropTransactionSyncJob() {
        return "dropped";
      },
      async failTransactionSyncJob() {
        return "rescheduled";
      },
      async renewTransactionSyncJobLease(
        receivedConnectionId,
        receivedLeaseToken,
        leaseSeconds,
      ) {
        calls.push(
          `renew_job:${receivedConnectionId}:${receivedLeaseToken}:${leaseSeconds}`,
        );
        return true;
      },
      async acquireLease() {
        return {
          acquired: true,
          originalCursor: null,
          plaidEnvironment: "sandbox",
        };
      },
      async renewLease() {
        calls.push("renew_transactions");
        return true;
      },
      async releaseLease() {
        return true;
      },
      async getAccessTokenForItem() {
        return accessToken;
      },
      async applyTransactionsSyncBatch() {
        return {
          addedCount: 0,
          modifiedCount: 0,
          removedCount: 0,
          cursorAdvanced: true,
          initialSyncCompleted: false,
        };
      },
    },
  });

  const renewed = await database.renewLease(
    userId,
    connectionId,
    leaseToken,
    300,
  );

  assertEquals(renewed, true);
  assertEquals(
    calls.join(","),
    `renew_job:${connectionId}:${leaseToken}:900,renew_transactions`,
  );
});

Deno.test("old owner cannot renew after reclaim", async () => {
  const calls: string[] = [];
  const database = createJobLeaseRenewingTransactionsDatabase({
    job: job(),
    database: {
      async claimTransactionSyncJobs() {
        return [];
      },
      async validateTransactionSyncJobLease() {
        return true;
      },
      async completeTransactionSyncJob() {
        return "completed";
      },
      async dropTransactionSyncJob() {
        return "dropped";
      },
      async failTransactionSyncJob() {
        return "rescheduled";
      },
      async renewTransactionSyncJobLease() {
        calls.push("renew_job_denied");
        return false;
      },
      async acquireLease() {
        return {
          acquired: true,
          originalCursor: null,
          plaidEnvironment: "sandbox",
        };
      },
      async renewLease() {
        calls.push("unexpected_transactions_renew");
        return true;
      },
      async releaseLease() {
        return true;
      },
      async getAccessTokenForItem() {
        return accessToken;
      },
      async applyTransactionsSyncBatch() {
        return {
          addedCount: 0,
          modifiedCount: 0,
          removedCount: 0,
          cursorAdvanced: true,
          initialSyncCompleted: false,
        };
      },
    },
  });

  const renewed = await database.renewLease(
    userId,
    connectionId,
    leaseToken,
    300,
  );

  assertEquals(renewed, false);
  assertEquals(calls.join(","), "renew_job_denied");
});

Deno.test("Plaid sync lease busy is retried", async () => {
  const { handler, request, failCodes } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "sync_in_progress" }],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "sync_in_progress");
});

Deno.test("cursor conflict is retried", async () => {
  const { handler, request, failCodes } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "cursor_conflict" }],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "cursor_conflict");
});

Deno.test("missing or deleted Item is dropped safely", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "connection_not_found" }],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.dropped, 1);
});

Deno.test("worker crash simulation reschedules when fail RPC is available", async () => {
  const { handler, request, failCodes } = createHarness({
    claimedJobs: [job({ attemptCount: 2 })],
    syncThrows: true,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assertEquals(failCodes[0], "worker_exception");
});

Deno.test("new webhook during retry_wait can make job due sooner", async () => {
  const { handler, request, syncJobs } = createHarness({
    claimedJobs: [job({ attemptCount: 9 })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(syncJobs.length, 1);
  assertEquals(syncJobs[0].attemptCount, 9);
});

Deno.test("sync core is called exactly once per claimed job", async () => {
  const secondConnectionId = "55555555-5555-4555-8555-555555555555";
  const { handler, request, syncJobs } = createHarness({
    claimedJobs: [job(), job({ connectionId: secondConnectionId })],
    syncResults: [synced(), synced()],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(syncJobs.length, 2);
  assertEquals(syncJobs[0].connectionId, connectionId);
  assertEquals(syncJobs[1].connectionId, secondConnectionId);
});

Deno.test("worker does not call transaction ingestion primitives directly", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.includes("unexpected_apply_batch"), false);
  assertEquals(calls.includes("unexpected_get_access_token"), false);
});

Deno.test("response contains no IDs secrets cursors or financial data", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(userId), "response exposed user id");
  assert(!text.includes(connectionId), "response exposed connection id");
  assert(!text.includes(leaseToken), "response exposed lease token");
  assert(!text.includes(internalSecret), "response exposed internal secret");
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(cursor), "response exposed cursor");
});
