import { createPlaidWebhookHandler } from "./handler.ts";
import {
  clearPlaidWebhookVerificationKeyCacheForTests,
  createPlaidWebhookVerifier,
} from "../_shared/plaid_webhook_verification.ts";

const validKid = "key-id";
const validJwt = "header.payload.signature";
const validRawBody =
  '{"webhook_type":"TRANSACTIONS","webhook_code":"SYNC_UPDATES_AVAILABLE","item_id":"plaid-item-id"}';

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function validKey(overrides: Record<string, unknown> = {}) {
  return {
    alg: "ES256",
    created_at: 1,
    crv: "P-256",
    expired_at: null,
    kid: validKid,
    kty: "EC",
    use: "sig",
    x: "x-coordinate",
    y: "y-coordinate",
    ...overrides,
  };
}

function createVerifierHarness(options: {
  header?: Record<string, unknown>;
  keyStatus?: number;
  key?: Record<string, unknown>;
  jwtPayload?: Record<string, unknown>;
  jwtVerifyThrows?: boolean | ((key: unknown, callCount: number) => boolean);
  now?: number;
} = {}) {
  clearPlaidWebhookVerificationKeyCacheForTests();

  let fetchCount = 0;
  let importCount = 0;
  let jwtVerifyCount = 0;
  let currentNow = options.now ?? 1_000_000;

  const verifier = createPlaidWebhookVerifier({
    decodeProtectedHeader: () =>
      options.header ?? {
        alg: "ES256",
        kid: validKid,
      },
    importJWK: async () => {
      importCount += 1;
      return `imported-key-${importCount}`;
    },
    jwtVerify: async (_jwt, key) => {
      jwtVerifyCount += 1;
      const shouldThrow = typeof options.jwtVerifyThrows === "function"
        ? options.jwtVerifyThrows(key, jwtVerifyCount)
        : options.jwtVerifyThrows;
      if (shouldThrow) {
        throw new Error("signature invalid");
      }
      return {
        payload: options.jwtPayload ?? {
          iat: Math.floor(currentNow / 1000),
          request_body_sha256: `hash:${validRawBody}`,
        },
      };
    },
    fetch: async () => {
      fetchCount += 1;
      return new Response(
        JSON.stringify({ key: options.key ?? validKey() }),
        {
          status: options.keyStatus ?? 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    },
    getEnv: (name) => {
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return "sandbox-secret";
      }
      return undefined;
    },
    now: () => currentNow,
    sha256Hex: async (value) => `hash:${value}`,
  });

  return {
    verifier,
    get fetchCount() {
      return fetchCount;
    },
    get importCount() {
      return importCount;
    },
    get jwtVerifyCount() {
      return jwtVerifyCount;
    },
    advance(ms: number) {
      currentNow += ms;
    },
  };
}

Deno.test("missing Plaid-Verification returns 401", async () => {
  const { verifier } = createVerifierHarness();

  const result = await verifier(validRawBody, null);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 401);
  }
});

Deno.test("alg other than ES256 is rejected", async () => {
  const { verifier, fetchCount } = createVerifierHarness({
    header: { alg: "HS256", kid: validKid },
  });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  assertEquals(fetchCount, 0);
});

Deno.test("missing kid is rejected", async () => {
  const { verifier, fetchCount } = createVerifierHarness({
    header: { alg: "ES256" },
  });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  assertEquals(fetchCount, 0);
});

Deno.test("key lookup failure returns 500", async () => {
  const { verifier } = createVerifierHarness({ keyStatus: 500 });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 500);
  }
});

Deno.test("wrong JWK metadata is rejected", async () => {
  const { verifier } = createVerifierHarness({
    key: validKey({ alg: "ES384" }),
  });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 401);
  }
});

Deno.test("invalid JWT signature is rejected", async () => {
  const { verifier } = createVerifierHarness({ jwtVerifyThrows: true });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 401);
  }
});

Deno.test("stale iat older than five minutes is rejected", async () => {
  const now = 1_000_000;
  const { verifier } = createVerifierHarness({
    now,
    jwtPayload: {
      iat: Math.floor(now / 1000) - 301,
      request_body_sha256: `hash:${validRawBody}`,
    },
  });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 401);
  }
});

