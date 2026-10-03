import {
  type AccountsRefreshDatabase,
  type InstitutionMetadataSource,
  normalizePlaidAccounts,
  type PersistAccountsSyncArgs,
  type PlaidAccountsRefreshResult,
  refreshPlaidAccountsForItem,
  type StoredInstitution,
} from "./plaid_accounts_refresh.ts";
import type { ItemHealthObservation } from "./plaid_item_health.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const accessToken = "access-sandbox-secret-token";
const clientId = "client-id-value";
const plaidSecret = "plaid-secret-value";
const now = new Date("2026-10-03T12:00:00.000Z");

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function assertJsonEquals(actual: unknown, expected: unknown): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}

function account(
  accountId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    account_id: accountId,
    name: `Account ${accountId}`,
    official_name: null,
    mask: "0000",
    type: "depository",
    subtype: "checking",
    balances: {
      current: 100,
      available: 90,
      iso_currency_code: "CAD",
      unofficial_currency_code: null,
    },
    ...overrides,
  };
}

function accountsGetPayload(
  accounts: unknown[],
  item: Record<string, unknown> = {
    institution_id: "ins_item",
    institution_name: "Item Bank",
  },
): Record<string, unknown> {
  return { accounts, item, request_id: "req" };
}

type FetchCall = { url: string; body: Record<string, unknown> };

type PlaidResponder = (url: string) => {
  status: number;
  body: unknown;
} | "throw";

function fakeFetch(
  responder: PlaidResponder,
  calls: FetchCall[],
): typeof fetch {
  return ((input: RequestInfo | URL, init?: RequestInit) => {
    const url = input.toString();
    calls.push({ url, body: JSON.parse(String(init?.body ?? "{}")) });
    const response = responder(url);
    if (response === "throw") {
      return Promise.reject(new Error("network down"));
    }
    return Promise.resolve(
      new Response(JSON.stringify(response.body), { status: response.status }),
    );
  }) as typeof fetch;
}

function accountsOk(
  accounts: unknown[],
  item?: Record<string, unknown>,
): PlaidResponder {
  return (url) => {
    if (url.includes("/accounts/get")) {
      return { status: 200, body: accountsGetPayload(accounts, item) };
    }
    if (url.includes("/institutions/get_by_id")) {
      return {
        status: 200,
        body: {
          institution: {
            name: "Plaid Bank",
            logo: "plaid-logo",
            primary_color: "#123456",
            url: "https://plaid-bank.example",
          },
        },
      };
    }
    return { status: 404, body: {} };
  };
}

function plaidError(errorCode: string): PlaidResponder {
  return (url) =>
    url.includes("/accounts/get")
      ? {
        status: 400,
        body: { error_type: "ITEM_ERROR", error_code: errorCode },
      }
      : { status: 404, body: {} };
}

type FakeDatabaseState = {
  tokenRequests: number;
  persisted: PersistAccountsSyncArgs[];
  observations: ItemHealthObservation[];
  institutionLookups: number;
};

function fakeDatabase(options: {
  accessToken?: string | null;
  stored?: StoredInstitution | null | "failed" | "throw";
  persistResult?: number | null;
  observationResult?: "applied" | "not_found" | null;
  withoutInstitutionLookup?: boolean;
} = {}): { database: AccountsRefreshDatabase; state: FakeDatabaseState } {
  const state: FakeDatabaseState = {
    tokenRequests: 0,
    persisted: [],
    observations: [],
    institutionLookups: 0,
  };

  const database: AccountsRefreshDatabase = {
    getAccessTokenForItem() {
      state.tokenRequests += 1;
      return Promise.resolve(
        options.accessToken === undefined ? accessToken : options.accessToken,
      );
    },
    persistAccountsSync(args) {
      state.persisted.push(args);
      return Promise.resolve(
        options.persistResult === undefined
          ? args.accounts.length
          : options.persistResult,
      );
    },
    recordItemHealthObservation(observation) {
      state.observations.push(observation);
      const result = options.observationResult === undefined
        ? "applied"
        : options.observationResult;
      if (result === "applied") {
        return Promise.resolve({
          applied: true,
          previousStatus: "active",
          status: "login_required",
          plaidItemId: "item",
        });
      }
      return Promise.resolve(result);
    },
  };

  if (!options.withoutInstitutionLookup) {
    database.getStoredInstitution = () => {
      state.institutionLookups += 1;
      if (options.stored === "throw") {
        return Promise.reject(new Error("db down"));
      }
      return Promise.resolve(
        options.stored === undefined
          ? {
            plaidInstitutionId: "ins_stored",
            name: "Stored Bank",
            logoBase64: "stored-logo",
            primaryColor: "#abcdef",
            url: "https://stored-bank.example",
          }
          : options.stored,
      );
    };
  }

  return { database, state };
}

