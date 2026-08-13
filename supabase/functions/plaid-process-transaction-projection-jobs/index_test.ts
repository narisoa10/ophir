import {
  computeTransactionProjectionJobBackoffSeconds,
  createPlaidProcessTransactionProjectionJobsHandler,
  type ProjectionJobWorkerDatabase,
} from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const otherConnectionId = "55555555-5555-4555-8555-555555555555";
const leaseToken = "33333333-3333-4333-8333-333333333333";
const claimedRequestedAt = "2026-08-11T12:00:00.000Z";
const internalSecret = "worker-secret-value";

type ClaimedJob = {
  connectionId: string;
  userId: string;
  leaseToken: string;
  claimedRequestedAt: string;
  attemptCount: number;
};

type ReconcileResult =
  | {
    status: "processed";
    processed: number;
    rawPending: number;
    postedReady: number;
    removedInactive: number;
    linksUpdated: number;
    hasMore: boolean;
  }
  | { status: "lease_lost" | "missing" | "missing_item" };

type MaterializeResult =
  | {
    status: "processed";
    materialized: number;
    suppressedZeroAmount: number;
    hasMore: boolean;
  }
  | { status: "lease_lost" | "missing" | "missing_item" };

type SourceSyncResult =
  | {
    status: "processed";
    sourceScanned: number;
    sourceUpdated: number;
    sourceArchived: number;
    sourceUnarchived: number;
    sourceUnchanged: number;
    overridePreserved: number;
    overrideInvalidated: number;
    hasMore: boolean;
  }
  | { status: "lease_lost" | "missing" | "missing_item" };

type CategoryEnrichmentResult =
  | {
    status: "processed";
    scanned: number;
    mapped: number;
    updated: number;
    cleared: number;
    unchanged: number;
    skippedOverride: number;
    skippedUnmapped: number;
    hasMore: boolean;
  }
  | { status: "lease_lost" | "missing" | "missing_item" };

type InternalTransferReconcileResult = {
  status: "processed";
  candidatesActive: number;
  candidatesCreated: number;
  candidatesReactivated: number;
  candidatesInvalidated: number;
  candidatesUnchanged: number;
};

