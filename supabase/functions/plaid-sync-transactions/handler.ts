import { createClient } from "npm:@supabase/supabase-js@2";
import type { AuthenticatedUser } from "../_shared/auth.ts";
import { authenticateRequest as defaultAuthenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";

type PlaidEnvironment = "sandbox" | "development" | "production";

type TransactionsUpdateStatus =
  | "TRANSACTIONS_UPDATE_STATUS_UNKNOWN"
  | "NOT_READY"
  | "INITIAL_UPDATE_COMPLETE"
  | "HISTORICAL_UPDATE_COMPLETE";

type PlaidEnvironmentConfig = {
  transactionsSyncUrl: string;
  secretEnvName: string;
};

type LeaseAcquireResult = {
  acquired: boolean;
  originalCursor: string | null;
  plaidEnvironment: string | null;
};

type NormalizedTransaction = {
  plaid_account_id: string;
  transaction_id: string;
  pending: boolean;
  pending_transaction_id: string | null;
  date: string;
  authorized_date: string | null;
  datetime: string | null;
  authorized_datetime: string | null;
  amount: number;
  iso_currency_code: string | null;
  unofficial_currency_code: string | null;
  name: string;
  merchant_name: string | null;
  payment_channel: string | null;
  merchant_entity_id: string | null;
  personal_finance_category_primary: string | null;
  personal_finance_category_detailed: string | null;
  personal_finance_category_confidence_level: string | null;
  personal_finance_category_version: string | null;
};

type RemovedTransaction = {
  transaction_id: string;
};

type ApplyTransactionsSyncBatchArgs = {
  userId: string;
  connectionId: string;
  originalCursor: string | null;
  finalCursor: string;
  markInitialSyncCompleted: boolean;
  added: NormalizedTransaction[];
  modified: NormalizedTransaction[];
  removed: RemovedTransaction[];
};

type ApplyTransactionsSyncBatchResult = {
  addedCount: number;
  modifiedCount: number;
  removedCount: number;
  cursorAdvanced: boolean;
  initialSyncCompleted: boolean;
};

export type TransactionsSyncDatabase = {
  acquireLease(
    userId: string,
    connectionId: string,
    ownerToken: string,
    leaseSeconds: number,
  ): Promise<LeaseAcquireResult | "not_found" | null>;
  renewLease(
    userId: string,
    connectionId: string,
    ownerToken: string,
    leaseSeconds: number,
  ): Promise<boolean>;
  releaseLease(
    userId: string,
    connectionId: string,
    ownerToken: string,
  ): Promise<boolean>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  applyTransactionsSyncBatch(
    args: ApplyTransactionsSyncBatchArgs,
  ): Promise<ApplyTransactionsSyncBatchResult | "cursor_conflict" | null>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => TransactionsSyncDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  randomUUID: () => string;
};

type PlaidSyncPage = {
  added: NormalizedTransaction[];
  modified: NormalizedTransaction[];
  removed: RemovedTransaction[];
  hasMore: boolean;
  nextCursor: string;
  transactionsUpdateStatus: TransactionsUpdateStatus | null;
};

type PlaidSyncPageResult =
  | { kind: "success"; page: PlaidSyncPage }
  | { kind: "mutation_during_pagination" }
  | { kind: "failed" }
  | { kind: "malformed" };

type CollectedSyncBatchResult =
  | {
    kind: "success";
    added: NormalizedTransaction[];
    modified: NormalizedTransaction[];
    removed: RemovedTransaction[];
    finalCursor: string;
    transactionsUpdateStatus: TransactionsUpdateStatus | null;
    pageCount: number;
  }
  | { kind: "mutation_during_pagination" }
  | { kind: "lease_lost" }
  | { kind: "failed" }
  | { kind: "malformed" };

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const transactionsSyncCount = 500;
const personalFinanceCategoryVersion = "v2";
const leaseTtlSeconds = 300;
const maxMutationRestarts = 2;

const plaidEnvironments: Record<PlaidEnvironment, PlaidEnvironmentConfig> = {
  sandbox: {
    transactionsSyncUrl: "https://sandbox.plaid.com/transactions/sync",
    secretEnvName: "PLAID_SANDBOX_SECRET",
  },
  development: {
    transactionsSyncUrl: "https://development.plaid.com/transactions/sync",
    secretEnvName: "PLAID_DEVELOPMENT_SECRET",
  },
  production: {
    transactionsSyncUrl: "https://production.plaid.com/transactions/sync",
    secretEnvName: "PLAID_PRODUCTION_SECRET",
  },
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId !== "string") {
    return null;
  }

  const trimmed = connectionId.trim();
  return uuidPattern.test(trimmed) ? trimmed : null;
}

