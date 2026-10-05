import { createClient } from "npm:@supabase/supabase-js@2.112.2";
import type { AuthenticatedUser } from "../_shared/auth.ts";
import { authenticateRequest as defaultAuthenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import {
  becameActive,
  fetchItemGetHealth,
  type ItemHealthReason,
  type ItemHealthStatus,
  observationFromItemGet,
  type PlaidApiEnvironment,
  plaidItemGetUrls,
  plaidSecretEnvNames,
  readPlaidApiEnvironment,
  recordItemHealthObservationRpc,
  type RecordItemHealthObservation,
} from "../_shared/plaid_item_health.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type StoredItemHealth = {
  status: ItemHealthStatus;
  statusReason: ItemHealthReason | null;
};

type RefreshItemStatusDatabase = {
  getItemEnvironment(
    userId: string,
    connectionId: string,
  ): Promise<PlaidApiEnvironment | "not_found" | null>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  recordItemHealthObservation: RecordItemHealthObservation;
  getItemHealth(
    userId: string,
    connectionId: string,
  ): Promise<StoredItemHealth | null>;
  enqueueTransactionSyncJob(externalPlaidItemId: string): Promise<void>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => RefreshItemStatusDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  now: () => Date;
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId !== "string") {
    return null;
  }

  const trimmed = connectionId.trim();
  return uuidPattern.test(trimmed) ? trimmed.toLowerCase() : null;
}

function readStatusReason(value: unknown): ItemHealthReason | null {
  return value === "login_required" ||
      value === "consent_expired" ||
      value === "permission_revoked"
    ? value
    : null;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): RefreshItemStatusDatabase | null {
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
    async getItemEnvironment(userId, connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("plaid_environment")
        .eq("id", connectionId)
        .eq("user_id", userId)
        .maybeSingle();

      if (error !== null) {
        return null;
      }
      if (data === null) {
        return "not_found";
      }

      return readPlaidApiEnvironment(
        (data as Record<string, unknown>).plaid_environment,
      );
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

    async getItemHealth(userId, connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("status, status_reason")
        .eq("id", connectionId)
        .eq("user_id", userId)
        .maybeSingle();

      if (error !== null || data === null) {
        return null;
      }

      const row = data as Record<string, unknown>;
      if (row.status !== "active" && row.status !== "login_required") {
        return null;
      }

      return {
        status: row.status,
        statusReason: readStatusReason(row.status_reason),
      };
    },

    async enqueueTransactionSyncJob(externalPlaidItemId) {
      await supabaseAdmin.rpc("plaid_enqueue_transaction_sync_job", {
        p_external_plaid_item_id: externalPlaidItemId,
      });
    },
  };
}

// Called by the app after Link update mode onSuccess. /item/get is the only
// authority for returning an Item to active and for clearing a pending
// disconnect.
export function createPlaidRefreshItemStatusHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    fetch: dependencies.fetch ?? fetch,
    getEnv,
    now: dependencies.now ?? (() => new Date()),
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
      return errorResponse(500, "config_missing");
    }

    const environment = await database.getItemEnvironment(
      user.id,
      connectionId,
    );
    if (environment === "not_found") {
      return errorResponse(404, "connection_not_found");
    }
    if (environment === null) {
      return errorResponse(500, "internal_error");
    }

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    const secret = deps.getEnv(plaidSecretEnvNames[environment]);
    if (
      typeof clientId !== "string" ||
      clientId.length === 0 ||
      typeof secret !== "string" ||
      secret.length === 0
    ) {
      return errorResponse(500, "plaid_config_missing");
    }

    const accessToken = await database.getAccessTokenForItem(
      user.id,
      connectionId,
    );
    if (accessToken === null) {
      return errorResponse(404, "connection_not_found");
    }

    const observedAt = deps.now().toISOString();
    const health = await fetchItemGetHealth(deps.fetch, {
      url: plaidItemGetUrls[environment],
      clientId,
      secret,
      accessToken,
    });

    if (health.kind === "item_unavailable") {
      return errorResponse(409, "reconnect_unavailable");
    }

    const observation = observationFromItemGet(
      connectionId,
      observedAt,
      health,
      true,
    );
    if (observation === null) {
      return errorResponse(502, "plaid_request_failed");
    }

    const result = await database.recordItemHealthObservation(observation);
    if (result === null) {
      return errorResponse(500, "persist_failed");
    }
    if (result === "not_found") {
      return errorResponse(404, "connection_not_found");
    }

    if (becameActive(result)) {
      try {
        await database.enqueueTransactionSyncJob(result.plaidItemId);
      } catch (_) {
        // The next webhook or manual sync catches up.
      }
    }

    const stored = await database.getItemHealth(user.id, connectionId);
    if (stored === null) {
      return errorResponse(500, "internal_error");
    }

    return jsonResponse(200, {
      status: stored.status,
      status_reason: stored.statusReason,
    });
  };
}