async function refresh(params: {
  responder: PlaidResponder;
  database: AccountsRefreshDatabase;
  institutionSource?: InstitutionMetadataSource;
  calls?: FetchCall[];
}): Promise<PlaidAccountsRefreshResult> {
  return await refreshPlaidAccountsForItem({
    userId,
    connectionId,
    database: params.database,
    fetchImpl: fakeFetch(params.responder, params.calls ?? []),
    clientId,
    secret: plaidSecret,
    now: () => now,
    institutionSource: params.institutionSource ?? "stored",
  });
}

function assertNoSecrets(value: unknown): void {
  const serialized = JSON.stringify(value);
  for (const secret of [accessToken, plaidSecret, clientId]) {
    if (serialized.includes(secret)) {
      throw new Error("secret leaked into helper result");
    }
  }
}

Deno.test("automatic refresh uses the full /accounts/get snapshot and persists every account", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase();
  const result = await refresh({
    responder: accountsOk([account("a1"), account("a2"), account("a3")]),
    database,
    calls,
  });

  assertJsonEquals(result, {
    kind: "refreshed",
    syncedAccountCount: 3,
    institutionName: "Stored Bank",
  });
  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, "https://sandbox.plaid.com/accounts/get");
  assertEquals(calls[0].body.access_token, accessToken);
  assertEquals(state.persisted.length, 1);
  assertJsonEquals(
    state.persisted[0].accounts.map((row) => row.plaid_account_id),
    ["a1", "a2", "a3"],
  );
  assertEquals(state.persisted[0].userId, userId);
  assertEquals(state.persisted[0].connectionId, connectionId);
});

Deno.test("quiet account without transactions keeps its fresh balance in the snapshot", async () => {
  const { database, state } = fakeDatabase();
  await refresh({
    responder: accountsOk([
      account("active"),
      account("quiet", {
        balances: {
          current: 4321.5,
          available: null,
          iso_currency_code: "cad",
          unofficial_currency_code: null,
        },
      }),
    ]),
    database,
  });

  const quiet = state.persisted[0].accounts.find((row) =>
    row.plaid_account_id === "quiet"
  );
  assertEquals(quiet?.current_balance, 4321.5);
  assertEquals(quiet?.available_balance, null);
  assertEquals(quiet?.currency_code, "CAD");
});

Deno.test("stored institution metadata is reused and /institutions/get_by_id is not called", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase();
  await refresh({ responder: accountsOk([account("a1")]), database, calls });

  assertEquals(
    calls.some((call) => call.url.includes("/institutions/get_by_id")),
    false,
  );
  assertEquals(state.institutionLookups, 1);
  const persisted = state.persisted[0];
  assertEquals(persisted.plaidInstitutionId, "ins_stored");
  assertEquals(persisted.institutionName, "Stored Bank");
  assertEquals(persisted.logoBase64, "stored-logo");
  assertEquals(persisted.primaryColor, "#abcdef");
  assertEquals(persisted.institutionUrl, "https://stored-bank.example");
});

Deno.test("stored institution with missing fields falls back to /accounts/get item fields", async () => {
  const { database, state } = fakeDatabase({
    stored: {
      plaidInstitutionId: null,
      name: null,
      logoBase64: "stored-logo",
      primaryColor: null,
      url: null,
    },
  });
  await refresh({ responder: accountsOk([account("a1")]), database });

  const persisted = state.persisted[0];
  assertEquals(persisted.plaidInstitutionId, "ins_item");
  assertEquals(persisted.institutionName, "Item Bank");
  assertEquals(persisted.logoBase64, "stored-logo");
});

Deno.test("missing stored institution falls back to /accounts/get item metadata", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase({ stored: null });
  const result = await refresh({
    responder: accountsOk([account("a1")]),
    database,
    calls,
  });

  assertEquals(result.kind, "refreshed");
  assertEquals(calls.length, 1);
  const persisted = state.persisted[0];
  assertEquals(persisted.plaidInstitutionId, "ins_item");
  assertEquals(persisted.institutionName, "Item Bank");
  assertEquals(persisted.logoBase64, null);
  assertEquals(persisted.primaryColor, null);
  assertEquals(persisted.institutionUrl, null);
});

