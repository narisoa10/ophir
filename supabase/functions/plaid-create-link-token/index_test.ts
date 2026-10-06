import { createPlaidCreateLinkTokenHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const webhookUrl =
  "https://example-project.supabase.co/functions/v1/plaid-webhook";
const sandboxSecret = "sandbox-secret-value";
const ownedConnectionId = "22222222-2222-4222-8222-222222222222";
const otherConnectionId = "33333333-3333-4333-8333-333333333333";
const itemAccessToken = "access-token-secret-value";

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
  requestBody?: Record<string, unknown>;
} = {}) {
  const fetchBodies: Array<Record<string, unknown>> = [];
  const fetchUrls: string[] = [];
  const tokenLookups: Array<{ userId: string; connectionId: string }> = [];
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const plaidWebhookUrl = options.plaidWebhookUrl === undefined
    ? webhookUrl
    : options.plaidWebhookUrl;

  const handler = createPlaidCreateLinkTokenHandler({
    authenticateRequest: async () =>
      authenticatedUserId === null ? null : { id: authenticatedUserId },
    createDatabase: () => ({
      async getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        tokenLookups.push({
          userId: receivedUserId,
          connectionId: receivedConnectionId,
        });
        return receivedUserId === userId &&
            receivedConnectionId === ownedConnectionId
          ? itemAccessToken
          : null;
      },
    }),
    fetch: async (url, init) => {
      fetchUrls.push(String(url));
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
    body: JSON.stringify(
      options.requestBody ?? { locale: options.locale ?? "en-CA" },
    ),
  });

  return { handler, request, fetchBodies, fetchUrls, tokenLookups };
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

Deno.test("initial and update Link request Canada only", async () => {
  for (const connectionId of [undefined, ownedConnectionId]) {
    const { handler, request, fetchBodies } = createHarness({
      requestBody: { locale: "en-CA", connection_id: connectionId },
    });

    const response = await handler(request);

    assertEquals(response.status, 200);
    assertEquals(JSON.stringify(fetchBodies[0].country_codes), '["CA"]');
  }
});

Deno.test("client cannot choose the Plaid country", async () => {
  const { handler, request, fetchBodies } = createHarness({
    requestBody: { locale: "en-US", country_codes: ["US"] },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(JSON.stringify(fetchBodies[0].country_codes), '["CA"]');
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

Deno.test("initial Link does not read any Item token", async () => {
  const { handler, request, tokenLookups } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(tokenLookups.length, 0);
  assertEquals("mode" in body, false);
});

Deno.test("update mode for owned Item sends access_token without products", async () => {
  const { handler, request, fetchBodies, fetchUrls, tokenLookups } =
    createHarness({
      requestBody: { locale: "fr-CA", connection_id: ownedConnectionId },
    });

  const response = await handler(request);
  const text = await response.text();
  const body = JSON.parse(text);

  assertEquals(response.status, 200);
  assertEquals(body.link_token, "link-sandbox-token");
  assertEquals(body.mode, "update");
  assertEquals(tokenLookups.length, 1);
  assertEquals(tokenLookups[0].userId, userId);
  assertEquals(tokenLookups[0].connectionId, ownedConnectionId);
  assertEquals(fetchUrls.length, 1);
  assertEquals(fetchUrls[0], "https://sandbox.plaid.com/link/token/create");
  assertEquals(fetchBodies[0].access_token, itemAccessToken);
  assertEquals(fetchBodies[0].language, "fr");
  assertEquals(
    (fetchBodies[0].user as Record<string, unknown>).client_user_id,
    userId,
  );
  assertEquals("products" in fetchBodies[0], false);
  assertEquals("transactions" in fetchBodies[0], false);
  assertEquals("webhook" in fetchBodies[0], false);
  assert(!text.includes(itemAccessToken), "response exposed access token");
});

Deno.test("update mode never calls public_token exchange", async () => {
  const { handler, request, fetchUrls } = createHarness({
    requestBody: { locale: "en-CA", connection_id: ownedConnectionId },
  });

  await handler(request);

  assertEquals(
    fetchUrls.some((url) => url.includes("public_token/exchange")),
    false,
  );
});

Deno.test("update mode does not require webhook config", async () => {
  const { handler, request } = createHarness({
    plaidWebhookUrl: null,
    requestBody: { locale: "en-CA", connection_id: ownedConnectionId },
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
});

Deno.test("update mode for another user's Item returns 404 without Plaid call", async () => {
  const { handler, request, fetchBodies } = createHarness({
    requestBody: { locale: "en-CA", connection_id: otherConnectionId },
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals((await response.json()).error.code, "connection_not_found");
  assertEquals(fetchBodies.length, 0);
});

Deno.test("update mode with malformed connection_id is rejected", async () => {
  for (const connectionId of ["not-a-uuid", 42, null, ""]) {
    const { handler, request, fetchBodies, tokenLookups } = createHarness({
      requestBody: { locale: "en-CA", connection_id: connectionId },
    });

    const response = await handler(request);

    assertEquals(response.status, 400);
    assertEquals(fetchBodies.length, 0);
    assertEquals(tokenLookups.length, 0);
  }
});

Deno.test("update mode with unavailable Item returns reconnect_unavailable", async () => {
  for (const errorCode of ["ITEM_NOT_FOUND", "INVALID_ACCESS_TOKEN"]) {
    const { handler, request } = createHarness({
      requestBody: { locale: "en-CA", connection_id: ownedConnectionId },
      plaidStatus: 400,
      plaidPayload: { error_type: "ITEM_ERROR", error_code: errorCode },
    });

    const response = await handler(request);

    assertEquals(response.status, 409);
    assertEquals((await response.json()).error.code, "reconnect_unavailable");
  }
});

Deno.test("update mode with other Plaid error returns 502", async () => {
  const { handler, request } = createHarness({
    requestBody: { locale: "en-CA", connection_id: ownedConnectionId },
    plaidStatus: 500,
    plaidPayload: { error_type: "API_ERROR", error_code: "INTERNAL_SERVER_ERROR" },
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 502);
  assert(!text.includes(itemAccessToken), "response exposed access token");
});