function readPlaidEnvironment(value: string | null): PlaidEnvironment | null {
  if (
    value === "sandbox" ||
    value === "development" ||
    value === "production"
  ) {
    return value;
  }

  return null;
}

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readNullableString(value: unknown): string | null {
  const text = readNonEmptyString(value);
  return text;
}

function readTransactionsUpdateStatus(
  value: unknown,
): TransactionsUpdateStatus | null | "invalid" {
  if (value === undefined || value === null) {
    return null;
  }

  if (
    value === "TRANSACTIONS_UPDATE_STATUS_UNKNOWN" ||
    value === "NOT_READY" ||
    value === "INITIAL_UPDATE_COMPLETE" ||
    value === "HISTORICAL_UPDATE_COMPLETE"
  ) {
    return value;
  }

  return "invalid";
}

function readAmount(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  return null;
}

function normalizePlaidTransaction(
  value: unknown,
): NormalizedTransaction | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const record = value as Record<string, unknown>;
  const plaidAccountId = readNonEmptyString(record.account_id);
  const transactionId = readNonEmptyString(record.transaction_id);
  const date = readNonEmptyString(record.date);
  const amount = readAmount(record.amount);
  const name = readNonEmptyString(record.name);

  if (
    plaidAccountId === null ||
    transactionId === null ||
    typeof record.pending !== "boolean" ||
    date === null ||
    amount === null ||
    name === null
  ) {
    return null;
  }

  const pfc = record.personal_finance_category;
  const pfcRecord = pfc && typeof pfc === "object" && !Array.isArray(pfc)
    ? pfc as Record<string, unknown>
    : null;

  return {
    plaid_account_id: plaidAccountId,
    transaction_id: transactionId,
    pending: record.pending,
    pending_transaction_id: readNullableString(record.pending_transaction_id),
    date,
    authorized_date: readNullableString(record.authorized_date),
    datetime: readNullableString(record.datetime),
    authorized_datetime: readNullableString(record.authorized_datetime),
    amount,
    iso_currency_code: readNullableString(record.iso_currency_code),
    unofficial_currency_code: readNullableString(
      record.unofficial_currency_code,
    ),
    name,
    merchant_name: readNullableString(record.merchant_name),
    payment_channel: readNullableString(record.payment_channel),
    merchant_entity_id: readNullableString(record.merchant_entity_id),
    personal_finance_category_primary: readNullableString(pfcRecord?.primary),
    personal_finance_category_detailed: readNullableString(
      pfcRecord?.detailed,
    ),
    personal_finance_category_confidence_level: readNullableString(
      pfcRecord?.confidence_level,
    ),
    personal_finance_category_version: readNullableString(pfcRecord?.version),
  };
}

function normalizeRemovedTransaction(
  value: unknown,
): RemovedTransaction | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const transactionId = readNonEmptyString(
    (value as Record<string, unknown>).transaction_id,
  );

  if (transactionId === null) {
    return null;
  }

  return { transaction_id: transactionId };
}

function normalizeTransactionArray(
  value: unknown,
): NormalizedTransaction[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const result: NormalizedTransaction[] = [];
  for (const item of value) {
    const normalized = normalizePlaidTransaction(item);
    if (normalized === null) {
      return null;
    }
    result.push(normalized);
  }

  return result;
}

function normalizeRemovedArray(value: unknown): RemovedTransaction[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const result: RemovedTransaction[] = [];
  for (const item of value) {
    const normalized = normalizeRemovedTransaction(item);
    if (normalized === null) {
      return null;
    }
    result.push(normalized);
  }

  return result;
}

function normalizePlaidSyncPayload(
  payload: Record<string, unknown>,
): PlaidSyncPage | null {
  const added = normalizeTransactionArray(payload.added);
  const modified = normalizeTransactionArray(payload.modified);
  const removed = normalizeRemovedArray(payload.removed);
  const transactionsUpdateStatus = readTransactionsUpdateStatus(
    payload.transactions_update_status,
  );

  if (
    added === null ||
    modified === null ||
    removed === null ||
    transactionsUpdateStatus === "invalid" ||
    typeof payload.has_more !== "boolean" ||
    typeof payload.next_cursor !== "string"
  ) {
    return null;
  }

  return {
    added,
    modified,
    removed,
    hasMore: payload.has_more,
    nextCursor: payload.next_cursor,
    transactionsUpdateStatus,
  };
}