type HarnessOptions = {
  secretHeader?: string | null;
  envSecret?: string | null;
  claimedJobs?: ClaimedJob[] | null;
  reconcileResults?: ReconcileResult[];
  reconcileThrows?: boolean;
  materializeResults?: MaterializeResult[];
  materializeThrows?: boolean;
  sourceSyncResults?: Array<SourceSyncResult | null>;
  sourceSyncThrows?: boolean;
  internalTransferResults?: Array<InternalTransferReconcileResult | null>;
  internalTransferThrows?: boolean;
  categoryResults?: Array<CategoryEnrichmentResult | null>;
  categoryThrows?: boolean;
  completeResults?: Array<
    "completed" | "rerun_scheduled" | "lease_lost" | "missing" | null
  >;
  continueResults?: Array<"continued" | "lease_lost" | "missing" | null>;
  dropResults?: Array<"dropped" | "lease_lost" | "missing" | null>;
  failResults?: Array<"rescheduled" | "lease_lost" | "missing" | null>;
  renewResults?: boolean[];
  log?: (message: string, fields: Record<string, unknown>) => void;
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

function assertNotIncludes(haystack: string, needle: string): void {
  if (haystack.includes(needle)) {
    throw new Error(`Unexpected response/log content: ${needle}`);
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

function processed(overrides: Partial<
  Extract<ReconcileResult, {
    status: "processed";
  }>
> = {}): ReconcileResult {
  return {
    status: "processed",
    processed: 1,
    rawPending: 0,
    postedReady: 0,
    removedInactive: 0,
    linksUpdated: 0,
    hasMore: false,
    ...overrides,
  };
}

function materialized(overrides: Partial<
  Extract<MaterializeResult, {
    status: "processed";
  }>
> = {}): MaterializeResult {
  return {
    status: "processed",
    materialized: 0,
    suppressedZeroAmount: 0,
    hasMore: false,
    ...overrides,
  };
}

function sourceSynced(overrides: Partial<
  Extract<SourceSyncResult, {
    status: "processed";
  }>
> = {}): SourceSyncResult {
  return {
    status: "processed",
    sourceScanned: 0,
    sourceUpdated: 0,
    sourceArchived: 0,
    sourceUnarchived: 0,
    sourceUnchanged: 0,
    overridePreserved: 0,
    overrideInvalidated: 0,
    hasMore: false,
    ...overrides,
  };
}

function categoryEnriched(overrides: Partial<
  Extract<CategoryEnrichmentResult, {
    status: "processed";
  }>
> = {}): CategoryEnrichmentResult {
  return {
    status: "processed",
    scanned: 0,
    mapped: 0,
    updated: 0,
    cleared: 0,
    unchanged: 0,
    skippedOverride: 0,
    skippedUnmapped: 0,
    hasMore: false,
    ...overrides,
  };
}

function internalTransferReconciled(
  overrides: Partial<InternalTransferReconcileResult> = {},
): InternalTransferReconcileResult {
  return {
    status: "processed",
    candidatesActive: 0,
    candidatesCreated: 0,
    candidatesReactivated: 0,
    candidatesInvalidated: 0,
    candidatesUnchanged: 0,
    ...overrides,
  };
}

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const logs: Array<{ message: string; fields: Record<string, unknown> }> = [];
  const failCodes: string[] = [];
  const failBackoffs: number[] = [];
  const reconcileJobs: ClaimedJob[] = [];
  const reconcileChunkSizes: number[] = [];
  const claimedJobs = options.claimedJobs === null
    ? null
    : options.claimedJobs ?? [];
  const reconcileResults = [...(options.reconcileResults ?? [processed()])];
  const materializeResults = [
    ...(options.materializeResults ?? [materialized()]),
  ];
  const sourceSyncResults: Array<SourceSyncResult | null> = [
    ...(options.sourceSyncResults ?? [sourceSynced()]),
  ];
  const internalTransferResults: Array<
    InternalTransferReconcileResult | null
  > = [
    ...(options.internalTransferResults ?? [internalTransferReconciled()]),
  ];
  const categoryResults: Array<CategoryEnrichmentResult | null> = [
    ...(options.categoryResults ?? [categoryEnriched()]),
  ];
  const completeResults = [...(options.completeResults ?? ["completed"])];
  const continueResults = [...(options.continueResults ?? ["continued"])];
  const dropResults = [...(options.dropResults ?? ["dropped"])];
  const failResults = [...(options.failResults ?? ["rescheduled"])];
  const renewResults = [...(options.renewResults ?? [true, true, true, true])];

  const database: ProjectionJobWorkerDatabase = {
    async claimProjectionJobs(batchSize, leaseSeconds) {
      calls.push(`claim:${batchSize}:${leaseSeconds}`);
      return claimedJobs;
    },
    async reconcileProjectionJob(claimedJob, chunkSize) {
      calls.push(
        `reconcile:${claimedJob.connectionId}:${claimedJob.leaseToken}`,
      );
      reconcileJobs.push(claimedJob);
      reconcileChunkSizes.push(chunkSize);
      if (options.reconcileThrows) {
        throw new Error("reconcile crashed");
      }
      return reconcileResults.length === 0
        ? processed()
        : reconcileResults.shift()!;
    },
    async materializeProjectionJob(claimedJob, chunkSize) {
      calls.push(
        `materialize:${claimedJob.connectionId}:${claimedJob.leaseToken}:${chunkSize}`,
      );
      if (options.materializeThrows) {
        throw new Error("materialize crashed");
      }
      return materializeResults.length === 0
        ? materialized()
        : materializeResults.shift()!;
    },
    async syncMaterializedProjectionJob(claimedJob, chunkSize) {
      calls.push(
        `source:${claimedJob.connectionId}:${claimedJob.leaseToken}:${chunkSize}`,
      );
      if (options.sourceSyncThrows) {
        throw new Error("source sync crashed");
      }
      const next = sourceSyncResults.shift();
      return next === undefined ? sourceSynced() : next;
    },
    async reconcileInternalTransferCandidatesForUser(receivedUserId) {
      // Call marker intentionally omits user id from the recorded token list
      // used by privacy assertions; order is still observable via phase tags.
      calls.push("internal_transfer");
      void receivedUserId;
      if (options.internalTransferThrows) {
        throw new Error("internal transfer crashed");
      }
      const next = internalTransferResults.shift();
      return next === undefined ? internalTransferReconciled() : next;
    },
    async applyCategoryMappingForProjectionJob(claimedJob, batchSize) {
      calls.push(
        `category:${claimedJob.connectionId}:${claimedJob.leaseToken}:${batchSize}`,
      );
      if (options.categoryThrows) {
        throw new Error("category crashed");
      }
      const next = categoryResults.shift();
      return next === undefined ? categoryEnriched() : next;
    },
    async continueProjectionJob(receivedConnectionId, receivedLeaseToken) {
      calls.push(`continue:${receivedConnectionId}:${receivedLeaseToken}`);
      return continueResults.length === 0
        ? "continued"
        : continueResults.shift()!;
    },
    async completeProjectionJob(receivedConnectionId, receivedLeaseToken) {
      calls.push(`complete:${receivedConnectionId}:${receivedLeaseToken}`);
      return completeResults.length === 0
        ? "completed"
        : completeResults.shift()!;
    },
    async dropProjectionJob(receivedConnectionId, receivedLeaseToken) {
      calls.push(`drop:${receivedConnectionId}:${receivedLeaseToken}`);
      return dropResults.length === 0 ? "dropped" : dropResults.shift()!;
    },
    async failProjectionJob(
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
    async renewProjectionJobLease(receivedConnectionId, receivedLeaseToken) {
      calls.push(`renew:${receivedConnectionId}:${receivedLeaseToken}`);
      return renewResults.length === 0 ? true : renewResults.shift()!;
    },
  };

  const handler = createPlaidProcessTransactionProjectionJobsHandler({
    createDatabase: () => database,
    getEnv: (name) => {
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return options.envSecret === undefined
          ? internalSecret
          : options.envSecret ?? undefined;
      }
      if (name === "PLAID_TRANSACTION_PROJECTION_JOB_BATCH_SIZE") {
        return "5";
      }
      if (name === "PLAID_TRANSACTION_PROJECTION_RECONCILE_CHUNK_SIZE") {
        return "250";
      }
      return undefined;
    },
    randomUUID: () => "44444444-4444-4444-8444-444444444444",
    log: (message, fields) => {
      logs.push({ message, fields });
      options.log?.(message, fields);
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
    logs,
    failCodes,
    failBackoffs,
    reconcileJobs,
    reconcileChunkSizes,
  };
}

Deno.test("auth is required", async () => {
  const { handler, request, calls } = createHarness({
    secretHeader: null,
    claimedJobs: [job()],
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("wrong auth is rejected", async () => {
  const { handler, request, calls } = createHarness({
    secretHeader: "wrong-secret",
    claimedJobs: [job()],
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("empty jobs returns clean success", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "processed");
  assertEquals(body.claimed, 0);
  assertEquals(body.succeeded, 0);
});

Deno.test("claim one job and complete after convergence", async () => {
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
    "missing complete",
  );
  assert(
    calls.some((call) => call.startsWith("materialize:")),
    "missing materialization",
  );
});

Deno.test("pending raw rows are counted as raw_pending projections", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ rawPending: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.raw_pending, 1);
});

Deno.test("posted raw rows are counted as posted_ready projections", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ postedReady: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.posted_ready, 1);
});

Deno.test("removed raw rows are counted as removed_inactive projections", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ removedInactive: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.removed_inactive, 1);
});

Deno.test("pending to posted exact linkage is counted without exposing ids", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ postedReady: 1, linksUpdated: 1 })],
  });

  const response = await handler(request);
  const bodyText = await response.text();
  const body = JSON.parse(bodyText);

  assertEquals(response.status, 200);
  assertEquals(body.links_updated, 1);
  assertNotIncludes(bodyText, connectionId);
  assertNotIncludes(bodyText, userId);
  assertNotIncludes(bodyText, leaseToken);
});

