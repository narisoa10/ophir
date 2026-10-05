import {
  connectItemErrorResult,
  type ConnectItemParams,
  type ConnectItemResult,
  parseConnectItemResult,
  type PlaidItemLookup,
  plaidItemLookupFromRows,
} from "./connect_item.ts";
import {
  createPlaidExchangeHandler,
  type ExchangeDatabase,
} from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const otherUserId = "33333333-3333-4333-8333-333333333333";
const connectionId = "22222222-2222-4222-8222-222222222222";
const existingConnectionId = "44444444-4444-4444-8444-444444444444";
const publicToken = "public-sandbox-a3-fixture-token";
const accessToken = "access-sandbox-a3-fixture-token";
const clientId = "client-id-a3-fixture";
const plaidSecret = "sandbox-secret-a3-fixture";
const plaidItemId = "plaid-item-a3";
const secrets = [publicToken, accessToken, clientId, plaidSecret];

const exchangePath = "/item/public_token/exchange";
const accountsPath = "/accounts/get";
const institutionPath = "/institutions/get_by_id";
const removePath = "/item/remove";

type Row = Record<string, unknown>;
type PlaidReply =
  | { status: number; body: unknown }
  | { status: number; raw: string }
  | "network"
  | "hang";
type Lookup = PlaidItemLookup | "throw";

type Options = {
  body?: Row;
  exchange?: PlaidReply;
  accounts?: PlaidReply;
  institution?: PlaidReply;
  remove?: PlaidReply;
  connect?: ConnectItemResult | "throw";
  lookup?: Lookup | ((plaidItemId: string) => Lookup);
  institutions?: Row[];
  items?: Row[];
  storedAccounts?: Row[];
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

function assertJsonEquals(actual: unknown, expected: unknown): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`Expected ${e}, got ${a}`);
  }
}

function plaidAccount(accountId: string, name: string, mask: string): Row {
  return {
    account_id: accountId,
    name,
    official_name: null,
    mask,
    type: "depository",
    subtype: "checking",
    balances: {
      current: 10,
      available: 9,
      iso_currency_code: "CAD",
      unofficial_currency_code: null,
    },
  };
}

function accountsReply(item: Row = {}): PlaidReply {
  return {
    status: 200,
    body: {
      accounts: [
        plaidAccount("acc-selected", "Checking", "0000"),
        plaidAccount("acc-unselected", "Savings", "1111"),
      ],
      item: {
        item_id: plaidItemId,
        institution_id: "ins_server",
        institution_name: "Item Bank",
        ...item,
      },
      request_id: "req-accounts",
    },
  };
}

function plaidError(errorCode: string, errorType = "ITEM_ERROR"): PlaidReply {
  return {
    status: 400,
    body: {
      error_type: errorType,
      error_code: errorCode,
      error_message: `failed for ${accessToken} and ${publicToken}`,
      request_id: `req-${errorCode}`,
    },
  };
}

function v2Body(extra: Row = {}): Row {
  return {
    contract_version: 2,
    public_token: publicToken,
    institution_id: "ins_client",
    selected_accounts: [{
      account_id: "acc-selected",
      name: "Checking",
      mask: "0000",
      type: "depository",
      subtype: "checking",
    }],
    ...extra,
  };
}

function v1Body(): Row {
  return {
    public_token: publicToken,
    institution_id: "ins_client",
    selected_accounts: [{ name: "Checking", mask: "0000" }],
  };
}

const created: ConnectItemResult = {
  kind: "created",
  connectionId,
  ambiguousCount: 0,
};

async function reply(spec: PlaidReply): Promise<Response> {
  if (spec === "network") {
    throw new TypeError("network down");
  }
  if (spec === "hang") {
    return await new Promise<Response>(() => {});
  }
  return new Response(
    "raw" in spec ? spec.raw : JSON.stringify(spec.body),
    { status: spec.status },
  );
}

