import {
  normalizePlaidAccounts,
  type PlaidAccountPayload,
} from "./plaid_accounts_refresh.ts";
import type { PlaidApiEnvironment } from "./plaid_item_health.ts";
import {
  plaidApiUrl,
  type PlaidCredentials,
  type PlaidFailure,
  postPlaid,
  readRecord,
} from "./plaid_http.ts";

export type PlaidClient = {
  fetchImpl: typeof fetch;
  environment: PlaidApiEnvironment;
  credentials: PlaidCredentials;
  timeoutMs?: number;
};

export type PlaidPublicTokenExchange = {
  kind: "ok";
  accessToken: string;
  itemId: string;
  requestId: string | null;
};

// The complete /accounts/get snapshot of the Item, in Plaid's order.
export type PlaidItemAccounts = {
  kind: "ok";
  itemId: string;
  institutionId: string | null;
  institutionName: string | null;
  accounts: PlaidAccountPayload[];
  requestId: string | null;
};

export type PlaidInstitution = {
  kind: "ok";
  institutionId: string;
  name: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  url: string | null;
  requestId: string | null;
};

export type PlaidItemRemoval = {
  kind: "ok";
  requestId: string;
};

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function malformed(
  operation: string,
  status: number,
  requestId: string | null,
): PlaidFailure {
  return { kind: "malformed_response", operation, status, requestId };
}

function post(
  client: PlaidClient,
  path: `/${string}`,
  body: Record<string, unknown>,
) {
  return postPlaid({
    fetchImpl: client.fetchImpl,
    url: plaidApiUrl(client.environment, path),
    credentials: client.credentials,
    body,
    timeoutMs: client.timeoutMs,
  });
}

// The returned access token is a credential: callers must never log it.
export async function exchangePublicToken(
  client: PlaidClient,
  publicToken: string,
): Promise<PlaidPublicTokenExchange | PlaidFailure> {
  const result = await post(client, "/item/public_token/exchange", {
    public_token: publicToken,
  });
  if (result.kind !== "ok") {
    return result;
  }

  const accessToken = readNonEmptyString(result.payload.access_token);
  const itemId = readNonEmptyString(result.payload.item_id);
  if (accessToken === null || itemId === null) {
    return malformed(result.operation, result.status, result.requestId);
  }

  return { kind: "ok", accessToken, itemId, requestId: result.requestId };
}

// Fails as a whole when any account is unusable; never drops or filters
// accounts, so callers always see every account Plaid returned for the Item.
export async function getItemAccounts(
  client: PlaidClient,
  accessToken: string,
): Promise<PlaidItemAccounts | PlaidFailure> {
  const result = await post(client, "/accounts/get", {
    access_token: accessToken,
  });
  if (result.kind !== "ok") {
    return result;
  }

  const item = readRecord(result.payload.item);
  const itemId = readNonEmptyString(item?.item_id);
  const accounts = normalizePlaidAccounts(result.payload.accounts);
  if (item === null || itemId === null || accounts === null) {
    return malformed(result.operation, result.status, result.requestId);
  }

  return {
    kind: "ok",
    itemId,
    institutionId: readNonEmptyString(item.institution_id),
    institutionName: readNonEmptyString(item.institution_name),
    accounts,
    requestId: result.requestId,
  };
}

export async function getInstitutionById(
  client: PlaidClient,
  institutionId: string,
  countryCodes: readonly string[] = ["CA"],
): Promise<PlaidInstitution | PlaidFailure> {
  const result = await post(client, "/institutions/get_by_id", {
    institution_id: institutionId,
    country_codes: countryCodes,
    options: { include_optional_metadata: true },
  });
  if (result.kind !== "ok") {
    return result;
  }

  const institution = readRecord(result.payload.institution);
  if (institution === null) {
    return malformed(result.operation, result.status, result.requestId);
  }

  return {
    kind: "ok",
    institutionId,
    name: readNonEmptyString(institution.name),
    logoBase64: readNonEmptyString(institution.logo),
    primaryColor: readNonEmptyString(institution.primary_color),
    url: readNonEmptyString(institution.url),
    requestId: result.requestId,
  };
}

// Plaid answers a removal with only a request_id; a 2xx body without one is not
// a confirmed removal. A transport_error leaves the Item's state unknown.
export async function removeItem(
  client: PlaidClient,
  accessToken: string,
): Promise<PlaidItemRemoval | PlaidFailure> {
  const result = await post(client, "/item/remove", {
    access_token: accessToken,
  });
  if (result.kind !== "ok") {
    return result;
  }

  if (result.requestId === null) {
    return malformed(result.operation, result.status, result.requestId);
  }

  return { kind: "ok", requestId: result.requestId };
}
