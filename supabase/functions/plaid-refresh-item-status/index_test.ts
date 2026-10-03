import { createPlaidRefreshItemStatusHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const otherUserId = "44444444-4444-4444-8444-444444444444";
const connectionId = "22222222-2222-4222-8222-222222222222";
const accessToken = "access-token-secret-value";
const sandboxSecret = "sandbox-secret-value";

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

type FakeResponse = { status: number; body: Record<string, unknown> };

function itemGet(
  error: Record<string, unknown> | null,
  consentExpirationTime: string | null = null,
): FakeResponse {
  return {
    status: 200,
    body: {
      item: { item_id: "plaid-item-id", error, consent_expiration_time: consentExpirationTime },
      request_id: "request-id",
    },
  };
}

function createHarness(options: {
  authenticatedUserId?: string | null;
  requestBody?: Record<string, unknown>;
  environment?: "sandbox" | "development" | "production" | null;
  itemGetResponse?: FakeResponse;
  previousStatus?: "active" | "login_required";
  recordResult?: "ok" | "not_found" | "failed";
  enqueueThrows?: boolean;
} = {}) {
  const calls: string[] = [];
  const fetchCalls: Array<{ url: string; body: Record<string, unknown> }> = [];
  const observations: Array<Record<string, unknown>> = [];
  const enqueueCalls: string[] = [];
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const previousStatus = options.previousStatus ?? "login_required";
  let storedStatus: string = previousStatus;
  let storedReason: string | null = previousStatus === "login_required"
    ? "login_required"
    : null;

  const handler = createPlaidRefreshItemStatusHandler({
    authenticateRequest: async () =>
      authenticatedUserId === null ? null : { id: authenticatedUserId },
    createDatabase: () => ({
      async getItemEnvironment(receivedUserId, receivedConnectionId) {
        calls.push("get_environment");
        if (receivedUserId !== userId || receivedConnectionId !== connectionId) {
          return "not_found";
        }
        return options.environment === undefined ? "sandbox" : options.environment;
      },
      async getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        calls.push("get_access_token");
        return receivedUserId === userId && receivedConnectionId === connectionId
          ? accessToken
          : null;
      },
      async recordItemHealthObservation(observation) {
        calls.push("record_observation");
        observations.push({ ...observation });
        if (options.recordResult === "failed") {
          return null;
        }
        if (options.recordResult === "not_found") {
          return "not_found";
        }
        storedStatus = observation.status;
        storedReason = observation.statusReason;
        return {
          applied: true,
          previousStatus,
          status: observation.status,
          plaidItemId: "plaid-item-id",
        };
      },
      async getItemHealth() {
        calls.push("get_item_health");
        return {
          status: storedStatus as "active" | "login_required",
          statusReason: storedReason as
            | "login_required"
            | "consent_expired"
            | "permission_revoked"
            | null,
        };
      },
      async enqueueTransactionSyncJob(externalPlaidItemId) {
        enqueueCalls.push(externalPlaidItemId);
        if (options.enqueueThrows) {
          throw new Error("enqueue failed");
        }
      },
    }),
    fetch: async (url, init) => {
      fetchCalls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      const fake = options.itemGetResponse ?? itemGet(null);
      return new Response(JSON.stringify(fake.body), { status: fake.status });
    },
    getEnv: (name) => {
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return sandboxSecret;
      }
      return undefined;
    },
    now: () => new Date("2026-10-03T12:00:00.000Z"),
  });

  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify(options.requestBody ?? { connection_id: connectionId }),
  });

  return { handler, request, calls, fetchCalls, observations, enqueueCalls };
}