async function run(options: Options = {}) {
  const plaidPaths: string[] = [];
  const plaidBodies: Row[] = [];
  const dbCalls: string[] = [];
  const connectParams: ConnectItemParams[] = [];
  const lookedUp: string[] = [];
  const logs: { message: string; fields: Record<string, unknown> }[] = [];

  const rows = (method: string, value: Row[] | undefined) => {
    dbCalls.push(method);
    return Promise.resolve(value ?? []);
  };

  const database: ExchangeDatabase = {
    listInstitutions: () => rows("listInstitutions", options.institutions),
    listPlaidItems: () => rows("listPlaidItems", options.items),
    listItemAccounts: () => rows("listItemAccounts", options.storedAccounts),
    listInstitutionAccounts: () =>
      rows("listInstitutionAccounts", options.storedAccounts),
    connectItem(params) {
      dbCalls.push("connectItem");
      connectParams.push(params);
      const connect = options.connect ?? created;
      return connect === "throw"
        ? Promise.reject(new Error("connection reset"))
        : Promise.resolve(connect);
    },
    findPlaidItem(receivedUserId, environment, receivedItemId) {
      dbCalls.push("findPlaidItem");
      lookedUp.push(receivedItemId);
      assertEquals(receivedUserId, userId);
      assertEquals(environment, "sandbox");
      const spec = typeof options.lookup === "function"
        ? options.lookup(receivedItemId)
        : options.lookup ?? { kind: "absent" };
      return spec === "throw"
        ? Promise.reject(new Error("read-back exploded"))
        : Promise.resolve(spec);
    },
  };

  const handler = createPlaidExchangeHandler({
    authenticateRequest: () => Promise.resolve({ id: userId }),
    createDatabase: () => database,
    getEnv: (name) =>
      ({
        PLAID_CLIENT_ID: clientId,
        PLAID_SANDBOX_SECRET: plaidSecret,
      } as Record<string, string>)[name],
    plaidTimeoutMs: 20,
    fetch: async (url, init) => {
      const path = new URL(url.toString()).pathname;
      plaidPaths.push(path);
      plaidBodies.push(JSON.parse(String(init?.body)));
      switch (path) {
        case exchangePath:
          return await reply(
            options.exchange ?? {
              status: 200,
              body: {
                access_token: accessToken,
                item_id: plaidItemId,
                request_id: "req-exchange",
              },
            },
          );
        case accountsPath:
          return await reply(options.accounts ?? accountsReply());
        case institutionPath:
          return await reply(
            options.institution ?? {
              status: 200,
              body: {
                institution: {
                  institution_id: "ins_server",
                  name: "Server Bank",
                  logo: "logo-base64",
                  primary_color: "#112233",
                  url: "https://bank.example",
                },
                request_id: "req-institution",
              },
            },
          );
        case removePath:
          return await reply(
            options.remove ??
              { status: 200, body: { request_id: "req-remove" } },
          );
        default:
          throw new Error(`unexpected Plaid path ${path}`);
      }
    },
    log: (message, fields) => logs.push({ message, fields }),
  });

  const response = await handler(
    new Request("http://localhost/plaid-exchange-public-token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(options.body ?? v2Body()),
    }),
  );
  const text = await response.text();

  const exposed = JSON.stringify(logs) + text;
  for (const secret of secrets) {
    assert(!exposed.includes(secret), `log or response leaked ${secret}`);
  }

  return {
    status: response.status,
    json: JSON.parse(text),
    plaidPaths,
    plaidBodies,
    dbCalls,
    connectParams,
    lookedUp,
    logs,
    messages: logs.map((log) => log.message),
    removeCalls: plaidPaths.filter((path) => path === removePath).length,
  };
}

type Result = Awaited<ReturnType<typeof run>>;

function logOf(result: Result, message: string): Record<string, unknown> {
  const entry = result.logs.find((log) => log.message === message);
  assert(entry !== undefined, `missing log ${message}: ${result.messages}`);
  return entry!.fields;
}

function assertFailure(result: Result, status: number, code: string): void {
  assertEquals(result.status, status);
  assertEquals(result.json.error.code, code);
}

function assertConnected(result: Result, id = connectionId): void {
  assertEquals(result.status, 200);
  assertJsonEquals(result.json, { connection_id: id });
}

// --- 1-4: before persistence ---------------------------------------------------

