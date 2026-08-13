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

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type ConfirmRpcResult = {
  status: string;
  reconciliation_id?: string;
  transfer_operation_id?: string | null;
  reason?: string;
};

type ConfirmDatabase = {
  confirmInternalTransferCandidate(
    userId: string,
    reconciliationId: string,
  ): Promise<{ data: ConfirmRpcResult | null; errorMessage: string | null }>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => ConfirmDatabase | null;
};

function readReconciliationId(body: Record<string, unknown>): string | null {
  const value = body.reconciliation_id;
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return uuidPattern.test(trimmed) ? trimmed : null;
}

function mapRpcException(message: string): Response {
  const lower = message.toLowerCase();

  if (lower.includes("reconciliation_not_found")) {
    return errorResponse(404, "not_found");
  }
  if (lower.includes("reversed")) {
    return errorResponse(409, "reversed");
  }
  if (lower.includes("invalid_state")) {
    return errorResponse(409, "invalid_state");
  }
  if (
    lower.includes("invalid_input") || lower.includes("operation_not_found")
  ) {
    return errorResponse(400, "invalid_request");
  }
  if (lower.includes("stale_candidate")) {
    return errorResponse(409, "stale_candidate");
  }

  return errorResponse(500, "internal_error");
}

function defaultCreateDatabase(): ConfirmDatabase | null {
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
    async confirmInternalTransferCandidate(userId, reconciliationId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_confirm_internal_transfer_candidate",
        {
          p_user_id: userId,
          p_reconciliation_id: reconciliationId,
        },
      );

      if (error !== null) {
        return {
          data: null,
          errorMessage: typeof error.message === "string"
            ? error.message
            : "rpc_failed",
        };
      }

      if (!data || typeof data !== "object" || Array.isArray(data)) {
        return { data: null, errorMessage: "invalid_rpc_payload" };
      }

      const row = data as Record<string, unknown>;
      const status = row.status;
      if (typeof status !== "string" || status.length === 0) {
        return { data: null, errorMessage: "invalid_rpc_payload" };
      }

      return {
        data: {
          status,
          reconciliation_id: typeof row.reconciliation_id === "string"
            ? row.reconciliation_id
            : undefined,
          transfer_operation_id: typeof row.transfer_operation_id === "string"
            ? row.transfer_operation_id
            : row.transfer_operation_id === null
            ? null
            : undefined,
          reason: typeof row.reason === "string" ? row.reason : undefined,
        },
        errorMessage: null,
      };
    },
  };
}

export function createPlaidConfirmInternalTransferHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ?? defaultCreateDatabase,
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

    const reconciliationId = readReconciliationId(body);
    if (reconciliationId === null) {
      return errorResponse(400, "invalid_request");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    // Forged body.user_id is intentionally ignored; JWT user.id is authoritative.
    const { data, errorMessage } = await database
      .confirmInternalTransferCandidate(
        user.id,
        reconciliationId,
      );

    if (errorMessage !== null) {
      return mapRpcException(errorMessage);
    }

    if (data === null) {
      return errorResponse(500, "internal_error");
    }

    if (data.status === "rejected" && data.reason === "stale_candidate") {
      return errorResponse(409, "stale_candidate");
    }

    if (data.status === "confirmed" || data.status === "already_confirmed") {
      if (
        typeof data.reconciliation_id !== "string" ||
        typeof data.transfer_operation_id !== "string"
      ) {
        return errorResponse(500, "internal_error");
      }

      return jsonResponse(200, {
        status: data.status,
        reconciliation_id: data.reconciliation_id,
        transfer_operation_id: data.transfer_operation_id,
      });
    }

    return errorResponse(500, "internal_error");
  };
}
