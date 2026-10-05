import {
  computeTransactionSyncJobBackoffSeconds,
  createJobLeaseRenewingTransactionsDatabase,
  createPlaidProcessTransactionSyncJobsHandler,
  type TransactionSyncJobWorkerDatabase,
} from "./handler.ts";
import type { PlaidTransactionsSyncCoreResult } from "../plaid-sync-transactions/handler.ts";
import type { AccountsRefreshDatabase } from "../_shared/plaid_accounts_refresh.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const leaseToken = "33333333-3333-4333-8333-333333333333";
const claimedRequestedAt = "2026-08-11T12:00:00.000Z";
const internalSecret = "worker-secret-value";
const accessToken = "access-token-secret-value";
const cursor = "cursor-secret-value";
const plaidClientId = "plaid-client-id-value";
const plaidSecret = "plaid-sandbox-secret-value";

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
  plaidCredentials?: boolean;
  accountsDatabase?: (calls: string[]) => AccountsRefreshDatabase | null;
  fetch?: (calls: string[]) => typeof fetch;
};

type LoggedEntry = { message: string; fields: Record<string, unknown> };

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
    async getItemHealthStatus() {
      calls.push("unexpected_get_item_status");
      return null;
    },
    async recordItemHealthObservation() {
      calls.push("unexpected_record_observation");
      return null;
    },
  };

  const logs: LoggedEntry[] = [];

  const handler = createPlaidProcessTransactionSyncJobsHandler({
    createDatabase: () => database,
    createAccountsRefreshDatabase: () => {
      if (options.accountsDatabase === undefined) {
        calls.push("unexpected_accounts_database");
        return null;
      }
      return options.accountsDatabase(calls);
    },
    fetch: options.fetch === undefined
      ? (() => {
        calls.push("unexpected_fetch");
        return Promise.reject(new Error("unexpected fetch"));
      }) as typeof fetch
      : options.fetch(calls),
    now: () => new Date("2026-10-03T12:00:00.000Z"),
    getEnv: (name) => {
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return options.envSecret === undefined
          ? internalSecret
          : options.envSecret ?? undefined;
      }
      if (name === "PLAID_TRANSACTION_SYNC_JOB_BATCH_SIZE") {
        return "5";
      }
      if (options.plaidCredentials && name === "PLAID_CLIENT_ID") {
        return plaidClientId;
      }
      if (options.plaidCredentials && name === "PLAID_SANDBOX_SECRET") {
        return plaidSecret;
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
    log: (message, fields) => {
      logs.push({ message, fields });
    },
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
    logs,
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
      async getItemHealthStatus() {
        return "active";
      },
      async recordItemHealthObservation() {
        return null;
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
      async getItemHealthStatus() {
        return "active";
      },
      async recordItemHealthObservation() {
        return null;
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

Deno.test("Item requiring login is dropped, not retried", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    syncResults: [{ kind: "item_login_required" }],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.dropped, 1);
  assertEquals(body.rescheduled, 0);
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

type PersistedAccountsCall = {
  plaidInstitutionId: string | null;
  institutionName: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  institutionUrl: string | null;
  accounts: Array<Record<string, unknown>>;
};

type AccountsRefreshFake = {
  persisted: PersistedAccountsCall[];
  observations: Array<Record<string, unknown>>;
  factory: (calls: string[]) => AccountsRefreshDatabase;
};

function accountsRefreshFake(options: {
  tokenAvailable?: boolean;
  persistSucceeds?: boolean;
  persistDisconnected?: boolean;
  persistSuperseded?: boolean;
  storedInstitution?: "row" | "failed";
  throwsOnToken?: boolean;
} = {}): AccountsRefreshFake {
  const persisted: PersistedAccountsCall[] = [];
  const observations: Array<Record<string, unknown>> = [];

  return {
    persisted,
    observations,
    factory: (calls) => ({
      getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        calls.push("accounts_get_access_token");
        if (options.throwsOnToken) {
          return Promise.reject(new Error("token rpc crashed"));
        }
        const available = (options.tokenAvailable ?? true) &&
          receivedUserId === userId && receivedConnectionId === connectionId;
        return Promise.resolve(available ? accessToken : null);
      },
      persistAccountsSync(args) {
        calls.push("persist_accounts");
        persisted.push({
          plaidInstitutionId: args.plaidInstitutionId,
          institutionName: args.institutionName,
          logoBase64: args.logoBase64,
          primaryColor: args.primaryColor,
          institutionUrl: args.institutionUrl,
          accounts: args.accounts as unknown as Array<Record<string, unknown>>,
        });
        if (options.persistDisconnected) {
          return Promise.resolve("disconnected");
        }
        if (options.persistSuperseded) {
          return Promise.resolve("superseded");
        }
        return Promise.resolve(
          (options.persistSucceeds ?? true) ? args.accounts.length : null,
        );
      },
      recordItemHealthObservation(observation) {
        calls.push("accounts_record_observation");
        observations.push({ ...observation });
        return Promise.resolve({
          applied: true,
          previousStatus: "active",
          status: observation.status,
          plaidItemId: "external-item-id",
        });
      },
      getStoredInstitution() {
        calls.push("stored_institution");
        if (options.storedInstitution === "failed") {
          return Promise.resolve("failed");
        }
        return Promise.resolve({
          plaidInstitutionId: "ins_stored",
          name: "Stored Bank",
          logoBase64: "stored-logo",
          primaryColor: "#abcdef",
          url: "https://stored-bank.example",
        });
      },
    }),
  };
}

const quietAccountBalance = 7654.32;

function plaidAccountsFetch(
  response: "ok" | { errorCode: string },
): (calls: string[]) => typeof fetch {
  return (calls) =>
    ((input: RequestInfo | URL) => {
      const url = input.toString();
      if (url.includes("/accounts/get")) {
        calls.push("plaid_accounts_get");
      } else if (url.includes("/institutions/get_by_id")) {
        calls.push("plaid_institutions_get_by_id");
      } else {
        calls.push(`plaid_other:${url}`);
      }

      if (response !== "ok") {
        return Promise.resolve(
          new Response(
            JSON.stringify({
              error_type: "ITEM_ERROR",
              error_code: response.errorCode,
            }),
            { status: 400 },
          ),
        );
      }

      return Promise.resolve(
        new Response(
          JSON.stringify({
            item: { institution_id: "ins_item", institution_name: "Item Bank" },
            accounts: [
              {
                account_id: "plaid-account-active",
                name: "Active Checking",
                mask: "1111",
                type: "depository",
                subtype: "checking",
                balances: {
                  current: 100,
                  available: 90,
                  iso_currency_code: "CAD",
                },
              },
              {
                account_id: "plaid-account-quiet",
                name: "Quiet Savings",
                mask: "2222",
                type: "depository",
                subtype: "savings",
                balances: {
                  current: quietAccountBalance,
                  available: null,
                  iso_currency_code: "CAD",
                },
              },
            ],
          }),
          { status: 200 },
        ),
      );
    }) as typeof fetch;
}

function refreshOutcomes(logs: LoggedEntry[]): unknown[] {
  return logs
    .filter((entry) =>
      entry.message === "plaid_transaction_sync_job_accounts_refresh"
    )
    .map((entry) => entry.fields.outcome);
}

function assertPrimaryJobSucceeded(
  body: Record<string, unknown>,
  calls: string[],
  syncJobs: ClaimedJob[],
): void {
  assertEquals(body.succeeded, 1);
  assertEquals(body.rescheduled, 0);
  assertEquals(body.dropped, 0);
  assertEquals(syncJobs.length, 1, "transaction sync must run exactly once");
  assertEquals(calls.some((call) => call.startsWith("fail:")), false);
  assertEquals(calls.some((call) => call.startsWith("drop:")), false);
  assertEquals(
    calls.filter((call) => call.startsWith("complete:")).length,
    1,
  );
}

Deno.test("A successful sync refreshes the full accounts snapshot with stored institution metadata", async () => {
  const fake = accountsRefreshFake();
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(calls.filter((call) => call === "plaid_accounts_get").length, 1);
  assertEquals(calls.includes("plaid_institutions_get_by_id"), false);
  assertEquals(fake.persisted.length, 1);
  const persisted = fake.persisted[0];
  assertEquals(
    persisted.accounts.map((account) => account.plaid_account_id).join(","),
    "plaid-account-active,plaid-account-quiet",
  );
  const quiet = persisted.accounts.find((account) =>
    account.plaid_account_id === "plaid-account-quiet"
  )!;
  assertEquals(quiet.current_balance, quietAccountBalance);
  assertEquals(persisted.plaidInstitutionId, "ins_stored");
  assertEquals(persisted.institutionName, "Stored Bank");
  assertEquals(persisted.logoBase64, "stored-logo");
  assertEquals(persisted.primaryColor, "#abcdef");
  assertEquals(persisted.institutionUrl, "https://stored-bank.example");
  assertEquals(refreshOutcomes(logs).join(","), "refreshed");
});

Deno.test("B accounts refresh starts only after the sync job is finalized", async () => {
  const fake = accountsRefreshFake();
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  await handler(request);

  const syncIndex = calls.indexOf(`sync:${connectionId}:${leaseToken}`);
  const completeIndex = calls.indexOf(`complete:${connectionId}:${leaseToken}`);
  const tokenIndex = calls.indexOf("accounts_get_access_token");
  const accountsIndex = calls.indexOf("plaid_accounts_get");
  const persistIndex = calls.indexOf("persist_accounts");
  assert(syncIndex >= 0 && syncIndex < completeIndex, "sync before complete");
  assert(completeIndex < tokenIndex, "refresh must start after completion");
  assert(tokenIndex < accountsIndex, "token before /accounts/get");
  assert(accountsIndex < persistIndex, "/accounts/get before persist");
});

Deno.test("B no accounts refresh for failed, retried, dropped or unconfirmed sync jobs", async () => {
  const scenarios: HarnessOptions[] = [
    { syncResults: [{ kind: "plaid_request_failed" }] },
    { syncResults: [{ kind: "persist_failed" }] },
    { syncResults: [{ kind: "cursor_conflict" }] },
    { syncResults: [{ kind: "item_login_required" }] },
    { syncResults: [{ kind: "connection_not_found" }] },
    { syncThrows: true },
    { completeResults: ["lease_lost"] },
    { completeResults: ["missing"] },
    { completeResults: [null] },
  ];

  for (const scenario of scenarios) {
    const fake = accountsRefreshFake();
    const { handler, request, calls, logs } = createHarness({
      claimedJobs: [job()],
      plaidCredentials: true,
      accountsDatabase: fake.factory,
      fetch: plaidAccountsFetch("ok"),
      ...scenario,
    });

    const response = await handler(request);

    assertEquals(response.status, 200);
    assertEquals(calls.includes("accounts_get_access_token"), false);
    assertEquals(calls.includes("plaid_accounts_get"), false);
    assertEquals(fake.persisted.length, 0);
    assertEquals(refreshOutcomes(logs).length, 0);
  }
});

Deno.test("B rerun-scheduled completion still refreshes accounts once", async () => {
  const fake = accountsRefreshFake();
  const { handler, request, calls, logs } = createHarness({
    claimedJobs: [job()],
    completeResults: ["rerun_scheduled"],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(body.succeeded, 1);
  assertEquals(body.rescheduled, 1);
  assertEquals(calls.filter((call) => call === "plaid_accounts_get").length, 1);
  assertEquals(refreshOutcomes(logs).join(","), "refreshed");
});

Deno.test("C ordinary /accounts/get failure keeps the transaction job succeeded", async () => {
  const fake = accountsRefreshFake();
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch({ errorCode: "INSTITUTION_DOWN" }),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 0);
  assertEquals(fake.observations.length, 0);
  assertEquals(refreshOutcomes(logs).join(","), "plaid_request_failed");
});

Deno.test("C snapshot refused after a concurrent Disconnect keeps the job succeeded without retry", async () => {
  const fake = accountsRefreshFake({ persistDisconnected: true });
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 1);
  assertEquals(fake.observations.length, 0);
  assertEquals(calls.filter((call) => call === "plaid_accounts_get").length, 1);
  assertEquals(refreshOutcomes(logs).join(","), "connection_disconnected");
});

Deno.test("C superseded accounts snapshot is benign: job succeeded, no retry, structured event", async () => {
  const fake = accountsRefreshFake({ persistSuperseded: true });
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 1);
  assertEquals(fake.observations.length, 0);
  assertEquals(calls.filter((call) => call === "plaid_accounts_get").length, 1);
  assertEquals(refreshOutcomes(logs).join(","), "snapshot_superseded");
  const events = logs.filter((entry) => entry.message === "accounts_snapshot_superseded");
  assertEquals(events.length, 1);
  assertEquals(Object.keys(events[0].fields).sort().join(","), "run_id,source");
  assertEquals(events[0].fields.source, "transaction_sync_job");
  assert(!JSON.stringify(logs).includes(accessToken), "log exposed access token");
  assert(!JSON.stringify(events).includes(connectionId), "event exposed connection id");
});

Deno.test("C only a superseded snapshot emits accounts_snapshot_superseded", async () => {
  for (const options of [{}, { persistDisconnected: true }, { persistSucceeds: false }]) {
    const fake = accountsRefreshFake(options);
    const { handler, request, logs } = createHarness({
      claimedJobs: [job()],
      plaidCredentials: true,
      accountsDatabase: fake.factory,
      fetch: plaidAccountsFetch("ok"),
    });

    await handler(request);

    assertEquals(
      logs.filter((entry) => entry.message === "accounts_snapshot_superseded").length,
      0,
    );
  }
});

Deno.test("D ITEM_LOGIN_REQUIRED records health without persist or job retry", async () => {
  const fake = accountsRefreshFake();
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch({ errorCode: "ITEM_LOGIN_REQUIRED" }),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 0);
  assertEquals(fake.observations.length, 1);
  assertEquals(fake.observations[0].connectionId, connectionId);
  assertEquals(fake.observations[0].status, "login_required");
  assertEquals(fake.observations[0].statusReason, "login_required");
  assertEquals(fake.observations[0].fromItemGet, false);
  assertEquals(fake.observations[0].clearPendingDisconnect, false);
  assertEquals(calls.filter((call) => call === "plaid_accounts_get").length, 1);
  assertEquals(refreshOutcomes(logs).join(","), "item_login_required");
});

Deno.test("E unavailable Item stays a safe best-effort outcome", async () => {
  for (const errorCode of ["ITEM_NOT_FOUND", "INVALID_ACCESS_TOKEN"]) {
    const fake = accountsRefreshFake();
    const { handler, request, calls, syncJobs, logs } = createHarness({
      claimedJobs: [job()],
      plaidCredentials: true,
      accountsDatabase: fake.factory,
      fetch: plaidAccountsFetch({ errorCode }),
    });

    const response = await handler(request);
    const body = await response.json();

    assertEquals(response.status, 200);
    assertPrimaryJobSucceeded(body, calls, syncJobs);
    assertEquals(fake.persisted.length, 0);
    assertEquals(fake.observations.length, 0);
    assertEquals(
      calls.filter((call) => call.startsWith("plaid_")).join(","),
      "plaid_accounts_get",
      "only /accounts/get may be called: no link token or token exchange",
    );
    assertEquals(refreshOutcomes(logs).join(","), "item_unavailable");
  }
});

Deno.test("F accounts persist failure keeps the transaction job succeeded", async () => {
  const fake = accountsRefreshFake({ persistSucceeds: false });
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 1);
  assertEquals(refreshOutcomes(logs).join(","), "persist_failed");
});

Deno.test("G stored institution failure does not persist and keeps the job succeeded", async () => {
  const fake = accountsRefreshFake({ storedInstitution: "failed" });
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(fake.persisted.length, 0);
  assertEquals(calls.includes("plaid_institutions_get_by_id"), false);
  assertEquals(refreshOutcomes(logs).join(","), "institution_lookup_failed");
});

Deno.test("H disconnected Item without a token fails closed before Plaid", async () => {
  const fake = accountsRefreshFake({ tokenAvailable: false });
  const { handler, request, calls, syncJobs, logs } = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertPrimaryJobSucceeded(body, calls, syncJobs);
  assertEquals(calls.some((call) => call.startsWith("plaid_")), false);
  assertEquals(fake.persisted.length, 0);
  assertEquals(fake.observations.length, 0);
  assertEquals(refreshOutcomes(logs).join(","), "connection_not_found");
});

Deno.test("refresh exceptions and missing config never change the primary job", async () => {
  const crashing = accountsRefreshFake({ throwsOnToken: true });
  const crashed = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: crashing.factory,
    fetch: plaidAccountsFetch("ok"),
  });
  const crashedBody = await (await crashed.handler(crashed.request)).json();
  assertPrimaryJobSucceeded(crashedBody, crashed.calls, crashed.syncJobs);
  assertEquals(refreshOutcomes(crashed.logs).join(","), "refresh_exception");

  const noSupabase = createHarness({
    claimedJobs: [job()],
    plaidCredentials: true,
    accountsDatabase: () => null,
    fetch: plaidAccountsFetch("ok"),
  });
  const noSupabaseBody = await (await noSupabase.handler(noSupabase.request))
    .json();
  assertPrimaryJobSucceeded(noSupabaseBody, noSupabase.calls, noSupabase.syncJobs);
  assertEquals(noSupabase.calls.includes("plaid_accounts_get"), false);
  assertEquals(
    refreshOutcomes(noSupabase.logs).join(","),
    "supabase_config_missing",
  );

  const noPlaid = createHarness({ claimedJobs: [job()] });
  const noPlaidBody = await (await noPlaid.handler(noPlaid.request)).json();
  assertPrimaryJobSucceeded(noPlaidBody, noPlaid.calls, noPlaid.syncJobs);
  assertEquals(noPlaid.calls.includes("unexpected_accounts_database"), false);
  assertEquals(noPlaid.calls.includes("unexpected_fetch"), false);
  assertEquals(refreshOutcomes(noPlaid.logs).join(","), "plaid_config_missing");
});

