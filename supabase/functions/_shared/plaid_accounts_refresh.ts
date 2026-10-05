import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.2";
import {
  isItemLoginRequiredError,
  isItemUnavailableError,
  loginRequiredObservation,
  type RecordItemHealthObservation,
} from "./plaid_item_health.ts";
import { plaidApiUrl, postPlaid } from "./plaid_http.ts";

export const PLAID_SANDBOX_ACCOUNTS_GET_URL = plaidApiUrl(
  "sandbox",
  "/accounts/get",
);
export const PLAID_SANDBOX_INSTITUTIONS_GET_BY_ID_URL = plaidApiUrl(
  "sandbox",
  "/institutions/get_by_id",
);

export type PlaidAccountPayload = {
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

export type StoredInstitution = {
  plaidInstitutionId: string | null;
  name: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  url: string | null;
};

export type PersistAccountsSyncArgs = {
  userId: string;
  connectionId: string;
  plaidInstitutionId: string | null;
  institutionName: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  institutionUrl: string | null;
  balanceFetchedAt: string;
  // When the /accounts/get request of this snapshot started; the freshness watermark.
  accountsObservedAt: string;
  accounts: PlaidAccountPayload[];
};

export type AccountsRefreshDatabase = {
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  // "disconnected": the Item was disconnected before the snapshot was written.
  // "superseded": a snapshot observed later was already accepted; nothing written.
  persistAccountsSync(
    args: PersistAccountsSyncArgs,
  ): Promise<number | "disconnected" | "superseded" | null>;
  recordItemHealthObservation: RecordItemHealthObservation;
  // null: the Item has no stored institution row yet.
  getStoredInstitution?(
    userId: string,
    connectionId: string,
  ): Promise<StoredInstitution | null | "failed">;
};

// "plaid": refresh institution metadata via /institutions/get_by_id (manual
// Sync / Connect). "stored": keep the metadata already stored for the Item so
// automatic refreshes never call /institutions/get_by_id and never clobber it.
export type InstitutionMetadataSource = "plaid" | "stored";

export type PlaidAccountsRefreshResult =
  | {
    kind: "refreshed";
    syncedAccountCount: number;
    institutionName: string | null;
  }
  | { kind: "connection_not_found" }
  | { kind: "connection_disconnected" }
  | { kind: "snapshot_superseded" }
  | { kind: "item_login_required" }
  | { kind: "item_unavailable" }
  | { kind: "plaid_request_failed" }
  | { kind: "plaid_payload_invalid" }
  | { kind: "institution_lookup_failed" }
  | { kind: "persist_failed" };

// plaid_persist_accounts_sync refuses a disconnected Item under the Item lock.
export function isPlaidItemDisconnectedRpcError(
  error: { message?: string } | null,
): boolean {
  return error?.message?.includes("plaid_item_disconnected") === true;
}

// plaid_persist_accounts_sync refuses a snapshot not newer than the Item watermark.
export function isPlaidAccountsSnapshotSupersededRpcError(
  error: { message?: string } | null,
): boolean {
  return error?.message?.includes("plaid_accounts_snapshot_superseded") === true;
}

export type PlaidCallResult =
  | { kind: "ok"; payload: Record<string, unknown> }
  | { kind: "item_login_required" }
  | { kind: "item_unavailable" }
  | { kind: "failed" };

function readRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
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

export async function callPlaid(
  fetchImpl: typeof fetch,
  url: string,
  clientId: string,
  secret: string,
  body: Record<string, unknown>,
): Promise<PlaidCallResult> {
  const result = await postPlaid({
    fetchImpl,
    url,
    credentials: { clientId, secret },
    body,
  });

  if (result.kind === "ok") {
    return { kind: "ok", payload: result.payload };
  }

  if (result.kind === "plaid_error") {
    const error = { error_code: result.error.errorCode };
    if (isItemLoginRequiredError(error)) {
      return { kind: "item_login_required" };
    }
    if (isItemUnavailableError(error)) {
      return { kind: "item_unavailable" };
    }
  }

  return { kind: "failed" };
}

export function normalizePlaidAccounts(
  accounts: unknown,
): PlaidAccountPayload[] | null {
  if (!Array.isArray(accounts)) {
    return null;
  }

  const mapped: PlaidAccountPayload[] = [];

  for (const account of accounts) {
    const record = readRecord(account);
    if (record === null) {
      return null;
    }

    const plaidAccountId = readNonEmptyString(record.account_id);
    const name = readNonEmptyString(record.name);
    const plaidType = readNonEmptyString(record.type);

    if (plaidAccountId === null || name === null || plaidType === null) {
      return null;
    }

    const balanceRecord = readRecord(record.balances);
    let currentBalance: number | null = null;
    let availableBalance: number | null = null;
    let isoCurrencyCode: string | null = null;
    let unofficialCurrencyCode: string | null = null;

    if (balanceRecord !== null) {
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

type ResolvedInstitution = {
  plaidInstitutionId: string | null;
  institutionName: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  institutionUrl: string | null;
};

async function institutionFromPlaid(params: {
  fetchImpl: typeof fetch;
  clientId: string;
  secret: string;
  plaidInstitutionId: string | null;
  itemInstitutionName: string | null;
}): Promise<ResolvedInstitution> {
  const resolved: ResolvedInstitution = {
    plaidInstitutionId: params.plaidInstitutionId,
    institutionName: params.itemInstitutionName,
    logoBase64: null,
    primaryColor: null,
    institutionUrl: null,
  };

  if (params.plaidInstitutionId === null) {
    return resolved;
  }

  const institutionResult = await callPlaid(
    params.fetchImpl,
    PLAID_SANDBOX_INSTITUTIONS_GET_BY_ID_URL,
    params.clientId,
    params.secret,
    {
      institution_id: params.plaidInstitutionId,
      country_codes: ["CA"],
      options: {
        include_optional_metadata: true,
      },
    },
  );

  if (institutionResult.kind !== "ok") {
    return resolved;
  }

  const institution = readRecord(institutionResult.payload.institution);
  if (institution === null) {
    return resolved;
  }

  return {
    plaidInstitutionId: params.plaidInstitutionId,
    institutionName: readNonEmptyString(institution.name) ??
      params.itemInstitutionName,
    logoBase64: readNonEmptyString(institution.logo),
    primaryColor: readNonEmptyString(institution.primary_color),
    institutionUrl: readNonEmptyString(institution.url),
  };
}

async function institutionFromStorage(params: {
  database: AccountsRefreshDatabase;
  userId: string;
  connectionId: string;
  plaidInstitutionId: string | null;
  itemInstitutionName: string | null;
}): Promise<ResolvedInstitution | "failed"> {
  if (params.database.getStoredInstitution === undefined) {
    return "failed";
  }

  let stored: StoredInstitution | null | "failed";
  try {
    stored = await params.database.getStoredInstitution(
      params.userId,
      params.connectionId,
    );
  } catch (_) {
    return "failed";
  }

  if (stored === "failed") {
    return "failed";
  }

  if (stored === null) {
    return {
      plaidInstitutionId: params.plaidInstitutionId,
      institutionName: params.itemInstitutionName,
      logoBase64: null,
      primaryColor: null,
      institutionUrl: null,
    };
  }

  return {
    plaidInstitutionId: stored.plaidInstitutionId ?? params.plaidInstitutionId,
    institutionName: stored.name ?? params.itemInstitutionName,
    logoBase64: stored.logoBase64,
    primaryColor: stored.primaryColor,
    institutionUrl: stored.url,
  };
}

// Fetches the full /accounts/get snapshot of one Item and persists it through
// plaid_persist_accounts_sync. The access token never leaves this function.
export async function refreshPlaidAccountsForItem(params: {
  userId: string;
  connectionId: string;
  database: AccountsRefreshDatabase;
  fetchImpl: typeof fetch;
  clientId: string;
  secret: string;
  now: () => Date;
  institutionSource: InstitutionMetadataSource;
}): Promise<PlaidAccountsRefreshResult> {
  const accessToken = await params.database.getAccessTokenForItem(
    params.userId,
    params.connectionId,
  );
  if (accessToken === null) {
    return { kind: "connection_not_found" };
  }

  // Taken once, before /accounts/get: orders this snapshot against concurrent ones.
  const accountsRequestedAt = params.now().toISOString();
  const accountsResult = await callPlaid(
    params.fetchImpl,
    PLAID_SANDBOX_ACCOUNTS_GET_URL,
    params.clientId,
    params.secret,
    { access_token: accessToken },
  );

  if (accountsResult.kind === "item_login_required") {
    const recorded = await params.database.recordItemHealthObservation(
      loginRequiredObservation(params.connectionId, accountsRequestedAt),
    );
    if (recorded === null) {
      return { kind: "persist_failed" };
    }
    if (recorded === "not_found") {
      return { kind: "connection_not_found" };
    }
    return { kind: "item_login_required" };
  }

  if (accountsResult.kind === "item_unavailable") {
    return { kind: "item_unavailable" };
  }

  if (accountsResult.kind === "failed") {
    return { kind: "plaid_request_failed" };
  }

  const item = readRecord(accountsResult.payload.item) ?? {};
  const plaidInstitutionId = readNonEmptyString(item.institution_id);
  const itemInstitutionName = readNonEmptyString(item.institution_name);

  const institution = params.institutionSource === "plaid"
    ? await institutionFromPlaid({
      fetchImpl: params.fetchImpl,
      clientId: params.clientId,
      secret: params.secret,
      plaidInstitutionId,
      itemInstitutionName,
    })
    : await institutionFromStorage({
      database: params.database,
      userId: params.userId,
      connectionId: params.connectionId,
      plaidInstitutionId,
      itemInstitutionName,
    });

  const accounts = normalizePlaidAccounts(accountsResult.payload.accounts);
  if (accounts === null) {
    return { kind: "plaid_payload_invalid" };
  }

  if (institution === "failed") {
    return { kind: "institution_lookup_failed" };
  }

  const syncedAccountCount = await params.database.persistAccountsSync({
    userId: params.userId,
    connectionId: params.connectionId,
    plaidInstitutionId: institution.plaidInstitutionId,
    institutionName: institution.institutionName,
    logoBase64: institution.logoBase64,
    primaryColor: institution.primaryColor,
    institutionUrl: institution.institutionUrl,
    balanceFetchedAt: params.now().toISOString(),
    accountsObservedAt: accountsRequestedAt,
    accounts,
  });

  if (syncedAccountCount === "disconnected") {
    return { kind: "connection_disconnected" };
  }

  if (syncedAccountCount === "superseded") {
    return { kind: "snapshot_superseded" };
  }

  if (syncedAccountCount === null) {
    return { kind: "persist_failed" };
  }

  return {
    kind: "refreshed",
    syncedAccountCount,
    institutionName: institution.institutionName,
  };
}

export async function persistAccountsSyncRpc(
  supabaseAdmin: SupabaseClient,
  args: PersistAccountsSyncArgs,
): Promise<number | "disconnected" | "superseded" | null> {
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
      p_accounts_observed_at: args.accountsObservedAt,
    },
  );

  if (error !== null) {
    if (isPlaidAccountsSnapshotSupersededRpcError(error)) {
      return "superseded";
    }
    return isPlaidItemDisconnectedRpcError(error) ? "disconnected" : null;
  }

  return typeof data === "number" ? data : null;
}

export async function readStoredInstitutionRow(
  supabaseAdmin: SupabaseClient,
  userId: string,
  connectionId: string,
): Promise<StoredInstitution | null | "failed"> {
  const { data, error } = await supabaseAdmin
    .from("institutions")
    .select("plaid_institution_id, name, logo_base64, primary_color, url")
    .eq("user_id", userId)
    .eq("plaid_item_id", connectionId)
    .maybeSingle();

  if (error !== null) {
    return "failed";
  }

  const row = readRecord(data);
  if (row === null) {
    return null;
  }

  return {
    plaidInstitutionId: readNonEmptyString(row.plaid_institution_id),
    name: readNonEmptyString(row.name),
    logoBase64: readNonEmptyString(row.logo_base64),
    primaryColor: readNonEmptyString(row.primary_color),
    url: readNonEmptyString(row.url),
  };
}