Deno.test("A3-1 Level 1 duplicate still blocks before any Plaid call", async () => {
  const stored = {
    institutions: [{ id: "institution-1", plaid_item_id: "item-1" }],
    items: [{ id: "item-1", disconnected_at: null }],
    storedAccounts: [{
      plaid_item_id: "item-1",
      plaid_account_id: "stored-1",
      name: "Checking",
      official_name: null,
      mask: "0000",
      plaid_type: "depository",
      plaid_subtype: "checking",
    }],
  };

  const v2 = await run(stored);
  assertEquals(v2.status, 200);
  assertJsonEquals(v2.json, {
    status: "duplicate",
    accounts: [{ index: 0, decision: "duplicate" }],
  });
  assertEquals(v2.plaidPaths.length, 0);

  const v1 = await run({ ...stored, body: v1Body() });
  assertJsonEquals(v1.json, { status: "duplicate" });
  assertEquals(v1.plaidPaths.length, 0);
});

Deno.test("A3-2/3/4 exchange failures stop before accounts, persistence and removal", async () => {
  for (
    const exchange of [
      plaidError("INVALID_PUBLIC_TOKEN", "INVALID_INPUT"),
      "network",
      "hang",
      { status: 200, body: { item_id: plaidItemId } },
      { status: 200, raw: "not json" },
    ] as PlaidReply[]
  ) {
    const result = await run({ exchange });
    assertFailure(result, 502, "plaid_request_failed");
    assertJsonEquals(result.plaidPaths, [exchangePath]);
    assertEquals(result.dbCalls.includes("connectItem"), false);
    assertEquals(result.dbCalls.includes("findPlaidItem"), false);
    assertJsonEquals(result.messages, ["plaid_exchange_failed"]);
  }

  const hung = await run({ exchange: "hang" });
  assertEquals(logOf(hung, "plaid_exchange_failed").reason, "timeout");
});

// --- 5-8: authoritative account snapshot --------------------------------------

Deno.test("A3-5/6/7 accounts/get failure removes the unsaved Item and keeps 502", async () => {
  for (
    const accounts of [
      plaidError("ITEM_LOGIN_REQUIRED"),
      "network",
      "hang",
      { status: 200, body: { accounts: [], request_id: "req-accounts" } },
      { status: 200, raw: "<html>" },
    ] as PlaidReply[]
  ) {
    const result = await run({ accounts });
    assertFailure(result, 502, "plaid_request_failed");
    assertJsonEquals(result.plaidPaths, [
      exchangePath,
      accountsPath,
      removePath,
    ]);
    assertJsonEquals(result.lookedUp, [plaidItemId]);
    assertEquals(result.dbCalls.includes("connectItem"), false);
    assertEquals(
      logOf(result, "plaid_accounts_get_failed").operation,
      accountsPath,
    );
    const removed = logOf(result, "plaid_connect_compensation_removed");
    assertEquals(removed.reason, "accounts_get_failed");
    assertEquals(removed.plaid_item_id, plaidItemId);
    assertJsonEquals(result.plaidBodies[2], { access_token: accessToken });
  }
});

Deno.test("A3-8 Item-ID mismatch never persists and removes only when both ids are unknown", async () => {
  const mismatch = accountsReply({ item_id: "plaid-item-other" });

  const absent = await run({ accounts: mismatch });
  assertFailure(absent, 500, "persist_failed");
  assertEquals(absent.dbCalls.includes("connectItem"), false);
  assertJsonEquals(absent.lookedUp, [plaidItemId, "plaid-item-other"]);
  assertEquals(absent.removeCalls, 1);
  assertEquals(
    logOf(absent, "plaid_item_id_mismatch").accounts_request_id,
    "req-accounts",
  );
  assertEquals(
    logOf(absent, "plaid_connect_compensation_removed").reason,
    "item_id_mismatch",
  );

  const otherKnown = await run({
    accounts: mismatch,
    lookup: (id) =>
      id === "plaid-item-other"
        ? {
          kind: "owned",
          connectionId: existingConnectionId,
          disconnected: false,
        }
        : { kind: "absent" },
  });
  assertFailure(otherKnown, 500, "persist_failed");
  assertEquals(otherKnown.removeCalls, 0);
  assertEquals(
    logOf(otherKnown, "plaid_connect_compensation_skipped").readback,
    "owned",
  );
});

