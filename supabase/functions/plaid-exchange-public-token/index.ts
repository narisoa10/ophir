import { createClient } from "npm:@supabase/supabase-js@2";
import { authenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";

const PLAID_SANDBOX_PUBLIC_TOKEN_EXCHANGE_URL =
  "https://sandbox.plaid.com/item/public_token/exchange";

function readPublicToken(body: Record<string, unknown>): string | null {
  const publicToken = body.public_token;
  if (typeof publicToken === "string" && publicToken.trim().length > 0) {
    return publicToken.trim();
  }

  return null;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  if (request.method !== "POST") {
    return methodNotAllowed();
  }

  const user = await authenticateRequest(request);
  if (user === null) {
    return errorResponse(401, "unauthorized");
  }

  const body = await readJsonObject(request);
  if (body === null) {
    return errorResponse(400, "invalid_request");
  }

  const publicToken = readPublicToken(body);
  if (publicToken === null) {
    return errorResponse(400, "invalid_request");
  }

  const clientId = Deno.env.get("PLAID_CLIENT_ID");
  const sandboxSecret = Deno.env.get("PLAID_SANDBOX_SECRET");

  if (
    typeof clientId !== "string" ||
    clientId.length === 0 ||
    typeof sandboxSecret !== "string" ||
    sandboxSecret.length === 0
  ) {
    return errorResponse(500, "plaid_config_missing");
  }

  let plaidResponse: Response;

  try {
    plaidResponse = await fetch(PLAID_SANDBOX_PUBLIC_TOKEN_EXCHANGE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": sandboxSecret,
      },
      body: JSON.stringify({
        public_token: publicToken,
      }),
    });
  } catch (_) {
    return errorResponse(502, "plaid_request_failed");
  }

  let plaidPayload: Record<string, unknown>;

  try {
    const parsed = await plaidResponse.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return errorResponse(502, "plaid_request_failed");
    }
    plaidPayload = parsed as Record<string, unknown>;
  } catch (_) {
    return errorResponse(502, "plaid_request_failed");
  }

  if (!plaidResponse.ok) {
    return errorResponse(502, "plaid_request_failed");
  }

  const accessToken = plaidPayload.access_token;
  const itemId = plaidPayload.item_id;

  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    typeof itemId !== "string" ||
    itemId.length === 0
  ) {
    return errorResponse(502, "plaid_request_failed");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return errorResponse(500, "supabase_config_missing");
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: connectionId, error: persistError } = await supabaseAdmin.rpc(
    "plaid_persist_sandbox_item",
    {
      p_user_id: user.id,
      p_plaid_item_id: itemId,
      p_access_token: accessToken,
    },
  );

  if (
    persistError !== null ||
    typeof connectionId !== "string" ||
    connectionId.length === 0
  ) {
    return errorResponse(500, "persist_failed");
  }

  return jsonResponse(200, {
    connection_id: connectionId,
  });
});