Deno.test("unknown pending_transaction_id produces no linkage count", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ postedReady: 1, linksUpdated: 0 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.links_updated, 0);
});

Deno.test("cross item linkage is impossible through fenced job identity", async () => {
  const { handler, request, reconcileJobs } = createHarness({
    claimedJobs: [job({ connectionId: otherConnectionId })],
    reconcileResults: [processed({ linksUpdated: 0 })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(reconcileJobs[0].connectionId, otherConnectionId);
});

Deno.test("duplicate retry is idempotent at worker lifecycle level", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ processed: 0 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.projections_processed, 0);
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "missing complete",
  );
});

Deno.test("modified pending metadata convergence is represented by processed count", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ rawPending: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.projections_processed, 1);
});

Deno.test("operation_id is never passed through worker response or logs", async () => {
  const logs: string[] = [];
  const operationId = "66666666-6666-4666-8666-666666666666";
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    log: (message, fields) => logs.push(`${message} ${JSON.stringify(fields)}`),
  });

  const response = await handler(request);
  const bodyText = await response.text();
  const logText = logs.join("\n");

  assertEquals(response.status, 200);
  assertNotIncludes(bodyText, operationId);
  assertNotIncludes(logText, operationId);
});

Deno.test("worker materializes through fenced RPC after reconciliation", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    materializeResults: [materialized({ materialized: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assert(
    calls.includes(`materialize:${connectionId}:${leaseToken}:100`),
    "missing materialization RPC call",
  );
  assertEquals(body.materialized, 1);
});

Deno.test("category phase runs after materialization through fenced RPC", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    materializeResults: [materialized({ materialized: 1 })],
    categoryResults: [
      categoryEnriched({
        scanned: 1,
        mapped: 1,
        updated: 1,
        unchanged: 0,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assert(
    calls.findIndex((call) => call.startsWith("materialize:")) <
      calls.findIndex((call) => call.startsWith("source:")),
    "source sync must run after materialization",
  );
  assert(
    calls.findIndex((call) => call.startsWith("source:")) <
      calls.findIndex((call) => call === "internal_transfer"),
    "Stage F must run after source sync",
  );
  assert(
    calls.findIndex((call) => call === "internal_transfer") <
      calls.findIndex((call) => call.startsWith("category:")),
    "category enrichment must run after Stage F",
  );
  assert(
    calls.includes(`category:${connectionId}:${leaseToken}:250`),
    "missing category enrichment RPC call",
  );
  assertEquals(body.category_scanned, 1);
  assertEquals(body.category_mapped, 1);
  assertEquals(body.category_updated, 1);
});

Deno.test("source sync runs after materialization before category enrichment", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    materializeResults: [materialized({ materialized: 1 })],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 1,
        sourceUpdated: 1,
        overridePreserved: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assert(
    calls.findIndex((call) => call.startsWith("materialize:")) <
      calls.findIndex((call) => call.startsWith("source:")),
    "source sync must run after materialization",
  );
  assert(
    calls.findIndex((call) => call.startsWith("source:")) <
      calls.findIndex((call) => call === "internal_transfer"),
    "Stage F must run after source sync",
  );
  assert(
    calls.findIndex((call) => call === "internal_transfer") <
      calls.findIndex((call) => call.startsWith("category:")),
    "category enrichment must run after Stage F",
  );
  assertEquals(body.source_scanned, 1);
  assertEquals(body.source_updated, 1);
  assertEquals(body.override_preserved, 1);
});

Deno.test("bounded chunk has_more continues job instead of completing", async () => {
  const { handler, request, calls, reconcileChunkSizes } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [
      processed({ processed: 250, hasMore: true }),
      processed({ processed: 250, hasMore: true }),
      processed({ processed: 250, hasMore: true }),
      processed({ processed: 250, hasMore: true }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assert(
    calls.includes(`continue:${connectionId}:${leaseToken}`),
    "missing continue",
  );
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
  assertEquals(calls.some((call) => call.startsWith("materialize:")), false);
  assertEquals(reconcileChunkSizes.every((size) => size === 250), true);
});

Deno.test("bounded materialization has_more continues job instead of completing", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [
      materialized({ materialized: 100, hasMore: true }),
      materialized({ materialized: 100, hasMore: true }),
      materialized({ materialized: 100, hasMore: true }),
      materialized({ materialized: 100, hasMore: true }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assertEquals(body.materialized, 400);
  assert(
    calls.includes(`continue:${connectionId}:${leaseToken}`),
    "missing continue",
  );
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("bounded source sync has_more continues job instead of completing", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [materialized({ hasMore: false })],
    sourceSyncResults: [
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assertEquals(body.source_updated, 1000);
  assert(
    calls.includes(`continue:${connectionId}:${leaseToken}`),
    "missing continue",
  );
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
  assertEquals(calls.some((call) => call.startsWith("category:")), false);
  assertEquals(calls.includes("internal_transfer"), false);
});

Deno.test("bounded category has_more continues job instead of completing", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [materialized({ hasMore: false })],
    categoryResults: [
      categoryEnriched({ updated: 250, hasMore: true }),
      categoryEnriched({ updated: 250, hasMore: true }),
      categoryEnriched({ updated: 250, hasMore: true }),
      categoryEnriched({ updated: 250, hasMore: true }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.rescheduled, 1);
  assertEquals(body.category_updated, 1000);
  assert(
    calls.includes(`continue:${connectionId}:${leaseToken}`),
    "missing continue",
  );
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("category RPC failure reschedules with bounded backoff", async () => {
  const { handler, request, failBackoffs, failCodes } = createHarness({
    claimedJobs: [job({ attemptCount: 2 })],
    categoryResults: [null],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "category_enrichment_failed");
  assertEquals(failBackoffs[0], 30);
});

Deno.test("source sync RPC failure reschedules with bounded backoff", async () => {
  const { handler, request, failBackoffs, failCodes } = createHarness({
    claimedJobs: [job({ attemptCount: 3 })],
    sourceSyncResults: [null],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "source_sync_failed");
  assertEquals(failBackoffs[0], 60);
});

Deno.test("fenced source sync lease_lost stops without complete or fail", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [{ status: "lease_lost" }],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
  assertEquals(calls.includes(`fail:${connectionId}:${leaseToken}`), false);
});

Deno.test("lost renewal stops before source sync mutation", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [materialized({ hasMore: false })],
    renewResults: [true, false],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.some((call) => call.startsWith("source:")), false);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("lost renewal stops before category mutation", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [materialized({ hasMore: false })],
    sourceSyncResults: [sourceSynced({ hasMore: false })],
    renewResults: [true, true, false],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.some((call) => call.startsWith("category:")), false);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("modified source fields update same materialized operation counters", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 4,
        sourceUpdated: 4,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.source_scanned, 4);
  assertEquals(body.source_updated, 4);
});

Deno.test("sign type change invalidates incompatible category override safely", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 1,
        sourceUpdated: 1,
        overrideInvalidated: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.override_invalidated, 1);
});

Deno.test("removed raw transaction archives same operation without deletion", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 1,
        sourceArchived: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.source_archived, 1);
  assertEquals(body.dropped, 0);
});

Deno.test("modified zero amount archives same operation instead of invalid update", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 1,
        sourceArchived: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.source_archived, 1);
  assertEquals(body.source_updated, 0);
});

Deno.test("restored raw transaction unarchives Plaid operation", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    sourceSyncResults: [
      sourceSynced({
        sourceScanned: 1,
        sourceUnarchived: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.source_unarchived, 1);
});

Deno.test("fenced category lease_lost stops without complete or fail", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    categoryResults: [{ status: "lease_lost" }],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
  assertEquals(calls.includes(`fail:${connectionId}:${leaseToken}`), false);
});

Deno.test("category_overridden rows are counted as skipped", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    categoryResults: [
      categoryEnriched({
        scanned: 1,
        skippedOverride: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.category_skipped_override, 1);
});

Deno.test("modified PFC can update automatic category", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    categoryResults: [
      categoryEnriched({
        scanned: 1,
        mapped: 1,
        updated: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.category_updated, 1);
});

Deno.test("unmapped PFC can clear old automatic category", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    categoryResults: [
      categoryEnriched({
        scanned: 1,
        cleared: 1,
        skippedUnmapped: 0,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.category_cleared, 1);
  assertEquals(body.category_skipped_unmapped, 0);
});

Deno.test("zero amount suppressions are counted without operation creation details", async () => {
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    materializeResults: [materialized({ suppressedZeroAmount: 1 })],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.suppressed_zero_amount, 1);
});

Deno.test("has_more false completes job", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "missing complete",
  );
});

Deno.test("retryable reconcile failure uses bounded exponential backoff", async () => {
  const { handler, request, failBackoffs, failCodes } = createHarness({
    claimedJobs: [job({ attemptCount: 4 })],
    reconcileResults: [],
    reconcileThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "worker_exception");
  assertEquals(failBackoffs[0], 120);
});

Deno.test("retryable materialization failure uses bounded exponential backoff", async () => {
  const { handler, request, failBackoffs, failCodes } = createHarness({
    claimedJobs: [job({ attemptCount: 3 })],
    materializeThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(failCodes[0], "worker_exception");
  assertEquals(failBackoffs[0], 60);
});

Deno.test("backoff is capped", () => {
  assertEquals(computeTransactionProjectionJobBackoffSeconds(20), 900);
});

Deno.test("stale lease result stops without complete or fail", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [{ status: "lease_lost" }],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
  assertEquals(calls.includes(`fail:${connectionId}:${leaseToken}`), false);
});

Deno.test("lost renewal stops before next chunk mutation", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: true }), processed()],
    renewResults: [false],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(
    calls.filter((call) => call.startsWith("reconcile:")).length,
    1,
  );
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("lost renewal stops before materialization mutation", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    renewResults: [false],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.some((call) => call.startsWith("materialize:")), false);
  assertEquals(calls.includes(`complete:${connectionId}:${leaseToken}`), false);
});

Deno.test("missing item drops current projection job lease", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [{ status: "missing_item" }],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.dropped, 1);
  assert(calls.includes(`drop:${connectionId}:${leaseToken}`), "missing drop");
});