// --- 9-11: institution metadata (AD3) -----------------------------------------

Deno.test("A3-9 institution metadata comes from Plaid, never from the client, with the full account snapshot", async () => {
  const result = await run();
  assertConnected(result);
  assertJsonEquals(result.plaidPaths, [
    exchangePath,
    accountsPath,
    institutionPath,
  ]);
  assertEquals(result.plaidBodies[2].institution_id, "ins_server");

  const params = result.connectParams[0];
  assertEquals(params.userId, userId);
  assertEquals(params.environment, "sandbox");
  assertEquals(params.plaidItemId, plaidItemId);
  assertEquals(params.accessToken, accessToken);
  assertEquals(params.plaidInstitutionId, "ins_server");
  assertEquals(params.institutionName, "Server Bank");
  assertEquals(params.logoBase64, "logo-base64");
  assertEquals(params.primaryColor, "#112233");
  assertEquals(params.url, "https://bank.example");
  assert(!Number.isNaN(Date.parse(params.balanceFetchedAt)), "timestamp");
  assertJsonEquals(
    params.accounts.map((account) => account.plaid_account_id),
    ["acc-selected", "acc-unselected"],
  );
});

Deno.test("A3-10 missing institution metadata follows the non-fatal AD3 path", async () => {
  const noInstitutionId = await run({
    accounts: accountsReply({ institution_id: null }),
  });
  assertConnected(noInstitutionId);
  assertEquals(noInstitutionId.plaidPaths.includes(institutionPath), false);
  const params = noInstitutionId.connectParams[0];
  assertEquals(params.plaidInstitutionId, null);
  assertEquals(params.institutionName, "Item Bank");
  assertEquals(params.logoBase64, null);

  const noName = await run({
    accounts: accountsReply({ institution_name: null }),
    institution: { status: 200, body: { institution: {} } },
  });
  assertConnected(noName);
  assertEquals(noName.connectParams[0].institutionName, null);
  assertEquals(noName.connectParams[0].plaidInstitutionId, "ins_server");
});

Deno.test("A3-11 institution lookup failure is logged and does not block the connection", async () => {
  for (
    const institution of [
      plaidError("INVALID_INSTITUTION", "INVALID_INPUT"),
      "network",
      "hang",
      { status: 200, body: { request_id: "req-institution" } },
    ] as PlaidReply[]
  ) {
    const result = await run({ institution });
    assertConnected(result);
    assertEquals(result.removeCalls, 0);
    assertEquals(result.connectParams[0].institutionName, "Item Bank");
    assertEquals(result.connectParams[0].logoBase64, null);
    assertEquals(
      logOf(result, "plaid_institution_lookup_failed").operation,
      institutionPath,
    );
  }
});

// --- 12-15: RPC outcomes -------------------------------------------------------

Deno.test("A3-12/26 created returns connection_id for v1 and v2 and never removes", async () => {
  for (const body of [v2Body(), v1Body()]) {
    const result = await run({ body });
    assertConnected(result);
    assertEquals(result.removeCalls, 0);
    assertEquals(result.dbCalls.includes("findPlaidItem"), false);
    assertEquals(result.dbCalls.filter((c) => c === "connectItem").length, 1);
    assertEquals(result.logs.length, 0);
  }
});

Deno.test("A3-13/27 idempotent_existing is success without removal or a second write", async () => {
  for (const body of [v2Body(), v1Body()]) {
    const result = await run({
      body,
      connect: {
        kind: "idempotent_existing",
        connectionId: existingConnectionId,
      },
    });
    assertConnected(result, existingConnectionId);
    assertEquals(result.removeCalls, 0);
    assertEquals(result.dbCalls.includes("findPlaidItem"), false);
    assertEquals(result.dbCalls.filter((c) => c === "connectItem").length, 1);
    logOf(result, "plaid_connect_idempotent_existing");
  }
});

