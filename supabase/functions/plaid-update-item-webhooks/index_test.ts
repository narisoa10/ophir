import { createPlaidUpdateItemWebhooksHandler } from "./handler.ts";

const internalSecret = "internal-secret-value";
const sandboxSecret = "sandbox-secret-value";
const webhookUrl =
  "https://example-project.supabase.co/functions/v1/plaid-webhook";
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
  webhookUrl?: string | null;
  items?: Array<{ connectionId: string; userId: string }>;
  accessTokenExists?: boolean;
  plaidStatuses?: number[];
  body?: Record<string, unknown>;
} = {}) {
  const listCalls: Array<{ batchSize: number; offset: number }> = [];
  const tokenCalls: Array<{ userId: string; connectionId: string }> = [];
  const fetchBodies: Array<Record<string, unknown>> = [];
  const plaidStatuses = [...(options.plaidStatuses ?? [200])];
  const items = options.items ?? [{ connectionId, userId }];

  const handler = createPlaidUpdateItemWebhooksHandler({
    createDatabase: () => ({
      async listSandboxItems(batchSize, offset) {
        listCalls.push({ batchSize, offset });
        return items;
      },
      async getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        tokenCalls.push({
          userId: receivedUserId,
          connectionId: receivedConnectionId,
        });
        return options.accessTokenExists === false ? null : accessToken;
      },
    }),
    fetch: async (_url, init) => {
      fetchBodies.push(JSON.parse(String(init?.body)));
      const status = plaidStatuses.length === 0 ? 200 : plaidStatuses.shift()!;
      return new Response(JSON.stringify({ request_id: "request-id" }), {
        status,
        headers: { "Content-Type": "application/json" },
      });
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
      if (name === "PLAID_WEBHOOK_URL") {
        return options.webhookUrl === undefined
          ? webhookUrl
          : options.webhookUrl ?? undefined;
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

  return { handler, request, listCalls, tokenCalls, fetchBodies };
}

Deno.test("internal auth is required", async () => {
  const { handler, request, listCalls } = createHarness({
    secretHeader: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(listCalls.length, 0);
});

Deno.test("batch controls are bounded", async () => {
  const { handler, request, listCalls } = createHarness({
    body: { batch_size: 2, offset: 3 },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(listCalls[0].batchSize, 2);
  assertEquals(listCalls[0].offset, 3);
});

Deno.test("webhook URL comes only from environment", async () => {
  const { handler, request, fetchBodies } = createHarness({
    body: {
      webhook: "https://attacker.example/webhook",
      access_token: "attacker-token",
    },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].webhook, webhookUrl);
  assertEquals(fetchBodies[0].access_token, accessToken);
});

Deno.test("missing webhook URL fails closed", async () => {
  const { handler, request, fetchBodies } = createHarness({
    webhookUrl: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(fetchBodies.length, 0);
});

Deno.test("one item failure does not stop the batch", async () => {
  const secondConnectionId = "33333333-3333-4333-8333-333333333333";
  const { handler, request, fetchBodies } = createHarness({
    items: [
      { connectionId, userId },
      { connectionId: secondConnectionId, userId },
    ],
    plaidStatuses: [500, 200],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(fetchBodies.length, 2);
  assertEquals(body.failed, 1);
  assertEquals(body.updated, 1);
});

Deno.test("missing local token skips item without calling Plaid", async () => {
  const { handler, request, fetchBodies } = createHarness({
    accessTokenExists: false,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(fetchBodies.length, 0);
  assertEquals(body.skipped, 1);
});

Deno.test("response does not expose tokens secrets webhook URL or item IDs", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes(sandboxSecret), "response exposed Plaid secret");
  assert(!text.includes(webhookUrl), "response exposed webhook URL");
  assert(!text.includes(connectionId), "response exposed connection id");
  assert(!text.includes(userId), "response exposed user id");
});
