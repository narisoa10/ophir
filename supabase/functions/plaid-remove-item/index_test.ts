import { createPlaidRemoveItemHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const otherConnectionId = "33333333-3333-4333-8333-333333333333";
const secretId = "44444444-4444-4444-8444-444444444444";
const accessToken = "access-token-secret-value";

type CleanupCall = {
  userId: string;
  connectionId: string;
  accessTokenSecretId: string;
};

type HarnessOptions = {
  authenticatedUserId?: string | null;
  itemExists?: boolean;
  accessTokenExists?: boolean;
  plaidStatus?: number;
  plaidErrorType?: string;
  plaidErrorCode?: string;
  cleanupSucceeds?: boolean;
  requestConnectionId?: string;
};

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

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const fetchBodies: Record<string, unknown>[] = [];
  const cleanupCalls: CleanupCall[] = [];

  const requestConnectionId = options.requestConnectionId ?? connectionId;
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const itemExists = options.itemExists ?? true;
  const accessTokenExists = options.accessTokenExists ?? true;
  const plaidStatus = options.plaidStatus ?? 200;
  const plaidErrorType = options.plaidErrorType;
  const plaidErrorCode = options.plaidErrorCode;
  const cleanupSucceeds = options.cleanupSucceeds ?? true;

  const handler = createPlaidRemoveItemHandler({
    authenticateRequest: async () => {
      if (authenticatedUserId === null) {
        return null;
      }

      return { id: authenticatedUserId };
    },
    createDatabase: () => ({
      async getPlaidItemForUser(receivedUserId, receivedConnectionId) {
        calls.push("get_item");
        if (
          !itemExists ||
          receivedUserId !== userId ||
          receivedConnectionId !== connectionId
        ) {
          return null;
        }

        return {
          id: connectionId,
          user_id: userId,
          plaid_environment: "sandbox",
          access_token_secret_id: secretId,
        };
      },
      async getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        calls.push("get_access_token");
        if (
          !accessTokenExists ||
          receivedUserId !== userId ||
          receivedConnectionId !== connectionId
        ) {
          return null;
        }

        return accessToken;
      },
      async cleanupPlaidItem(
        receivedUserId,
        receivedConnectionId,
        receivedAccessTokenSecretId,
      ) {
        calls.push("cleanup");
        cleanupCalls.push({
          userId: receivedUserId,
          connectionId: receivedConnectionId,
          accessTokenSecretId: receivedAccessTokenSecretId,
        });

        if (!cleanupSucceeds) {
          return null;
        }

        return {
          accounts_deleted: 12,
          plaid_items_deleted: 1,
          vault_secrets_deleted: 1,
        };
      },
    }),
    fetch: async (_url, init) => {
      calls.push("plaid_remove");
      fetchBodies.push(JSON.parse(String(init?.body)));

      const payload = plaidStatus >= 200 && plaidStatus < 300
        ? { request_id: "request-id" }
        : {
          error_type: plaidErrorType,
          error_code: plaidErrorCode,
          request_id: "request-id",
        };

      return new Response(JSON.stringify(payload), {
        status: plaidStatus,
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
  });

  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ connection_id: requestConnectionId }),
  });

  return { handler, request, calls, cleanupCalls, fetchBodies };
}