Deno.test("A3-14 strong_duplicate keeps the duplicate shape and removes only the proven-unsaved Item", async () => {
  for (const body of [v2Body(), v1Body()]) {
    const result = await run({
      body,
      connect: { kind: "strong_duplicate", blockingCount: 1 },
    });
    assertEquals(result.status, 200);
    assertJsonEquals(result.json, { status: "duplicate" });
    assertJsonEquals(result.lookedUp, [plaidItemId]);
    assertEquals(result.removeCalls, 1);
    assertEquals(
      logOf(result, "plaid_connect_compensation_removed").reason,
      "strong_duplicate",
    );
  }

  for (
    const lookup of [
      { kind: "failed" },
      "throw",
      { kind: "foreign" },
      {
        kind: "owned",
        connectionId: existingConnectionId,
        disconnected: false,
      },
    ] as Lookup[]
  ) {
    const result = await run({
      connect: { kind: "strong_duplicate", blockingCount: 1 },
      lookup,
    });
    assertJsonEquals(result.json, { status: "duplicate" });
    assertEquals(result.removeCalls, 0);
    logOf(result, "plaid_connect_compensation_skipped");
  }
});

Deno.test("A3-15 ambiguous accounts are created, logged by count and never treated as duplicates", async () => {
  const result = await run({
    connect: { kind: "created", connectionId, ambiguousCount: 2 },
  });
  assertConnected(result);
  assertEquals(result.removeCalls, 0);
  assertEquals(
    logOf(result, "plaid_connect_ambiguous_accounts").ambiguous_count,
    2,
  );

  assertJsonEquals(
    parseConnectItemResult({
      outcome: "strong_duplicate",
      decisions: [{ index: 0, decision: "ambiguous" }],
    }),
    { kind: "uncertain", code: null },
  );
});

// --- 16-20: failed persistence and read-back -----------------------------------

const rejected: ConnectItemResult = {
  kind: "definitively_rejected",
  code: "P0001",
};

function assertUncertainSkip(result: Result, readback: string): void {
  assertFailure(result, 500, "persist_failed");
  assertEquals(result.removeCalls, 0);
  assertJsonEquals(result.lookedUp, [plaidItemId]);
  const skipped = logOf(result, "plaid_connect_compensation_skipped");
  assertEquals(skipped.reason, "persist_uncertain");
  assertEquals(skipped.readback, readback);
  assertEquals(
    result.messages.includes("plaid_connect_compensation_removed"),
    false,
  );
}

// An uncertain RPC may still be running: no read-back result may lead to
// /item/remove, because the RPC can commit after the read.
Deno.test("A3-19/U1 uncertain RPC with the Item absent never removes it", async () => {
  for (
    const connect of [
      { kind: "uncertain", code: null },
      { kind: "uncertain", code: "08006" },
      "throw",
    ] as const
  ) {
    const result = await run({ connect });
    assertUncertainSkip(result, "absent");
    assertEquals(
      logOf(result, "plaid_connect_persist_failed").result,
      "uncertain",
    );
  }
});

Deno.test("A3-17/U2 uncertain RPC whose commit is found by read-back is success", async () => {
  for (const connect of [{ kind: "uncertain", code: null }, "throw"] as const) {
    const result = await run({
      connect,
      lookup: { kind: "owned", connectionId, disconnected: false },
    });
    assertConnected(result);
    assertEquals(result.removeCalls, 0);
    logOf(result, "plaid_connect_persist_recovered");
  }
});

Deno.test("A3-18/U3 uncertain RPC with the Item owned by another user never removes", async () => {
  const result = await run({
    connect: { kind: "uncertain", code: null },
    lookup: { kind: "foreign" },
  });
  assertUncertainSkip(result, "foreign");
});

Deno.test("A3-20/U4 uncertain RPC with a failed read-back never removes", async () => {
  for (const lookup of [{ kind: "failed" }, "throw"] as Lookup[]) {
    const result = await run({
      connect: { kind: "uncertain", code: null },
      lookup,
    });
    assertUncertainSkip(result, "failed");
  }
});

