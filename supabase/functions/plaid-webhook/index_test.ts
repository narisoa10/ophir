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

function createHandlerHarness(options: {
  verificationOk?: boolean;
  rawBody?: string;
  enqueueResult?: "accepted" | "coalesced" | "ignored" | null;
} = {}) {
  const enqueueCalls: string[] = [];
  const handler = createPlaidWebhookHandler({
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
    }),
  });

  const request = new Request("https://example.com", {
    method: "POST",
    headers: { "Plaid-Verification": validJwt },
    body: options.rawBody ?? validRawBody,
  });

  return { handler, request, enqueueCalls };
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
