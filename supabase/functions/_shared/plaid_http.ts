import type { PlaidApiEnvironment } from "./plaid_item_health.ts";

// Bounds the whole request: connect, response headers and body.
export const PLAID_REQUEST_TIMEOUT_MS = 15_000;

// Ophir is Canada-only: every Plaid request that takes country_codes sends this.
export const PLAID_COUNTRY_CODES = ["CA"] as const;

export const plaidApiBaseUrls: Record<PlaidApiEnvironment, string> = {
  sandbox: "https://sandbox.plaid.com",
  development: "https://development.plaid.com",
  production: "https://production.plaid.com",
};

export function plaidApiUrl(
  environment: PlaidApiEnvironment,
  path: `/${string}`,
): string {
  return `${plaidApiBaseUrls[environment]}${path}`;
}

export type PlaidCredentials = {
  clientId: string;
  secret: string;
};

export type PlaidApiError = {
  operation: string;
  status: number;
  errorType: string | null;
  errorCode: string | null;
  errorMessage: string | null;
  displayMessage: string | null;
  requestId: string | null;
};

export type PlaidFailure =
  // Plaid answered with a well-formed API error.
  | { kind: "plaid_error"; error: PlaidApiError }
  // Plaid produced no response at all; whether it acted is unknown.
  | {
    kind: "transport_error";
    operation: string;
    reason: "timeout" | "network";
  }
  // A response arrived but is not a usable Plaid result.
  | {
    kind: "malformed_response";
    operation: string;
    status: number;
    requestId: string | null;
  };

export type PlaidHttpResult =
  | {
    kind: "ok";
    operation: string;
    status: number;
    payload: Record<string, unknown>;
    requestId: string | null;
  }
  | PlaidFailure;

const MAX_DIAGNOSTIC_LENGTH = 300;
const MIN_REDACTED_VALUE_LENGTH = 8;
const plaidCredentialPattern =
  /\b(?:access|public|link)-(?:sandbox|development|production)-[A-Za-z0-9-]+/g;
const redacted = "[redacted]";

export function readRecord(value: unknown): Record<string, unknown> | null {
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

function operationOf(url: string): string {
  try {
    return new URL(url).pathname;
  } catch (_) {
    return "unknown";
  }
}

function redactDiagnostic(
  value: unknown,
  sensitiveValues: readonly string[],
): string | null {
  let text = readNonEmptyString(value);
  if (text === null) {
    return null;
  }

  for (const sensitive of sensitiveValues) {
    text = text.split(sensitive).join(redacted);
  }
  text = text.replace(plaidCredentialPattern, redacted);

  return text.length > MAX_DIAGNOSTIC_LENGTH
    ? text.slice(0, MAX_DIAGNOSTIC_LENGTH)
    : text;
}

function sensitiveValuesOf(
  credentials: PlaidCredentials,
  body: Record<string, unknown>,
): string[] {
  const values = [credentials.clientId, credentials.secret];
  for (const value of Object.values(body)) {
    if (typeof value === "string") {
      values.push(value);
    }
  }
  return values.filter((value) => value.length >= MIN_REDACTED_VALUE_LENGTH);
}

type RawResponse =
  | { kind: "response"; status: number; ok: boolean; text: string }
  | { kind: "network" }
  | { kind: "timeout" };

async function readRawResponse(
  fetchImpl: typeof fetch,
  url: string,
  init: RequestInit,
  signal: AbortSignal,
): Promise<RawResponse> {
  try {
    const response = await fetchImpl(url, { ...init, signal });
    const text = await response.text();
    return {
      kind: "response",
      status: response.status,
      ok: response.ok,
      text,
    };
  } catch (_) {
    return signal.aborted ? { kind: "timeout" } : { kind: "network" };
  }
}

// The race keeps the timeout finite even when a fetch implementation ignores
// the abort signal.
async function readWithTimeout(
  fetchImpl: typeof fetch,
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<RawResponse> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timedOut = new Promise<RawResponse>((resolve) => {
    timer = setTimeout(() => {
      controller.abort();
      resolve({ kind: "timeout" });
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      readRawResponse(fetchImpl, url, init, controller.signal),
      timedOut,
    ]);
  } finally {
    clearTimeout(timer);
  }
}

// One Plaid POST. Never throws, never returns credentials or request bodies.
export async function postPlaid(params: {
  fetchImpl: typeof fetch;
  url: string;
  credentials: PlaidCredentials;
  body: Record<string, unknown>;
  timeoutMs?: number;
}): Promise<PlaidHttpResult> {
  const operation = operationOf(params.url);
  const raw = await readWithTimeout(
    params.fetchImpl,
    params.url,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": params.credentials.clientId,
        "PLAID-SECRET": params.credentials.secret,
      },
      body: JSON.stringify(params.body),
    },
    params.timeoutMs ?? PLAID_REQUEST_TIMEOUT_MS,
  );

  if (raw.kind !== "response") {
    return { kind: "transport_error", operation, reason: raw.kind };
  }

  let payload: Record<string, unknown> | null;
  try {
    payload = readRecord(JSON.parse(raw.text));
  } catch (_) {
    payload = null;
  }

  if (payload === null) {
    return {
      kind: "malformed_response",
      operation,
      status: raw.status,
      requestId: null,
    };
  }

  const requestId = readNonEmptyString(payload.request_id);
  const errorType = readNonEmptyString(payload.error_type);
  const errorCode = readNonEmptyString(payload.error_code);

  if (errorType !== null || errorCode !== null) {
    const sensitiveValues = sensitiveValuesOf(params.credentials, params.body);
    return {
      kind: "plaid_error",
      error: {
        operation,
        status: raw.status,
        errorType,
        errorCode,
        errorMessage: redactDiagnostic(payload.error_message, sensitiveValues),
        displayMessage: redactDiagnostic(
          payload.display_message,
          sensitiveValues,
        ),
        requestId,
      },
    };
  }

  if (!raw.ok) {
    return {
      kind: "malformed_response",
      operation,
      status: raw.status,
      requestId,
    };
  }

  return {
    kind: "ok",
    operation,
    status: raw.status,
    payload,
    requestId,
  };
}

// Log-safe summary of a failure: codes and identifiers only, no messages.
export function plaidFailureLogFields(
  failure: PlaidFailure,
): Record<string, string | number | null> {
  switch (failure.kind) {
    case "plaid_error":
      return {
        operation: failure.error.operation,
        failure: failure.kind,
        status: failure.error.status,
        error_type: failure.error.errorType,
        error_code: failure.error.errorCode,
        request_id: failure.error.requestId,
      };
    case "transport_error":
      return {
        operation: failure.operation,
        failure: failure.kind,
        reason: failure.reason,
      };
    case "malformed_response":
      return {
        operation: failure.operation,
        failure: failure.kind,
        status: failure.status,
        request_id: failure.requestId,
      };
  }
}
