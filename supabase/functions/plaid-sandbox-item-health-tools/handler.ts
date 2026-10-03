import { createClient } from "npm:@supabase/supabase-js@2";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import { authorizeInternalRequest } from "../_shared/internal_auth.ts";

const PLAID_SANDBOX_RESET_LOGIN_URL =
  "https://sandbox.plaid.com/sandbox/item/reset_login";
const PLAID_SANDBOX_FIRE_WEBHOOK_URL =
  "https://sandbox.plaid.com/sandbox/item/fire_webhook";

// ITEM codes /sandbox/item/fire_webhook can fire that the Item health E2E
// needs. ITEM ERROR (ITEM_LOGIN_REQUIRED) comes from reset_login instead;
// fire_webhook's ERROR is an Assets webhook and PENDING_EXPIRATION is not
// supported by the Sandbox endpoint.
const FIREABLE_ITEM_WEBHOOK_CODES = new Set([
  "LOGIN_REPAIRED",
  "PENDING_DISCONNECT",
  "USER_PERMISSION_REVOKED",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type SandboxAction =
  | { action: "reset_login" }
  | { action: "fire_item_webhook"; webhookCode: string };

type PlaidItemRow = {
  id: string;
  user_id: string;
  plaid_environment: string;
};

type SandboxItemHealthToolsDatabase = {
  getPlaidItemByConnectionId(
    connectionId: string,
  ): Promise<PlaidItemRow | null | "lookup_failed">;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
};

type HandlerDependencies = {
  createDatabase: () => SandboxItemHealthToolsDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId !== "string") {
    return null;
  }

  const trimmed = connectionId.trim();
  return uuidPattern.test(trimmed) ? trimmed.toLowerCase() : null;
}

function readAction(body: Record<string, unknown>): SandboxAction | null {
  if (body.action === "reset_login") {
    return { action: "reset_login" };
  }

  if (
    body.action === "fire_item_webhook" &&
    typeof body.webhook_code === "string" &&
    FIREABLE_ITEM_WEBHOOK_CODES.has(body.webhook_code)
  ) {
    return { action: "fire_item_webhook", webhookCode: body.webhook_code };
  }

  return null;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): SandboxItemHealthToolsDatabase | null {
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

// Sandbox-only operator helper. The environment check runs before the access
// token is read, so non-sandbox Items never reach a Plaid call.
export function createPlaidSandboxItemHealthToolsHandler(
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
    const action = readAction(body);
    if (connectionId === null || action === null) {
      return errorResponse(400, "invalid_request");
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
      return errorResponse(404, "connection_not_found");
    }

    if (plaidItem.plaid_environment !== "sandbox") {
      return errorResponse(403, "environment_not_allowed");
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

    const accessToken = await database.getAccessTokenForItem(
      plaidItem.user_id,
      plaidItem.id,
    );
    if (accessToken === null) {
      return errorResponse(500, "access_token_unavailable");
    }

    const url = action.action === "reset_login"
      ? PLAID_SANDBOX_RESET_LOGIN_URL
      : PLAID_SANDBOX_FIRE_WEBHOOK_URL;
    const plaidBody = action.action === "reset_login"
      ? { access_token: accessToken }
      : {
        access_token: accessToken,
        webhook_type: "ITEM",
        webhook_code: action.webhookCode,
      };

    try {
      const plaidResponse = await deps.fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "PLAID-CLIENT-ID": clientId,
          "PLAID-SECRET": sandboxSecret,
        },
        body: JSON.stringify(plaidBody),
      });

      if (!plaidResponse.ok) {
        return errorResponse(502, "plaid_request_failed");
      }
    } catch (_) {
      return errorResponse(502, "plaid_request_failed");
    }

    return jsonResponse(200, { status: "ok", action: action.action });
  };
}
