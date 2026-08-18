import { createClient } from "npm:@supabase/supabase-js@2";
import { authorizeInternalRequest } from "../_shared/internal_auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";

const defaultBatchSize = 5;
const maxBatchSize = 5;
const defaultJobLeaseSeconds = 900;
const defaultChunkSize = 250;
const defaultMaterializationChunkSize = 100;
const defaultSourceSyncChunkSize = 250;
const defaultCategoryChunkSize = 250;
const maxChunksPerJob = 4;
const maxBackoffSeconds = 15 * 60;

type ClaimedProjectionJob = {
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

type HandlerDependencies = {
  createDatabase: () => ProjectionJobWorkerDatabase | null;
  getEnv: (name: string) => string | undefined;
  randomUUID: () => string;
  log: (message: string, fields: Record<string, unknown>) => void;
};

export type ProjectionJobWorkerDatabase = {
  claimProjectionJobs(
    batchSize: number,
    leaseSeconds: number,
  ): Promise<ClaimedProjectionJob[] | null>;
  reconcileProjectionJob(
    job: ClaimedProjectionJob,
    chunkSize: number,
  ): Promise<ReconcileResult | null>;
  materializeProjectionJob(
    job: ClaimedProjectionJob,
    chunkSize: number,
  ): Promise<MaterializeResult | null>;
  syncMaterializedProjectionJob(
    job: ClaimedProjectionJob,
    chunkSize: number,
  ): Promise<SourceSyncResult | null>;
  applyCategoryMappingForProjectionJob(
    job: ClaimedProjectionJob,
    batchSize: number,
  ): Promise<CategoryEnrichmentResult | null>;
  continueProjectionJob(
    connectionId: string,
    leaseToken: string,
  ): Promise<"continued" | "lease_lost" | "missing" | null>;
  completeProjectionJob(
    connectionId: string,
    leaseToken: string,
    claimedRequestedAt: string,
  ): Promise<"completed" | "rerun_scheduled" | "lease_lost" | "missing" | null>;
  dropProjectionJob(
    connectionId: string,
    leaseToken: string,
  ): Promise<"dropped" | "lease_lost" | "missing" | null>;
  failProjectionJob(
    connectionId: string,
    leaseToken: string,
    errorCode: string,
    backoffSeconds: number,
  ): Promise<"rescheduled" | "lease_lost" | "missing" | null>;
  renewProjectionJobLease(
    connectionId: string,
    leaseToken: string,
    leaseSeconds: number,
  ): Promise<boolean>;
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
    getEnv("PLAID_TRANSACTION_PROJECTION_JOB_BATCH_SIZE"),
  );
  if (configured === null) {
    return defaultBatchSize;
  }

  return Math.min(configured, maxBatchSize);
}

function boundedChunkSize(
  getEnv: (name: string) => string | undefined,
): number {
  const configured = readPositiveInteger(
    getEnv("PLAID_TRANSACTION_PROJECTION_RECONCILE_CHUNK_SIZE"),
  );
  if (configured === null) {
    return defaultChunkSize;
  }

  return Math.min(configured, defaultChunkSize);
}

export function computeTransactionProjectionJobBackoffSeconds(
  attemptCount: number,
): number {
  const normalizedAttempt = Number.isInteger(attemptCount) && attemptCount > 0
    ? attemptCount
    : 1;
  const backoff = 15 * (2 ** (normalizedAttempt - 1));
  return Math.min(maxBackoffSeconds, backoff);
}

function parseRpcStatus(value: unknown): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const status = (value as Record<string, unknown>).status;
  return typeof status === "string" ? status : null;
}

function normalizeClaimedJob(value: unknown): ClaimedProjectionJob | null {
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

function normalizeReconcileResult(value: unknown): ReconcileResult | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  const status = row.status;

  if (
    status === "lease_lost" ||
    status === "missing" ||
    status === "missing_item"
  ) {
    return { status };
  }

  if (
    status !== "processed" ||
    typeof row.processed !== "number" ||
    typeof row.raw_pending !== "number" ||
    typeof row.posted_ready !== "number" ||
    typeof row.removed_inactive !== "number" ||
    typeof row.links_updated !== "number" ||
    typeof row.has_more !== "boolean"
  ) {
    return null;
  }

  return {
    status: "processed",
    processed: row.processed,
    rawPending: row.raw_pending,
    postedReady: row.posted_ready,
    removedInactive: row.removed_inactive,
    linksUpdated: row.links_updated,
    hasMore: row.has_more,
  };
}

