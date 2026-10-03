import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type PlaidApiEnvironment = "sandbox" | "development" | "production";

export type ItemHealthStatus = "active" | "login_required";

export type ItemHealthReason =
  | "login_required"
  | "consent_expired"
  | "permission_revoked";

export type ItemHealthObservation = {
  connectionId: string;
  observedAt: string;
  status: ItemHealthStatus;
  statusReason: ItemHealthReason | null;
  fromItemGet: boolean;
  consentExpiresAt: string | null;
  clearPendingDisconnect: boolean;
};

export type ItemHealthObservationResult = {
  applied: boolean;
  previousStatus: ItemHealthStatus;
  status: ItemHealthStatus;
  plaidItemId: string;
};

export type RecordItemHealthObservation = (
  observation: ItemHealthObservation,
) => Promise<ItemHealthObservationResult | "not_found" | null>;

export type ItemGetHealth =
  | { kind: "healthy"; consentExpiresAt: string | null }
  | {
    kind: "login_required";
    reason: ItemHealthReason;
    consentExpiresAt: string | null;
  }
  | { kind: "other_item_error" }
  | { kind: "item_unavailable" }
  | { kind: "failed" };

export const plaidItemGetUrls: Record<PlaidApiEnvironment, string> = {
  sandbox: "https://sandbox.plaid.com/item/get",
  development: "https://development.plaid.com/item/get",
  production: "https://production.plaid.com/item/get",
};

export const plaidSecretEnvNames: Record<PlaidApiEnvironment, string> = {
  sandbox: "PLAID_SANDBOX_SECRET",
  development: "PLAID_DEVELOPMENT_SECRET",
  production: "PLAID_PRODUCTION_SECRET",
};

export function readPlaidApiEnvironment(
  value: unknown,
): PlaidApiEnvironment | null {
  return value === "sandbox" || value === "development" ||
      value === "production"
    ? value
    : null;
}

const itemLoginRequiredCode = "ITEM_LOGIN_REQUIRED";

// Plaid errors after which the stored access_token cannot be used for the Item
// any more; update mode cannot repair them.
const itemUnavailableCodes = new Set(["ITEM_NOT_FOUND", "INVALID_ACCESS_TOKEN"]);

function readRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

export function readPlaidErrorCode(payload: unknown): string | null {
  const errorCode = readRecord(payload)?.error_code;
  return typeof errorCode === "string" && errorCode.length > 0
    ? errorCode
    : null;
}

export function isItemLoginRequiredError(payload: unknown): boolean {
  return readPlaidErrorCode(payload) === itemLoginRequiredCode;
}

export function isItemUnavailableError(payload: unknown): boolean {
  const errorCode = readPlaidErrorCode(payload);
  return errorCode !== null && itemUnavailableCodes.has(errorCode);
}

export function loginRequiredObservation(
  connectionId: string,
  observedAt: string,
): ItemHealthObservation {
  return {
    connectionId,
    observedAt,
    status: "login_required",
    statusReason: "login_required",
    fromItemGet: false,
    consentExpiresAt: null,
    clearPendingDisconnect: false,
  };
}

function readReason(errorCodeReason: unknown): ItemHealthReason {
  if (errorCodeReason === "OAUTH_CONSENT_EXPIRED") {
    return "consent_expired";
  }
  if (errorCodeReason === "OAUTH_USER_REVOKED") {
    return "permission_revoked";
  }
  return "login_required";
}

function readConsentExpiration(value: unknown): string | null | "invalid" {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    return "invalid";
  }
  return value;
}

export function readItemGetHealth(payload: unknown): ItemGetHealth {
  const item = readRecord(readRecord(payload)?.item);
  if (item === null) {
    return { kind: "failed" };
  }

  const consentExpiresAt = readConsentExpiration(item.consent_expiration_time);
  if (consentExpiresAt === "invalid") {
    return { kind: "failed" };
  }

  if (item.error === undefined || item.error === null) {
    return { kind: "healthy", consentExpiresAt };
  }

  const itemError = readRecord(item.error);
  if (itemError === null) {
    return { kind: "failed" };
  }

  if (itemError.error_code === itemLoginRequiredCode) {
    return {
      kind: "login_required",
      reason: readReason(itemError.error_code_reason),
      consentExpiresAt,
    };
  }

  return { kind: "other_item_error" };
}

export async function fetchItemGetHealth(
  fetchImpl: typeof fetch,
  params: {
    url: string;
    clientId: string;
    secret: string;
    accessToken: string;
  },
): Promise<ItemGetHealth> {
  let response: Response;
  try {
    response = await fetchImpl(params.url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": params.clientId,
        "PLAID-SECRET": params.secret,
      },
      body: JSON.stringify({ access_token: params.accessToken }),
    });
  } catch (_) {
    return { kind: "failed" };
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch (_) {
    return { kind: "failed" };
  }

  if (!response.ok) {
    return isItemUnavailableError(payload)
      ? { kind: "item_unavailable" }
      : { kind: "failed" };
  }

  return readItemGetHealth(payload);
}

// Only healthy and login-required /item/get results change Ophir health; other
// Item errors (institution outages and similar) leave the stored state as is.
export function observationFromItemGet(
  connectionId: string,
  observedAt: string,
  health: ItemGetHealth,
  clearPendingDisconnect: boolean,
): ItemHealthObservation | null {
  if (health.kind === "healthy") {
    return {
      connectionId,
      observedAt,
      status: "active",
      statusReason: null,
      fromItemGet: true,
      consentExpiresAt: health.consentExpiresAt,
      clearPendingDisconnect,
    };
  }

  if (health.kind === "login_required") {
    return {
      connectionId,
      observedAt,
      status: "login_required",
      statusReason: health.reason,
      fromItemGet: true,
      consentExpiresAt: health.consentExpiresAt,
      clearPendingDisconnect: false,
    };
  }

  return null;
}

export function becameActive(
  result: ItemHealthObservationResult | "not_found" | null,
): result is ItemHealthObservationResult {
  return result !== null &&
    result !== "not_found" &&
    result.applied &&
    result.previousStatus === "login_required" &&
    result.status === "active";
}

function readStatus(value: unknown): ItemHealthStatus | null {
  return value === "active" || value === "login_required" ? value : null;
}

export async function recordItemHealthObservationRpc(
  supabaseAdmin: SupabaseClient,
  observation: ItemHealthObservation,
): Promise<ItemHealthObservationResult | "not_found" | null> {
  const { data, error } = await supabaseAdmin.rpc(
    "plaid_record_item_status_observation",
    {
      p_connection_id: observation.connectionId,
      p_observed_at: observation.observedAt,
      p_status: observation.status,
      p_status_reason: observation.statusReason,
      p_from_item_get: observation.fromItemGet,
      p_consent_expires_at: observation.consentExpiresAt,
      p_clear_pending_disconnect: observation.clearPendingDisconnect,
    },
  );

  if (error !== null) {
    return null;
  }
  if (data === null) {
    return "not_found";
  }

  const result = readRecord(data);
  const previousStatus = readStatus(result?.previous_status);
  const status = readStatus(result?.status);
  if (
    result === null ||
    typeof result.applied !== "boolean" ||
    previousStatus === null ||
    status === null ||
    typeof result.plaid_item_id !== "string"
  ) {
    return null;
  }

  return {
    applied: result.applied,
    previousStatus,
    status,
    plaidItemId: result.plaid_item_id,
  };
}
