import { createClient } from "npm:@supabase/supabase-js@2";
import { authenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";

const PLAID_SANDBOX_ACCOUNTS_GET_URL =
  "https://sandbox.plaid.com/accounts/get";
const PLAID_SANDBOX_INSTITUTIONS_GET_BY_ID_URL =
  "https://sandbox.plaid.com/institutions/get_by_id";

type PlaidAccountPayload = {
  plaid_account_id: string;
  name: string;
  official_name: string | null;
  mask: string | null;
  plaid_type: string;
  plaid_subtype: string | null;
  currency_code: string | null;
  unofficial_currency_code: string | null;
  current_balance: number | null;
  available_balance: number | null;
};

function readConnectionId(body: Record<string, unknown>): string | null {
  const connectionId = body.connection_id;
  if (typeof connectionId === "string" && connectionId.trim().length > 0) {
    return connectionId.trim();
  }

  return null;
}

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readNullableNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function readIsoCurrencyCode(value: unknown): string | null {
  const iso = readNonEmptyString(value);
  if (iso === null || iso.length !== 3) {
    return null;
  }

  return iso.toUpperCase();
}

function readUnofficialCurrencyCode(value: unknown): string | null {
  return readNonEmptyString(value);
}

async function callPlaid(
  url: string,
  clientId: string,
  secret: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  let response: Response;

  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": secret,
      },
      body: JSON.stringify(body),
    });
  } catch (_) {
    return null;
  }

  let payload: Record<string, unknown>;

  try {
    const parsed = await response.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }
    payload = parsed as Record<string, unknown>;
  } catch (_) {
    return null;
  }

  if (!response.ok) {
    return null;
  }

  return payload;
}

function normalizePlaidAccounts(accounts: unknown): PlaidAccountPayload[] | null {
  if (!Array.isArray(accounts)) {
    return null;
  }

  const mapped: PlaidAccountPayload[] = [];

  for (const account of accounts) {
    if (!account || typeof account !== "object" || Array.isArray(account)) {
      return null;
    }

    const record = account as Record<string, unknown>;
    const plaidAccountId = readNonEmptyString(record.account_id);
    const name = readNonEmptyString(record.name);
    const plaidType = readNonEmptyString(record.type);

    if (plaidAccountId === null || name === null || plaidType === null) {
      return null;
    }

    const balances = record.balances;
    let currentBalance: number | null = null;
    let availableBalance: number | null = null;
    let isoCurrencyCode: string | null = null;
    let unofficialCurrencyCode: string | null = null;

    if (balances && typeof balances === "object" && !Array.isArray(balances)) {
      const balanceRecord = balances as Record<string, unknown>;
      currentBalance = readNullableNumber(balanceRecord.current);
      availableBalance = readNullableNumber(balanceRecord.available);
      isoCurrencyCode = readIsoCurrencyCode(balanceRecord.iso_currency_code);
      unofficialCurrencyCode = readUnofficialCurrencyCode(
        balanceRecord.unofficial_currency_code,
      );
    }

    if (isoCurrencyCode === null && unofficialCurrencyCode === null) {
      return null;
    }

    mapped.push({
      plaid_account_id: plaidAccountId,
      name,
      official_name: readNonEmptyString(record.official_name),
      mask: readNonEmptyString(record.mask),
      plaid_type: plaidType,
      plaid_subtype: readNonEmptyString(record.subtype),
      currency_code: isoCurrencyCode,
      unofficial_currency_code: unofficialCurrencyCode,
      current_balance: currentBalance,
      available_balance: availableBalance,
    });
  }

  return mapped;
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

  const connectionId = readConnectionId(body);
  if (connectionId === null) {
    return errorResponse(400, "invalid_request");
  }

  const clientId = Deno.env.get("PLAID_CLIENT_ID");
  const sandboxSecret = Deno.env.get("PLAID_SANDBOX_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (
    typeof clientId !== "string" ||
    clientId.length === 0 ||
    typeof sandboxSecret !== "string" ||
    sandboxSecret.length === 0 ||
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return errorResponse(500, "config_missing");
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: accessToken, error: accessTokenError } = await supabaseAdmin
    .rpc("plaid_get_access_token_for_item", {
      p_user_id: user.id,
      p_connection_id: connectionId,
    });

  if (
    accessTokenError !== null ||
    typeof accessToken !== "string" ||
    accessToken.length === 0
  ) {
    return errorResponse(404, "connection_not_found");
  }

  const accountsPayload = await callPlaid(
    PLAID_SANDBOX_ACCOUNTS_GET_URL,
    clientId,
    sandboxSecret,
    { access_token: accessToken },
  );

  if (accountsPayload === null) {
    return errorResponse(502, "plaid_request_failed");
  }

  const item = accountsPayload.item;
  const itemRecord = item && typeof item === "object" && !Array.isArray(item)
    ? item as Record<string, unknown>
    : {};

  const plaidInstitutionId = readNonEmptyString(itemRecord.institution_id);
  let institutionName = readNonEmptyString(itemRecord.institution_name);
  let logoBase64: string | null = null;
  let primaryColor: string | null = null;
  let institutionUrl: string | null = null;

  if (plaidInstitutionId !== null) {
    const institutionPayload = await callPlaid(
      PLAID_SANDBOX_INSTITUTIONS_GET_BY_ID_URL,
      clientId,
      sandboxSecret,
      {
        institution_id: plaidInstitutionId,
        country_codes: ["CA"],
        options: {
          include_optional_metadata: true,
        },
      },
    );

    if (institutionPayload !== null) {
      const institution = institutionPayload.institution;
      if (
        institution &&
        typeof institution === "object" &&
        !Array.isArray(institution)
      ) {
        const institutionRecord = institution as Record<string, unknown>;
        const institutionApiName = readNonEmptyString(institutionRecord.name);
        institutionName = institutionApiName ?? institutionName;
        logoBase64 = readNonEmptyString(institutionRecord.logo);
        primaryColor = readNonEmptyString(institutionRecord.primary_color);
        institutionUrl = readNonEmptyString(institutionRecord.url);
      }
    }
  }

  const mappedAccounts = normalizePlaidAccounts(accountsPayload.accounts);
  if (mappedAccounts === null) {
    return errorResponse(502, "plaid_payload_invalid");
  }

  const balanceFetchedAt = new Date().toISOString();

  const { data: syncedAccountCount, error: persistError } = await supabaseAdmin
    .rpc("plaid_persist_accounts_sync", {
      p_user_id: user.id,
      p_connection_id: connectionId,
      p_plaid_institution_id: plaidInstitutionId,
      p_institution_name: institutionName,
      p_logo_base64: logoBase64,
      p_primary_color: primaryColor,
      p_url: institutionUrl,
      p_balance_fetched_at: balanceFetchedAt,
      p_accounts: mappedAccounts,
    });

  if (persistError !== null || typeof syncedAccountCount !== "number") {
    return errorResponse(500, "persist_failed");
  }

  return jsonResponse(200, {
    synced_account_count: syncedAccountCount,
    institution_name: institutionName,
  });
});
