import { createClient } from "npm:@supabase/supabase-js@2";
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

type EnqueueResult = "accepted" | "coalesced" | "ignored";

type WebhookDatabase = {
  enqueueTransactionSyncJob(
    externalPlaidItemId: string,
  ): Promise<EnqueueResult | null>;
};

type HandlerDependencies = {
  createDatabase: () => WebhookDatabase | null;
  verifyWebhook: (
    rawBody: string,
    plaidVerification: string | null,
  ) => Promise<PlaidWebhookVerificationResult>;
};

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
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

      if (error !== null || !data || typeof data !== "object") {
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
    },
  };
}

export function createPlaidWebhookHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ?? defaultCreateDatabase,
    verifyWebhook: dependencies.verifyWebhook ?? createPlaidWebhookVerifier(),
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
    if (
      webhookType !== "TRANSACTIONS" ||
      webhookCode !== "SYNC_UPDATES_AVAILABLE"
    ) {
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

    const enqueueResult = await database.enqueueTransactionSyncJob(itemId);
    if (enqueueResult === null) {
      return errorResponse(500, "enqueue_failed");
    }

    if (enqueueResult === "ignored") {
      return jsonResponse(200, { status: "ignored" });
    }

    return jsonResponse(200, { status: "accepted" });
  };
}
