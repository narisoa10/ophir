import { createPlaidSandboxItemHealthToolsHandler } from "./handler.ts";

const internalSecret = "internal-secret-value";
const sandboxSecret = "sandbox-secret-value";
const connectionId = "22222222-2222-4222-8222-222222222222";
const userId = "11111111-1111-4111-8111-111111111111";
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

function createHarness(options: {
  secretHeader?: string | null;
  requestBody?: Record<string, unknown>;
  plaidEnvironment?: string | null;
  plaidStatus?: number;
} = {}) {
  const calls: string[] = [];
  const fetchCalls: Array<{ url: string; body: Record<string, unknown> }> = [];
  const logs: string[] = [];
  const originalLog = console.log;
  const originalError = console.error;

  const handler = createPlaidSandboxItemHealthToolsHandler({
    createDatabase: () => ({
      async getPlaidItemByConnectionId(receivedConnectionId) {
        calls.push("get_item");
        if (
          options.plaidEnvironment === null ||
          receivedConnectionId !== connectionId
        ) {
          return null;
        }
        return {
          id: connectionId,
          user_id: userId,
          plaid_environment: options.plaidEnvironment ?? "sandbox",
        };
      },
      async getAccessTokenForItem() {
        calls.push("get_access_token");
        return accessToken;
      },
    }),
    fetch: async (url, init) => {
      fetchCalls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return new Response(
        JSON.stringify({ request_id: "request-id", webhook_fired: true }),
        { status: options.plaidStatus ?? 200 },
      );
    },
    getEnv: (name) => {
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return internalSecret;
      }
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return sandboxSecret;
      }
      return undefined;
    },
  });

  const headers: Record<string, string> = {};
  const secretHeader = options.secretHeader === undefined
    ? internalSecret
    : options.secretHeader;
  if (secretHeader !== null) {
    headers["x-ophir-internal-secret"] = secretHeader;
  }

  const request = new Request("https://example.com", {
    method: "POST",
    headers,
    body: JSON.stringify(
      options.requestBody ?? { connection_id: connectionId, action: "reset_login" },
    ),
  });

  const run = async () => {
    console.log = (...args: unknown[]) => logs.push(args.join(" "));
    console.error = (...args: unknown[]) => logs.push(args.join(" "));
    try {
      return await handler(request);
    } finally {
      console.log = originalLog;
      console.error = originalError;
    }
  };

  return { run, calls, fetchCalls, logs };
}

Deno.test("missing or wrong internal secret returns 401 before DB access", async () => {
  for (const secretHeader of [null, "wrong-secret"]) {
    const { run, calls, fetchCalls } = createHarness({ secretHeader });

    const response = await run();

    assertEquals(response.status, 401);
    assertEquals(calls.length, 0);
    assertEquals(fetchCalls.length, 0);
  }
});

Deno.test("reset_login on sandbox Item calls only sandbox reset_login", async () => {
  const { run, calls, fetchCalls } = createHarness();

  const response = await run();
  const text = await response.text();
  const body = JSON.parse(text);

  assertEquals(response.status, 200);
  assertEquals(body.status, "ok");
  assertEquals(body.action, "reset_login");
  assertEquals(calls.join(","), "get_item,get_access_token");
  assertEquals(fetchCalls.length, 1);
  assertEquals(fetchCalls[0].url, "https://sandbox.plaid.com/sandbox/item/reset_login");
  assertEquals(fetchCalls[0].body.access_token, accessToken);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(connectionId), "response exposed connection id");
});

Deno.test("fire_item_webhook sends whitelisted ITEM code to sandbox fire_webhook", async () => {
  for (
    const code of ["LOGIN_REPAIRED", "PENDING_DISCONNECT", "USER_PERMISSION_REVOKED"]
  ) {
    const { run, fetchCalls } = createHarness({
      requestBody: {
        connection_id: connectionId,
        action: "fire_item_webhook",
        webhook_code: code,
      },
    });

    const response = await run();

    assertEquals(response.status, 200);
    assertEquals((await response.json()).action, "fire_item_webhook");
    assertEquals(fetchCalls[0].url, "https://sandbox.plaid.com/sandbox/item/fire_webhook");
    assertEquals(fetchCalls[0].body.webhook_type, "ITEM");
    assertEquals(fetchCalls[0].body.webhook_code, code);
  }
});

Deno.test("development and production Items are rejected before token read", async () => {
  for (const plaidEnvironment of ["development", "production", "unknown"]) {
    const { run, calls, fetchCalls } = createHarness({ plaidEnvironment });

    const response = await run();

    assertEquals(response.status, 403);
    assertEquals((await response.json()).error.code, "environment_not_allowed");
    assertEquals(calls.includes("get_access_token"), false);
    assertEquals(fetchCalls.length, 0);
  }
});

Deno.test("unknown connection returns 404 without token read", async () => {
  const { run, calls, fetchCalls } = createHarness({ plaidEnvironment: null });

  const response = await run();

  assertEquals(response.status, 404);
  assertEquals(calls.includes("get_access_token"), false);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("invalid action, code or connection_id is rejected before DB access", async () => {
  const bodies: Array<Record<string, unknown>> = [
    { connection_id: connectionId, action: "delete_item" },
    { connection_id: connectionId, action: "fire_item_webhook" },
    { connection_id: connectionId, action: "fire_item_webhook", webhook_code: "ERROR" },
    { connection_id: connectionId, action: "fire_item_webhook", webhook_code: "PENDING_EXPIRATION" },
    { connection_id: connectionId, action: "fire_item_webhook", webhook_code: "SYNC_UPDATES_AVAILABLE" },
    { connection_id: "not-a-uuid", action: "reset_login" },
    { action: "reset_login" },
  ];

  for (const requestBody of bodies) {
    const { run, calls, fetchCalls } = createHarness({ requestBody });

    const response = await run();

    assertEquals(response.status, 400);
    assertEquals(calls.length, 0);
    assertEquals(fetchCalls.length, 0);
  }
});

Deno.test("Plaid failure returns 502 without leaking token", async () => {
  const { run, logs } = createHarness({ plaidStatus: 400 });

  const response = await run();
  const text = await response.text();

  assertEquals(response.status, 502);
  for (const output of [text, ...logs]) {
    assert(!output.includes(accessToken), "output exposed access token");
    assert(!output.includes(sandboxSecret), "output exposed Plaid secret");
  }
});