Deno.test("U5 uncertain RPC with a disconnected Item of this user never removes", async () => {
  const result = await run({
    connect: { kind: "uncertain", code: null },
    lookup: { kind: "owned", connectionId, disconnected: true },
  });
  assertUncertainSkip(result, "owned_disconnected");
});

Deno.test("A3-16/R1 definitively rejected RPC with the Item absent removes it after one read-back", async () => {
  for (const code of ["22023", "P0001", "23505", "PGRST202"]) {
    const result = await run({
      connect: { kind: "definitively_rejected", code },
    });
    assertFailure(result, 500, "persist_failed");
    assertJsonEquals(result.lookedUp, [plaidItemId]);
    assertEquals(result.removeCalls, 1);
    assertEquals(logOf(result, "plaid_connect_persist_failed").code, code);
    assertEquals(
      logOf(result, "plaid_connect_compensation_removed").reason,
      "persist_rejected",
    );
  }
});

Deno.test("R2 definitively rejected RPC with the Item stored for this user is success", async () => {
  const result = await run({
    connect: rejected,
    lookup: { kind: "owned", connectionId, disconnected: false },
  });
  assertConnected(result);
  assertEquals(result.removeCalls, 0);
});

Deno.test("R2b definitively rejected RPC fails closed on any non-absent read-back", async () => {
  for (
    const [lookup, readback] of [
      [{ kind: "foreign" }, "foreign"],
      [{ kind: "failed" }, "failed"],
      ["throw", "failed"],
      [
        { kind: "owned", connectionId, disconnected: true },
        "owned_disconnected",
      ],
    ] as [Lookup, string][]
  ) {
    const result = await run({ connect: rejected, lookup });
    assertFailure(result, 500, "persist_failed");
    assertEquals(result.removeCalls, 0);
    const skipped = logOf(result, "plaid_connect_compensation_skipped");
    assertEquals(skipped.reason, "persist_rejected");
    assertEquals(skipped.readback, readback);
  }
});

Deno.test("R3 SQLSTATE class 08 is uncertain and never removes an absent Item", async () => {
  for (const code of ["08000", "08003", "08006", "08P01"]) {
    for (const status of [400, 500, 503]) {
      const connect = connectItemErrorResult({ code }, status);
      assertJsonEquals(connect, { kind: "uncertain", code });

      const result = await run({ connect });
      assertUncertainSkip(result, "absent");
    }
  }
});

// A call canceled while waiting for the advisory lock proves nothing about the
// execution holding it, which may still commit the same Item.
Deno.test("R4 57014 is uncertain and never removes an absent Item", async () => {
  for (const status of [400, 500, 503]) {
    const connect = connectItemErrorResult({ code: "57014" }, status);
    assertJsonEquals(connect, { kind: "uncertain", code: "57014" });

    const result = await run({ connect });
    assertUncertainSkip(result, "absent");
    const failed = logOf(result, "plaid_connect_persist_failed");
    assertEquals(failed.result, "uncertain");
    assertEquals(failed.code, "57014");
  }
});

Deno.test("R5 57014 with the Item committed for this user is success", async () => {
  const result = await run({
    connect: connectItemErrorResult({ code: "57014" }, 500),
    lookup: { kind: "owned", connectionId, disconnected: false },
  });
  assertConnected(result);
  assertJsonEquals(result.lookedUp, [plaidItemId]);
  assertEquals(result.removeCalls, 0);
  logOf(result, "plaid_connect_persist_recovered");
});

// --- 21-24: compensation results -----------------------------------------------

Deno.test("A3-21 successful removal is logged with its request id", async () => {
  const result = await run({ connect: rejected });
  const removed = logOf(result, "plaid_connect_compensation_removed");
  assertEquals(removed.request_id, "req-remove");
  assertEquals(removed.user_id, userId);
  assertEquals(removed.exchange_request_id, "req-exchange");
});