Deno.test("failed institution lookup does not persist and does not clobber metadata", async () => {
  for (const stored of ["failed", "throw"] as const) {
    const { database, state } = fakeDatabase({ stored });
    const result = await refresh({
      responder: accountsOk([account("a1")]),
      database,
    });

    assertJsonEquals(result, { kind: "institution_lookup_failed" });
    assertEquals(state.persisted.length, 0);
  }
});

Deno.test("stored source without an institution reader fails closed", async () => {
  const { database, state } = fakeDatabase({ withoutInstitutionLookup: true });
  const result = await refresh({
    responder: accountsOk([account("a1")]),
    database,
  });

  assertJsonEquals(result, { kind: "institution_lookup_failed" });
  assertEquals(state.persisted.length, 0);
});

Deno.test("plaid source keeps manual-sync behavior and calls /institutions/get_by_id", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase();
  const result = await refresh({
    responder: accountsOk([account("a1")]),
    database,
    calls,
    institutionSource: "plaid",
  });

  assertJsonEquals(result, {
    kind: "refreshed",
    syncedAccountCount: 1,
    institutionName: "Plaid Bank",
  });
  assertEquals(state.institutionLookups, 0);
  assertJsonEquals(calls.map((call) => call.url), [
    "https://sandbox.plaid.com/accounts/get",
    "https://sandbox.plaid.com/institutions/get_by_id",
  ]);
  assertJsonEquals(calls[1].body, {
    institution_id: "ins_item",
    country_codes: ["CA"],
    options: { include_optional_metadata: true },
  });
  const persisted = state.persisted[0];
  assertEquals(persisted.plaidInstitutionId, "ins_item");
  assertEquals(persisted.logoBase64, "plaid-logo");
  assertEquals(persisted.primaryColor, "#123456");
  assertEquals(persisted.institutionUrl, "https://plaid-bank.example");
});

Deno.test("ITEM_LOGIN_REQUIRED records the existing login_required observation without persisting", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase();
  const result = await refresh({
    responder: plaidError("ITEM_LOGIN_REQUIRED"),
    database,
    calls,
  });

  assertJsonEquals(result, { kind: "item_login_required" });
  assertEquals(calls.length, 1);
  assertEquals(state.persisted.length, 0);
  assertEquals(state.institutionLookups, 0);
  assertJsonEquals(state.observations, [{
    connectionId,
    observedAt: now.toISOString(),
    status: "login_required",
    statusReason: "login_required",
    fromItemGet: false,
    consentExpiresAt: null,
    clearPendingDisconnect: false,
  }]);
});

Deno.test("ITEM_LOGIN_REQUIRED with failed health write is persist_failed", async () => {
  const { database } = fakeDatabase({ observationResult: null });
  const result = await refresh({
    responder: plaidError("ITEM_LOGIN_REQUIRED"),
    database,
  });

  assertJsonEquals(result, { kind: "persist_failed" });
});

Deno.test("ITEM_LOGIN_REQUIRED for an unknown connection is connection_not_found", async () => {
  const { database } = fakeDatabase({ observationResult: "not_found" });
  const result = await refresh({
    responder: plaidError("ITEM_LOGIN_REQUIRED"),
    database,
  });

  assertJsonEquals(result, { kind: "connection_not_found" });
});

Deno.test("missing access token fails closed before any Plaid call", async () => {
  const calls: FetchCall[] = [];
  const { database, state } = fakeDatabase({ accessToken: null });
  const result = await refresh({
    responder: accountsOk([account("a1")]),
    database,
    calls,
  });

  assertJsonEquals(result, { kind: "connection_not_found" });
  assertEquals(calls.length, 0);
  assertEquals(state.persisted.length, 0);
  assertEquals(state.observations.length, 0);
  assertEquals(state.institutionLookups, 0);
});

Deno.test("unavailable Item fails closed without health write or persist", async () => {
  for (const errorCode of ["ITEM_NOT_FOUND", "INVALID_ACCESS_TOKEN"]) {
    const { database, state } = fakeDatabase();
    const result = await refresh({
      responder: plaidError(errorCode),
      database,
    });

    assertJsonEquals(result, { kind: "item_unavailable" });
    assertEquals(state.persisted.length, 0);
    assertEquals(state.observations.length, 0);
  }
});

Deno.test("other Plaid failures are plaid_request_failed without health write or persist", async () => {
  const responders: PlaidResponder[] = [
    plaidError("INSTITUTION_DOWN"),
    () => "throw",
    () => ({ status: 500, body: "not-an-object" }),
    () => ({ status: 200, body: ["array"] }),
  ];

  for (const responder of responders) {
    const { database, state } = fakeDatabase();
    const result = await refresh({ responder, database });

    assertJsonEquals(result, { kind: "plaid_request_failed" });
    assertEquals(state.persisted.length, 0);
    assertEquals(state.observations.length, 0);
  }
});

