import { authenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";

const PLAID_SANDBOX_LINK_TOKEN_CREATE_URL =
  "https://sandbox.plaid.com/link/token/create";

const PLAID_CLIENT_NAME = "Ophir";
const PLAID_COUNTRY_CODES = ["CA"] as const;
const PLAID_PRODUCTS = ["transactions"] as const;

// https://plaid.com/docs/api/link/#linktokencreate — Supported languages
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

  const appLocale = readAppLocale(body);
  if (appLocale === null) {
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

  const language = normalizePlaidLanguage(appLocale);

  let plaidResponse: Response;

  try {
    plaidResponse = await fetch(PLAID_SANDBOX_LINK_TOKEN_CREATE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": sandboxSecret,
      },
      body: JSON.stringify({
        client_name: PLAID_CLIENT_NAME,
        language,
        country_codes: PLAID_COUNTRY_CODES,
        products: PLAID_PRODUCTS,
        user: {
          client_user_id: user.id,
        },
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

  return jsonResponse(200, {
    link_token: linkToken,
    expiration,
  });
});
