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
import { isItemUnavailableError } from "../_shared/plaid_item_health.ts";

const PLAID_SANDBOX_LINK_TOKEN_CREATE_URL =
  "https://sandbox.plaid.com/link/token/create";

const PLAID_CLIENT_NAME = "Ophir";
const PLAID_COUNTRY_CODES = ["CA"] as const;
const PLAID_PRODUCTS = ["transactions"] as const;
const TRANSACTIONS_DAYS_REQUESTED = 730;

const PLAID_LINK_LANGUAGES = new Set([
  "da",
  "nl",
  "en",
  "et",
  "fr",
  "de",
  "hi",
  "it",
  "lv",
  "lt",
  "no",
  "pl",
  "pt",
  "ro",
  "es",
  "sv",
  "vi",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type LinkTokenDatabase = {
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => LinkTokenDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
};

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): LinkTokenDatabase | null {
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
  };
}

// undefined: initial Link; null: malformed connection_id.
function readUpdateConnectionId(
  body: Record<string, unknown>,
): string | null | undefined {
  if (!("connection_id" in body)) {
    return undefined;
  }

  const connectionId = body.connection_id;
  if (typeof connectionId !== "string") {
    return null;
  }

  const trimmed = connectionId.trim();
  return uuidPattern.test(trimmed) ? trimmed.toLowerCase() : null;
}

function normalizePlaidLanguage(appLocale: string): string {
  const primary = appLocale.trim().toLowerCase().split(/[-_]/)[0];

  if (primary.length === 0) {
    return "en";
  }

  return PLAID_LINK_LANGUAGES.has(primary) ? primary : "en";
}

function readAppLocale(body: Record<string, unknown>): string | null {
  const locale = body.locale;
  if (typeof locale === "string" && locale.trim().length > 0) {
    return locale;
  }

  return null;
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

export function createPlaidCreateLinkTokenHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(deps.getEnv)),
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

    const appLocale = readAppLocale(body);
    if (appLocale === null) {
      return errorResponse(400, "invalid_request");
    }

    const updateConnectionId = readUpdateConnectionId(body);
    if (updateConnectionId === null) {
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

    const language = normalizePlaidLanguage(appLocale);
    let linkTokenRequest: Record<string, unknown>;

    if (updateConnectionId === undefined) {
      const webhookUrl = readWebhookUrl(deps.getEnv);
      if (webhookUrl === null) {
        return errorResponse(500, "plaid_webhook_config_missing");
      }

      linkTokenRequest = {
        client_name: PLAID_CLIENT_NAME,
        language,
        country_codes: PLAID_COUNTRY_CODES,
        products: PLAID_PRODUCTS,
        webhook: webhookUrl,
        transactions: {
          days_requested: TRANSACTIONS_DAYS_REQUESTED,
        },
        user: {
          client_user_id: user.id,
        },
      };
    } else {
      const database = deps.createDatabase();
      if (database === null) {
        return errorResponse(500, "config_missing");
      }

      const accessToken = await database.getAccessTokenForItem(
        user.id,
        updateConnectionId,
      );
      if (accessToken === null) {
        return errorResponse(404, "connection_not_found");
      }

      // Update mode: Plaid derives products and webhook from the existing Item.
      linkTokenRequest = {
        client_name: PLAID_CLIENT_NAME,
        language,
        country_codes: PLAID_COUNTRY_CODES,
        user: {
          client_user_id: user.id,
        },
        access_token: accessToken,
      };
    }

    let plaidResponse: Response;

    try {
      plaidResponse = await deps.fetch(PLAID_SANDBOX_LINK_TOKEN_CREATE_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "PLAID-CLIENT-ID": clientId,
          "PLAID-SECRET": sandboxSecret,
        },
        body: JSON.stringify(linkTokenRequest),
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
      return updateConnectionId !== undefined &&
          isItemUnavailableError(plaidPayload)
        ? errorResponse(409, "reconnect_unavailable")
        : errorResponse(502, "plaid_request_failed");
    }

    const linkToken = plaidPayload.link_token;
    const expiration = plaidPayload.expiration;

    if (
      typeof linkToken !== "string" ||
      linkToken.length === 0 ||
      typeof expiration !== "string" ||
      expiration.length === 0
    ) {
      return errorResponse(502, "plaid_request_failed");
    }

    if (updateConnectionId !== undefined) {
      return jsonResponse(200, {
        link_token: linkToken,
        expiration,
        mode: "update",
      });
    }

    return jsonResponse(200, {
      link_token: linkToken,
      expiration,
    });
  };
}
