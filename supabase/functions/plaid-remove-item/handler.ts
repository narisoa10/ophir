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

type PlaidItemRow = {
  id: string;
  user_id: string;
  plaid_environment: string;
  access_token_secret_id: string;
};

type LocalCleanupResult = {
  accounts_deleted: number;
  plaid_items_deleted: number;
  vault_secrets_deleted: number;
};

type RemoveItemDatabase = {
  getPlaidItemForUser(
    userId: string,
    connectionId: string,
  ): Promise<PlaidItemRow | null>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  cleanupPlaidItem(
    userId: string,
    connectionId: string,
    accessTokenSecretId: string,
  ): Promise<LocalCleanupResult | null>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => RemoveItemDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

type PlaidEnvironmentConfig = {
  itemRemoveUrl: string;
  secretEnvName: string;
};

type PlaidRemoveOutcome = "removed" | "already_removed" | "failed";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const plaidEnvironments: Record<PlaidEnvironment, PlaidEnvironmentConfig> = {
  sandbox: {
    itemRemoveUrl: "https://sandbox.plaid.com/item/remove",
    secretEnvName: "PLAID_SANDBOX_SECRET",
  },
  development: {
    itemRemoveUrl: "https://development.plaid.com/item/remove",
    secretEnvName: "PLAID_DEVELOPMENT_SECRET",
  },
  production: {
    itemRemoveUrl: "https://production.plaid.com/item/remove",
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

function readPlaidEnvironment(value: string): PlaidEnvironment | null {
  if (
    value === "sandbox" ||
    value === "development" ||
    value === "production"
  ) {
    return value;
  }

  return null;
}

async function callPlaidItemRemove(
  fetchImpl: typeof fetch,
  config: PlaidEnvironmentConfig,
  clientId: string,
  secret: string,
  accessToken: string,
): Promise<PlaidRemoveOutcome> {
  let response: Response;

  try {
    response = await fetchImpl(config.itemRemoveUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": secret,
      },
      body: JSON.stringify({
        access_token: accessToken,
      }),
    });
  } catch (_) {
    return "failed";
  }

  let payload: Record<string, unknown>;

  try {
    const parsed = await response.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return "failed";
    }
    payload = parsed as Record<string, unknown>;
  } catch (_) {
    return "failed";
  }

  if (response.ok) {
    return "removed";
  }

  if (
    payload.error_type === "ITEM_ERROR" &&
    payload.error_code === "ITEM_NOT_FOUND"
  ) {
    return "already_removed";
  }

  return "failed";
}

function defaultCreateDatabase(): RemoveItemDatabase | null {
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
    async getPlaidItemForUser(userId, connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("id, user_id, plaid_environment, access_token_secret_id")
        .eq("id", connectionId)
        .eq("user_id", userId)
        .maybeSingle();

      if (error !== null || data === null) {
        return null;
      }

      return data as PlaidItemRow;
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

    async cleanupPlaidItem(userId, connectionId, accessTokenSecretId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_remove_item_local_cleanup",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
          p_access_token_secret_id: accessTokenSecretId,
        },
      );

      if (error !== null || !data || typeof data !== "object") {
        return null;
      }

      const result = data as Record<string, unknown>;
      const accountsDeleted = result.accounts_deleted;
      const plaidItemsDeleted = result.plaid_items_deleted;
      const vaultSecretsDeleted = result.vault_secrets_deleted;

      if (
        typeof accountsDeleted !== "number" ||
        typeof plaidItemsDeleted !== "number" ||
        typeof vaultSecretsDeleted !== "number"
      ) {
        return null;
      }

      return {
        accounts_deleted: accountsDeleted,
        plaid_items_deleted: plaidItemsDeleted,
        vault_secrets_deleted: vaultSecretsDeleted,
      };
    },
  };
}

export function createPlaidRemoveItemHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ?? defaultCreateDatabase,
    fetch: dependencies.fetch ?? fetch,
    getEnv: dependencies.getEnv ?? ((name) => Deno.env.get(name) ?? undefined),
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

    const plaidItem = await database.getPlaidItemForUser(
      user.id,
      connectionId,
    );

    if (plaidItem === null) {
      return errorResponse(404, "connection_not_found");
    }

    const environment = readPlaidEnvironment(plaidItem.plaid_environment);
    if (environment === null) {
      return errorResponse(500, "plaid_environment_unsupported");
    }

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    const config = plaidEnvironments[environment];
    const secret = deps.getEnv(config.secretEnvName);

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

    const plaidRemoveOutcome = await callPlaidItemRemove(
      deps.fetch,
      config,
      clientId,
      secret,
      accessToken,
    );

    if (plaidRemoveOutcome === "failed") {
      return errorResponse(502, "plaid_request_failed");
    }

    const cleanupResult = await database.cleanupPlaidItem(
      user.id,
      connectionId,
      plaidItem.access_token_secret_id,
    );

    if (
      cleanupResult === null ||
      cleanupResult.plaid_items_deleted !== 1 ||
      cleanupResult.vault_secrets_deleted !== 1
    ) {
      return errorResponse(500, "local_cleanup_failed");
    }

    return jsonResponse(200, {
      status: "removed",
    });
  };
}