Deno.test("body hash mismatch is rejected", async () => {
  const { verifier } = createVerifierHarness({
    jwtPayload: {
      iat: 1000,
      request_body_sha256: "different-hash",
    },
  });

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.status, 401);
  }
});

Deno.test("exact raw-body hash is accepted", async () => {
  const { verifier } = createVerifierHarness();

  const result = await verifier(validRawBody, validJwt);

  assertEquals(result.ok, true);
});

Deno.test("whitespace-modified body fails hash", async () => {
  const { verifier } = createVerifierHarness({
    jwtPayload: {
      iat: 1000,
      request_body_sha256: `hash:${validRawBody}`,
    },
  });

  const result = await verifier(`${validRawBody}\n`, validJwt);

  assertEquals(result.ok, false);
});

Deno.test("cached key is reused", async () => {
  const harness = createVerifierHarness();

  const first = await harness.verifier(validRawBody, validJwt);
  const second = await harness.verifier(validRawBody, validJwt);

  assertEquals(first.ok, true);
  assertEquals(second.ok, true);
  assertEquals(harness.fetchCount, 1);
});

Deno.test("expired cache key is refetched", async () => {
  const harness = createVerifierHarness();

  const first = await harness.verifier(validRawBody, validJwt);
  harness.advance(24 * 60 * 60 * 1000 + 1);
  const second = await harness.verifier(validRawBody, validJwt);

  assertEquals(first.ok, true);
  assertEquals(second.ok, true);
  assertEquals(harness.fetchCount, 2);
});

Deno.test("cached-key verify failure refetches once", async () => {
  const harness = createVerifierHarness({
    jwtVerifyThrows: (key, callCount) =>
      key === "imported-key-1" && callCount > 1,
  });

  const first = await harness.verifier(validRawBody, validJwt);
  const second = await harness.verifier(validRawBody, validJwt);

  assertEquals(first.ok, true);
  assertEquals(second.ok, true);
  assertEquals(harness.fetchCount, 2);
});

const healthConnectionId = "22222222-2222-4222-8222-222222222222";
const healthUserId = "11111111-1111-4111-8111-111111111111";
const healthAccessToken = "access-token-secret-value";

type ItemGetFake = { status: number; body: Record<string, unknown> };

function itemGetFake(
  error: Record<string, unknown> | null,
  consentExpirationTime: string | null = null,
): ItemGetFake {
  return {
    status: 200,
    body: {
      item: {
        item_id: "plaid-item-id",
        error,
        consent_expiration_time: consentExpirationTime,
      },
      request_id: "request-id",
    },
  };
}

function itemWebhookBody(
  webhookCode: string,
  extra: Record<string, unknown> = {},
): string {
  return JSON.stringify({
    webhook_type: "ITEM",
    webhook_code: webhookCode,
    item_id: "plaid-item-id",
    ...extra,
  });
}

