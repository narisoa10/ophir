import { createPlaidSyncAccountsHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const accessToken = "access-token-secret-value";

type HarnessOptions = {
  authenticatedUserId?: string | null;
  requestConnectionId?: string;
  accessTokenExists?: boolean;
  plaidAccountsStatus?: number;
  malformedAccounts?: boolean;
  persistSucceeds?: boolean;
  bootstrapStatus?: "synced" | "deferred";
  bootstrapThrows?: boolean;
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

function accountsPayload(): Record<string, unknown> {
  return {
    item: {
      institution_id: "ins_109508",
      institution_name: "First Platypus Bank",
    },
    accounts: [
      {
        account_id: "plaid-account-1",
        name: "Checking",
        official_name: "Checking",
        mask: "0000",
        type: "depository",
        subtype: "checking",
        balances: {
          current: 100.25,
          available: 90.25,
          iso_currency_code: "CAD",
          unofficial_currency_code: null,
        },
      },
    ],
  };
}

function institutionPayload(): Record<string, unknown> {
  return {
    institution: {
      name: "First Platypus Bank",
      logo: "logo-base64",
      primary_color: "#111111",
      url: "https://example.com",
    },
  };
}

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const bootstrapCalls: Array<{ userId: string; connectionId: string }> = [];

  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const requestConnectionId = options.requestConnectionId ?? connectionId;
  const accessTokenExists = options.accessTokenExists ?? true;
  const plaidAccountsStatus = options.plaidAccountsStatus ?? 200;
  const malformedAccounts = options.malformedAccounts ?? false;
  const persistSucceeds = options.persistSucceeds ?? true;
  const bootstrapStatus = options.bootstrapStatus ?? "synced";
  const bootstrapThrows = options.bootstrapThrows ?? false;

  const handler = createPlaidSyncAccountsHandler({
    authenticateRequest: async () => {
      if (authenticatedUserId === null) {
        return null;
      }

      return { id: authenticatedUserId };
    },
    createDatabase: () => ({
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
      async persistAccountsSync(args) {
        calls.push("persist_accounts");
        assertEquals(args.userId, userId);
        assertEquals(args.connectionId, connectionId);
        assertEquals(args.accounts.length, 1);
        return persistSucceeds ? args.accounts.length : null;
      },
    }),
    bootstrapTransactions: async (receivedUserId, receivedConnectionId) => {
      calls.push("bootstrap_transactions");
      bootstrapCalls.push({
        userId: receivedUserId,
        connectionId: receivedConnectionId,
      });
      if (bootstrapThrows) {
        throw new Error("bootstrap failed");
      }
      return bootstrapStatus;
    },
    fetch: async (url) => {
      calls.push(url.toString().includes("institutions/get_by_id")
        ? "plaid_institution"
        : "plaid_accounts");

      if (url.toString().includes("institutions/get_by_id")) {
        return new Response(JSON.stringify(institutionPayload()), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      return new Response(
        JSON.stringify(malformedAccounts ? { accounts: "bad" } : accountsPayload()),
        {
          status: plaidAccountsStatus,
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

  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ connection_id: requestConnectionId }),
  });

  return { handler, request, calls, bootstrapCalls };
}

Deno.test("successful account sync triggers exactly one initial transaction bootstrap", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(calls.filter((call) => call === "bootstrap_transactions").length, 1);
  assertEquals(bootstrapCalls.length, 1);
  assertEquals(bootstrapCalls[0].connectionId, connectionId);
  assertEquals(body.transactions_bootstrap_status, "synced");
});

Deno.test("transaction bootstrap starts only after account persistence success", async () => {
  const { handler, request, calls } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assert(
    calls.indexOf("persist_accounts") < calls.indexOf("bootstrap_transactions"),
    "bootstrap ran before account persistence",
  );
});

Deno.test("account sync failure does not start transaction bootstrap", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness({
    persistSucceeds: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals(calls.includes("bootstrap_transactions"), false);
  assertEquals(bootstrapCalls.length, 0);
});

Deno.test("Plaid account payload failure does not start transaction bootstrap", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness({
    malformedAccounts: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(calls.includes("persist_accounts"), false);
  assertEquals(bootstrapCalls.length, 0);
});

Deno.test("bootstrap failure is deferred and account sync remains successful", async () => {
  const { handler, request, bootstrapCalls } = createHarness({
    bootstrapStatus: "deferred",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(bootstrapCalls.length, 1);
  assertEquals(body.synced_account_count, 1);
  assertEquals(body.transactions_bootstrap_status, "deferred");
});

Deno.test("bootstrap exception is deferred and does not fail account sync", async () => {
  const { handler, request, bootstrapCalls } = createHarness({
    bootstrapThrows: true,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(bootstrapCalls.length, 1);
  assertEquals(body.synced_account_count, 1);
  assertEquals(body.transactions_bootstrap_status, "deferred");
});

Deno.test("missing connection does not call Plaid or bootstrap", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness({
    accessTokenExists: false,
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("plaid_accounts"), false);
  assertEquals(bootstrapCalls.length, 0);
});

Deno.test("auth required", async () => {
  const { handler, request, calls } = createHarness({
    authenticatedUserId: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("no access token is exposed in response", async () => {
  const { handler, request } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
});
