import { createClient } from "npm:@supabase/supabase-js@2";
import {
  createPlaidTransactionsSyncDatabase,
  type PlaidTransactionsSyncCoreResult,
  syncPlaidTransactionsForConnection,
  type TransactionsSyncDatabase,
} from "../plaid-sync-transactions/handler.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";

const internalSecretHeader = "x-ophir-internal-secret";
const internalSecretEnvName = "OPHIR_INTERNAL_WORKER_SECRET";
const defaultBatchSize = 5;
const maxBatchSize = 5;
const defaultJobLeaseSeconds = 900;
const maxBackoffSeconds = 15 * 60;

type ClaimedTransactionSyncJob = {
  connectionId: string;
  userId: string;
  leaseToken: string;
  claimedRequestedAt: string;
  attemptCount: number;
};

type CompletionStatus = "completed" | "rerun_scheduled" | "missing";
type DropStatus = "dropped" | "missing";

export type TransactionSyncJobWorkerDatabase = TransactionsSyncDatabase & {
  claimTransactionSyncJobs(
    batchSize: number,
    leaseSeconds: number,
  ): Promise<ClaimedTransactionSyncJob[] | null>;
  validateTransactionSyncJobLease(
    connectionId: string,
    leaseToken: string,
  ): Promise<boolean>;
  completeTransactionSyncJob(
    connectionId: string,
    leaseToken: string,
    claimedRequestedAt: string,
  ): Promise<CompletionStatus | "lease_lost" | null>;
  dropTransactionSyncJob(
    connectionId: string,
    leaseToken: string,
  ): Promise<DropStatus | "lease_lost" | null>;
  failTransactionSyncJob(
    connectionId: string,
    leaseToken: string,
    errorCode: string,
    backoffSeconds: number,
  ): Promise<"rescheduled" | "lease_lost" | "missing" | null>;
  renewTransactionSyncJobLease(
    connectionId: string,
    leaseToken: string,
    leaseSeconds: number,
  ): Promise<boolean>;
};

type WorkerSyncResult = PlaidTransactionsSyncCoreResult;

type HandlerDependencies = {
  createDatabase: () => TransactionSyncJobWorkerDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  randomUUID: () => string;
  syncTransactions: (params: {
    job: ClaimedTransactionSyncJob;
    database: TransactionSyncJobWorkerDatabase;
    fetchImpl: typeof fetch;
    getEnv: (name: string) => string | undefined;
  }) => Promise<WorkerSyncResult>;
  log: (message: string, fields: Record<string, unknown>) => void;
};

function readPositiveInteger(value: string | undefined): number | null {
  if (value === undefined || value.trim().length === 0) {
    return null;
  }

  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function boundedBatchSize(
  getEnv: (name: string) => string | undefined,
): number {
  const configured = readPositiveInteger(
    getEnv("PLAID_TRANSACTION_SYNC_JOB_BATCH_SIZE"),
  );
  if (configured === null) {
    return defaultBatchSize;
  }

  return Math.min(configured, maxBatchSize);
}

function parseRpcStatus(value: unknown): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const status = (value as Record<string, unknown>).status;
  return typeof status === "string" ? status : null;
}

function normalizeClaimedJob(value: unknown): ClaimedTransactionSyncJob | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  if (
    typeof row.connection_id !== "string" ||
    typeof row.user_id !== "string" ||
    typeof row.lease_token !== "string" ||
    typeof row.claimed_requested_at !== "string" ||
    typeof row.attempt_count !== "number" ||
    !Number.isInteger(row.attempt_count)
  ) {
    return null;
  }

  return {
    connectionId: row.connection_id,
    userId: row.user_id,
    leaseToken: row.lease_token,
    claimedRequestedAt: row.claimed_requested_at,
    attemptCount: row.attempt_count,
  };
}

function constantTimeEquals(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const maxLength = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < maxLength; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return difference === 0;
}

function authorizeInternalRequest(
  request: Request,
  getEnv: (name: string) => string | undefined,
): "authorized" | "unauthorized" | "config_missing" {
  const expectedSecret = getEnv(internalSecretEnvName);
  if (typeof expectedSecret !== "string" || expectedSecret.length === 0) {
    return "config_missing";
  }

  const receivedSecret = request.headers.get(internalSecretHeader);
  if (
    receivedSecret === null ||
    !constantTimeEquals(receivedSecret, expectedSecret)
  ) {
    return "unauthorized";
  }

  return "authorized";
}

