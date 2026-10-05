import { createClient } from "npm:@supabase/supabase-js@2.112.2";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
} from "../_shared/http.ts";
import {
  createPlaidWebhookVerifier,
  type PlaidWebhookVerificationResult,
} from "../_shared/plaid_webhook_verification.ts";
import {
  becameActive,
  fetchItemGetHealth,
  type ItemHealthObservation,
  observationFromItemGet,
  plaidItemGetUrls,
  recordItemHealthObservationRpc,
  type RecordItemHealthObservation,
} from "../_shared/plaid_item_health.ts";

type EnqueueResult = "accepted" | "coalesced" | "ignored";

type ItemConnection = {
  connectionId: string;
  userId: string;
};

type AccessDeadlineKind = "pending_disconnect" | "consent_expiration";

type WebhookDatabase = {
  enqueueTransactionSyncJob(
    externalPlaidItemId: string,
  ): Promise<EnqueueResult | null>;
  resolveItemConnection(
    externalPlaidItemId: string,
  ): Promise<ItemConnection | "not_found" | null>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  recordItemHealthObservation: RecordItemHealthObservation;
  setItemAccessDeadline(
    externalPlaidItemId: string,
    kind: AccessDeadlineKind,
    at: string,
  ): Promise<"applied" | "ignored" | null>;
};

type HandlerDependencies = {
  createDatabase: () => WebhookDatabase | null;
  verifyWebhook: (
    rawBody: string,
    plaidVerification: string | null,
  ) => Promise<PlaidWebhookVerificationResult>;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  now: () => Date;
};

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readTimestamp(value: unknown): string | null {
  const timestamp = readNonEmptyString(value);
  return timestamp !== null && !Number.isNaN(Date.parse(timestamp))
    ? timestamp
    : null;
}

function readPayload(rawBody: string): Record<string, unknown> | null {
  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch (_) {
    return null;
  }
}

function readEnqueueResult(data: unknown): EnqueueResult | null {
  if (!data || typeof data !== "object") {
    return null;
  }

  const status = (data as Record<string, unknown>).status;
  if (
    status === "accepted" ||
    status === "coalesced" ||
    status === "ignored"
  ) {
    return status;
  }

  return null;
}

function defaultCreateDatabase(): WebhookDatabase | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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
    async enqueueTransactionSyncJob(externalPlaidItemId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_enqueue_transaction_sync_job",
        {
          p_external_plaid_item_id: externalPlaidItemId,
        },
      );

      if (error !== null) {
        return null;
      }

      return readEnqueueResult(data);
    },

    async resolveItemConnection(externalPlaidItemId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_resolve_item_connection",
        {
          p_external_plaid_item_id: externalPlaidItemId,
        },
      );

      if (error !== null || !Array.isArray(data)) {
        return null;
      }

      if (data.length === 0) {
        return "not_found";
      }

      const row = data[0] as Record<string, unknown>;
      if (
        typeof row.connection_id !== "string" ||
        typeof row.user_id !== "string"
      ) {
        return null;
      }

      return { connectionId: row.connection_id, userId: row.user_id };
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

    recordItemHealthObservation(observation) {
      return recordItemHealthObservationRpc(supabaseAdmin, observation);
    },

    async setItemAccessDeadline(externalPlaidItemId, kind, at) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_set_item_access_deadline",
        {
          p_external_plaid_item_id: externalPlaidItemId,
          p_kind: kind,
          p_at: at,
        },
      );

      if (error !== null || !data || typeof data !== "object") {
        return null;
      }

      const status = (data as Record<string, unknown>).status;
      return status === "applied" || status === "ignored" ? status : null;
    },
  };
}

async function handleTransactionsSyncUpdates(
  database: WebhookDatabase,
  itemId: string,
): Promise<Response> {
  const enqueueResult = await database.enqueueTransactionSyncJob(itemId);
  if (enqueueResult === null) {
    return errorResponse(500, "enqueue_failed");
  }

  if (enqueueResult === "ignored") {
    return jsonResponse(200, { status: "ignored" });
  }

  return jsonResponse(200, { status: "accepted" });
}

async function enqueueAfterRecovery(
  database: WebhookDatabase,
  itemId: string,
): Promise<void> {
  try {
    await database.enqueueTransactionSyncJob(itemId);
  } catch (_) {
    // The next SYNC_UPDATES_AVAILABLE webhook or manual sync catches up.
  }
}

function observationResponse(
  result: Awaited<ReturnType<RecordItemHealthObservation>>,
): Response | null {
  if (result === null) {
    return errorResponse(500, "persist_failed");
  }

  if (result === "not_found") {
    return jsonResponse(200, { status: "ignored" });
  }

  return null;
}