function isPlaidMutationDuringPagination(
  payload: Record<string, unknown>,
): boolean {
  return payload.error_code === "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION";
}

async function callPlaidTransactionsSync(
  fetchImpl: typeof fetch,
  config: PlaidEnvironmentConfig,
  clientId: string,
  secret: string,
  accessToken: string,
  cursor: string | null,
): Promise<PlaidSyncPageResult> {
  const requestBody: Record<string, unknown> = {
    access_token: accessToken,
    count: transactionsSyncCount,
    options: {
      personal_finance_category_version: personalFinanceCategoryVersion,
    },
  };

  if (cursor !== null) {
    requestBody.cursor = cursor;
  }

  let response: Response;

  try {
    response = await fetchImpl(config.transactionsSyncUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": secret,
      },
      body: JSON.stringify(requestBody),
    });
  } catch (_) {
    return { kind: "failed" };
  }

  let payload: Record<string, unknown>;

  try {
    const parsed = await response.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return { kind: "malformed" };
    }
    payload = parsed as Record<string, unknown>;
  } catch (_) {
    return { kind: "malformed" };
  }

  if (!response.ok) {
    if (isPlaidMutationDuringPagination(payload)) {
      return { kind: "mutation_during_pagination" };
    }

    return { kind: "failed" };
  }

  const page = normalizePlaidSyncPayload(payload);
  if (page === null) {
    return { kind: "malformed" };
  }

  return { kind: "success", page };
}

async function collectTransactionsSyncBatch(params: {
  database: TransactionsSyncDatabase;
  fetchImpl: typeof fetch;
  config: PlaidEnvironmentConfig;
  clientId: string;
  secret: string;
  accessToken: string;
  userId: string;
  connectionId: string;
  ownerToken: string;
  originalCursor: string | null;
}): Promise<CollectedSyncBatchResult> {
  let cursor: string | null = params.originalCursor;
  let pageCount = 0;
  const added: NormalizedTransaction[] = [];
  const modified: NormalizedTransaction[] = [];
  const removed: RemovedTransaction[] = [];

  while (true) {
    const leaseRenewed = await params.database.renewLease(
      params.userId,
      params.connectionId,
      params.ownerToken,
      leaseTtlSeconds,
    );

    if (!leaseRenewed) {
      return { kind: "lease_lost" };
    }

    const pageResult = await callPlaidTransactionsSync(
      params.fetchImpl,
      params.config,
      params.clientId,
      params.secret,
      params.accessToken,
      cursor,
    );

    if (pageResult.kind !== "success") {
      return pageResult;
    }

    pageCount += 1;
    added.push(...pageResult.page.added);
    modified.push(...pageResult.page.modified);
    removed.push(...pageResult.page.removed);

    cursor = pageResult.page.nextCursor;

    if (!pageResult.page.hasMore) {
      return {
        kind: "success",
        added,
        modified,
        removed,
        finalCursor: pageResult.page.nextCursor,
        transactionsUpdateStatus: pageResult.page.transactionsUpdateStatus,
        pageCount,
      };
    }
  }
}

function parseApplyResult(
  data: unknown,
): ApplyTransactionsSyncBatchResult | null {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return null;
  }

  const result = data as Record<string, unknown>;
  if (
    typeof result.added_count !== "number" ||
    typeof result.modified_count !== "number" ||
    typeof result.removed_count !== "number" ||
    result.cursor_advanced !== true
  ) {
    return null;
  }

  return {
    addedCount: result.added_count,
    modifiedCount: result.modified_count,
    removedCount: result.removed_count,
    cursorAdvanced: true,
    initialSyncCompleted: result.initial_sync_completed === true,
  };
}

function isDatabaseErrorCode(
  error: { code?: string; message?: string } | null,
  expectedMessage: string,
): boolean {
  if (error === null) {
    return false;
  }

  return error.message === expectedMessage ||
    error.message?.includes(expectedMessage) === true;
}

