import { createPlaidCreateLinkTokenHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const webhookUrl =
  "https://example-project.supabase.co/functions/v1/plaid-webhook";
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

function createHarness(options: {
  authenticatedUserId?: string | null;
  locale?: string;
  plaidWebhookUrl?: string | null;
  plaidStatus?: number;
  plaidPayload?: Record<string, unknown>;
} = {}) {
  const fetchBodies: Array<Record<string, unknown>> = [];
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const plaidWebhookUrl = options.plaidWebhookUrl === undefined
    ? webhookUrl
    : options.plaidWebhookUrl;

  const handler = createPlaidCreateLinkTokenHandler({
    authenticateRequest: async () =>
      authenticatedUserId === null ? null : { id: authenticatedUserId },
    fetch: async (_url, init) => {
      fetchBodies.push(JSON.parse(String(init?.body)));

      return new Response(
        JSON.stringify(
          options.plaidPayload ?? {
            link_token: "link-sandbox-token",
            expiration: "2026-08-11T12:00:00Z",
            request_id: "request-id",
          },
        ),
        {
          status: options.plaidStatus ?? 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    },
    getEnv: (name) => {
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return sandboxSecret;
      }
      if (name === "PLAID_WEBHOOK_URL") {
        return plaidWebhookUrl ?? undefined;
      }
      return undefined;
    },
  });

  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ locale: options.locale ?? "en-CA" }),
  });

  return { handler, request, fetchBodies };
}

Deno.test("webhook is sent to Plaid link token create", async () => {
  const { handler, request, fetchBodies } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies.length, 1);
  assertEquals(fetchBodies[0].webhook, webhookUrl);
});

Deno.test("transactions product and 730 days are preserved", async () => {
  const { handler, request, fetchBodies } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals((fetchBodies[0].products as string[]).join(","), "transactions");
  assertEquals(
    (fetchBodies[0].transactions as Record<string, unknown>).days_requested,
    730,
  );
});

Deno.test("missing Plaid webhook URL fails closed before Plaid call", async () => {
  const { handler, request, fetchBodies } = createHarness({
    plaidWebhookUrl: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(fetchBodies.length, 0);
});

Deno.test("empty Plaid webhook URL fails closed before Plaid call", async () => {
  const { handler, request, fetchBodies } = createHarness({
    plaidWebhookUrl: " ",
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(fetchBodies.length, 0);
});

Deno.test("non-HTTPS Plaid webhook URL is rejected", async () => {
  const { handler, request, fetchBodies } = createHarness({
    plaidWebhookUrl: "http://example.com/functions/v1/plaid-webhook",
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(fetchBodies.length, 0);
});

Deno.test("webhook URL is not returned to client", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(webhookUrl), "response exposed webhook URL");
});

Deno.test("secrets are not returned to client", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(sandboxSecret), "response exposed Plaid secret");
});