function normalizeMaterializeResult(value: unknown): MaterializeResult | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  const status = row.status;

  if (
    status === "lease_lost" ||
    status === "missing" ||
    status === "missing_item"
  ) {
    return { status };
  }

  if (
    status !== "processed" ||
    typeof row.materialized !== "number" ||
    typeof row.suppressed_zero_amount !== "number" ||
    typeof row.has_more !== "boolean"
  ) {
    return null;
  }

  return {
    status: "processed",
    materialized: row.materialized,
    suppressedZeroAmount: row.suppressed_zero_amount,
    hasMore: row.has_more,
  };
}

function normalizeSourceSyncResult(value: unknown): SourceSyncResult | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  const status = row.status;

  if (
    status === "lease_lost" ||
    status === "missing" ||
    status === "missing_item"
  ) {
    return { status };
  }

  if (
    status !== "processed" ||
    typeof row.source_scanned !== "number" ||
    typeof row.source_updated !== "number" ||
    typeof row.source_archived !== "number" ||
    typeof row.source_unarchived !== "number" ||
    typeof row.source_unchanged !== "number" ||
    typeof row.override_preserved !== "number" ||
    typeof row.override_invalidated !== "number" ||
    typeof row.has_more !== "boolean"
  ) {
    return null;
  }

  return {
    status: "processed",
    sourceScanned: row.source_scanned,
    sourceUpdated: row.source_updated,
    sourceArchived: row.source_archived,
    sourceUnarchived: row.source_unarchived,
    sourceUnchanged: row.source_unchanged,
    overridePreserved: row.override_preserved,
    overrideInvalidated: row.override_invalidated,
    hasMore: row.has_more,
  };
}