Deno.test("auth required", async () => {
  const { handler, request, calls, fetchCalls } = createHarness({
    authenticatedUserId: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("invalid connection_id is rejected", async () => {
  const { handler, request, calls } = createHarness({
    requestBody: { connection_id: "not-a-uuid" },
  });

  const response = await handler(request);

  assertEquals(response.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("another user's Item returns 404 without token or Plaid call", async () => {
  const { handler, request, calls, fetchCalls } = createHarness({
    authenticatedUserId: otherUserId,
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals((await response.json()).error.code, "connection_not_found");
  assertEquals(calls.includes("get_access_token"), false);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("unknown connection returns 404", async () => {
  const { handler, calls } = createHarness();
  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ connection_id: "55555555-5555-4555-8555-555555555555" }),
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("get_access_token"), false);
});

Deno.test("healthy item/get after repair restores active and clears pending disconnect", async () => {
  const { handler, request, fetchCalls, observations, enqueueCalls } =
    createHarness({ itemGetResponse: itemGet(null, "2027-01-01T00:00:00Z") });

  const response = await handler(request);
  const text = await response.text();
  const body = JSON.parse(text);

  assertEquals(response.status, 200);
  assertEquals(body.status, "active");
  assertEquals(body.status_reason, null);
  assertEquals(fetchCalls.length, 1);
  assertEquals(fetchCalls[0].url, "https://sandbox.plaid.com/item/get");
  assertEquals(observations.length, 1);
  assertEquals(observations[0].observedAt, "2026-10-03T12:00:00.000Z");
  assertEquals(observations[0].status, "active");
  assertEquals(observations[0].fromItemGet, true);
  assertEquals(observations[0].consentExpiresAt, "2027-01-01T00:00:00Z");
  assertEquals(observations[0].clearPendingDisconnect, true);
  assertEquals(enqueueCalls.length, 1);
  assertEquals(enqueueCalls[0], "plaid-item-id");
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(sandboxSecret), "response exposed Plaid secret");
});

Deno.test("already active Item does not enqueue", async () => {
  const { handler, request, enqueueCalls } = createHarness({
    previousStatus: "active",
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("still broken Item stays login_required and keeps pending disconnect", async () => {
  const { handler, request, observations, enqueueCalls } = createHarness({
    itemGetResponse: itemGet({
      error_code: "ITEM_LOGIN_REQUIRED",
      error_code_reason: "OAUTH_CONSENT_EXPIRED",
    }),
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "login_required");
  assertEquals(body.status_reason, "consent_expired");
  assertEquals(observations[0].clearPendingDisconnect, false);
  assertEquals(enqueueCalls.length, 0);
});

Deno.test("unavailable Item returns reconnect_unavailable without health write", async () => {
  const { handler, request, observations } = createHarness({
    itemGetResponse: { status: 400, body: { error_code: "ITEM_NOT_FOUND" } },
  });

  const response = await handler(request);

  assertEquals(response.status, 409);
  assertEquals((await response.json()).error.code, "reconnect_unavailable");
  assertEquals(observations.length, 0);
});

Deno.test("item/get failure or other Item error returns 502 without health write", async () => {
  for (
    const fake of [
      { status: 500, body: { error_code: "INTERNAL_SERVER_ERROR" } },
      itemGet({ error_code: "INSTITUTION_DOWN" }),
    ]
  ) {
    const { handler, request, observations } = createHarness({
      itemGetResponse: fake,
    });

    const response = await handler(request);
    const text = await response.text();

    assertEquals(response.status, 502);
    assertEquals(observations.length, 0);
    assert(!text.includes(accessToken), "response exposed access token");
  }
});

Deno.test("health write failure returns 500", async () => {
  const { handler, request } = createHarness({ recordResult: "failed" });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("enqueue failure does not fail refresh", async () => {
  const { handler, request, enqueueCalls } = createHarness({
    enqueueThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(enqueueCalls.length, 1);
});

Deno.test("missing environment secret fails closed before token read", async () => {
  const { handler, request, calls, fetchCalls } = createHarness({
    environment: "production",
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(calls.includes("get_access_token"), false);
  assertEquals(fetchCalls.length, 0);
});