Deno.test("malformed accounts payload is not persisted", async () => {
  const payloads: unknown[][] = [
    [account("a1"), account("a2", { account_id: " " })],
    [account("a1", { name: null })],
    [account("a1", { type: 7 })],
    [account("a1", { balances: { current: 1 } })],
    [account("a1", { balances: { iso_currency_code: "CADX" } })],
    ["not-an-account"],
  ];

  for (const accounts of payloads) {
    const { database, state } = fakeDatabase();
    const result = await refresh({ responder: accountsOk(accounts), database });

    assertJsonEquals(result, { kind: "plaid_payload_invalid" });
    assertEquals(state.persisted.length, 0);
  }

  const { database, state } = fakeDatabase();
  const missingArray = await refresh({
    responder: (url) =>
      url.includes("/accounts/get")
        ? { status: 200, body: { item: {} } }
        : { status: 404, body: {} },
    database,
  });
  assertJsonEquals(missingArray, { kind: "plaid_payload_invalid" });
  assertEquals(state.persisted.length, 0);
});

Deno.test("persist failure is reported, not masked", async () => {
  const { database, state } = fakeDatabase({ persistResult: null });
  const result = await refresh({
    responder: accountsOk([account("a1")]),
    database,
  });

  assertJsonEquals(result, { kind: "persist_failed" });
  assertEquals(state.persisted.length, 1);
});

Deno.test("access token and Plaid credentials never appear in results or persist args", async () => {
  const scenarios: Array<{
    responder: PlaidResponder;
    options?: Parameters<typeof fakeDatabase>[0];
  }> = [
    { responder: accountsOk([account("a1")]) },
    { responder: plaidError("ITEM_LOGIN_REQUIRED") },
    { responder: plaidError("ITEM_NOT_FOUND") },
    { responder: plaidError("INSTITUTION_DOWN") },
    { responder: accountsOk([account("a1", { name: null })]) },
    {
      responder: accountsOk([account("a1")]),
      options: { persistResult: null },
    },
    { responder: accountsOk([account("a1")]), options: { stored: "failed" } },
  ];

  for (const scenario of scenarios) {
    const { database, state } = fakeDatabase(scenario.options);
    const result = await refresh({ responder: scenario.responder, database });
    assertNoSecrets(result);
    assertNoSecrets(state.persisted);
    assertNoSecrets(state.observations);
  }
});

Deno.test("Plaid credentials are sent only as headers", async () => {
  const headers: Headers[] = [];
  const fetchImpl = ((_input: RequestInfo | URL, init?: RequestInit) => {
    headers.push(new Headers(init?.headers));
    if (String(init?.body).includes(plaidSecret)) {
      throw new Error("secret leaked into request body");
    }
    return Promise.resolve(
      new Response(JSON.stringify(accountsGetPayload([account("a1")]))),
    );
  }) as typeof fetch;
  const { database } = fakeDatabase();

  await refreshPlaidAccountsForItem({
    userId,
    connectionId,
    database,
    fetchImpl,
    clientId,
    secret: plaidSecret,
    now: () => now,
    institutionSource: "stored",
  });

  assertEquals(headers.length, 1);
  assertEquals(headers[0].get("PLAID-CLIENT-ID"), clientId);
  assertEquals(headers[0].get("PLAID-SECRET"), plaidSecret);
});

Deno.test("normalizePlaidAccounts keeps the existing mapping contract", () => {
  assertJsonEquals(
    normalizePlaidAccounts([
      account(" a1 ", {
        official_name: " Official ",
        mask: " ",
        subtype: null,
        persistent_account_id: " pai ",
        balances: {
          current: "12.5",
          available: "x",
          iso_currency_code: null,
          unofficial_currency_code: "BTC",
        },
      }),
    ]),
    [{
      plaid_account_id: "a1",
      name: "Account  a1",
      official_name: "Official",
      mask: null,
      plaid_type: "depository",
      plaid_subtype: null,
      currency_code: null,
      unofficial_currency_code: "BTC",
      current_balance: 12.5,
      available_balance: null,
      persistent_account_id: "pai",
    }],
  );
  assertEquals(normalizePlaidAccounts(null), null);
  assertJsonEquals(normalizePlaidAccounts([]), []);
});
