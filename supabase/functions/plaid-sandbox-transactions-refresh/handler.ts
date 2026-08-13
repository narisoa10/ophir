import { createClient } from "npm:@supabase/supabase-js@2";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import { authorizeInternalRequest } from "../_shared/internal_auth.ts";

const PLAID_SANDBOX_TRANSACTIONS_REFRESH_URL =
  "https://sandbox.plaid.com/transactions/refresh";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type PlaidItemRow = {
  id: string;
  user_id: string;
  plaid_environment: string;
};

type SandboxRefreshDatabase = {
  getPlaidItemByConnectionId(
    connectionId: string,
  ): Promise<PlaidItemRow | null | "lookup_failed">;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
};

type HandlerDependencies = {
  createDatabase: () => SandboxRefreshDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId !== "string") {
    return null;
  }

  const trimmed = connectionId.trim();
  return uuidPattern.test(trimmed) ? trimmed : null;
}

function readRequestId(payload: unknown): string | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return null;
  }

  const requestId = (payload as Record<string, unknown>).request_id;
  if (typeof requestId !== "string") {
    return null;
  }

  const trimmed = requestId.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): SandboxRefreshDatabase | null {
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
    async getPlaidItemByConnectionId(connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("id, user_id, plaid_environment")
        .eq("id", connectionId)
        .maybeSingle();

      if (error !== null) {
        return "lookup_failed";
      }

      if (data === null) {
        return null;
      }

      const row = data as Record<string, unknown>;
      if (
        typeof row.id !== "string" ||
        typeof row.user_id !== "string" ||
        typeof row.plaid_environment !== "string"
      ) {
        return "lookup_failed";
      }

      return {
        id: row.id,
        user_id: row.user_id,
        plaid_environment: row.plaid_environment,
      };
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
  };
}

export function createPlaidSandboxTransactionsRefreshHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    fetch: dependencies.fetch ?? fetch,
    getEnv,
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
      return errorResponse(500, "plaid_config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    const plaidItem = await database.getPlaidItemByConnectionId(connectionId);
    if (plaidItem === "lookup_failed") {
      return errorResponse(500, "internal_error");
    }
    if (plaidItem === null) {
      return errorResponse(404, "not_found");
    }

    if (plaidItem.plaid_environment !== "sandbox") {
      return errorResponse(403, "sandbox_only");
    }

    const accessToken = await database.getAccessTokenForItem(
      plaidItem.user_id,
      plaidItem.id,
    );
    if (accessToken === null) {
      return errorResponse(500, "access_token_unavailable");
    }

    try {
      const plaidResponse = await deps.fetch(
        PLAID_SANDBOX_TRANSACTIONS_REFRESH_URL,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "PLAID-CLIENT-ID": clientId,
            "PLAID-SECRET": sandboxSecret,
          },
          body: JSON.stringify({
            access_token: accessToken,
          }),
        },
      );

      if (!plaidResponse.ok) {
        return errorResponse(502, "plaid_request_failed");
      }

      let requestId: string | null = null;
      try {
        requestId = readRequestId(await plaidResponse.json());
      } catch (_) {
        requestId = null;
      }

      const responseBody: Record<string, unknown> = {
        status: "refreshed",
        connection_id: plaidItem.id,
      };
      if (requestId !== null) {
        responseBody.request_id = requestId;
      }

      return jsonResponse(200, responseBody);
    } catch (_) {
      return errorResponse(502, "plaid_request_failed");
    }
  };
}
