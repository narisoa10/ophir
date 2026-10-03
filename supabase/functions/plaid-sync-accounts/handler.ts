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
import {
  createPlaidTransactionsSyncDatabase,
  syncPlaidTransactionsForConnection,
} from "../plaid-sync-transactions/handler.ts";
import { recordItemHealthObservationRpc } from "../_shared/plaid_item_health.ts";
import {
  type AccountsRefreshDatabase,
  type PlaidAccountsRefreshResult,
  refreshPlaidAccountsForItem,
} from "../_shared/plaid_accounts_refresh.ts";

type TransactionBootstrapStatus = "synced" | "deferred";

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => AccountsRefreshDatabase | null;
  bootstrapTransactions: (
    userId: string,
    connectionId: string,
  ) => Promise<TransactionBootstrapStatus>;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  now: () => Date;
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId === "string" && connectionId.trim().length > 0) {
    return connectionId.trim();
  }

  return null;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): AccountsRefreshDatabase | null {
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

    async persistAccountsSync(args) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_persist_accounts_sync",
        {
          p_user_id: args.userId,
          p_connection_id: args.connectionId,
          p_plaid_institution_id: args.plaidInstitutionId,
          p_institution_name: args.institutionName,
          p_logo_base64: args.logoBase64,
          p_primary_color: args.primaryColor,
          p_url: args.institutionUrl,
          p_balance_fetched_at: args.balanceFetchedAt,
          p_accounts: args.accounts,
        },
      );

      if (error !== null || typeof data !== "number") {
        return null;
      }

      return data;
    },

    recordItemHealthObservation(observation) {
      return recordItemHealthObservationRpc(supabaseAdmin, observation);
    },
  };
}

function createDefaultTransactionBootstrap(
  fetchImpl: typeof fetch,
  getEnv: (name: string) => string | undefined,
): (
  userId: string,
  connectionId: string,
) => Promise<TransactionBootstrapStatus> {
  return async (userId, connectionId) => {
    const database = createPlaidTransactionsSyncDatabase(getEnv);
    if (database === null) {
      return "deferred";
    }

    const result = await syncPlaidTransactionsForConnection({
      userId,
      connectionId,
      database,
      fetchImpl,
      getEnv,
      ownerToken: crypto.randomUUID(),
    });

    return result.kind === "synced" ? "synced" : "deferred";
  };
}

function refreshFailureResponse(
  result: Exclude<PlaidAccountsRefreshResult, { kind: "refreshed" }>,
): Response {
  switch (result.kind) {
    case "connection_not_found":
      return errorResponse(404, "connection_not_found");
    case "item_login_required":
      return errorResponse(409, "item_login_required");
    case "persist_failed":
      return errorResponse(500, "persist_failed");
    case "plaid_payload_invalid":
      return errorResponse(502, "plaid_payload_invalid");
    case "item_unavailable":
    case "plaid_request_failed":
    case "institution_lookup_failed":
      return errorResponse(502, "plaid_request_failed");
  }
}

export function createPlaidSyncAccountsHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const fetchImpl = dependencies.fetch ?? fetch;
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    bootstrapTransactions: dependencies.bootstrapTransactions ??
      createDefaultTransactionBootstrap(fetchImpl, getEnv),
    fetch: fetchImpl,
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

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    const sandboxSecret = deps.getEnv("PLAID_SANDBOX_SECRET");

    if (
      typeof clientId !== "string" ||
      clientId.length === 0 ||
      typeof sandboxSecret !== "string" ||
      sandboxSecret.length === 0
    ) {
      return errorResponse(500, "config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "config_missing");
    }

    const refresh = await refreshPlaidAccountsForItem({
      userId: user.id,
      connectionId,
      database,
      fetchImpl: deps.fetch,
      clientId,
      secret: sandboxSecret,
      now: deps.now,
      institutionSource: "plaid",
    });

    if (refresh.kind !== "refreshed") {
      return refreshFailureResponse(refresh);
    }

    let transactionsBootstrapStatus: TransactionBootstrapStatus = "deferred";
    try {
      transactionsBootstrapStatus = await deps.bootstrapTransactions(
        user.id,
        connectionId,
      );
    } catch (_) {
      transactionsBootstrapStatus = "deferred";
    }

    return jsonResponse(200, {
      synced_account_count: refresh.syncedAccountCount,
      institution_name: refresh.institutionName,
      transactions_bootstrap_status: transactionsBootstrapStatus,
    });
  };
}