Deno.test("auth required", async () => {
  const { handler, request, calls } = createHarness({
    authenticatedUserId: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("cannot remove another user's connection", async () => {
  const { handler, request, calls, cleanupCalls } = createHarness({
    authenticatedUserId: otherConnectionId,
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("plaid_remove"), false);
  assertEquals(cleanupCalls.length, 0);
});

Deno.test("missing connection returns safe not found", async () => {
  const { handler, request, calls, cleanupCalls } = createHarness({
    itemExists: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("plaid_remove"), false);
  assertEquals(cleanupCalls.length, 0);
});

Deno.test("access token is never returned", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const responseText = await response.text();

  assertEquals(response.status, 200);
  assert(!responseText.includes(accessToken), "response exposed access token");
  assert(!responseText.includes(secretId), "response exposed Vault secret id");
});

Deno.test("successful item remove performs local cleanup after Plaid", async () => {
  const { handler, request, calls, cleanupCalls, fetchBodies } =
    createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(
    calls.join(","),
    "get_item,get_access_token,plaid_remove,cleanup",
  );
  assertEquals(fetchBodies.length, 1);
  assertEquals(fetchBodies[0].access_token, accessToken);
  assertEquals(cleanupCalls.length, 1);
  assertEquals(cleanupCalls[0].connectionId, connectionId);
  assertEquals(cleanupCalls[0].accessTokenSecretId, secretId);
});

Deno.test("Plaid failure does not perform local cleanup", async () => {
  const { handler, request, cleanupCalls } = createHarness({
    plaidStatus: 500,
    plaidErrorType: "API_ERROR",
    plaidErrorCode: "INTERNAL_SERVER_ERROR",
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(cleanupCalls.length, 0);
});

Deno.test("Plaid ITEM_NOT_FOUND performs local cleanup", async () => {
  const { handler, request, calls, cleanupCalls } = createHarness({
    plaidStatus: 400,
    plaidErrorType: "ITEM_ERROR",
    plaidErrorCode: "ITEM_NOT_FOUND",
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(
    calls.join(","),
    "get_item,get_access_token,plaid_remove,cleanup",
  );
  assertEquals(cleanupCalls.length, 1);
});

Deno.test("other ITEM_ERROR does not perform local cleanup", async () => {
  const { handler, request, cleanupCalls } = createHarness({
    plaidStatus: 400,
    plaidErrorType: "ITEM_ERROR",
    plaidErrorCode: "ITEM_LOGIN_REQUIRED",
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(cleanupCalls.length, 0);
});

Deno.test("missing access token does not call Plaid or cleanup", async () => {
  const { handler, request, calls, cleanupCalls } = createHarness({
    accessTokenExists: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("plaid_remove"), false);
  assertEquals(cleanupCalls.length, 0);
});

Deno.test("local cleanup result must delete item and Vault secret", async () => {
  const { handler, request } = createHarness({
    cleanupSucceeds: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("retry after cleanup failure succeeds on ITEM_NOT_FOUND", async () => {
  const calls: string[] = [];
  const cleanupCalls: CleanupCall[] = [];
  let plaidCallCount = 0;
  let cleanupCallCount = 0;

  const handler = createPlaidRemoveItemHandler({
    authenticateRequest: async () => ({ id: userId }),
    createDatabase: () => ({
      async getPlaidItemForUser(receivedUserId, receivedConnectionId) {
        calls.push("get_item");
        if (
          receivedUserId !== userId ||
          receivedConnectionId !== connectionId
        ) {
          return null;
        }

        return {
          id: connectionId,
          user_id: userId,
          plaid_environment: "sandbox",
          access_token_secret_id: secretId,
        };
      },
      async getAccessTokenForItem(receivedUserId, receivedConnectionId) {
        calls.push("get_access_token");
        if (
          receivedUserId !== userId ||
          receivedConnectionId !== connectionId
        ) {
          return null;
        }

        return accessToken;
      },
      async cleanupPlaidItem(
        receivedUserId,
        receivedConnectionId,
        receivedAccessTokenSecretId,
      ) {
        calls.push("cleanup");
        cleanupCallCount += 1;
        cleanupCalls.push({
          userId: receivedUserId,
          connectionId: receivedConnectionId,
          accessTokenSecretId: receivedAccessTokenSecretId,
        });

        if (cleanupCallCount === 1) {
          return null;
        }

        return {
          accounts_deleted: 12,
          plaid_items_deleted: 1,
          vault_secrets_deleted: 1,
        };
      },
    }),
    fetch: async (_url, init) => {
      calls.push("plaid_remove");
      plaidCallCount += 1;
      const body = JSON.parse(String(init?.body));
      assertEquals(body.access_token, accessToken);

      if (plaidCallCount === 1) {
        return new Response(JSON.stringify({ request_id: "request-id" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      return new Response(
        JSON.stringify({
          error_type: "ITEM_ERROR",
          error_code: "ITEM_NOT_FOUND",
          request_id: "request-id",
        }),
        {
          status: 400,
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
  });

  const request = () =>
    new Request("https://example.com", {
      method: "POST",
      body: JSON.stringify({ connection_id: connectionId }),
    });

  const firstResponse = await handler(request());
  const secondResponse = await handler(request());

  assertEquals(firstResponse.status, 500);
  assertEquals(secondResponse.status, 200);
  assertEquals(cleanupCalls.length, 2);
  assertEquals(plaidCallCount, 2);
});

Deno.test("cleanup targets only requested connection", async () => {
  const { handler, request, cleanupCalls } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(cleanupCalls.length, 1);
  assertEquals(cleanupCalls[0].connectionId, connectionId);
  assertEquals(cleanupCalls[0].connectionId === otherConnectionId, false);
});

Deno.test("invalid connection id is rejected before Plaid", async () => {
  const { handler, request, calls, cleanupCalls } = createHarness({
    requestConnectionId: "not-a-uuid",
  });

  const response = await handler(request);

  assertEquals(response.status, 400);
  assertEquals(calls.length, 0);
  assertEquals(cleanupCalls.length, 0);
});
