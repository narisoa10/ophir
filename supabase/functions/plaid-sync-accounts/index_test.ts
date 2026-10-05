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
  persistDisconnected?: boolean;
  persistSuperseded?: boolean;
  now?: () => Date;
  bootstrapStatus?: "synced" | "deferred";
  bootstrapThrows?: boolean;
  accountsOverride?: Record<string, unknown>[];
  accountsErrorCode?: string;
  recordResult?: "applied" | "not_found" | "failed";
  institutionFails?: boolean;
};

type PersistArgs = {
  plaidInstitutionId: string | null;
  institutionName: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  institutionUrl: string | null;
  balanceFetchedAt: string;
  accountsObservedAt: string;
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
  let persistArgs: PersistArgs | null = null;
  const institutionFails = options.institutionFails ?? false;

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
  const accountsErrorCode = options.accountsErrorCode;
  const recordResult = options.recordResult ?? "applied";
  const observations: Array<Record<string, unknown>> = [];

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
        persistArgs = {
          plaidInstitutionId: args.plaidInstitutionId,
          institutionName: args.institutionName,
          logoBase64: args.logoBase64,
          primaryColor: args.primaryColor,
          institutionUrl: args.institutionUrl,
          balanceFetchedAt: args.balanceFetchedAt,
          accountsObservedAt: args.accountsObservedAt,
        };
        if (options.persistDisconnected) {
          return "disconnected";
        }
        if (options.persistSuperseded) {
          return "superseded";
        }
        return persistSucceeds ? args.accounts.length : null;
      },
      async recordItemHealthObservation(observation) {
        calls.push("record_observation");
        observations.push({ ...observation });
        if (recordResult === "failed") {
          return null;
        }
        if (recordResult === "not_found") {
          return "not_found";
        }
        return {
          applied: true,
          previousStatus: "active",
          status: observation.status,
          plaidItemId: "external-item-id",
        };
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
        if (institutionFails) {
          return new Response(
            JSON.stringify({ error_code: "INSTITUTION_NOT_FOUND" }),
            { status: 400, headers: { "Content-Type": "application/json" } },
          );
        }
        return new Response(JSON.stringify(institutionPayload()), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      if (accountsErrorCode !== undefined) {
        return new Response(
          JSON.stringify({
            error_type: "ITEM_ERROR",
            error_code: accountsErrorCode,
            request_id: "request-id",
          }),
          {
            status: 400,
            headers: { "Content-Type": "application/json" },
          },
        );
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
    now: options.now ?? (() => new Date("2026-10-03T12:00:00.000Z")),
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
    observations,
    getPersistedAccounts: () => persistedAccounts,
    getPersistArgs: () => persistArgs,
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

Deno.test("accounts ITEM_LOGIN_REQUIRED records health and returns structured 409", async () => {
  const { handler, request, calls, bootstrapCalls, observations } =
    createHarness({ accountsErrorCode: "ITEM_LOGIN_REQUIRED" });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 409);
  assertEquals(JSON.parse(text).error.code, "item_login_required");
  assertEquals(observations.length, 1);
  assertEquals(observations[0].connectionId, connectionId);
  assertEquals(observations[0].observedAt, "2026-10-03T12:00:00.000Z");
  assertEquals(observations[0].status, "login_required");
  assertEquals(observations[0].statusReason, "login_required");
  assertEquals(observations[0].fromItemGet, false);
  assertEquals(observations[0].clearPendingDisconnect, false);
  assertEquals(calls.includes("persist_accounts"), false);
  assertEquals(bootstrapCalls.length, 0);
  assert(!text.includes(accessToken), "response exposed access token");
});

Deno.test("accounts ITEM_LOGIN_REQUIRED with failed health write returns persist_failed", async () => {
  const { handler, request } = createHarness({
    accountsErrorCode: "ITEM_LOGIN_REQUIRED",
    recordResult: "failed",
  });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "persist_failed");
});

Deno.test("other accounts Plaid errors stay 502 without health write", async () => {
  const { handler, request, observations } = createHarness({
    accountsErrorCode: "INSTITUTION_DOWN",
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals((await response.json()).error.code, "plaid_request_failed");
  assertEquals(observations.length, 0);
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

Deno.test("manual sync persists the full snapshot with Plaid institution metadata", async () => {
  const { handler, request, calls, getPersistedAccounts, getPersistArgs } =
    createHarness({
      accountsOverride: [
        baseAccount({ account_id: "plaid-account-a" }),
        baseAccount({ account_id: "plaid-account-quiet" }),
      ],
    });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(
    JSON.stringify(body),
    JSON.stringify({
      synced_account_count: 2,
      institution_name: "First Platypus Bank",
      transactions_bootstrap_status: "synced",
    }),
  );
  assertEquals(
    calls.join(","),
    "get_access_token,plaid_accounts,plaid_institution,persist_accounts,bootstrap_transactions",
  );
  assertEquals(
    getPersistedAccounts()!.map((account) => account.plaid_account_id).join(","),
    "plaid-account-a,plaid-account-quiet",
  );
  const persistArgs = getPersistArgs()!;
  assertEquals(persistArgs.plaidInstitutionId, "ins_109508");
  assertEquals(persistArgs.institutionName, "First Platypus Bank");
  assertEquals(persistArgs.logoBase64, "logo-base64");
  assertEquals(persistArgs.primaryColor, "#111111");
  assertEquals(persistArgs.institutionUrl, "https://example.com");
  assert(
    !Number.isNaN(Date.parse(persistArgs.balanceFetchedAt)),
    "balance_fetched_at is not a timestamp",
  );
});

Deno.test("institution lookup failure keeps the item name and null metadata as before", async () => {
  const { handler, request, getPersistArgs } = createHarness({
    institutionFails: true,
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.institution_name, "First Platypus Bank");
  const persistArgs = getPersistArgs()!;
  assertEquals(persistArgs.plaidInstitutionId, "ins_109508");
  assertEquals(persistArgs.institutionName, "First Platypus Bank");
  assertEquals(persistArgs.logoBase64, null);
  assertEquals(persistArgs.primaryColor, null);
  assertEquals(persistArgs.institutionUrl, null);
});

Deno.test("another user's connection gets no token, no Plaid call and a 404", async () => {
  const { handler, request, calls, bootstrapCalls, observations } =
    createHarness({
      authenticatedUserId: "33333333-3333-4333-8333-333333333333",
    });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 404);
  assertEquals(JSON.parse(text).error.code, "connection_not_found");
  assertEquals(calls.join(","), "get_access_token");
  assertEquals(observations.length, 0);
  assertEquals(bootstrapCalls.length, 0);
  assert(!text.includes(accessToken), "response exposed access token");
});

Deno.test("persist failure keeps the 500 persist_failed contract", async () => {
  const { handler, request } = createHarness({ persistSucceeds: false });

  const response = await handler(request);

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "persist_failed");
});

Deno.test("manual Sync of an Item disconnected mid-refresh fails closed with 409 connection_disconnected", async () => {
  const { handler, request, calls, bootstrapCalls } = createHarness({
    persistDisconnected: true,
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 409);
  assertEquals(JSON.parse(text).error.code, "connection_disconnected");
  assertEquals(calls.includes("bootstrap_transactions"), false);
  assertEquals(bootstrapCalls.length, 0);
  assertEquals(calls.includes("record_observation"), false);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
});

Deno.test("manual Sync superseded by a newer snapshot returns 200 with 0/null and still bootstraps", async () => {
  const { handler, request, calls, bootstrapCalls, observations } = createHarness({
    persistSuperseded: true,
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assertEquals(
    text,
    JSON.stringify({
      synced_account_count: 0,
      institution_name: null,
      transactions_bootstrap_status: "synced",
    }),
  );
  // One /accounts/get, no retry, no health write.
  assertEquals(
    calls.join(","),
    "get_access_token,plaid_accounts,plaid_institution,persist_accounts,bootstrap_transactions",
  );
  assertEquals(bootstrapCalls.length, 1);
  assertEquals(observations.length, 0);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
});

Deno.test("manual Sync superseded keeps the deferred bootstrap status", async () => {
  const { handler, request } = createHarness({
    persistSuperseded: true,
    bootstrapThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.synced_account_count, 0);
  assertEquals(body.institution_name, null);
  assertEquals(body.transactions_bootstrap_status, "deferred");
});

Deno.test("manual Sync passes the observation time taken before /accounts/get", async () => {
  // Every now() call advances the clock by one second.
  let ticks = 0;
  const harness = createHarness({
    now: () => new Date(Date.parse("2026-10-03T12:00:00.000Z") + 1000 * ticks++),
  });

  const response = await harness.handler(harness.request);

  assertEquals(response.status, 200);
  assertEquals(harness.calls.filter((call) => call === "plaid_accounts").length, 1);
  const persistArgs = harness.getPersistArgs()!;
  assertEquals(persistArgs.accountsObservedAt, "2026-10-03T12:00:00.000Z");
  assert(
    Date.parse(persistArgs.balanceFetchedAt) > Date.parse(persistArgs.accountsObservedAt),
    "balance time must be taken at persist, after the observation time",
  );
});

Deno.test("malformed accounts payload keeps the 502 plaid_payload_invalid contract", async () => {
  const { handler, request, calls } = createHarness({ malformedAccounts: true });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals((await response.json()).error.code, "plaid_payload_invalid");
  assertEquals(calls.includes("persist_accounts"), false);
});

Deno.test("unavailable Item errors keep the 502 plaid_request_failed contract", async () => {
  for (const errorCode of ["ITEM_NOT_FOUND", "INVALID_ACCESS_TOKEN"]) {
    const { handler, request, calls, observations } = createHarness({
      accountsErrorCode: errorCode,
    });

    const response = await handler(request);

    assertEquals(response.status, 502);
    assertEquals((await response.json()).error.code, "plaid_request_failed");
    assertEquals(observations.length, 0);
    assertEquals(calls.includes("persist_accounts"), false);
  }
});

Deno.test("handler writes no access token or Plaid secret to console output", async () => {
  const written: string[] = [];
  const original = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    error: console.error,
    debug: console.debug,
  };
  const capture = (...args: unknown[]) => {
    written.push(args.map((arg) => String(arg)).join(" "));
  };
  console.log = capture;
  console.info = capture;
  console.warn = capture;
  console.error = capture;
  console.debug = capture;

  try {
    const scenarios: HarnessOptions[] = [
      {},
      { accountsErrorCode: "ITEM_LOGIN_REQUIRED" },
      { accountsErrorCode: "INSTITUTION_DOWN" },
      { accountsErrorCode: "ITEM_NOT_FOUND" },
      { malformedAccounts: true },
      { persistSucceeds: false },
      { institutionFails: true },
      { accessTokenExists: false },
    ];
    for (const scenario of scenarios) {
      const { handler, request } = createHarness(scenario);
      const text = await (await handler(request)).text();
      assert(!text.includes(accessToken), "response exposed access token");
      assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
    }
  } finally {
    Object.assign(console, original);
  }

  const output = written.join("\n");
  assert(!output.includes(accessToken), "console exposed access token");
  assert(!output.includes("sandbox-secret"), "console exposed Plaid secret");
});
