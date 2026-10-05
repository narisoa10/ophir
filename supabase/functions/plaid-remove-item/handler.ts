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

type LifecycleItemRow = {
  plaid_environment: string;
  disconnected_at: string | null;
};

type ItemLifecycleDatabase = {
  getItemLifecycleState(
    userId: string,
    connectionId: string,
  ): Promise<LifecycleItemRow | null | "failed">;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  disconnectItemLocal(
    userId: string,
    connectionId: string,
  ): Promise<"disconnected" | "already_disconnected" | "not_found" | null>;
  deleteItemLocal(
    userId: string,
    connectionId: string,
  ): Promise<"deleted" | "not_found" | null>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => RemoveItemDatabase | null;
  createLifecycleDatabase: () => ItemLifecycleDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

type PlaidEnvironmentConfig = {
  itemRemoveUrl: string;
  secretEnvName: string;
};

// "unknown": no Plaid answer was read (network error, unreadable body), so the
// Item may or may not have been removed.
type PlaidRemoveOutcome = "removed" | "already_removed" | "failed" | "unknown";

// Absent action: the original remove contract (plaid_remove_item_local_cleanup).
type RequestAction = "legacy_remove" | "disconnect" | "delete";

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

function readAction(body: Record<string, unknown>): RequestAction | null {
  const action = body.action;
  if (action === undefined) {
    return "legacy_remove";
  }

  return action === "disconnect" || action === "delete" ? action : null;
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
    return "unknown";
  }

  let payload: Record<string, unknown>;

  try {
    const parsed = await response.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return "unknown";
    }
    payload = parsed as Record<string, unknown>;
  } catch (_) {
    return "unknown";
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

function defaultCreateLifecycleDatabase(): ItemLifecycleDatabase | null {
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
    async getItemLifecycleState(userId, connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("plaid_environment, disconnected_at")
        .eq("id", connectionId)
        .eq("user_id", userId)
        .maybeSingle();

      if (error !== null) {
        return "failed";
      }
      if (data === null) {
        return null;
      }

      const row = data as Record<string, unknown>;
      if (
        typeof row.plaid_environment !== "string" ||
        (row.disconnected_at !== null &&
          typeof row.disconnected_at !== "string")
      ) {
        return "failed";
      }

      return {
        plaid_environment: row.plaid_environment,
        disconnected_at: row.disconnected_at,
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

    async disconnectItemLocal(userId, connectionId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_disconnect_item_local",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
        },
      );

      const status = error === null && data && typeof data === "object"
        ? (data as Record<string, unknown>).status
        : null;
      return status === "disconnected" ||
          status === "already_disconnected" ||
          status === "not_found"
        ? status
        : null;
    },

    async deleteItemLocal(userId, connectionId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_delete_item_local",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
        },
      );

      const status = error === null && data && typeof data === "object"
        ? (data as Record<string, unknown>).status
        : null;
      return status === "deleted" || status === "not_found" ? status : null;
    },
  };
}

type RemoteRemoval =
  | { kind: "removed" }
  | { kind: "disconnected_meanwhile" }
  | { kind: "response"; response: Response };

// The Plaid Item must be removed before the local transition: the local
// Disconnect deletes the only access token, after which /item/remove is
// impossible. Without a confirmed Plaid answer nothing local changes.
async function removePlaidItemForLifecycle(
  deps: HandlerDependencies,
  database: ItemLifecycleDatabase,
  userId: string,
  connectionId: string,
  plaidEnvironment: string,
): Promise<RemoteRemoval> {
  const environment = readPlaidEnvironment(plaidEnvironment);
  if (environment === null) {
    return {
      kind: "response",
      response: errorResponse(500, "plaid_environment_unsupported"),
    };
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
    return {
      kind: "response",
      response: errorResponse(500, "plaid_config_missing"),
    };
  }

  const accessToken = await database.getAccessTokenForItem(
    userId,
    connectionId,
  );
  if (accessToken === null) {
    // A concurrent Disconnect deletes the token; anything else is unexpected.
    const current = await database.getItemLifecycleState(userId, connectionId);
    if (current === null) {
      return {
        kind: "response",
        response: errorResponse(404, "connection_not_found"),
      };
    }
    if (current !== "failed" && current.disconnected_at !== null) {
      return { kind: "disconnected_meanwhile" };
    }
    return {
      kind: "response",
      response: errorResponse(500, "local_lifecycle_failed"),
    };
  }

  const outcome = await callPlaidItemRemove(
    deps.fetch,
    config,
    clientId,
    secret,
    accessToken,
  );

  if (outcome === "failed") {
    return {
      kind: "response",
      response: errorResponse(502, "plaid_request_failed"),
    };
  }
  if (outcome === "unknown") {
    return {
      kind: "response",
      response: errorResponse(502, "plaid_outcome_unknown"),
    };
  }

  return { kind: "removed" };
}

async function deleteItemLocally(
  database: ItemLifecycleDatabase,
  userId: string,
  connectionId: string,
): Promise<Response> {
  const deleted = await database.deleteItemLocal(userId, connectionId);
  switch (deleted) {
    case "deleted":
      return jsonResponse(200, { status: "deleted" });
    case "not_found":
      return errorResponse(404, "connection_not_found");
    case null:
      return errorResponse(500, "local_lifecycle_failed");
  }
}

// Disconnect: Plaid Item removed, local history kept (plaid_disconnect_item_local).
// Delete: an active Item is first disconnected the same way, then
// plaid_delete_item_local removes it; an already disconnected Item has no token
// and no Plaid Item left, so only the local Delete runs.
async function handleItemLifecycle(
  deps: HandlerDependencies,
  action: "disconnect" | "delete",
  userId: string,
  connectionId: string,
): Promise<Response> {
  const database = deps.createLifecycleDatabase();
  if (database === null) {
    return errorResponse(500, "supabase_config_missing");
  }

  const item = await database.getItemLifecycleState(userId, connectionId);
  if (item === "failed") {
    return errorResponse(500, "local_lifecycle_failed");
  }
  if (item === null) {
    return errorResponse(404, "connection_not_found");
  }

  if (item.disconnected_at !== null) {
    return action === "disconnect"
      ? jsonResponse(200, { status: "already_disconnected" })
      : await deleteItemLocally(database, userId, connectionId);
  }

  const removal = await removePlaidItemForLifecycle(
    deps,
    database,
    userId,
    connectionId,
    item.plaid_environment,
  );
  if (removal.kind === "response") {
    return removal.response;
  }
  if (removal.kind === "disconnected_meanwhile") {
    return action === "disconnect"
      ? jsonResponse(200, { status: "already_disconnected" })
      : await deleteItemLocally(database, userId, connectionId);
  }

  const disconnected = await database.disconnectItemLocal(userId, connectionId);
  if (disconnected === null) {
    return errorResponse(500, "local_lifecycle_failed");
  }
  if (disconnected === "not_found") {
    return errorResponse(404, "connection_not_found");
  }

  return action === "disconnect"
    ? jsonResponse(200, { status: disconnected })
    : await deleteItemLocally(database, userId, connectionId);
}

export function createPlaidRemoveItemHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ?? defaultCreateDatabase,
    createLifecycleDatabase: dependencies.createLifecycleDatabase ??
      defaultCreateLifecycleDatabase,
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
    const action = readAction(body);
    if (connectionId === null || action === null) {
      return errorResponse(400, "invalid_request");
    }

    if (action !== "legacy_remove") {
      return await handleItemLifecycle(deps, action, user.id, connectionId);
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

    if (plaidRemoveOutcome === "failed" || plaidRemoveOutcome === "unknown") {
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
