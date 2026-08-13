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
import {
  createPlaidTransactionsSyncDatabase,
  syncPlaidTransactionsForConnection,
} from "../plaid-sync-transactions/handler.ts";

const PLAID_SANDBOX_ACCOUNTS_GET_URL = "https://sandbox.plaid.com/accounts/get";
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
  persistent_account_id: string | null;
};

type AccountSyncDatabase = {
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  persistAccountsSync(args: {
    userId: string;
    connectionId: string;
    plaidInstitutionId: string | null;
    institutionName: string | null;
    logoBase64: string | null;
    primaryColor: string | null;
    institutionUrl: string | null;
    balanceFetchedAt: string;
    accounts: PlaidAccountPayload[];
  }): Promise<number | null>;
};

type TransactionBootstrapStatus = "synced" | "deferred";

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => AccountSyncDatabase | null;
  bootstrapTransactions: (
    userId: string,
    connectionId: string,
  ) => Promise<TransactionBootstrapStatus>;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
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
  fetchImpl: typeof fetch,
  url: string,
  clientId: string,
  secret: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  let response: Response;

  try {
    response = await fetchImpl(url, {
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

function normalizePlaidAccounts(
  accounts: unknown,
): PlaidAccountPayload[] | null {
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
      persistent_account_id: readNonEmptyString(record.persistent_account_id),
    });
  }

  return mapped;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): AccountSyncDatabase | null {
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

    async persistAccountsSync(args) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_persist_accounts_sync",
        {
          p_user_id: args.userId,
          p_connection_id: args.connectionId,
          p_plaid_institution_id: args.plaidInstitutionId,
          p_institution_name: args.institutionName,
          p_logo_base64: args.logoBase64,
          p_primary_color: args.primaryColor,
          p_url: args.institutionUrl,
          p_balance_fetched_at: args.balanceFetchedAt,
          p_accounts: args.accounts,
        },
      );

      if (error !== null || typeof data !== "number") {
        return null;
      }

      return data;
    },
  };
}

function createDefaultTransactionBootstrap(
  fetchImpl: typeof fetch,
  getEnv: (name: string) => string | undefined,
): (
  userId: string,
  connectionId: string,
) => Promise<TransactionBootstrapStatus> {
  return async (userId, connectionId) => {
    const database = createPlaidTransactionsSyncDatabase(getEnv);
    if (database === null) {
      return "deferred";
    }

    const result = await syncPlaidTransactionsForConnection({
      userId,
      connectionId,
      database,
      fetchImpl,
      getEnv,
      ownerToken: crypto.randomUUID(),
    });

    return result.kind === "synced" ? "synced" : "deferred";
  };
}

export function createPlaidSyncAccountsHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const fetchImpl = dependencies.fetch ?? fetch;
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    bootstrapTransactions: dependencies.bootstrapTransactions ??
      createDefaultTransactionBootstrap(fetchImpl, getEnv),
    fetch: fetchImpl,
    getEnv,
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

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    const sandboxSecret = deps.getEnv("PLAID_SANDBOX_SECRET");

    if (
      typeof clientId !== "string" ||
      clientId.length === 0 ||
      typeof sandboxSecret !== "string" ||
      sandboxSecret.length === 0
    ) {
      return errorResponse(500, "config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "config_missing");
    }

    const accessToken = await database.getAccessTokenForItem(
      user.id,
      connectionId,
    );

    if (accessToken === null) {
      return errorResponse(404, "connection_not_found");
    }

    const accountsPayload = await callPlaid(
      deps.fetch,
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
        deps.fetch,
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
    const syncedAccountCount = await database.persistAccountsSync({
      userId: user.id,
      connectionId,
      plaidInstitutionId,
      institutionName,
      logoBase64,
      primaryColor,
      institutionUrl,
      balanceFetchedAt,
      accounts: mappedAccounts,
    });

    if (syncedAccountCount === null) {
      return errorResponse(500, "persist_failed");
    }

    let transactionsBootstrapStatus: TransactionBootstrapStatus = "deferred";
    try {
      transactionsBootstrapStatus = await deps.bootstrapTransactions(
        user.id,
        connectionId,
      );
    } catch (_) {
      transactionsBootstrapStatus = "deferred";
    }

    return jsonResponse(200, {
      synced_account_count: syncedAccountCount,
      institution_name: institutionName,
      transactions_bootstrap_status: transactionsBootstrapStatus,
    });
  };
}
