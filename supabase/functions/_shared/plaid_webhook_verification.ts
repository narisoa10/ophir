import {
  decodeProtectedHeader as defaultDecodeProtectedHeader,
  importJWK as defaultImportJWK,
  type JWK,
  jwtVerify as defaultJwtVerify,
  type JWTVerifyOptions,
} from "npm:jose";

type PlaidVerificationKey = {
  alg: string;
  crv: string;
  expired_at: number | null;
  kid: string;
  kty: string;
  use?: string;
  x: string;
  y: string;
};

type CachedKey = {
  importedKey: unknown;
  expiresAtMs: number;
  plaidExpiredAtMs: number | null;
};

type VerificationDependencies = {
  decodeProtectedHeader: (jwt: string) => Record<string, unknown>;
  importJWK: (jwk: Record<string, unknown>, alg: string) => Promise<unknown>;
  jwtVerify: (
    jwt: string,
    key: unknown,
    options: Record<string, unknown>,
  ) => Promise<{ payload: Record<string, unknown> }>;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  now: () => number;
  sha256Hex: (value: string) => Promise<string>;
};

export type PlaidWebhookVerificationResult =
  | { ok: true; kid: string }
  | { ok: false; status: 401 | 500; code: string };

const PLAID_SANDBOX_WEBHOOK_VERIFICATION_KEY_GET_URL =
  "https://sandbox.plaid.com/webhook_verification_key/get";

const cacheTtlMs = 24 * 60 * 60 * 1000;
const maxWebhookAgeSeconds = 5 * 60;
const futureIatToleranceSeconds = 60;

const keyCache = new Map<string, CachedKey>();

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEquals(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false;
  }

  let diff = 0;
  for (let index = 0; index < left.length; index += 1) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }

  return diff === 0;
}

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeVerificationKey(
  value: unknown,
  expectedKid: string,
  nowMs: number,
): PlaidVerificationKey | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const record = value as Record<string, unknown>;
  const kid = readNonEmptyString(record.kid);
  const alg = readNonEmptyString(record.alg);
  const kty = readNonEmptyString(record.kty);
  const crv = readNonEmptyString(record.crv);
  const use = readNonEmptyString(record.use);
  const x = readNonEmptyString(record.x);
  const y = readNonEmptyString(record.y);
  const expiredAt = record.expired_at;

  if (
    kid !== expectedKid ||
    alg !== "ES256" ||
    kty !== "EC" ||
    crv !== "P-256" ||
    (use !== null && use !== "sig") ||
    x === null ||
    y === null ||
    !(expiredAt === null || typeof expiredAt === "number")
  ) {
    return null;
  }

  if (typeof expiredAt === "number" && expiredAt * 1000 <= nowMs) {
    return null;
  }

  return {
    alg,
    crv,
    expired_at: expiredAt,
    kid,
    kty,
    use: use ?? undefined,
    x,
    y,
  };
}

function isCachedKeyUsable(cached: CachedKey, nowMs: number): boolean {
  if (cached.expiresAtMs <= nowMs) {
    return false;
  }

  return cached.plaidExpiredAtMs === null || cached.plaidExpiredAtMs > nowMs;
}

async function fetchVerificationKey(
  kid: string,
  deps: VerificationDependencies,
): Promise<
  { kind: "ok"; key: CachedKey } | { kind: "invalid" } | {
    kind: "failed";
  }
> {
  const clientId = deps.getEnv("PLAID_CLIENT_ID");
  const sandboxSecret = deps.getEnv("PLAID_SANDBOX_SECRET");

  if (
    typeof clientId !== "string" ||
    clientId.length === 0 ||
    typeof sandboxSecret !== "string" ||
    sandboxSecret.length === 0
  ) {
    return { kind: "failed" };
  }

  let response: Response;
  try {
    response = await deps.fetch(
      PLAID_SANDBOX_WEBHOOK_VERIFICATION_KEY_GET_URL,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "PLAID-CLIENT-ID": clientId,
          "PLAID-SECRET": sandboxSecret,
        },
        body: JSON.stringify({ key_id: kid }),
      },
    );
  } catch (_) {
    return { kind: "failed" };
  }

  if (!response.ok) {
    return { kind: "failed" };
  }

  let payload: Record<string, unknown>;
  try {
    const parsed = await response.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return { kind: "failed" };
    }
    payload = parsed as Record<string, unknown>;
  } catch (_) {
    return { kind: "failed" };
  }

  const nowMs = deps.now();
  const key = normalizeVerificationKey(payload.key, kid, nowMs);
  if (key === null) {
    return { kind: "invalid" };
  }

  let importedKey: unknown;
  try {
    importedKey = await deps.importJWK(key, "ES256");
  } catch (_) {
    return { kind: "invalid" };
  }

  const plaidExpiredAtMs = key.expired_at === null
    ? null
    : key.expired_at * 1000;
  const cacheExpiresAtMs = Math.min(
    nowMs + cacheTtlMs,
    plaidExpiredAtMs ?? Number.POSITIVE_INFINITY,
  );

  return {
    kind: "ok",
    key: {
      importedKey,
      expiresAtMs: cacheExpiresAtMs,
      plaidExpiredAtMs,
    },
  };
}