// ERROR and LOGIN_REPAIRED are treated as hints: /item/get is the authority for
// the stored state. Non-2xx makes Plaid redeliver while /item/get is failing.
async function handleItemGetWebhook(
  deps: HandlerDependencies,
  database: WebhookDatabase,
  itemId: string,
): Promise<Response> {
  const connection = await database.resolveItemConnection(itemId);
  if (connection === null) {
    return errorResponse(500, "item_resolve_failed");
  }

  if (connection === "not_found") {
    return jsonResponse(200, { status: "ignored" });
  }

  const clientId = deps.getEnv("PLAID_CLIENT_ID");
  const secret = deps.getEnv("PLAID_SANDBOX_SECRET");
  if (
    typeof clientId !== "string" ||
    clientId.length === 0 ||
    typeof secret !== "string" ||
    secret.length === 0
  ) {
    return errorResponse(500, "plaid_config_missing");
  }

  const accessToken = await database.getAccessTokenForItem(
    connection.userId,
    connection.connectionId,
  );
  if (accessToken === null) {
    return errorResponse(500, "item_health_failed");
  }

  const observedAt = deps.now().toISOString();
  const health = await fetchItemGetHealth(deps.fetch, {
    url: plaidItemGetUrls.sandbox,
    clientId,
    secret,
    accessToken,
  });

  if (health.kind === "failed") {
    return errorResponse(500, "item_health_failed");
  }

  const observation = observationFromItemGet(
    connection.connectionId,
    observedAt,
    health,
    false,
  );
  if (observation === null) {
    return jsonResponse(200, { status: "ignored" });
  }

  const result = await database.recordItemHealthObservation(observation);
  const failure = observationResponse(result);
  if (failure !== null) {
    return failure;
  }

  if (becameActive(result)) {
    await enqueueAfterRecovery(database, itemId);
  }

  return jsonResponse(200, { status: "accepted" });
}

async function handlePermissionRevoked(
  deps: HandlerDependencies,
  database: WebhookDatabase,
  itemId: string,
): Promise<Response> {
  const connection = await database.resolveItemConnection(itemId);
  if (connection === null) {
    return errorResponse(500, "item_resolve_failed");
  }

  if (connection === "not_found") {
    return jsonResponse(200, { status: "ignored" });
  }

  const observation: ItemHealthObservation = {
    connectionId: connection.connectionId,
    observedAt: deps.now().toISOString(),
    status: "login_required",
    statusReason: "permission_revoked",
    fromItemGet: false,
    consentExpiresAt: null,
    clearPendingDisconnect: false,
  };

  const result = await database.recordItemHealthObservation(observation);
  return observationResponse(result) ??
    jsonResponse(200, { status: "accepted" });
}

async function handleAccessDeadline(
  database: WebhookDatabase,
  itemId: string,
  kind: AccessDeadlineKind,
  at: string | null,
): Promise<Response> {
  if (at === null) {
    return jsonResponse(200, { status: "ignored" });
  }

  const result = await database.setItemAccessDeadline(itemId, kind, at);
  if (result === null) {
    return errorResponse(500, "persist_failed");
  }

  return jsonResponse(200, {
    status: result === "applied" ? "accepted" : "ignored",
  });
}

export function createPlaidWebhookHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ?? defaultCreateDatabase,
    verifyWebhook: dependencies.verifyWebhook ?? createPlaidWebhookVerifier(),
    fetch: dependencies.fetch ?? fetch,
    getEnv: dependencies.getEnv ??
      ((name: string) => Deno.env.get(name) ?? undefined),
    now: dependencies.now ?? (() => new Date()),
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (request.method !== "POST") {
      return methodNotAllowed();
    }

    const rawBody = await request.text();
    const verification = await deps.verifyWebhook(
      rawBody,
      request.headers.get("Plaid-Verification"),
    );

    if (!verification.ok) {
      return errorResponse(verification.status, verification.code);
    }

    const payload = readPayload(rawBody);
    if (payload === null) {
      return jsonResponse(200, { status: "ignored" });
    }

    const webhookType = readNonEmptyString(payload.webhook_type);
    const webhookCode = readNonEmptyString(payload.webhook_code);
    const isTransactionsSync = webhookType === "TRANSACTIONS" &&
      webhookCode === "SYNC_UPDATES_AVAILABLE";
    const isItemHealth = webhookType === "ITEM" &&
      (webhookCode === "ERROR" ||
        webhookCode === "LOGIN_REPAIRED" ||
        webhookCode === "USER_PERMISSION_REVOKED" ||
        webhookCode === "PENDING_EXPIRATION" ||
        webhookCode === "PENDING_DISCONNECT");

    if (!isTransactionsSync && !isItemHealth) {
      return jsonResponse(200, { status: "ignored" });
    }

    const itemId = readNonEmptyString(payload.item_id);
    if (itemId === null) {
      return jsonResponse(200, { status: "ignored" });
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    switch (webhookCode) {
      case "SYNC_UPDATES_AVAILABLE":
        return await handleTransactionsSyncUpdates(database, itemId);
      case "ERROR":
      case "LOGIN_REPAIRED":
        return await handleItemGetWebhook(deps, database, itemId);
      case "USER_PERMISSION_REVOKED":
        return await handlePermissionRevoked(deps, database, itemId);
      case "PENDING_EXPIRATION":
        return await handleAccessDeadline(
          database,
          itemId,
          "consent_expiration",
          readTimestamp(payload.consent_expiration_time),
        );
      default:
        return await handleAccessDeadline(
          database,
          itemId,
          "pending_disconnect",
          readTimestamp(payload.disconnect_time),
        );
    }
  };
}