export function createPlaidTransactionsSyncDatabase(
  getEnv: (name: string) => string | undefined = (name) =>
    Deno.env.get(name) ?? undefined,
): TransactionsSyncDatabase | null {
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
    async acquireLease(userId, connectionId, ownerToken, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_acquire_transactions_sync_lease",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
          p_owner_token: ownerToken,
          p_lease_seconds: leaseSeconds,
        },
      );

      if (error !== null) {
        return isDatabaseErrorCode(error, "plaid_item_not_found")
          ? "not_found"
          : null;
      }

      if (!data || typeof data !== "object" || Array.isArray(data)) {
        return null;
      }

      const result = data as Record<string, unknown>;
      if (typeof result.acquired !== "boolean") {
        return null;
      }

      if (!result.acquired) {
        return {
          acquired: false,
          originalCursor: null,
          plaidEnvironment: null,
        };
      }

      if (
        result.original_cursor !== null &&
        typeof result.original_cursor !== "string"
      ) {
        return null;
      }

      if (typeof result.plaid_environment !== "string") {
        return null;
      }

      return {
        acquired: true,
        originalCursor: result.original_cursor,
        plaidEnvironment: result.plaid_environment,
      };
    },

    async renewLease(userId, connectionId, ownerToken, leaseSeconds) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_renew_transactions_sync_lease",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
          p_owner_token: ownerToken,
          p_lease_seconds: leaseSeconds,
        },
      );

      return error === null && data === true;
    },

    async releaseLease(userId, connectionId, ownerToken) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_release_transactions_sync_lease",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
          p_owner_token: ownerToken,
        },
      );

      return error === null && data === true;
    },

    async getAccessTokenForItem(userId, connectionId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_get_access_token_for_item",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
        },
      );

      if (error !== null || typeof data !== "string" || data.length === 0) {
        return null;
      }

      return data;
    },

    async applyTransactionsSyncBatch(args) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_apply_transactions_sync_batch",
        {
          p_user_id: args.userId,
          p_connection_id: args.connectionId,
          p_original_cursor: args.originalCursor,
          p_final_cursor: args.finalCursor,
          p_mark_initial_sync_completed: args.markInitialSyncCompleted,
          p_added: args.added,
          p_modified: args.modified,
          p_removed: args.removed,
        },
      );

      if (error !== null) {
        return isDatabaseErrorCode(error, "cursor_conflict")
          ? "cursor_conflict"
          : null;
      }

      return parseApplyResult(data);
    },
  };
}

export type PlaidTransactionsSyncCoreResult =
  | {
    kind: "synced";
    addedCount: number;
    modifiedCount: number;
    removedCount: number;
    pageCount: number;
    restartCount: number;
    transactionsUpdateStatus: TransactionsUpdateStatus | null;
    initialSyncCompleted: boolean;
  }
  | { kind: "connection_not_found" }
  | { kind: "sync_in_progress" }
  | { kind: "lease_acquire_failed" }
  | { kind: "plaid_environment_unsupported" }
  | { kind: "plaid_config_missing" }
  | { kind: "plaid_pagination_mutation_exhausted" }
  | { kind: "plaid_payload_invalid" }
  | { kind: "plaid_request_failed" }
  | { kind: "cursor_conflict" }
  | { kind: "persist_failed" };