async function getKey(
  kid: string,
  deps: VerificationDependencies,
  forceRefresh: boolean,
): Promise<
  { kind: "ok"; key: CachedKey; fromCache: boolean } | {
    kind: "invalid";
  } | { kind: "failed" }
> {
  const nowMs = deps.now();
  const cached = keyCache.get(kid);
  if (!forceRefresh && cached && isCachedKeyUsable(cached, nowMs)) {
    return { kind: "ok", key: cached, fromCache: true };
  }

  keyCache.delete(kid);
  const fetched = await fetchVerificationKey(kid, deps);
  if (fetched.kind !== "ok") {
    return fetched;
  }

  keyCache.set(kid, fetched.key);
  return { kind: "ok", key: fetched.key, fromCache: false };
}

function validateIssuedAt(
  value: unknown,
  nowMs: number,
): boolean {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return false;
  }

  const nowSeconds = Math.floor(nowMs / 1000);
  if (value > nowSeconds + futureIatToleranceSeconds) {
    return false;
  }

  return nowSeconds - value <= maxWebhookAgeSeconds;
}

async function verifySignatureWithKey(
  jwt: string,
  key: unknown,
  deps: VerificationDependencies,
): Promise<Record<string, unknown> | null> {
  try {
    const { payload } = await deps.jwtVerify(jwt, key, {
      algorithms: ["ES256"],
    });
    return payload;
  } catch (_) {
    return null;
  }
}

export function clearPlaidWebhookVerificationKeyCacheForTests(): void {
  keyCache.clear();
}

export function createPlaidWebhookVerifier(
  dependencies: Partial<VerificationDependencies> = {},
): (rawBody: string, plaidVerification: string | null) => Promise<
  PlaidWebhookVerificationResult
> {
  const deps: VerificationDependencies = {
    decodeProtectedHeader: dependencies.decodeProtectedHeader ??
      ((jwt) => defaultDecodeProtectedHeader(jwt) as Record<string, unknown>),
    importJWK: dependencies.importJWK ??
      ((jwk, alg) => defaultImportJWK(jwk as JWK, alg)),
    jwtVerify: dependencies.jwtVerify ??
      ((jwt, key, options) =>
        defaultJwtVerify(
          jwt,
          key as CryptoKey,
          options as JWTVerifyOptions,
        ) as Promise<{
          payload: Record<string, unknown>;
        }>),
    fetch: dependencies.fetch ?? fetch,
    getEnv: dependencies.getEnv ??
      ((name) => Deno.env.get(name) ?? undefined),
    now: dependencies.now ?? (() => Date.now()),
    sha256Hex: dependencies.sha256Hex ?? sha256Hex,
  };

  return async (
    rawBody: string,
    plaidVerification: string | null,
  ): Promise<PlaidWebhookVerificationResult> => {
    const jwt = readNonEmptyString(plaidVerification);
    if (jwt === null) {
      return { ok: false, status: 401, code: "missing_plaid_verification" };
    }

    let header: Record<string, unknown>;
    try {
      header = deps.decodeProtectedHeader(jwt);
    } catch (_) {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    if (header.alg !== "ES256") {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    const kid = readNonEmptyString(header.kid);
    if (kid === null) {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    let keyResult = await getKey(kid, deps, false);
    if (keyResult.kind === "failed") {
      return { ok: false, status: 500, code: "plaid_key_lookup_failed" };
    }
    if (keyResult.kind === "invalid") {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    let payload = await verifySignatureWithKey(
      jwt,
      keyResult.key.importedKey,
      deps,
    );
    if (payload === null && keyResult.fromCache) {
      keyResult = await getKey(kid, deps, true);
      if (keyResult.kind === "failed") {
        return { ok: false, status: 500, code: "plaid_key_lookup_failed" };
      }
      if (keyResult.kind === "invalid") {
        return { ok: false, status: 401, code: "invalid_plaid_verification" };
      }
      payload = await verifySignatureWithKey(
        jwt,
        keyResult.key.importedKey,
        deps,
      );
    }

    if (payload === null) {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    if (!validateIssuedAt(payload.iat, deps.now())) {
      return { ok: false, status: 401, code: "stale_plaid_verification" };
    }

    const expectedHash = readNonEmptyString(payload.request_body_sha256);
    if (expectedHash === null) {
      return { ok: false, status: 401, code: "invalid_plaid_verification" };
    }

    const actualHash = await deps.sha256Hex(rawBody);
    if (!constantTimeEquals(actualHash, expectedHash)) {
      return { ok: false, status: 401, code: "invalid_body_hash" };
    }

    return { ok: true, kid };
  };
}