function createHandlerHarness(options: {
  verificationOk?: boolean;
  rawBody?: string;
  enqueueResult?: "accepted" | "coalesced" | "ignored" | null;
  itemKnown?: boolean;
  resolveFails?: boolean;
  itemGetResponse?: ItemGetFake;
  itemGetThrows?: boolean;
  previousStatus?: "active" | "login_required";
  recordApplied?: boolean;
  recordResult?: "ok" | "not_found" | "failed";
  deadlineResult?: "applied" | "ignored" | null;
} = {}) {
  const enqueueCalls: string[] = [];
  const dbCalls: string[] = [];
  const fetchCalls: Array<{ url: string; body: Record<string, unknown> }> = [];
  const observations: Array<Record<string, unknown>> = [];
  const deadlines: Array<{ itemId: string; kind: string; at: string }> = [];
  const handler = createPlaidWebhookHandler({
    fetch: async (url, init) => {
      fetchCalls.push({
        url: String(url),
        body: JSON.parse(String(init?.body)),
      });
      if (options.itemGetThrows) {
        throw new Error("network down");
      }
      const fake = options.itemGetResponse ?? itemGetFake(null);
      return new Response(JSON.stringify(fake.body), {
        status: fake.status,
        headers: { "Content-Type": "application/json" },
      });
    },
    getEnv: (name) => {
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return "sandbox-secret";
      }
      return undefined;
    },
    now: () => new Date("2026-10-03T12:00:00.000Z"),
    verifyWebhook: async () => {
      if (options.verificationOk === false) {
        return {
          ok: false,
          status: 401,
          code: "invalid_plaid_verification",
        };
      }
      return { ok: true, kid: validKid };
    },
    createDatabase: () => ({
      async enqueueTransactionSyncJob(externalPlaidItemId) {
        enqueueCalls.push(externalPlaidItemId);
        return options.enqueueResult === undefined
          ? "accepted"
          : options.enqueueResult;
      },
      async resolveItemConnection(externalPlaidItemId) {
        dbCalls.push(`resolve:${externalPlaidItemId}`);
        if (options.resolveFails) {
          return null;
        }
        if (options.itemKnown === false) {
          return "not_found";
        }
        return { connectionId: healthConnectionId, userId: healthUserId };
      },
      async getAccessTokenForItem(userId, connectionId) {
        dbCalls.push("get_access_token");
        return userId === healthUserId && connectionId === healthConnectionId
          ? healthAccessToken
          : null;
      },
      async recordItemHealthObservation(observation) {
        dbCalls.push("record_observation");
        observations.push({ ...observation });
        if (options.recordResult === "failed") {
          return null;
        }
        if (options.recordResult === "not_found") {
          return "not_found";
        }
        const previousStatus = options.previousStatus ?? "active";
        const applied = options.recordApplied ?? true;
        return {
          applied,
          previousStatus,
          status: applied ? observation.status : previousStatus,
          plaidItemId: "plaid-item-id",
        };
      },
      async setItemAccessDeadline(itemId, kind, at) {
        dbCalls.push("set_deadline");
        deadlines.push({ itemId, kind, at });
        return options.deadlineResult === undefined
          ? "applied"
          : options.deadlineResult;
      },
    }),
  });

  const request = new Request("https://example.com", {
    method: "POST",
    headers: { "Plaid-Verification": validJwt },
    body: options.rawBody ?? validRawBody,
  });

  return {
    handler,
    request,
    enqueueCalls,
    dbCalls,
    fetchCalls,
    observations,
    deadlines,
  };
}

Deno.test("no DB call before verification success", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    verificationOk: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("verified SYNC_UPDATES_AVAILABLE enqueues once", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "accepted");
  assertEquals(enqueueCalls.length, 1);
  assertEquals(enqueueCalls[0], "plaid-item-id");
});