Deno.test("repeated successful jobs reuse the same idempotent persist path", async () => {
  const fake = accountsRefreshFake();
  const secondLease = "66666666-6666-4666-8666-666666666666";
  const { handler, request, calls } = createHarness({
    claimedJobs: [job(), job({ leaseToken: secondLease })],
    syncResults: [synced(), synced()],
    plaidCredentials: true,
    accountsDatabase: fake.factory,
    fetch: plaidAccountsFetch("ok"),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(body.succeeded, 2);
  assertEquals(fake.persisted.length, 2);
  assertEquals(
    JSON.stringify(fake.persisted[0].accounts),
    JSON.stringify(fake.persisted[1].accounts),
  );
  assertEquals(
    calls.filter((call) => call.startsWith("plaid_other")).length,
    0,
  );
  assertEquals(calls.includes("unexpected_apply_batch"), false);
});

Deno.test("I no token, secret or raw Plaid account data in response, logs or console", async () => {
  const written: string[] = [];
  const original = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    error: console.error,
    debug: console.debug,
  };
  const capture = (...args: unknown[]) => {
    written.push(args.map((arg) => String(arg)).join(" "));
  };
  console.log = capture;
  console.info = capture;
  console.warn = capture;
  console.error = capture;
  console.debug = capture;

  const responses: string[] = [];
  const loggedEntries: LoggedEntry[] = [];
  try {
    const scenarios: Array<{
      fetchResponse: "ok" | { errorCode: string };
      fake: AccountsRefreshFake;
    }> = [
      { fetchResponse: "ok", fake: accountsRefreshFake() },
      {
        fetchResponse: { errorCode: "ITEM_LOGIN_REQUIRED" },
        fake: accountsRefreshFake(),
      },
      {
        fetchResponse: { errorCode: "ITEM_NOT_FOUND" },
        fake: accountsRefreshFake(),
      },
      {
        fetchResponse: { errorCode: "INSTITUTION_DOWN" },
        fake: accountsRefreshFake(),
      },
      {
        fetchResponse: "ok",
        fake: accountsRefreshFake({ persistSucceeds: false }),
      },
      {
        fetchResponse: "ok",
        fake: accountsRefreshFake({ storedInstitution: "failed" }),
      },
      {
        fetchResponse: "ok",
        fake: accountsRefreshFake({ tokenAvailable: false }),
      },
    ];

    for (const scenario of scenarios) {
      const { handler, request, logs } = createHarness({
        claimedJobs: [job()],
        plaidCredentials: true,
        accountsDatabase: scenario.fake.factory,
        fetch: plaidAccountsFetch(scenario.fetchResponse),
      });
      responses.push(await (await handler(request)).text());
      loggedEntries.push(...logs);
    }
  } finally {
    Object.assign(console, original);
  }

  const haystack = [
    ...responses,
    JSON.stringify(loggedEntries),
    ...written,
  ].join("\n");
  for (
    const sensitive of [
      accessToken,
      plaidSecret,
      plaidClientId,
      internalSecret,
      userId,
      connectionId,
      "Quiet Savings",
      "Active Checking",
      "1111",
      "2222",
      String(quietAccountBalance),
      "plaid-account-quiet",
      "stored-logo",
    ]
  ) {
    assert(!haystack.includes(sensitive), `leaked sensitive value ${sensitive}`);
  }
});
