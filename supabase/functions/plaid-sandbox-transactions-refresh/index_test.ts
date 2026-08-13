import { createPlaidSandboxTransactionsRefreshHandler } from "./handler.ts";

const internalSecret = "internal-secret-value";
const sandboxSecret = "sandbox-secret-value";
const clientId = "client-id-value";
const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const accessToken = "access-token-secret-value";

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

type ItemResult =
  | {
    id: string;
    user_id: string;
    plaid_environment: string;
  }
  | null
  | "lookup_failed";

function createHarness(options: {
  method?: string;
  secretHeader?: string | null;
  body?: Record<string, unknown> | null;
  item?: ItemResult;
  accessToken?: string | null;
  plaidStatus?: number;
  plaidBody?: Record<string, unknown>;
  getEnvOverrides?: Record<string, string | undefined>;
  fetchShouldThrow?: boolean;
} = {}) {
  const fetchCalls: Array<{
    url: string;
    headers: Headers;
    body: Record<string, unknown>;
  }> = [];
  let accessTokenCalls = 0;

  const handler = createPlaidSandboxTransactionsRefreshHandler({
    createDatabase: () => ({
      async getPlaidItemByConnectionId() {
        return options.item === undefined
          ? {
            id: connectionId,
            user_id: userId,
            plaid_environment: "sandbox",
          }
          : options.item;
      },
      async getAccessTokenForItem() {
        accessTokenCalls += 1;
        if (options.accessToken === null) {
          return null;
        }
        return options.accessToken ?? accessToken;
      },
    }),
    fetch: async (url, init) => {
      if (options.fetchShouldThrow) {
        throw new Error("network_failed");
      }

      const headers = new Headers(init?.headers);
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      fetchCalls.push({
        url: String(url),
        headers,
        body,
      });

      return new Response(
        JSON.stringify(
          options.plaidBody ?? {
            request_id: "plaid-request-id",
          },
        ),
        {
          status: options.plaidStatus ?? 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    },
    getEnv: (name) => {
      if (options.getEnvOverrides && name in options.getEnvOverrides) {
        return options.getEnvOverrides[name];
      }
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return internalSecret;
      }
      if (name === "PLAID_CLIENT_ID") {
        return clientId;
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return sandboxSecret;
      }
      return undefined;
    },
  });

  const headers = new Headers();
  if (options.secretHeader !== null) {
    headers.set(
      "x-ophir-internal-secret",
      options.secretHeader ?? internalSecret,
    );
  }

  const method = options.method ?? "POST";
  const requestInit: RequestInit = {
    method,
    headers,
  };
  if (method !== "GET" && method !== "HEAD") {
    requestInit.body = options.body === null ? "not-json" : JSON.stringify(
      options.body ?? {
        connection_id: connectionId,
      },
    );
  }

  const request = new Request("https://example.com", requestInit);

  return {
    handler,
    request,
    fetchCalls,
    getAccessTokenCalls: () => accessTokenCalls,
  };
}

Deno.test("missing internal secret returns 401", async () => {
  const { handler, request, fetchCalls } = createHarness({
    secretHeader: null,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error.code, "unauthorized");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("wrong internal secret returns 401", async () => {
  const { handler, request, fetchCalls } = createHarness({
    secretHeader: "wrong-secret",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error.code, "unauthorized");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("non-POST is rejected", async () => {
  const { handler, request, fetchCalls } = createHarness({
    method: "GET",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 405);
  assertEquals(body.error.code, "method_not_allowed");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("missing connection_id returns invalid_request", async () => {
  const { handler, request, fetchCalls } = createHarness({
    body: {},
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error.code, "invalid_request");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("invalid connection_id returns invalid_request", async () => {
  const { handler, request, fetchCalls } = createHarness({
    body: { connection_id: "not-a-uuid" },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error.code, "invalid_request");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("missing item returns not_found", async () => {
  const { handler, request, fetchCalls } = createHarness({
    item: null,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 404);
  assertEquals(body.error.code, "not_found");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("non-sandbox item returns sandbox_only", async () => {
  const { handler, request, fetchCalls } = createHarness({
    item: {
      id: connectionId,
      user_id: userId,
      plaid_environment: "production",
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 403);
  assertEquals(body.error.code, "sandbox_only");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("missing PLAID_CLIENT_ID returns plaid_config_missing", async () => {
  const { handler, request, fetchCalls } = createHarness({
    getEnvOverrides: {
      PLAID_CLIENT_ID: undefined,
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error.code, "plaid_config_missing");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("missing PLAID_SANDBOX_SECRET returns plaid_config_missing", async () => {
  const { handler, request, fetchCalls } = createHarness({
    getEnvOverrides: {
      PLAID_SANDBOX_SECRET: undefined,
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error.code, "plaid_config_missing");
  assertEquals(fetchCalls.length, 0);
});

Deno.test("access-token failure does not call Plaid", async () => {
  const harness = createHarness({
    accessToken: null,
  });

  const response = await harness.handler(harness.request);
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error.code, "access_token_unavailable");
  assertEquals(harness.fetchCalls.length, 0);
  assertEquals(harness.getAccessTokenCalls(), 1);
});

Deno.test("happy path refreshes sandbox transactions safely", async () => {
  const { handler, request, fetchCalls } = createHarness();

  const response = await handler(request);
  const body = await response.json();
  const text = JSON.stringify(body);

  assertEquals(response.status, 200);
  assertEquals(body.status, "refreshed");
  assertEquals(body.connection_id, connectionId);
  assertEquals(body.request_id, "plaid-request-id");
  assertEquals(fetchCalls.length, 1);
  assertEquals(
    fetchCalls[0].url,
    "https://sandbox.plaid.com/transactions/refresh",
  );
  assertEquals(fetchCalls[0].body.access_token, accessToken);
  assertEquals(fetchCalls[0].headers.get("PLAID-CLIENT-ID"), clientId);
  assertEquals(fetchCalls[0].headers.get("PLAID-SECRET"), sandboxSecret);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(sandboxSecret), "response exposed Plaid secret");
  assert(!text.includes(clientId), "response exposed Plaid client id");
  assert(!text.includes(internalSecret), "response exposed internal secret");
  assert(!text.includes(userId), "response exposed user id");
});

Deno.test("Plaid non-2xx returns plaid_request_failed", async () => {
  const { handler, request, fetchCalls } = createHarness({
    plaidStatus: 400,
    plaidBody: {
      error_code: "INVALID_ACCESS_TOKEN",
      error_message: "should not leak",
      request_id: "failed-request-id",
    },
  });

  const response = await handler(request);
  const body = await response.json();
  const text = JSON.stringify(body);

  assertEquals(response.status, 502);
  assertEquals(body.error.code, "plaid_request_failed");
  assertEquals(fetchCalls.length, 1);
  assert(!text.includes("should not leak"), "response leaked Plaid error body");
  assert(
    !text.includes("failed-request-id"),
    "response leaked failed request id",
  );
});

Deno.test("Plaid request_id is safely propagated", async () => {
  const { handler, request } = createHarness({
    plaidBody: { request_id: "safe-request-id-123" },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.request_id, "safe-request-id-123");
});

Deno.test("caller cannot override user_id or Plaid URL inputs", async () => {
  const { handler, request, fetchCalls } = createHarness({
    body: {
      connection_id: connectionId,
      user_id: "99999999-9999-4999-8999-999999999999",
      access_token: "attacker-token",
      environment: "production",
    },
    item: {
      id: connectionId,
      user_id: userId,
      plaid_environment: "sandbox",
    },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchCalls.length, 1);
  assertEquals(fetchCalls[0].body.access_token, accessToken);
  assertEquals(
    fetchCalls[0].url,
    "https://sandbox.plaid.com/transactions/refresh",
  );
});