export function computeTransactionSyncJobBackoffSeconds(
  attemptCount: number,
): number {
  const normalizedAttempt = Number.isInteger(attemptCount) && attemptCount > 0
    ? attemptCount
    : 1;
  const backoff = 15 * (2 ** (normalizedAttempt - 1));
  return Math.min(maxBackoffSeconds, backoff);
}

function classifySyncResult(result: WorkerSyncResult): {
  action: "complete" | "drop" | "retry";
  code: string;
} {
  switch (result.kind) {
    case "synced":
      return { action: "complete", code: "synced" };
    case "connection_not_found":
    case "plaid_environment_unsupported":
      return { action: "drop", code: result.kind };
    case "sync_in_progress":
    case "lease_acquire_failed":
    case "plaid_config_missing":
    case "plaid_pagination_mutation_exhausted":
    case "plaid_payload_invalid":
    case "plaid_request_failed":
    case "cursor_conflict":
    case "persist_failed":
      return { action: "retry", code: result.kind };
  }
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): TransactionSyncJobWorkerDatabase | null {
  const transactionsDatabase = createPlaidTransactionsSyncDatabase(getEnv);
  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

  if (
    transactionsDatabase === null ||
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return null;
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  return {
    ...transactionsDatabase,

    async claimTransactionSyncJobs(batchSize, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_claim_transaction_sync_jobs",
        {
          p_batch_size: batchSize,
          p_lease_seconds: leaseSeconds,
        },
      );

      if (error !== null || !Array.isArray(data)) {
        return null;
      }

      const jobs: ClaimedTransactionSyncJob[] = [];
      for (const row of data) {
        const job = normalizeClaimedJob(row);
        if (job === null) {
          return null;
        }
        jobs.push(job);
      }

      return jobs;
    },

    async validateTransactionSyncJobLease(connectionId, leaseToken) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_validate_transaction_sync_job_lease",
        {
          p_plaid_item_id: connectionId,
          p_lease_token: leaseToken,
        },
      );

      return error === null && data === true;
    },

    async completeTransactionSyncJob(
      connectionId,
      leaseToken,
      claimedRequestedAt,
    ) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_complete_transaction_sync_job",
        {
          p_plaid_item_id: connectionId,
          p_lease_token: leaseToken,
          p_claimed_requested_at: claimedRequestedAt,
        },
      );

      if (error !== null) {
        return null;
      }

      const status = parseRpcStatus(data);
      if (
        status === "completed" ||
        status === "rerun_scheduled" ||
        status === "missing" ||
        status === "lease_lost"
      ) {
        return status;
      }

      return null;
    },

    async dropTransactionSyncJob(connectionId, leaseToken) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_drop_transaction_sync_job",
        {
          p_plaid_item_id: connectionId,
          p_lease_token: leaseToken,
        },
      );

      if (error !== null) {
        return null;
      }

      const status = parseRpcStatus(data);
      if (
        status === "dropped" ||
        status === "missing" ||
        status === "lease_lost"
      ) {
        return status;
      }

      return null;
    },

    async failTransactionSyncJob(
      connectionId,
      leaseToken,
      errorCode,
      backoffSeconds,
    ) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_fail_transaction_sync_job",
        {
          p_plaid_item_id: connectionId,
          p_lease_token: leaseToken,
          p_error_code: errorCode,
          p_backoff_seconds: backoffSeconds,
        },
      );

      if (error !== null) {
        return null;
      }

      const status = parseRpcStatus(data);
      if (
        status === "rescheduled" ||
        status === "lease_lost" ||
        status === "missing"
      ) {
        return status;
      }

      return null;
    },

    async renewTransactionSyncJobLease(connectionId, leaseToken, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_renew_transaction_sync_job_lease",
        {
          p_plaid_item_id: connectionId,
          p_lease_token: leaseToken,
          p_lease_seconds: leaseSeconds,
        },
      );

      return error === null && data === true;
    },
  };
}