Deno.test("A3-22 removal Plaid error keeps the original failure and logs cleanup metadata", async () => {
  const result = await run({
    connect: rejected,
    remove: plaidError("INTERNAL_SERVER_ERROR", "API_ERROR"),
  });
  assertFailure(result, 500, "persist_failed");
  assertEquals(result.removeCalls, 1);
  const failed = logOf(result, "plaid_connect_compensation_failed");
  assertEquals(failed.failure, "plaid_error");
  assertEquals(failed.error_code, "INTERNAL_SERVER_ERROR");
  assertEquals(failed.plaid_item_id, plaidItemId);
  assertEquals(failed.reason, "persist_rejected");

  const alreadyGone = await run({
    connect: rejected,
    remove: plaidError("ITEM_NOT_FOUND"),
  });
  assertEquals(
    logOf(alreadyGone, "plaid_connect_compensation_removed").already_removed,
    true,
  );
});

Deno.test("A3-23 removal timeout or network failure is logged once, without retries", async () => {
  for (
    const [remove, reason] of [["network", "network"], [
      "hang",
      "timeout",
    ]] as const
  ) {
    const result = await run({ connect: rejected, remove });
    assertFailure(result, 500, "persist_failed");
    assertEquals(result.removeCalls, 1);
    const failed = logOf(result, "plaid_connect_compensation_failed");
    assertEquals(failed.failure, "transport_error");
    assertEquals(failed.reason, reason);
  }

  const accountsFailed = await run({ accounts: "network", remove: "hang" });
  assertFailure(accountsFailed, 502, "plaid_request_failed");
  assertEquals(accountsFailed.removeCalls, 1);
});

Deno.test("A3-24 malformed removal response is a compensation failure", async () => {
  for (
    const remove of [
      { status: 200, body: {} },
      { status: 200, raw: "OK" },
      { status: 503, body: { request_id: "req-503" } },
    ] as PlaidReply[]
  ) {
    const result = await run({
      connect: { kind: "strong_duplicate", blockingCount: 1 },
      remove,
    });
    assertJsonEquals(result.json, { status: "duplicate" });
    assertEquals(
      logOf(result, "plaid_connect_compensation_failed").failure,
      "malformed_response",
    );
  }
});

// --- 25: lost responses ----------------------------------------------------------

Deno.test("A3-25 lost responses never remove a committed Item", async () => {
  // The RPC committed but its answer was lost on the way back to Edge.
  const lostRpcAnswer = await run({
    connect: "throw",
    lookup: { kind: "owned", connectionId, disconnected: false },
  });
  assertConnected(lostRpcAnswer);
  assertEquals(lostRpcAnswer.removeCalls, 0);

  // The client retries after losing the 200: the public token is single-use.
  const retriedToken = await run({
    exchange: plaidError("INVALID_PUBLIC_TOKEN", "INVALID_INPUT"),
  });
  assertFailure(retriedToken, 502, "plaid_request_failed");
  assertEquals(retriedToken.removeCalls, 0);
  assertEquals(retriedToken.dbCalls.includes("connectItem"), false);

  // A retry that reaches an already stored Item is idempotent.
  const retriedItem = await run({
    connect: { kind: "idempotent_existing", connectionId },
  });
  assertConnected(retriedItem);
  assertEquals(retriedItem.removeCalls, 0);
});

// --- adapters ------------------------------------------------------------------

Deno.test("RPC result parser accepts only the documented outcomes", () => {
  assertJsonEquals(
    parseConnectItemResult({
      outcome: "created",
      connection_id: connectionId,
      accounts_persisted: 2,
      institution_persisted: true,
      decisions: [
        { index: 0, decision: "new" },
        { index: 1, decision: "ambiguous" },
      ],
    }),
    { kind: "created", connectionId, ambiguousCount: 1 },
  );
  assertJsonEquals(
    parseConnectItemResult({
      outcome: "idempotent_existing",
      connection_id: connectionId,
    }),
    { kind: "idempotent_existing", connectionId },
  );
  assertJsonEquals(
    parseConnectItemResult({
      outcome: "strong_duplicate",
      decisions: [
        { index: 0, decision: "duplicate" },
        { index: 1, decision: "disconnected_existing" },
        { index: 2, decision: "new" },
      ],
    }),
    { kind: "strong_duplicate", blockingCount: 2 },
  );

  for (
    const data of [
      null,
      "created",
      [],
      { outcome: "created", decisions: [] },
      { outcome: "created", connection_id: connectionId },
      {
        outcome: "created",
        connection_id: connectionId,
        decisions: [{ decision: "maybe" }],
      },
      { outcome: "idempotent_existing" },
      { outcome: "strong_duplicate", decisions: [] },
      { outcome: "partial" },
    ]
  ) {
    assertJsonEquals(parseConnectItemResult(data), {
      kind: "uncertain",
      code: null,
    });
  }
});