Deno.test("duplicate delivery coalesced still returns accepted", async () => {
  const { handler, request } = createHandlerHarness({
    enqueueResult: "coalesced",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "accepted");
});

Deno.test("unsupported verified webhook is ignored", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: JSON.stringify({
      webhook_type: "ITEM",
      webhook_code: "WEBHOOK_UPDATE_ACKNOWLEDGED",
      item_id: "plaid-item-id",
    }),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "ignored");
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("WEBHOOK_UPDATE_ACKNOWLEDGED is verified then ignored", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: JSON.stringify({
      webhook_type: "ITEM",
      webhook_code: "WEBHOOK_UPDATE_ACKNOWLEDGED",
      item_id: "plaid-item-id",
    }),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "ignored");
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("unknown Item is ignored", async () => {
  const { handler, request } = createHandlerHarness({
    enqueueResult: "ignored",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "ignored");
});

Deno.test("malformed JSON after valid signature is ignored", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: "{bad",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "ignored");
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("enqueue failure returns 500", async () => {
  const { handler, request } = createHandlerHarness({
    enqueueResult: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("fake user_id and environment in webhook are not trusted", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: JSON.stringify({
      webhook_type: "TRANSACTIONS",
      webhook_code: "SYNC_UPDATES_AVAILABLE",
      item_id: "plaid-item-id",
      user_id: "fake-user",
      environment: "production",
    }),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 1);
  assertEquals(enqueueCalls[0], "plaid-item-id");
});

Deno.test("readiness flags do not affect enqueue contract", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: JSON.stringify({
      webhook_type: "TRANSACTIONS",
      webhook_code: "SYNC_UPDATES_AVAILABLE",
      item_id: "plaid-item-id",
      initial_update_complete: true,
      historical_update_complete: true,
    }),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 1);
});

Deno.test("no secrets or raw body in responses", async () => {
  const { handler, request } = createHandlerHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(validRawBody), "response exposed raw body");
  assert(!text.includes(validJwt), "response exposed JWT");
  assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
});

Deno.test("unverified ITEM webhook does not touch DB or Plaid", async () => {
  const { handler, request, dbCalls, fetchCalls } = createHandlerHarness({
    verificationOk: false,
    rawBody: itemWebhookBody("ERROR"),
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(dbCalls.length, 0);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("ITEM ERROR is confirmed through item/get and recorded", async () => {
  const { handler, request, fetchCalls, observations, enqueueCalls } =
    createHandlerHarness({
      rawBody: itemWebhookBody("ERROR", {
        error: { error_code: "ITEM_LOGIN_REQUIRED" },
      }),
      itemGetResponse: itemGetFake({
        error_type: "ITEM_ERROR",
        error_code: "ITEM_LOGIN_REQUIRED",
        error_code_reason: "OAUTH_USER_REVOKED",
      }),
    });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assertEquals(JSON.parse(text).status, "accepted");
  assertEquals(fetchCalls.length, 1);
  assertEquals(fetchCalls[0].url, "https://sandbox.plaid.com/item/get");
  assertEquals(fetchCalls[0].body.access_token, healthAccessToken);
  assertEquals(observations.length, 1);
  assertEquals(observations[0].connectionId, healthConnectionId);
  assertEquals(observations[0].observedAt, "2026-10-03T12:00:00.000Z");
  assertEquals(observations[0].status, "login_required");
  assertEquals(observations[0].statusReason, "permission_revoked");
  assertEquals(observations[0].fromItemGet, true);
  assertEquals(observations[0].clearPendingDisconnect, false);
  assertEquals(enqueueCalls.length, 0);
  assert(!text.includes(healthAccessToken), "response exposed access token");
});

Deno.test("ITEM ERROR with healthy item/get does not mark login_required", async () => {
  const { handler, request, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    itemGetResponse: itemGetFake(null),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(observations.length, 1);
  assertEquals(observations[0].status, "active");
});

Deno.test("ITEM ERROR with non-login item error does not change health", async () => {
  const { handler, request, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    itemGetResponse: itemGetFake({
      error_type: "INSTITUTION_ERROR",
      error_code: "INSTITUTION_DOWN",
    }),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "ignored");
  assertEquals(observations.length, 0);
});

Deno.test("item/get failure returns 500 so Plaid retries", async () => {
  const { handler, request, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    itemGetResponse: {
      status: 500,
      body: { error_type: "API_ERROR", error_code: "INTERNAL_SERVER_ERROR" },
    },
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 500);
  assertEquals(JSON.parse(text).error.code, "item_health_failed");
  assertEquals(observations.length, 0);
  assert(!text.includes(healthAccessToken), "response exposed access token");
});

Deno.test("item/get network error returns 500", async () => {
  const { handler, request } = createHandlerHarness({
    rawBody: itemWebhookBody("LOGIN_REPAIRED"),
    itemGetThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("LOGIN_REPAIRED restores active via item/get and enqueues sync", async () => {
  const { handler, request, observations, enqueueCalls } =
    createHandlerHarness({
      rawBody: itemWebhookBody("LOGIN_REPAIRED"),
      itemGetResponse: itemGetFake(null),
      previousStatus: "login_required",
    });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(observations.length, 1);
  assertEquals(observations[0].status, "active");
  assertEquals(observations[0].fromItemGet, true);
  assertEquals(observations[0].clearPendingDisconnect, false);
  assertEquals(enqueueCalls.length, 1);
  assertEquals(enqueueCalls[0], "plaid-item-id");
});

Deno.test("LOGIN_REPAIRED with still-broken item/get stays login_required", async () => {
  const { handler, request, observations, enqueueCalls } =
    createHandlerHarness({
      rawBody: itemWebhookBody("LOGIN_REPAIRED"),
      itemGetResponse: itemGetFake({
        error_type: "ITEM_ERROR",
        error_code: "ITEM_LOGIN_REQUIRED",
      }),
      previousStatus: "login_required",
    });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(observations[0].status, "login_required");
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("duplicate LOGIN_REPAIRED delivery does not enqueue again", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: itemWebhookBody("LOGIN_REPAIRED"),
    itemGetResponse: itemGetFake(null),
    previousStatus: "active",
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("stale ITEM observation is acknowledged without enqueue", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: itemWebhookBody("LOGIN_REPAIRED"),
    itemGetResponse: itemGetFake(null),
    previousStatus: "login_required",
    recordApplied: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("recovery enqueue failure does not fail LOGIN_REPAIRED", async () => {
  const { handler, request, enqueueCalls } = createHandlerHarness({
    rawBody: itemWebhookBody("LOGIN_REPAIRED"),
    itemGetResponse: itemGetFake(null),
    previousStatus: "login_required",
    enqueueResult: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 1);
});

Deno.test("ITEM webhook for unknown Item is ignored without Plaid call", async () => {
  const { handler, request, fetchCalls, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    itemKnown: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "ignored");
  assertEquals(fetchCalls.length, 0);
  assertEquals(observations.length, 0);
});

Deno.test("ITEM resolve failure returns 500", async () => {
  const { handler, request, fetchCalls } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    resolveFails: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("health write failure returns 500", async () => {
  const { handler, request } = createHandlerHarness({
    rawBody: itemWebhookBody("ERROR"),
    recordResult: "failed",
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("USER_PERMISSION_REVOKED records permission_revoked without item/get", async () => {
  const { handler, request, fetchCalls, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("USER_PERMISSION_REVOKED"),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchCalls.length, 0);
  assertEquals(observations.length, 1);
  assertEquals(observations[0].status, "login_required");
  assertEquals(observations[0].statusReason, "permission_revoked");
  assertEquals(observations[0].fromItemGet, false);
  assertEquals(observations[0].consentExpiresAt, null);
  assertEquals(observations[0].clearPendingDisconnect, false);
});

Deno.test("PENDING_DISCONNECT writes only pending_disconnect deadline", async () => {
  const { handler, request, deadlines, observations, fetchCalls } =
    createHandlerHarness({
      rawBody: itemWebhookBody("PENDING_DISCONNECT", {
        reason: "INSTITUTION_MIGRATION",
        disconnect_time: "2026-10-10T00:00:00Z",
        consent_expiration_time: "2026-12-01T00:00:00Z",
      }),
    });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(deadlines.length, 1);
  assertEquals(deadlines[0].itemId, "plaid-item-id");
  assertEquals(deadlines[0].kind, "pending_disconnect");
  assertEquals(deadlines[0].at, "2026-10-10T00:00:00Z");
  assertEquals(observations.length, 0);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("PENDING_EXPIRATION writes only consent_expiration deadline", async () => {
  const { handler, request, deadlines, observations } = createHandlerHarness({
    rawBody: itemWebhookBody("PENDING_EXPIRATION", {
      consent_expiration_time: "2026-12-01T00:00:00Z",
      disconnect_time: "2026-10-10T00:00:00Z",
    }),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(deadlines.length, 1);
  assertEquals(deadlines[0].kind, "consent_expiration");
  assertEquals(deadlines[0].at, "2026-12-01T00:00:00Z");
  assertEquals(observations.length, 0);
});

Deno.test("deadline webhook without valid timestamp is ignored", async () => {
  const { handler, request, deadlines } = createHandlerHarness({
    rawBody: itemWebhookBody("PENDING_DISCONNECT", {
      disconnect_time: "not-a-date",
    }),
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "ignored");
  assertEquals(deadlines.length, 0);
});

Deno.test("deadline write failure returns 500", async () => {
  const { handler, request } = createHandlerHarness({
    rawBody: itemWebhookBody("PENDING_DISCONNECT", {
      disconnect_time: "2026-10-10T00:00:00Z",
    }),
    deadlineResult: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("deadline webhook for unknown Item is ignored", async () => {
  const { handler, request } = createHandlerHarness({
    rawBody: itemWebhookBody("PENDING_DISCONNECT", {
      disconnect_time: "2026-10-10T00:00:00Z",
    }),
    deadlineResult: "ignored",
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "ignored");
});

Deno.test("other ITEM codes are ignored without DB or Plaid calls", async () => {
  for (const code of ["NEW_ACCOUNTS_AVAILABLE", "USER_ACCOUNT_REVOKED"]) {
    const { handler, request, dbCalls, fetchCalls } = createHandlerHarness({
      rawBody: itemWebhookBody(code),
    });

    const response = await handler(request);

    assertEquals(response.status, 200);
    assertEquals((await response.json()).status, "ignored");
    assertEquals(dbCalls.length, 0);
    assertEquals(fetchCalls.length, 0);
  }
});