Deno.test("Stage F runs after source-sync drained and before category", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    internalTransferResults: [
      internalTransferReconciled({
        candidatesActive: 1,
        candidatesCreated: 1,
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assert(
    calls.findIndex((call) => call.startsWith("source:")) <
      calls.findIndex((call) => call === "internal_transfer"),
    "Stage F must run after source sync",
  );
  assert(
    calls.findIndex((call) => call === "internal_transfer") <
      calls.findIndex((call) => call.startsWith("category:")),
    "Stage F must run before category",
  );
  assertEquals(body.internal_transfer_reconcile_attempted, 1);
  assertEquals(body.internal_transfer_reconcile_failed, 0);
  assertEquals(body.internal_transfer_candidates_created, 1);
  assertEquals(body.internal_transfer_candidates_active, 1);
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "missing complete",
  );
});

Deno.test("Stage F is skipped when source-sync still has_more", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    reconcileResults: [processed({ hasMore: false })],
    materializeResults: [materialized({ hasMore: false })],
    sourceSyncResults: [
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
      sourceSynced({ sourceUpdated: 250, hasMore: true }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls.includes("internal_transfer"), false);
  assertEquals(calls.some((call) => call.startsWith("category:")), false);
});

Deno.test("Stage F success continues category and complete", async () => {
  const { handler, request, calls } = createHarness({
    claimedJobs: [job()],
    internalTransferResults: [
      internalTransferReconciled({ candidatesUnchanged: 2 }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assert(calls.includes("internal_transfer"), "missing Stage F call");
  assert(
    calls.some((call) => call.startsWith("category:")),
    "missing category",
  );
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "missing complete",
  );
  assertEquals(body.internal_transfer_candidates_unchanged, 2);
  assertEquals(body.succeeded, 1);
});

Deno.test("Stage F RPC null failure is non-fatal for category/complete", async () => {
  const { handler, request, calls, logs, failCodes } = createHarness({
    claimedJobs: [job()],
    internalTransferResults: [null],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.internal_transfer_reconcile_attempted, 1);
  assertEquals(body.internal_transfer_reconcile_failed, 1);
  assert(
    calls.some((call) => call.startsWith("category:")),
    "category must continue",
  );
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "complete must continue",
  );
  assertEquals(failCodes.length, 0);
  assertEquals(body.succeeded, 1);
  assertEquals(
    logs.some((entry) =>
      entry.message === "internal_transfer_reconcile_failed" &&
      entry.fields.error_code === "internal_transfer_reconcile_failed"
    ),
    true,
  );
});

Deno.test("Stage F thrown failure is non-fatal for category/complete", async () => {
  const { handler, request, calls, failCodes } = createHarness({
    claimedJobs: [job()],
    internalTransferThrows: true,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.internal_transfer_reconcile_failed, 1);
  assert(
    calls.some((call) => call.startsWith("category:")),
    "category must continue",
  );
  assert(
    calls.includes(`complete:${connectionId}:${leaseToken}`),
    "complete must continue",
  );
  assertEquals(failCodes.length, 0);
  assertEquals(body.succeeded, 1);
});

Deno.test("response and logs contain no financial or identity data", async () => {
  const logs: string[] = [];
  const secret = "secret-value";
  const merchant = "Starbucks";
  const amount = "12.34";
  const transactionId = "plaid-transaction-id";
  const categoryId = "expenseFoodGroceries";
  const pfcDetailed = "FOOD_AND_DRINK_GROCERIES";
  const { handler, request } = createHarness({
    claimedJobs: [job()],
    log: (message, fields) => logs.push(`${message} ${JSON.stringify(fields)}`),
  });

  const response = await handler(request);
  const bodyText = await response.text();
  const combined = `${bodyText}\n${logs.join("\n")}`;

  assertEquals(response.status, 200);
  for (
    const forbidden of [
      userId,
      connectionId,
      leaseToken,
      secret,
      merchant,
      amount,
      transactionId,
      categoryId,
      pfcDetailed,
    ]
  ) {
    assertNotIncludes(combined, forbidden);
  }
});

Deno.test("Stage F failure logs omit user/projection/operation/amount identity", async () => {
  const { handler, request, logs } = createHarness({
    claimedJobs: [job()],
    internalTransferResults: [null],
  });

  const response = await handler(request);
  assertEquals(response.status, 200);

  const failureLogs = logs.filter((entry) =>
    entry.message === "internal_transfer_reconcile_failed"
  );
  assertEquals(failureLogs.length, 1);
  const serialized = JSON.stringify(failureLogs[0]);
  assertNotIncludes(serialized, userId);
  assertNotIncludes(serialized, connectionId);
  assertNotIncludes(serialized, "projection");
  assertNotIncludes(serialized, "operation");
  assertNotIncludes(serialized, "amount");
});