Deno.test("RPC error adapter treats only proven rollbacks as definitively rejected", () => {
  for (
    const [code, status] of [
      ["23505", 409],
      ["22023", 400],
      ["P0001", 400],
      ["42883", 404],
      ["40001", 500],
      ["40P01", 500],
      ["P0004", 500],
      ["PGRST202", 404],
      ["PGRST301", 401],
    ] as const
  ) {
    assertJsonEquals(connectItemErrorResult({ code, message: "x" }, status), {
      kind: "definitively_rejected",
      code,
    });
  }
});

Deno.test("RPC error adapter keeps connection, server and gateway failures uncertain", () => {
  for (
    const [code, status] of [
      ["08006", 503],
      ["08000", 500],
      ["08003", 400],
      ["08P01", 500],
      ["40003", 500],
      ["57014", 400],
      ["57014", 500],
      ["57014", 503],
      ["57P01", 503],
      ["53300", 503],
      ["58030", 500],
      ["XX000", 500],
      ["PGRST000", 503],
      ["PGRST001", 503],
      ["PGRST003", 504],
      ["PGRST116", 406],
      ["23505", 0],
      ["23505", 502],
      ["23505", 504],
      ["P0001", 200],
    ] as const
  ) {
    assertJsonEquals(connectItemErrorResult({ code, message: "x" }, status), {
      kind: "uncertain",
      code,
    });
  }

  for (
    const [error, status] of [
      [{ code: "", message: "TypeError: fetch failed" }, 0],
      [{ code: "EPIPE" }, 0],
      [{ code: "ECONNRESET" }, 502],
      [{ code: "BAD_GATEWAY", message: "upstream" }, 502],
      [{ message: "Bad Gateway" }, 502],
      [{ code: 23505 }, 409],
      [{}, 500],
      ["boom", 500],
      [null, 500],
      [{ code: "23505" }, undefined],
      [{ code: "23505" }, "409"],
    ] as const
  ) {
    assertEquals(connectItemErrorResult(error, status).kind, "uncertain");
  }
  assertJsonEquals(connectItemErrorResult({ code: "EPIPE" }, 0), {
    kind: "uncertain",
    code: "EPIPE",
  });
});

Deno.test("read-back adapter classifies ownership and fails closed", () => {
  assertJsonEquals(plaidItemLookupFromRows([], null, userId), {
    kind: "absent",
  });
  assertJsonEquals(
    plaidItemLookupFromRows(
      [{ id: connectionId, user_id: userId, disconnected_at: null }],
      null,
      userId,
    ),
    { kind: "owned", connectionId, disconnected: false },
  );
  assertJsonEquals(
    plaidItemLookupFromRows(
      [{ id: connectionId, user_id: userId, disconnected_at: "2026-10-01" }],
      null,
      userId,
    ),
    { kind: "owned", connectionId, disconnected: true },
  );
  assertJsonEquals(
    plaidItemLookupFromRows(
      [{ id: connectionId, user_id: otherUserId, disconnected_at: null }],
      null,
      userId,
    ),
    { kind: "foreign" },
  );

  for (
    const [data, error] of [
      [null, { code: "PGRST000" }],
      [[], { code: "57014" }],
      [null, null],
      [[{ id: connectionId }], null],
      [[{ id: connectionId, user_id: userId, disconnected_at: 5 }], null],
      [[
        { id: connectionId, user_id: userId, disconnected_at: null },
        { id: existingConnectionId, user_id: userId, disconnected_at: null },
      ], null],
    ] as const
  ) {
    assertJsonEquals(plaidItemLookupFromRows(data, error, userId), {
      kind: "failed",
    });
  }
});