export async function syncPlaidTransactionsForConnection(params: {
  userId: string;
  connectionId: string;
  database: TransactionsSyncDatabase;
  fetchImpl: typeof fetch;
  getEnv: (name: string) => string | undefined;
  ownerToken: string;
}): Promise<PlaidTransactionsSyncCoreResult> {
  const lease = await params.database.acquireLease(
    params.userId,
    params.connectionId,
    params.ownerToken,
    leaseTtlSeconds,
  );

  if (lease === "not_found") {
    return { kind: "connection_not_found" };
  }

  if (lease === null) {
    return { kind: "lease_acquire_failed" };
  }

  if (!lease.acquired) {
    return { kind: "sync_in_progress" };
  }

  try {
    const environment = readPlaidEnvironment(lease.plaidEnvironment);
    if (environment === null) {
      return { kind: "plaid_environment_unsupported" };
    }

    const clientId = params.getEnv("PLAID_CLIENT_ID");
    const config = plaidEnvironments[environment];
    const secret = params.getEnv(config.secretEnvName);

    if (
      typeof clientId !== "string" ||
      clientId.length === 0 ||
      typeof secret !== "string" ||
      secret.length === 0
    ) {
      return { kind: "plaid_config_missing" };
    }

    const accessToken = await params.database.getAccessTokenForItem(
      params.userId,
      params.connectionId,
    );

    if (accessToken === null) {
      return { kind: "connection_not_found" };
    }

    let restartCount = 0;

    while (true) {
      const batch = await collectTransactionsSyncBatch({
        database: params.database,
        fetchImpl: params.fetchImpl,
        config,
        clientId,
        secret,
        accessToken,
        userId: params.userId,
        connectionId: params.connectionId,
        ownerToken: params.ownerToken,
        originalCursor: lease.originalCursor,
      });

      if (batch.kind === "mutation_during_pagination") {
        if (restartCount >= maxMutationRestarts) {
          return { kind: "plaid_pagination_mutation_exhausted" };
        }

        restartCount += 1;
        continue;
      }

      if (batch.kind === "lease_lost") {
        return { kind: "sync_in_progress" };
      }

      if (batch.kind === "malformed") {
        return { kind: "plaid_payload_invalid" };
      }

      if (batch.kind === "failed") {
        return { kind: "plaid_request_failed" };
      }

      const leaseStillOwned = await params.database.renewLease(
        params.userId,
        params.connectionId,
        params.ownerToken,
        leaseTtlSeconds,
      );

      if (!leaseStillOwned) {
        return { kind: "sync_in_progress" };
      }

      const markInitialSyncCompleted =
        batch.transactionsUpdateStatus === "HISTORICAL_UPDATE_COMPLETE";
      const applyResult = await params.database.applyTransactionsSyncBatch({
        userId: params.userId,
        connectionId: params.connectionId,
        originalCursor: lease.originalCursor,
        finalCursor: batch.finalCursor,
        markInitialSyncCompleted,
        added: batch.added,
        modified: batch.modified,
        removed: batch.removed,
      });

      if (applyResult === "cursor_conflict") {
        return { kind: "cursor_conflict" };
      }

      if (applyResult === null) {
        return { kind: "persist_failed" };
      }

      return {
        kind: "synced",
        addedCount: applyResult.addedCount,
        modifiedCount: applyResult.modifiedCount,
        removedCount: applyResult.removedCount,
        pageCount: batch.pageCount,
        restartCount,
        transactionsUpdateStatus: batch.transactionsUpdateStatus,
        initialSyncCompleted: applyResult.initialSyncCompleted,
      };
    }
  } finally {
    try {
      await params.database.releaseLease(
        params.userId,
        params.connectionId,
        params.ownerToken,
      );
    } catch (_) {
      // Lease expiration is the crash-recovery path; release is best-effort.
    }
  }
}

export function createPlaidSyncTransactionsHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createPlaidTransactionsSyncDatabase()),
    fetch: dependencies.fetch ?? fetch,
    getEnv: dependencies.getEnv ?? ((name) => Deno.env.get(name) ?? undefined),
    randomUUID: dependencies.randomUUID ?? (() => crypto.randomUUID()),
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (request.method !== "POST") {
      return methodNotAllowed();
    }

    const user = await deps.authenticateRequest(request);
    if (user === null) {
      return errorResponse(401, "unauthorized");
    }

    const body = await readJsonObject(request);
    if (body === null) {
      return errorResponse(400, "invalid_request");
    }

    const connectionId = readConnectionId(body);
    if (connectionId === null) {
      return errorResponse(400, "invalid_request");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    const result = await syncPlaidTransactionsForConnection({
      userId: user.id,
      connectionId,
      database,
      fetchImpl: deps.fetch,
      getEnv: deps.getEnv,
      ownerToken: deps.randomUUID(),
    });

    switch (result.kind) {
      case "synced":
        return jsonResponse(200, {
          status: "synced",
          added_count: result.addedCount,
          modified_count: result.modifiedCount,
          removed_count: result.removedCount,
          page_count: result.pageCount,
          restart_count: result.restartCount,
          transactions_update_status: result.transactionsUpdateStatus,
          initial_sync_completed: result.initialSyncCompleted,
        });
      case "connection_not_found":
        return errorResponse(404, "connection_not_found");
      case "sync_in_progress":
        return errorResponse(409, "sync_in_progress");
      case "lease_acquire_failed":
        return errorResponse(500, "lease_acquire_failed");
      case "plaid_environment_unsupported":
        return errorResponse(500, "plaid_environment_unsupported");
      case "plaid_config_missing":
        return errorResponse(500, "plaid_config_missing");
      case "plaid_pagination_mutation_exhausted":
        return errorResponse(502, "plaid_pagination_mutation_exhausted");
      case "plaid_payload_invalid":
        return errorResponse(502, "plaid_payload_invalid");
      case "plaid_request_failed":
        return errorResponse(502, "plaid_request_failed");
      case "cursor_conflict":
        return errorResponse(409, "cursor_conflict");
      case "persist_failed":
        return errorResponse(500, "persist_failed");
    }
  };
}
