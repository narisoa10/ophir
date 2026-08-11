import { createClient } from "npm:@supabase/supabase-js@2";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import { authorizeInternalRequest } from "../_shared/internal_auth.ts";

const PLAID_SANDBOX_ITEM_WEBHOOK_UPDATE_URL =
  "https://sandbox.plaid.com/item/webhook/update";
const defaultBatchSize = 20;
const maxBatchSize = 50;

type PlaidItemReference = {
  connectionId: string;
  userId: string;
};

type ItemWebhookMaintenanceDatabase = {
  listSandboxItems(
    batchSize: number,
    offset: number,
  ): Promise<PlaidItemReference[] | null>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
};

type HandlerDependencies = {
  createDatabase: () => ItemWebhookMaintenanceDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

function readInteger(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return null;
  }

  return value;
}

function readBatchControls(body: Record<string, unknown>): {
  batchSize: number;
  offset: number;
} | null {
  const batchSizeValue = body.batch_size;
  const offsetValue = body.offset;
  const batchSize = batchSizeValue === undefined
    ? defaultBatchSize
    : readInteger(batchSizeValue);
  const offset = offsetValue === undefined ? 0 : readInteger(offsetValue);

  if (
    batchSize === null ||
    offset === null ||
    batchSize < 1 ||
    batchSize > maxBatchSize ||
    offset < 0
  ) {
    return null;
  }

  return { batchSize, offset };
}

function readWebhookUrl(
  getEnv: (name: string) => string | undefined,
): string | null {
  const rawUrl = getEnv("PLAID_WEBHOOK_URL");
  if (typeof rawUrl !== "string" || rawUrl.trim().length === 0) {
    return null;
  }

  try {
    const url = new URL(rawUrl.trim());
    if (url.protocol !== "https:") {
      return null;
    }

    return url.toString();
  } catch (_) {
    return null;
  }
}

function normalizeItemReference(value: unknown): PlaidItemReference | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const row = value as Record<string, unknown>;
  if (
    typeof row.connection_id !== "string" ||
    typeof row.user_id !== "string"
  ) {
    return null;
  }

  return {
    connectionId: row.connection_id,
    userId: row.user_id,
  };
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): ItemWebhookMaintenanceDatabase | null {
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
    async listSandboxItems(batchSize, offset) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_list_sandbox_items_for_webhook_maintenance",
        {
          p_batch_size: batchSize,
          p_offset: offset,
        },
      );

      if (error !== null || !Array.isArray(data)) {
        return null;
      }

      const items: PlaidItemReference[] = [];
      for (const row of data) {
        const item = normalizeItemReference(row);
        if (item === null) {
          return null;
        }
        items.push(item);
      }

      return items;
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

export function createPlaidUpdateItemWebhooksHandler(
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

    const controls = readBatchControls(body);
    if (controls === null) {
      return errorResponse(400, "invalid_request");
    }

    const webhookUrl = readWebhookUrl(deps.getEnv);
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
    if (webhookUrl === null) {
      return errorResponse(500, "plaid_webhook_config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    const items = await database.listSandboxItems(
      controls.batchSize,
      controls.offset,
    );
    if (items === null) {
      return errorResponse(500, "list_items_failed");
    }

    let updated = 0;
    let failed = 0;
    let skipped = 0;

    for (const item of items) {
      const accessToken = await database.getAccessTokenForItem(
        item.userId,
        item.connectionId,
      );

      if (accessToken === null) {
        skipped += 1;
        continue;
      }

      try {
        const plaidResponse = await deps.fetch(
          PLAID_SANDBOX_ITEM_WEBHOOK_UPDATE_URL,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "PLAID-CLIENT-ID": clientId,
              "PLAID-SECRET": sandboxSecret,
            },
            body: JSON.stringify({
              access_token: accessToken,
              webhook: webhookUrl,
            }),
          },
        );

        if (plaidResponse.ok) {
          updated += 1;
        } else {
          failed += 1;
        }
      } catch (_) {
        failed += 1;
      }
    }

    return jsonResponse(200, {
      status: "processed",
      scanned: items.length,
      updated,
      failed,
      skipped,
    });
  };
}