export function createJobLeaseRenewingTransactionsDatabase(params: {
  job: ClaimedTransactionSyncJob;
  database: TransactionSyncJobWorkerDatabase;
}): TransactionsSyncDatabase {
  return {
    ...params.database,
    async renewLease(userId, connectionId, ownerToken, leaseSeconds) {
      const jobLeaseRenewed = await params.database
        .renewTransactionSyncJobLease(
          params.job.connectionId,
          params.job.leaseToken,
          defaultJobLeaseSeconds,
        );

      if (!jobLeaseRenewed) {
        return false;
      }

      return await params.database.renewLease(
        userId,
        connectionId,
        ownerToken,
        leaseSeconds,
      );
    },
  };
}

async function defaultSyncTransactions(params: {
  job: ClaimedTransactionSyncJob;
  database: TransactionSyncJobWorkerDatabase;
  fetchImpl: typeof fetch;
  getEnv: (name: string) => string | undefined;
}): Promise<WorkerSyncResult> {
  return await syncPlaidTransactionsForConnection({
    userId: params.job.userId,
    connectionId: params.job.connectionId,
    database: createJobLeaseRenewingTransactionsDatabase({
      job: params.job,
      database: params.database,
    }),
    fetchImpl: params.fetchImpl,
    getEnv: params.getEnv,
    ownerToken: params.job.leaseToken,
  });
}

export function createPlaidProcessTransactionSyncJobsHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const fetchImpl = dependencies.fetch ?? fetch;
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    fetch: fetchImpl,
    getEnv,
    randomUUID: dependencies.randomUUID ?? (() => crypto.randomUUID()),
    syncTransactions: dependencies.syncTransactions ?? defaultSyncTransactions,
    log: dependencies.log ??
      ((message, fields) => console.log(message, JSON.stringify(fields))),
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (request.method !== "POST") {
      return methodNotAllowed();
    }

    const auth = authorizeInternalRequest(request, deps.getEnv);
    if (auth === "unauthorized") {
      return errorResponse(401, "unauthorized");
    }
    if (auth === "config_missing") {
      return errorResponse(500, "internal_auth_config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    const runId = deps.randomUUID();
    const batchSize = boundedBatchSize(deps.getEnv);
    const jobs = await database.claimTransactionSyncJobs(
      batchSize,
      defaultJobLeaseSeconds,
    );

    if (jobs === null) {
      return errorResponse(500, "claim_failed");
    }

    let succeeded = 0;
    let rescheduled = 0;
    let dropped = 0;

    for (const job of jobs) {
      const stillOwnsLease = await database.validateTransactionSyncJobLease(
        job.connectionId,
        job.leaseToken,
      );
      if (!stillOwnsLease) {
        continue;
      }

      let syncResult: WorkerSyncResult;
      try {
        syncResult = await deps.syncTransactions({
          job,
          database,
          fetchImpl: deps.fetch,
          getEnv: deps.getEnv,
        });
      } catch (_) {
        const failResult = await database.failTransactionSyncJob(
          job.connectionId,
          job.leaseToken,
          "worker_exception",
          computeTransactionSyncJobBackoffSeconds(job.attemptCount),
        );

        if (failResult === "rescheduled") {
          rescheduled += 1;
        } else if (failResult === "missing") {
          dropped += 1;
        }
        continue;
      }

      const classification = classifySyncResult(syncResult);

      if (classification.action === "complete") {
        const completion = await database.completeTransactionSyncJob(
          job.connectionId,
          job.leaseToken,
          job.claimedRequestedAt,
        );

        if (completion === "completed") {
          succeeded += 1;
        } else if (completion === "rerun_scheduled") {
          succeeded += 1;
          rescheduled += 1;
        } else if (completion === "missing") {
          dropped += 1;
        }
        continue;
      }

      if (classification.action === "drop") {
        const dropResult = await database.dropTransactionSyncJob(
          job.connectionId,
          job.leaseToken,
        );

        if (dropResult === "dropped" || dropResult === "missing") {
          dropped += 1;
        }
        continue;
      }

      const failResult = await database.failTransactionSyncJob(
        job.connectionId,
        job.leaseToken,
        classification.code,
        computeTransactionSyncJobBackoffSeconds(job.attemptCount),
      );

      if (failResult === "rescheduled") {
        rescheduled += 1;
      } else if (failResult === "missing") {
        dropped += 1;
      }
    }

    const responseBody = {
      status: "processed",
      claimed: jobs.length,
      succeeded,
      rescheduled,
      dropped,
    };

    deps.log("plaid_transaction_sync_job_worker_processed", {
      run_id: runId,
      ...responseBody,
    });

    return jsonResponse(200, responseBody);
  };
}
