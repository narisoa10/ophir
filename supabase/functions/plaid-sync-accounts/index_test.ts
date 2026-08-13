import { createPlaidSyncAccountsHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const accessToken = "access-token-secret-value";

type PersistedAccount = {
  plaid_account_id: string;
  name: string;
  official_name: string | null;
  mask: string | null;
  plaid_type: string;
  plaid_subtype: string | null;
  currency_code: string | null;
  unofficial_currency_code: string | null;
  current_balance: number | null;
  available_balance: number | null;
  persistent_account_id: string | null;
};

type HarnessOptions = {
  authenticatedUserId?: string | null;
  requestConnectionId?: string;
  accessTokenExists?: boolean;
  plaidAccountsStatus?: number;
  malformedAccounts?: boolean;
  persistSucceeds?: boolean;
  bootstrapStatus?: "synced" | "deferred";
  bootstrapThrows?: boolean;
  accountsOverride?: Record<string, unknown>[];
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

function baseAccount(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
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
    ...overrides,
  };
}

function accountsPayload(
  accounts?: Record<string, unknown>[],
): Record<string, unknown> {
  return {
    item: {
      institution_id: "ins_109508",
      institution_name: "First Platypus Bank",
    },
    accounts: accounts ?? [baseAccount()],
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
  let persistedAccounts: PersistedAccount[] | null = null;

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
  const accountsOverride = options.accountsOverride;

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
        persistedAccounts = args.accounts as PersistedAccount[];
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
      calls.push(
        url.toString().includes("institutions/get_by_id")
          ? "plaid_institution"
          : "plaid_accounts",
      );

      if (url.toString().includes("institutions/get_by_id")) {
        return new Response(JSON.stringify(institutionPayload()), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      return new Response(
        JSON.stringify(
          malformedAccounts
            ? { accounts: "bad" }
            : accountsPayload(accountsOverride),
        ),
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

  return {
    handler,
    request,
    calls,
    bootstrapCalls,
    getPersistedAccounts: () => persistedAccounts,
  };
}

async function syncAndGetPersisted(
  options: HarnessOptions = {},
): Promise<{
  status: number;
  body: Record<string, unknown>;
  bodyText: string;
  persisted: PersistedAccount[] | null;
  calls: string[];
}> {
  const { handler, request, calls, getPersistedAccounts } = createHarness(
    options,
  );
  const response = await handler(request);
  const bodyText = await response.text();
  const body = JSON.parse(bodyText) as Record<string, unknown>;
  return {
    status: response.status,
    body,
    bodyText,
    persisted: getPersistedAccounts(),
    calls,
  };
}

Deno.test("successful account sync triggers exactly one initial transaction bootstrap", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness();

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(
    calls.filter((call) => call === "bootstrap_transactions").length,
    1,
  );
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

Deno.test("B1 valid PAI string maps to trimmed persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({ persistent_account_id: "  pai-value-1  " }),
    ],
  });

  assertEquals(result.status, 200);
  assert(result.persisted !== null, "persist payload missing");
  assertEquals(result.persisted![0].persistent_account_id, "pai-value-1");
});

Deno.test("B2 PAI null maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: null })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B3 PAI absent maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount()],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B4 PAI whitespace maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: "   " })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B5 PAI empty string maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: "" })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B6 PAI numeric maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: 12345 })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B7 PAI boolean maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: true })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B8 PAI object maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: { id: "x" } })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B9 PAI array maps to null persist payload", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: ["pai"] })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, null);
});

Deno.test("B10 multiple accounts keep representation-specific PAI values", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({
        account_id: "plaid-account-a",
        persistent_account_id: "pai-a",
      }),
      baseAccount({
        account_id: "plaid-account-b",
        persistent_account_id: null,
      }),
    ],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted!.length, 2);
  assertEquals(result.persisted![0].plaid_account_id, "plaid-account-a");
  assertEquals(result.persisted![0].persistent_account_id, "pai-a");
  assertEquals(result.persisted![1].plaid_account_id, "plaid-account-b");
  assertEquals(result.persisted![1].persistent_account_id, null);
});

Deno.test("B11 PAI does not alter plaid_account_id", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({
        account_id: "stable-plaid-account-id",
        persistent_account_id: "pai-other",
      }),
    ],
  });

  assertEquals(result.status, 200);
  assertEquals(
    result.persisted![0].plaid_account_id,
    "stable-plaid-account-id",
  );
  assertEquals(result.persisted![0].persistent_account_id, "pai-other");
});

Deno.test("B12 handler persist payload keeps plaid_account_id as account identity field", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({
        account_id: "identity-account",
        persistent_account_id: "pai-not-identity",
      }),
    ],
  });

  assertEquals(result.status, 200);
  const account = result.persisted![0];
  assertEquals(account.plaid_account_id, "identity-account");
  assert(
    Object.prototype.hasOwnProperty.call(account, "persistent_account_id"),
    "persistent_account_id missing from payload",
  );
  assertEquals(account.persistent_account_id, "pai-not-identity");
});

Deno.test("B13 HTTP success response does not expose PAI", async () => {
  const pai = "pai-must-not-appear-in-http";
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: pai })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.persisted![0].persistent_account_id, pai);
  assert(!result.bodyText.includes(pai), "response exposed PAI");
  assertEquals("persistent_account_id" in result.body, false);
  assertEquals("plaid_account_id" in result.body, false);
  assertEquals(typeof result.body.synced_account_count, "number");
  assertEquals(typeof result.body.institution_name, "string");
  assertEquals(typeof result.body.transactions_bootstrap_status, "string");
});

Deno.test("B14 error response does not expose PAI or secrets", async () => {
  const pai = "pai-error-path-secret";
  const result = await syncAndGetPersisted({
    persistSucceeds: false,
    accountsOverride: [baseAccount({ persistent_account_id: pai })],
  });

  assertEquals(result.status, 500);
  assert(!result.bodyText.includes(pai), "error response exposed PAI");
  assert(
    !result.bodyText.includes(accessToken),
    "error response exposed token",
  );
  assert(
    !result.bodyText.includes("sandbox-secret"),
    "error response exposed Plaid secret",
  );
});

Deno.test("B15 B16 no canonical membership or duplicate detection calls", async () => {
  const result = await syncAndGetPersisted({
    accountsOverride: [baseAccount({ persistent_account_id: "pai-x" })],
  });

  assertEquals(result.status, 200);
  assertEquals(result.calls.includes("persist_accounts"), true);
  assertEquals(result.calls.includes("canonical"), false);
  assertEquals(result.calls.includes("membership"), false);
  assertEquals(result.calls.includes("duplicate"), false);
  for (const call of result.calls) {
    assert(!call.includes("canonical"), `unexpected canonical call: ${call}`);
    assert(!call.includes("membership"), `unexpected membership call: ${call}`);
    assert(!call.includes("duplicate"), `unexpected duplicate call: ${call}`);
  }
});

Deno.test("B17 repeated mapper invocation with same PAI is deterministic", async () => {
  const first = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({ persistent_account_id: "  same-pai  " }),
    ],
  });
  const second = await syncAndGetPersisted({
    accountsOverride: [
      baseAccount({ persistent_account_id: "  same-pai  " }),
    ],
  });

  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(
    first.persisted![0].persistent_account_id,
    second.persisted![0].persistent_account_id,
  );
  assertEquals(first.persisted![0].persistent_account_id, "same-pai");
});