function normalizeCategoryEnrichmentResult(
  value: unknown,
): CategoryEnrichmentResult | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  const status = row.status;

  if (
    status === "lease_lost" ||
    status === "missing" ||
    status === "missing_item"
  ) {
    return { status };
  }

  if (
    status !== "processed" ||
    typeof row.scanned !== "number" ||
    typeof row.mapped !== "number" ||
    typeof row.updated !== "number" ||
    typeof row.cleared !== "number" ||
    typeof row.unchanged !== "number" ||
    typeof row.skipped_override !== "number" ||
    typeof row.skipped_unmapped !== "number" ||
    typeof row.has_more !== "boolean"
  ) {
    return null;
  }

  return {
    status: "processed",
    scanned: row.scanned,
    mapped: row.mapped,
    updated: row.updated,
    cleared: row.cleared,
    unchanged: row.unchanged,
    skippedOverride: row.skipped_override,
    skippedUnmapped: row.skipped_unmapped,
    hasMore: row.has_more,
  };
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): ProjectionJobWorkerDatabase | null {
  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

  if (
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return null;
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  return {
    async claimProjectionJobs(batchSize, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_claim_transaction_projection_jobs",
        {
          p_batch_size: batchSize,
          p_lease_seconds: leaseSeconds,
        },
      );

      if (error !== null || !Array.isArray(data)) {
        return null;
      }

      const jobs: ClaimedProjectionJob[] = [];
      for (const row of data) {
        const job = normalizeClaimedJob(row);
        if (job === null) {
          return null;
        }
        jobs.push(job);
      }

      return jobs;
    },

    async reconcileProjectionJob(job, chunkSize) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_reconcile_transaction_operation_projections",
        {
          p_user_id: job.userId,
          p_plaid_item_id: job.connectionId,
          p_lease_token: job.leaseToken,
          p_batch_size: chunkSize,
        },
      );

      return error === null ? normalizeReconcileResult(data) : null;
    },

    async materializeProjectionJob(job, chunkSize) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_materialize_transaction_operations",
        {
          p_user_id: job.userId,
          p_plaid_item_id: job.connectionId,
          p_lease_token: job.leaseToken,
          p_batch_size: chunkSize,
        },
      );

      return error === null ? normalizeMaterializeResult(data) : null;
    },

    async syncMaterializedProjectionJob(job, chunkSize) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_sync_materialized_transaction_operations",
        {
          p_user_id: job.userId,
          p_plaid_item_id: job.connectionId,
          p_lease_token: job.leaseToken,
          p_batch_size: chunkSize,
        },
      );

      return error === null ? normalizeSourceSyncResult(data) : null;
    },

    async applyCategoryMappingForProjectionJob(job, batchSize) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_apply_pfc_category_mapping_for_item_with_lease",
        {
          p_user_id: job.userId,
          p_plaid_item_id: job.connectionId,
          p_lease_token: job.leaseToken,
          p_batch_size: batchSize,
        },
      );

      return error === null ? normalizeCategoryEnrichmentResult(data) : null;
    },

    async continueProjectionJob(connectionId, leaseToken) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_continue_transaction_projection_job",
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
        status === "continued" ||
        status === "lease_lost" ||
        status === "missing"
      ) {
        return status;
      }
      return null;
    },

    async completeProjectionJob(
      connectionId,
      leaseToken,
      claimedRequestedAt,
    ) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_complete_transaction_projection_job",
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
        status === "lease_lost" ||
        status === "missing"
      ) {
        return status;
      }
      return null;
    },

    async failProjectionJob(
      connectionId,
      leaseToken,
      errorCode,
      backoffSeconds,
    ) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_fail_transaction_projection_job",
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

    async dropProjectionJob(connectionId, leaseToken) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_drop_transaction_projection_job",
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
        status === "lease_lost" ||
        status === "missing"
      ) {
        return status;
      }
      return null;
    },

    async renewProjectionJobLease(connectionId, leaseToken, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_renew_transaction_projection_job_lease",
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

async function failJob(params: {
  database: ProjectionJobWorkerDatabase;
  job: ClaimedProjectionJob;
  errorCode: string;
}): Promise<"rescheduled" | "lease_lost" | "missing" | null> {
  return await params.database.failProjectionJob(
    params.job.connectionId,
    params.job.leaseToken,
    params.errorCode,
    computeTransactionProjectionJobBackoffSeconds(params.job.attemptCount),
  );
}

export function createPlaidProcessTransactionProjectionJobsHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    getEnv,
    randomUUID: dependencies.randomUUID ?? (() => crypto.randomUUID()),
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
    const chunkSize = boundedChunkSize(deps.getEnv);
    const materializationChunkSize = defaultMaterializationChunkSize;
    const sourceSyncChunkSize = defaultSourceSyncChunkSize;
    const categoryChunkSize = defaultCategoryChunkSize;
    const jobs = await database.claimProjectionJobs(
      batchSize,
      defaultJobLeaseSeconds,
    );

    if (jobs === null) {
      return errorResponse(500, "claim_failed");
    }

    let succeeded = 0;
    let rescheduled = 0;
    let dropped = 0;
    let chunksProcessed = 0;
    let projectionsProcessed = 0;
    let rawPending = 0;
    let postedReady = 0;
    let removedInactive = 0;
    let linksUpdated = 0;
    let materialized = 0;
    let suppressedZeroAmount = 0;
    let sourceScanned = 0;
    let sourceUpdated = 0;
    let sourceArchived = 0;
    let sourceUnarchived = 0;
    let sourceUnchanged = 0;
    let overridePreserved = 0;
    let overrideInvalidated = 0;
    let categoryScanned = 0;
    let categoryMapped = 0;
    let categoryUpdated = 0;
    let categoryCleared = 0;
    let categoryUnchanged = 0;
    let categorySkippedOverride = 0;
    let categorySkippedUnmapped = 0;

    for (const job of jobs) {
      let jobHasMore = false;
      let leaseLost = false;

      try {
        for (
          let chunkIndex = 0;
          chunkIndex < maxChunksPerJob;
          chunkIndex += 1
        ) {
          if (chunkIndex > 0) {
            const renewed = await database.renewProjectionJobLease(
              job.connectionId,
              job.leaseToken,
              defaultJobLeaseSeconds,
            );

            if (!renewed) {
              leaseLost = true;
              break;
            }
          }

          const reconcile = await database.reconcileProjectionJob(
            job,
            chunkSize,
          );

          if (reconcile === null) {
            const failResult = await failJob({
              database,
              job,
              errorCode: "reconcile_failed",
            });
            if (failResult === "rescheduled") {
              rescheduled += 1;
            } else if (failResult === "missing") {
              dropped += 1;
            }
            leaseLost = failResult === "lease_lost";
            break;
          }

          if (reconcile.status !== "processed") {
            switch (reconcile.status) {
              case "lease_lost":
                leaseLost = true;
                break;
              case "missing":
              case "missing_item": {
                const dropResult = await database.dropProjectionJob(
                  job.connectionId,
                  job.leaseToken,
                );
                if (dropResult === "dropped" || dropResult === "missing") {
                  dropped += 1;
                }
                leaseLost = true;
                break;
              }
            }
            break;
          }

          chunksProcessed += 1;
          projectionsProcessed += reconcile.processed;
          rawPending += reconcile.rawPending;
          postedReady += reconcile.postedReady;
          removedInactive += reconcile.removedInactive;
          linksUpdated += reconcile.linksUpdated;
          jobHasMore = reconcile.hasMore;

          if (!jobHasMore) {
            break;
          }
        }

        if (!leaseLost && !jobHasMore) {
          for (
            let chunkIndex = 0;
            chunkIndex < maxChunksPerJob;
            chunkIndex += 1
          ) {
            const renewed = await database.renewProjectionJobLease(
              job.connectionId,
              job.leaseToken,
              defaultJobLeaseSeconds,
            );

            if (!renewed) {
              leaseLost = true;
              break;
            }

            const materialize = await database.materializeProjectionJob(
              job,
              materializationChunkSize,
            );

            if (materialize === null) {
              const failResult = await failJob({
                database,
                job,
                errorCode: "materialize_failed",
              });
              if (failResult === "rescheduled") {
                rescheduled += 1;
              } else if (failResult === "missing") {
                dropped += 1;
              }
              leaseLost = failResult === "lease_lost";
              break;
            }

            if (materialize.status !== "processed") {
              switch (materialize.status) {
                case "lease_lost":
                  leaseLost = true;
                  break;
                case "missing":
                case "missing_item": {
                  const dropResult = await database.dropProjectionJob(
                    job.connectionId,
                    job.leaseToken,
                  );
                  if (dropResult === "dropped" || dropResult === "missing") {
                    dropped += 1;
                  }
                  leaseLost = true;
                  break;
                }
              }
              break;
            }

            chunksProcessed += 1;
            materialized += materialize.materialized;
            suppressedZeroAmount += materialize.suppressedZeroAmount;
            jobHasMore = materialize.hasMore;

            if (!jobHasMore) {
              break;
            }
          }
        }

        if (!leaseLost && !jobHasMore) {
          for (
            let chunkIndex = 0;
            chunkIndex < maxChunksPerJob;
            chunkIndex += 1
          ) {
            const renewed = await database.renewProjectionJobLease(
              job.connectionId,
              job.leaseToken,
              defaultJobLeaseSeconds,
            );

            if (!renewed) {
              leaseLost = true;
              break;
            }

            const sourceSync = await database.syncMaterializedProjectionJob(
              job,
              sourceSyncChunkSize,
            );

            if (sourceSync === null) {
              const failResult = await failJob({
                database,
                job,
                errorCode: "source_sync_failed",
              });
              if (failResult === "rescheduled") {
                rescheduled += 1;
              } else if (failResult === "missing") {
                dropped += 1;
              }
              leaseLost = failResult === "lease_lost";
              break;
            }

            if (sourceSync.status !== "processed") {
              switch (sourceSync.status) {
                case "lease_lost":
                  leaseLost = true;
                  break;
                case "missing":
                case "missing_item": {
                  const dropResult = await database.dropProjectionJob(
                    job.connectionId,
                    job.leaseToken,
                  );
                  if (dropResult === "dropped" || dropResult === "missing") {
                    dropped += 1;
                  }
                  leaseLost = true;
                  break;
                }
              }
              break;
            }

            chunksProcessed += 1;
            sourceScanned += sourceSync.sourceScanned;
            sourceUpdated += sourceSync.sourceUpdated;
            sourceArchived += sourceSync.sourceArchived;
            sourceUnarchived += sourceSync.sourceUnarchived;
            sourceUnchanged += sourceSync.sourceUnchanged;
            overridePreserved += sourceSync.overridePreserved;
            overrideInvalidated += sourceSync.overrideInvalidated;
            jobHasMore = sourceSync.hasMore;

            if (!jobHasMore) {
              break;
            }
          }
        }

        if (!leaseLost && !jobHasMore) {
          for (
            let chunkIndex = 0;
            chunkIndex < maxChunksPerJob;
            chunkIndex += 1
          ) {
            const renewed = await database.renewProjectionJobLease(
              job.connectionId,
              job.leaseToken,
              defaultJobLeaseSeconds,
            );

            if (!renewed) {
              leaseLost = true;
              break;
            }

            const category = await database
              .applyCategoryMappingForProjectionJob(
                job,
                categoryChunkSize,
              );

            if (category === null) {
              const failResult = await failJob({
                database,
                job,
                errorCode: "category_enrichment_failed",
              });
              if (failResult === "rescheduled") {
                rescheduled += 1;
              } else if (failResult === "missing") {
                dropped += 1;
              }
              leaseLost = failResult === "lease_lost";
              break;
            }

            if (category.status !== "processed") {
              switch (category.status) {
                case "lease_lost":
                  leaseLost = true;
                  break;
                case "missing":
                case "missing_item": {
                  const dropResult = await database.dropProjectionJob(
                    job.connectionId,
                    job.leaseToken,
                  );
                  if (dropResult === "dropped" || dropResult === "missing") {
                    dropped += 1;
                  }
                  leaseLost = true;
                  break;
                }
              }
              break;
            }

            chunksProcessed += 1;
            categoryScanned += category.scanned;
            categoryMapped += category.mapped;
            categoryUpdated += category.updated;
            categoryCleared += category.cleared;
            categoryUnchanged += category.unchanged;
            categorySkippedOverride += category.skippedOverride;
            categorySkippedUnmapped += category.skippedUnmapped;
            jobHasMore = category.hasMore;

            if (!jobHasMore) {
              break;
            }
          }
        }
      } catch (_) {
        const failResult = await failJob({
          database,
          job,
          errorCode: "worker_exception",
        });
        if (failResult === "rescheduled") {
          rescheduled += 1;
        } else if (failResult === "missing") {
          dropped += 1;
        }
        continue;
      }

      if (leaseLost) {
        continue;
      }

      if (jobHasMore) {
        const continuation = await database.continueProjectionJob(
          job.connectionId,
          job.leaseToken,
        );
        if (continuation === "continued") {
          rescheduled += 1;
        } else if (continuation === "missing") {
          dropped += 1;
        }
        continue;
      }

      const completion = await database.completeProjectionJob(
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
      } else if (completion === null) {
        const failResult = await failJob({
          database,
          job,
          errorCode: "complete_failed",
        });
        if (failResult === "rescheduled") {
          rescheduled += 1;
        } else if (failResult === "missing") {
          dropped += 1;
        }
      }
    }

    const responseBody = {
      status: "processed",
      claimed: jobs.length,
      succeeded,
      rescheduled,
      dropped,
      chunks_processed: chunksProcessed,
      projections_processed: projectionsProcessed,
      raw_pending: rawPending,
      posted_ready: postedReady,
      removed_inactive: removedInactive,
      links_updated: linksUpdated,
      materialized,
      suppressed_zero_amount: suppressedZeroAmount,
      source_scanned: sourceScanned,
      source_updated: sourceUpdated,
      source_archived: sourceArchived,
      source_unarchived: sourceUnarchived,
      source_unchanged: sourceUnchanged,
      override_preserved: overridePreserved,
      override_invalidated: overrideInvalidated,
      category_scanned: categoryScanned,
      category_mapped: categoryMapped,
      category_updated: categoryUpdated,
      category_cleared: categoryCleared,
      category_unchanged: categoryUnchanged,
      category_skipped_override: categorySkippedOverride,
      category_skipped_unmapped: categorySkippedUnmapped,
    };

    deps.log("plaid_transaction_projection_job_worker_processed", {
      run_id: runId,
      ...responseBody,
    });

    return jsonResponse(200, responseBody);
  };
}
