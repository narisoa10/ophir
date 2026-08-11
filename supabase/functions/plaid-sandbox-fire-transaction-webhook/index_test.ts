import { createPlaidSandboxFireTransactionWebhookHandler } from "./handler.ts";

const internalSecret = "internal-secret-value";
const sandboxSecret = "sandbox-secret-value";
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

function createHarness(options: {
  secretHeader?: string | null;
  body?: Record<string, unknown>;
  accessTokenExists?: boolean;
} = {}) {
  const listCalls: Array<{ batchSize: number; offset: number }> = [];
  const fetchBodies: Array<Record<string, unknown>> = [];

  const handler = createPlaidSandboxFireTransactionWebhookHandler({
    createDatabase: () => ({
      async listSandboxItems(batchSize, offset) {
        listCalls.push({ batchSize, offset });
        return [{ connectionId, userId }];
      },
      async getAccessTokenForItem() {
        return options.accessTokenExists === false ? null : accessToken;
      },
    }),
    fetch: async (_url, init) => {
      fetchBodies.push(JSON.parse(String(init?.body)));
      return new Response(
        JSON.stringify({ webhook_fired: true, request_id: "request-id" }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
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

  const headers = new Headers();
  if (options.secretHeader !== null) {
    headers.set(
      "x-ophir-internal-secret",
      options.secretHeader ?? internalSecret,
    );
  }

  const request = new Request("https://example.com", {
    method: "POST",
    headers,
    body: JSON.stringify(options.body ?? {}),
  });

  return { handler, request, listCalls, fetchBodies };
}

Deno.test("internal auth is required", async () => {
  const { handler, request, listCalls } = createHarness({
    secretHeader: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(listCalls.length, 0);
});

Deno.test("fires fixed transactions sync webhook", async () => {
  const { handler, request, fetchBodies } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.fired, 1);
  assertEquals(fetchBodies[0].webhook_type, "TRANSACTIONS");
  assertEquals(fetchBodies[0].webhook_code, "SYNC_UPDATES_AVAILABLE");
  assertEquals(fetchBodies[0].access_token, accessToken);
});

Deno.test("request cannot override sandbox webhook payload", async () => {
  const { handler, request, fetchBodies } = createHarness({
    body: {
      access_token: "attacker-token",
      webhook_type: "ITEM",
      webhook_code: "ERROR",
      batch_size: 1,
      offset: 0,
    },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].access_token, accessToken);
  assertEquals(fetchBodies[0].webhook_type, "TRANSACTIONS");
  assertEquals(fetchBodies[0].webhook_code, "SYNC_UPDATES_AVAILABLE");
});

Deno.test("batch controls are bounded", async () => {
  const { handler, request, listCalls } = createHarness({
    body: { batch_size: 1, offset: 2 },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(listCalls[0].batchSize, 1);
  assertEquals(listCalls[0].offset, 2);
});

Deno.test("missing local token skips item without calling Plaid", async () => {
  const { handler, request, fetchBodies } = createHarness({
    accessTokenExists: false,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.skipped, 1);
  assertEquals(fetchBodies.length, 0);
});

Deno.test("response does not expose access token or secrets", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(sandboxSecret), "response exposed Plaid secret");
  assert(!text.includes(connectionId), "response exposed connection id");
  assert(!text.includes(userId), "response exposed user id");
});
