import {
  aggregateLink,
  type AccountDecision,
  classifyAccount,
  type ExistingAccount,
  type IncomingAccount,
  type LinkClassification,
} from "./account_identity.ts";
import { createPlaidExchangeHandler, type ExchangeDatabase } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const publicToken = "public-sandbox-fixture";
const accessToken = "access-sandbox-fixture";
const plaidItemId = "plaid-item-fixture";

type DatabaseMethod =
  | "listInstitutions"
  | "listPlaidItems"
  | "listItemAccounts"
  | "listInstitutionAccounts"
  | "persistSandboxItem";

type Row = Record<string, unknown>;

type Classify = (
  incoming: readonly IncomingAccount[],
  existing: readonly ExistingAccount[],
  confirmAmbiguous: boolean,
) => LinkClassification | null;

type HarnessOptions = {
  institutions?: Row[];
  items?: Row[];
  accounts?: Row[];
  legacyAccounts?: Row[];
  failing?: DatabaseMethod;
  throwing?: DatabaseMethod;
  classifyLink?: Classify;
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

function institution(itemId = "item-1", id = "institution-1"): Row {
  return { id, plaid_item_id: itemId };
}

function item(id = "item-1", disconnectedAt: string | null = null): Row {
  return { id, disconnected_at: disconnectedAt };
}

function storedAccount(overrides: Row = {}): Row {
  return {
    plaid_item_id: "item-1",
    plaid_account_id: "stored-account-1",
    name: "Checking",
    official_name: "Gold Standard Checking",
    mask: "0000",
    plaid_type: "depository",
    plaid_subtype: "checking",
    ...overrides,
  };
}

function selected(overrides: Row = {}): Row {
  return {
    account_id: "incoming-account-1",
    name: "Checking",
    mask: "0000",
    type: "depository",
    subtype: "checking",
    ...overrides,
  };
}

function v2Body(accounts: Row[], extra: Row = {}): Row {
  return {
    contract_version: 2,
    public_token: publicToken,
    institution_id: "ins_1",
    selected_accounts: accounts,
    ...extra,
  };
}

function v1Body(accounts: Row[] = [{ name: "Checking", mask: "0000" }]): Row {
  return {
    public_token: publicToken,
    institution_id: "ins_1",
    selected_accounts: accounts,
  };
}

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const accessedDatabaseMembers = new Set<string>();
  let exchangeCalls = 0;
  const exchangeBodies: Row[] = [];

  const respond = async (
    method: DatabaseMethod,
    rows: Row[] | undefined,
  ): Promise<Row[] | null> => {
    calls.push(method);
    if (options.throwing === method) {
      throw new Error("database exploded");
    }
    if (options.failing === method) {
      return null;
    }
    return rows ?? [];
  };

  const database: ExchangeDatabase = {
    listInstitutions: () => respond("listInstitutions", options.institutions),
    listPlaidItems: () => respond("listPlaidItems", options.items),
    listItemAccounts: () => respond("listItemAccounts", options.accounts),
    listInstitutionAccounts: () =>
      respond("listInstitutionAccounts", options.legacyAccounts),
    async persistSandboxItem(receivedUserId, receivedItemId, receivedToken) {
      calls.push("persistSandboxItem");
      if (options.throwing === "persistSandboxItem") {
        throw new Error("persist exploded");
      }
      if (
        options.failing === "persistSandboxItem" ||
        receivedUserId !== userId ||
        receivedItemId !== plaidItemId ||
        receivedToken !== accessToken
      ) {
        return null;
      }
      return connectionId;
    },
  };

  const recordingDatabase = new Proxy(database, {
    get(target, property, receiver) {
      accessedDatabaseMembers.add(String(property));
      return Reflect.get(target, property, receiver);
    },
  });

  const handler = createPlaidExchangeHandler({
    authenticateRequest: async () => ({ id: userId }),
    createDatabase: () => recordingDatabase,
    getEnv: (name) =>
      ({
        PLAID_CLIENT_ID: "client-id",
        PLAID_SANDBOX_SECRET: "sandbox-secret",
      } as Record<string, string>)[name],
    fetch: async (_url, init) => {
      exchangeCalls += 1;
      exchangeBodies.push(JSON.parse(String(init?.body)));
      return new Response(
        JSON.stringify({
          access_token: accessToken,
          item_id: plaidItemId,
          request_id: "request-id",
        }),
        { status: 200 },
      );
    },
    ...(options.classifyLink ? { classifyLink: options.classifyLink } : {}),
  });

  async function send(body: unknown) {
    const response = await handler(
      new Request("http://localhost/plaid-exchange-public-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }),
    );
    const text = await response.text();
    return { status: response.status, text, json: JSON.parse(text) };
  }

  return {
    send,
    calls,
    accessedDatabaseMembers,
    exchangeBodies,
    get exchangeCalls() {
      return exchangeCalls;
    },
  };
}

function oneActiveAccount(account: Row = storedAccount()): HarnessOptions {
  return {
    institutions: [institution()],
    items: [item()],
    accounts: [account],
  };
}

function decisions(json: Record<string, unknown>): unknown {
  return json.accounts;
}

const storedDisplay = { name: "Checking", subtype: "checking", mask: "0000" };

function ambiguousReview(index = 0, candidates: Row[] = [storedDisplay]): Row {
  return { index, decision: "ambiguous", candidates };
}

// --- v2: NEW ---------------------------------------------------------------

Deno.test("1 new account exchanges and persists", async () => {
  const harness = createHarness({});
  const result = await harness.send(v2Body([selected()]));

  assertEquals(result.status, 200);
  assertJsonEquals(result.json, { connection_id: connectionId });
  assertEquals(harness.exchangeCalls, 1);
  assertEquals(harness.exchangeBodies[0].public_token, publicToken);
  assertEquals(harness.calls.at(-1), "persistSandboxItem");
});

Deno.test("3 same institution but a different account exchanges", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ name: "Savings", mask: "1111", subtype: "savings" })]),
  );

  assertEquals(result.status, 200);
  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
});

Deno.test("4 same name with a different mask and a known type conflict is new", async () => {
  for (const conflict of [{ type: "credit" }, { subtype: "savings" }]) {
    const harness = createHarness(oneActiveAccount());
    const result = await harness.send(
      v2Body([selected({ mask: "9999", ...conflict })]),
    );

    assertEquals(result.json.connection_id, connectionId);
    assertEquals(harness.exchangeCalls, 1);
  }
});

Deno.test("different name and different mask is new", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ name: "Everyday Checking", mask: "9999" })]),
  );

  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
});

Deno.test("5 null mask without a name candidate is new", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ name: "Business Checking", mask: null })]),
  );

  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
});

Deno.test("13 several new accounts exchange once", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([
      selected({ account_id: "a", name: "Savings", mask: "1111" }),
      selected({ account_id: "b", name: "Credit Card", mask: "2222" }),
      selected({ account_id: "c", name: "Mortgage", mask: null }),
    ]),
  );

  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
});

Deno.test("v2 with no stored institution skips account reads and exchanges", async () => {
  const harness = createHarness({});
  await harness.send(v2Body([selected()]));

  assertJsonEquals(harness.calls, ["listInstitutions", "persistSandboxItem"]);
  assertEquals(harness.exchangeCalls, 1);
});

// --- v2: DUPLICATE -----------------------------------------------------------

Deno.test("2 active duplicate blocks exchange", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(v2Body([selected()]));

  assertEquals(result.status, 200);
  assertJsonEquals(result.json, {
    status: "duplicate",
    accounts: [{ index: 0, decision: "duplicate" }],
  });
  assertEquals(harness.exchangeCalls, 0);
  assert(!harness.calls.includes("persistSandboxItem"), "nothing persisted");
});

Deno.test("10 name matching official_name is a duplicate", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ name: "  Gold Standard Checking " })]),
  );

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("11 replayed plaid_account_id is a duplicate even if name changed", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([
      selected({
        account_id: "stored-account-1",
        name: "Renamed",
        mask: null,
      }),
    ]),
  );

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("unknown type on one side does not contradict a duplicate", async () => {
  const harness = createHarness(
    oneActiveAccount(storedAccount({ plaid_type: null, plaid_subtype: null })),
  );
  const result = await harness.send(v2Body([selected()]));

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("mask and name are compared after trimming", async () => {
  const harness = createHarness(
    oneActiveAccount(storedAccount({ name: " Checking ", mask: " 0000 " })),
  );
  const result = await harness.send(
    v2Body([selected({ name: "Checking  ", mask: "0000 " })]),
  );

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

// --- v2: AMBIGUOUS -----------------------------------------------------------

Deno.test("6 null mask with a matching name requires confirmation", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(v2Body([selected({ mask: null })]));

  assertEquals(result.status, 200);
  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [ambiguousReview()],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("same name with a different mask and the same types requires confirmation", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(v2Body([selected({ mask: "9999" })]));

  assertEquals(result.status, 200);
  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [ambiguousReview()],
  });
  assertEquals(harness.exchangeCalls, 0);
  assert(!harness.calls.includes("persistSandboxItem"), "nothing persisted");
});

Deno.test("same name with a different mask and unknown types requires confirmation", async () => {
  const unknownTypes: Array<{ incoming: Row; stored: Row }> = [
    { incoming: { type: null, subtype: null }, stored: {} },
    { incoming: {}, stored: { plaid_type: null, plaid_subtype: null } },
    { incoming: { subtype: null }, stored: { plaid_type: null } },
  ];

  for (const { incoming, stored } of unknownTypes) {
    const harness = createHarness(oneActiveAccount(storedAccount(stored)));
    const result = await harness.send(
      v2Body([selected({ mask: "9999", ...incoming })]),
    );

    assertEquals(result.json.status, "confirmation_required");
    assertEquals(harness.exchangeCalls, 0);
  }
});

Deno.test("name matching official_name with a different mask requires confirmation", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ name: "Gold Standard Checking", mask: "9999" })]),
  );

  assertEquals(result.json.status, "confirmation_required");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("different-mask match on a disconnected Item stays ambiguous", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item("item-1", "2026-10-03T00:00:00Z")],
    accounts: [storedAccount()],
  });
  const result = await harness.send(v2Body([selected({ mask: "9999" })]));

  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [ambiguousReview()],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("confirmed different-mask account exchanges after a full recheck", async () => {
  const harness = createHarness(oneActiveAccount());
  const first = await harness.send(v2Body([selected({ mask: "9999" })]));
  assertEquals(first.json.status, "confirmation_required");
  assertEquals(harness.exchangeCalls, 0);

  const readsBefore = harness.calls.filter((c) => c === "listItemAccounts")
    .length;
  const confirmed = await harness.send(
    v2Body([selected({ mask: "9999" })], { confirm_ambiguous: true }),
  );

  assertEquals(confirmed.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
  assertEquals(
    harness.calls.filter((c) => c === "listItemAccounts").length,
    readsBefore + 1,
  );
});

Deno.test("confirmation is refused when a strong match appeared meanwhile", async () => {
  const appeared = [
    { disconnectedAt: null, status: "duplicate" },
    { disconnectedAt: "2026-10-03T00:00:00Z", status: "disconnected_existing" },
  ];

  for (const { disconnectedAt, status } of appeared) {
    const options: HarnessOptions = {
      institutions: [institution()],
      items: [item("item-1", disconnectedAt)],
      accounts: [storedAccount({ mask: "1234" })],
    };
    const harness = createHarness(options);
    const first = await harness.send(v2Body([selected({ mask: "9999" })]));
    assertEquals(first.json.status, "confirmation_required");

    options.accounts!.push(
      storedAccount({ plaid_account_id: "stored-account-2", mask: "9999" }),
    );
    const confirmed = await harness.send(
      v2Body([selected({ mask: "9999" })], { confirm_ambiguous: true }),
    );

    assertEquals(confirmed.json.status, status);
    assertEquals(harness.exchangeCalls, 0);
    assert(!harness.calls.includes("persistSandboxItem"), "nothing persisted");
  }
});

Deno.test("stored null or blank mask with a matching name requires confirmation", async () => {
  for (const mask of [null, "   "]) {
    const harness = createHarness(oneActiveAccount(storedAccount({ mask })));
    const result = await harness.send(v2Body([selected()]));

    assertEquals(result.json.status, "confirmation_required");
    assertEquals(harness.exchangeCalls, 0);
  }
});

Deno.test("7 confirmed ambiguous account exchanges after a full recheck", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected({ mask: null })], { confirm_ambiguous: true }),
  );

  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
  assert(harness.calls.includes("listItemAccounts"), "rechecked server state");
});

Deno.test("8 confirm_ambiguous never overrides a duplicate", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([selected()], { confirm_ambiguous: true }),
  );

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("8b confirm_ambiguous never overrides a disconnected existing account", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item("item-1", "2026-10-03T00:00:00Z")],
    accounts: [storedAccount()],
  });
  const result = await harness.send(
    v2Body([selected()], { confirm_ambiguous: true }),
  );

  assertEquals(result.json.status, "disconnected_existing");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("9 name and mask match with conflicting type or subtype is ambiguous", async () => {
  for (const conflict of [{ type: "credit" }, { subtype: "savings" }]) {
    const harness = createHarness(oneActiveAccount());
    const result = await harness.send(v2Body([selected(conflict)]));

    assertJsonEquals(decisions(result.json), [ambiguousReview()]);
    assertEquals(result.json.status, "confirmation_required");
    assertEquals(harness.exchangeCalls, 0);
  }
});

// --- v2: DISCONNECTED_EXISTING and partial -----------------------------------

Deno.test("14 account of a disconnected Item is disconnected_existing", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item("item-1", "2026-10-03T00:00:00Z")],
    accounts: [storedAccount()],
  });
  const result = await harness.send(v2Body([selected()]));

  assertJsonEquals(result.json, {
    status: "disconnected_existing",
    accounts: [{ index: 0, decision: "disconnected_existing" }],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("an active match wins over a disconnected match of the same account", async () => {
  const harness = createHarness({
    institutions: [institution("item-1"), institution("item-2", "inst-2")],
    items: [item("item-1", "2026-10-03T00:00:00Z"), item("item-2")],
    accounts: [
      storedAccount(),
      storedAccount({ plaid_item_id: "item-2", plaid_account_id: "s-2" }),
    ],
  });
  const result = await harness.send(v2Body([selected()]));

  assertEquals(result.json.status, "duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("12 duplicate plus new is partial_duplicate", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([
      selected({ account_id: "a" }),
      selected({ account_id: "b", name: "Savings", mask: "1111" }),
    ]),
  );

  assertJsonEquals(result.json, {
    status: "partial_duplicate",
    accounts: [
      { index: 0, decision: "duplicate" },
      { index: 1, decision: "new" },
    ],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("15 disconnected plus new is partial_duplicate", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item("item-1", "2026-10-03T00:00:00Z")],
    accounts: [storedAccount()],
  });
  const result = await harness.send(
    v2Body([
      selected({ account_id: "a", name: "Savings", mask: "1111" }),
      selected({ account_id: "b" }),
    ]),
  );

  assertJsonEquals(result.json, {
    status: "partial_duplicate",
    accounts: [
      { index: 0, decision: "new" },
      { index: 1, decision: "disconnected_existing" },
    ],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("duplicate plus ambiguous is partial_duplicate even when confirmed", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item()],
    accounts: [
      storedAccount(),
      storedAccount({
        plaid_account_id: "s-2",
        name: "Savings",
        official_name: null,
        mask: "1111",
      }),
    ],
  });
  const result = await harness.send(
    v2Body(
      [
        selected({ account_id: "a" }),
        selected({ account_id: "b", name: "Savings", mask: null }),
      ],
      { confirm_ambiguous: true },
    ),
  );

  assertEquals(result.json.status, "partial_duplicate");
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("duplicate plus disconnected only is duplicate", async () => {
  const harness = createHarness({
    institutions: [institution("item-1"), institution("item-2", "inst-2")],
    items: [item("item-1"), item("item-2", "2026-10-03T00:00:00Z")],
    accounts: [
      storedAccount(),
      storedAccount({
        plaid_item_id: "item-2",
        plaid_account_id: "s-2",
        name: "Savings",
        official_name: null,
        mask: "1111",
      }),
    ],
  });
  const result = await harness.send(
    v2Body([
      selected({ account_id: "a" }),
      selected({ account_id: "b", name: "Savings", mask: "1111" }),
    ]),
  );

  assertJsonEquals(result.json, {
    status: "duplicate",
    accounts: [
      { index: 0, decision: "duplicate" },
      { index: 1, decision: "disconnected_existing" },
    ],
  });
  assertEquals(harness.exchangeCalls, 0);
});

// --- v2 validation -------------------------------------------------------------

Deno.test("16 malformed v2 requests are 400 without any read or exchange", async () => {
  const longText = "x".repeat(257);
  const malformed: unknown[] = [
    v2Body([]),
    v2Body(Array.from({ length: 51 }, (_, i) => selected({ account_id: `a${i}` }))),
    v2Body([selected({ account_id: "" })]),
    v2Body([selected({ account_id: longText })]),
    v2Body([selected({ name: "  " })]),
    v2Body([selected({ name: longText })]),
    v2Body([selected({ mask: 1234 })]),
    v2Body([selected({ mask: "123456789" })]),
    v2Body([selected({ type: 7 })]),
    v2Body([selected({ subtype: ["checking"] })]),
    { ...v2Body([]), selected_accounts: ["not-an-object"] },
    v2Body([selected()], { confirm_ambiguous: "true" }),
    v2Body([selected()], { confirm_ambiguous: null }),
    v2Body([selected()], { public_token: "" }),
    v2Body([selected()], { institution_id: null }),
    { ...v2Body([selected()]), selected_accounts: "nope" },
  ];

  for (const body of malformed) {
    const harness = createHarness(oneActiveAccount());
    const result = await harness.send(body);

    assertEquals(result.status, 400, JSON.stringify(body).slice(0, 80));
    assertJsonEquals(result.json, { error: { code: "invalid_request" } });
    assertEquals(harness.exchangeCalls, 0);
    assertEquals(harness.calls.length, 0);
  }
});

Deno.test("17 duplicate account_id inside one request is 400", async () => {
  const harness = createHarness({});
  const result = await harness.send(
    v2Body([
      selected({ account_id: "same" }),
      selected({ account_id: " same ", name: "Savings" }),
    ]),
  );

  assertEquals(result.status, 400);
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("18 unknown contract_version is 400", async () => {
  for (const version of [1, 3, "2", null]) {
    const harness = createHarness({});
    const result = await harness.send(
      v2Body([selected()], { contract_version: version }),
    );

    assertEquals(result.status, 400);
    assertEquals(harness.exchangeCalls, 0);
  }
});

Deno.test("v2 accepts omitted mask, type and subtype as unknown", async () => {
  const harness = createHarness({});
  const result = await harness.send(
    v2Body([{ account_id: "a", name: "Checking" }]),
  );

  assertEquals(result.json.connection_id, connectionId);
  assertEquals(harness.exchangeCalls, 1);
});

// --- fail closed ---------------------------------------------------------------

Deno.test("19 failure of every required DB read is 500 without exchange", async () => {
  const reads: DatabaseMethod[] = [
    "listInstitutions",
    "listPlaidItems",
    "listItemAccounts",
  ];
  for (const method of reads) {
    for (const mode of ["failing", "throwing"] as const) {
      const harness = createHarness({ ...oneActiveAccount(), [mode]: method });
      const result = await harness.send(v2Body([selected({ name: "Other" })]));

      assertEquals(result.status, 500, `${mode} ${method}`);
      assertJsonEquals(result.json, {
        error: { code: "duplicate_check_failed" },
      });
      assertEquals(harness.exchangeCalls, 0);
      assert(!harness.calls.includes("persistSandboxItem"), "no persist");
    }
  }
});

Deno.test("20 inconsistent Item relationships fail closed", async () => {
  const inconsistent: HarnessOptions[] = [
    { institutions: [{ id: "i", plaid_item_id: null }] },
    { institutions: [institution()], items: [] },
    { institutions: [institution()], items: [item("someone-else")] },
    { institutions: [institution()], items: [item("item-1", 42 as never)] },
    { institutions: [institution()], items: [{ disconnected_at: null }] },
    {
      ...oneActiveAccount(),
      accounts: [storedAccount({ plaid_item_id: "item-unknown" })],
    },
    { ...oneActiveAccount(), accounts: [storedAccount({ plaid_item_id: null })] },
    { ...oneActiveAccount(), accounts: [storedAccount({ name: 5 })] },
    { ...oneActiveAccount(), accounts: [storedAccount({ mask: {} })] },
    { ...oneActiveAccount(), accounts: [storedAccount({ plaid_subtype: 1 })] },
  ];

  for (const options of inconsistent) {
    const harness = createHarness(options);
    const result = await harness.send(v2Body([selected({ name: "Other" })]));

    assertEquals(result.status, 500, JSON.stringify(options).slice(0, 120));
    assertEquals(result.json.error.code, "duplicate_check_failed");
    assertEquals(harness.exchangeCalls, 0);
  }
});

Deno.test("25 invalid internal classification never exchanges", async () => {
  const broken: Classify[] = [
    () => null,
    () => {
      throw new Error("classifier exploded");
    },
    () => ({ status: "bogus" as never, decisions: ["new"] }),
    () => ({ status: "proceed", decisions: [] }),
    () => ({ status: "confirmation_required", decisions: ["ambiguous"] }),
  ];

  for (const classifyLink of broken) {
    const harness = createHarness({ classifyLink });
    const result = await harness.send(v2Body([selected()]));

    assertEquals(result.status, 500);
    assertEquals(result.json.error.code, "duplicate_check_failed");
    assertEquals(harness.exchangeCalls, 0);
  }

  assertEquals(aggregateLink(["bogus" as AccountDecision], false), null);
  assertEquals(aggregateLink([], false), null);
});

Deno.test("exchange and persist failures are not reported as duplicates", async () => {
  const persistFails = createHarness({ failing: "persistSandboxItem" });
  const persisted = await persistFails.send(v2Body([selected()]));
  assertEquals(persisted.status, 500);
  assertEquals(persisted.json.error.code, "persist_failed");

  const persistThrows = createHarness({ throwing: "persistSandboxItem" });
  const thrown = await persistThrows.send(v2Body([selected()]));
  assertEquals(thrown.status, 500);
  assertEquals(thrown.json.error.code, "persist_failed");
});

// --- v1 backward compatibility -------------------------------------------------

Deno.test("21 v1 keeps the old rule: one matching name and mask blocks", async () => {
  const harness = createHarness({
    institutions: [institution()],
    legacyAccounts: [{ name: "Checking", mask: "0000" }],
  });
  const result = await harness.send(
    v1Body([
      { name: "Checking", mask: "0000" },
      { name: "Savings", mask: "1111" },
    ]),
  );

  assertEquals(result.status, 200);
  assertJsonEquals(result.json, { status: "duplicate" });
  assertEquals(harness.exchangeCalls, 0);
  assertJsonEquals(harness.calls, [
    "listInstitutions",
    "listInstitutionAccounts",
  ]);
});

Deno.test("21b v1 new account exchanges with the old success body", async () => {
  const harness = createHarness({
    institutions: [institution()],
    legacyAccounts: [{ name: "Checking", mask: "0000" }],
  });
  const result = await harness.send(v1Body([{ name: "Checking", mask: "9999" }]));

  assertJsonEquals(result.json, { connection_id: connectionId });
  assertEquals(harness.exchangeCalls, 1);
});

Deno.test("21c v1 still requires a mask on every account", async () => {
  const harness = createHarness({});
  const result = await harness.send(v1Body([{ name: "Checking", mask: null }]));

  assertEquals(result.status, 400);
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("21d v1 read failure stays duplicate_check_failed", async () => {
  for (const method of ["listInstitutions", "listInstitutionAccounts"] as const) {
    const harness = createHarness({
      institutions: [institution()],
      failing: method,
    });
    const result = await harness.send(v1Body());

    assertEquals(result.status, 500);
    assertEquals(result.json.error.code, "duplicate_check_failed");
    assertEquals(harness.exchangeCalls, 0);
  }
});

Deno.test("22 v1 never receives the new statuses", async () => {
  // Shapes that are partial, ambiguous or disconnected under v2.
  const harness = createHarness({
    institutions: [institution()],
    items: [item("item-1", "2026-10-03T00:00:00Z")],
    accounts: [storedAccount()],
    legacyAccounts: [{ name: "Checking", mask: "0000" }],
  });
  const result = await harness.send(
    v1Body([
      { name: "Checking", mask: "0000" },
      { name: "Savings", mask: "1111" },
    ]),
  );

  assertJsonEquals(result.json, { status: "duplicate" });
  assert(!("accounts" in result.json), "no per-account detail for v1");
  assert(!harness.calls.includes("listPlaidItems"), "v1 does not use v2 reads");
});

// --- privacy and scope ---------------------------------------------------------

Deno.test("23 non-ambiguous responses never echo account ids, names, masks or tokens", async () => {
  const harness = createHarness(oneActiveAccount());
  const bodies = [
    v2Body([selected()]),
    v2Body([selected({ account_id: "a" }), selected({ account_id: "b", name: "Savings" })]),
    v2Body([selected({ name: "Unrelated", mask: "4242" })]),
  ];

  for (const body of bodies) {
    const result = await harness.send(body);
    for (
      const secret of [
        "incoming-account-1",
        "stored-account-1",
        "Checking",
        "Savings",
        "Gold Standard",
        "0000",
        "4242",
        publicToken,
        accessToken,
        plaidItemId,
        "sandbox-secret",
      ]
    ) {
      assert(!result.text.includes(secret), `response leaked ${secret}`);
    }
  }
});

Deno.test("ambiguous candidates carry only the stored display name, subtype and mask", async () => {
  const harness = createHarness({
    institutions: [institution()],
    items: [item()],
    accounts: [storedAccount({ plaid_account_id: "stored-secret-id", mask: "1234" })],
  });
  const result = await harness.send(
    v2Body([selected({ account_id: "incoming-secret-id", mask: "9999" })]),
  );

  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [
      ambiguousReview(0, [{ name: "Checking", subtype: "checking", mask: "1234" }]),
    ],
  });
  for (
    const secret of [
      "stored-secret-id",
      "incoming-secret-id",
      "item-1",
      "institution-1",
      "Gold Standard",
      "depository",
      "9999",
      userId,
      publicToken,
      accessToken,
      plaidItemId,
      "sandbox-secret",
    ]
  ) {
    assert(!result.text.includes(secret), `response leaked ${secret}`);
  }
});

Deno.test("a stored mask longer than a mask is never returned", async () => {
  const harness = createHarness(
    oneActiveAccount(storedAccount({ mask: "123456789012", plaid_subtype: null })),
  );
  const result = await harness.send(v2Body([selected()]));

  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [ambiguousReview(0, [{ name: "Checking", subtype: null, mask: null }])],
  });
  assert(!result.text.includes("123456789012"), "long mask leaked");
});

Deno.test("several similar stored accounts are all listed once", async () => {
  const harness = createHarness({
    institutions: [institution("item-1"), institution("item-2", "inst-2")],
    items: [item("item-1"), item("item-2", "2026-10-03T00:00:00Z")],
    accounts: [
      storedAccount({ plaid_account_id: "s-1", mask: "1111" }),
      storedAccount({ plaid_account_id: "s-2", mask: "2222" }),
      storedAccount({ plaid_item_id: "item-2", plaid_account_id: "s-3", mask: "1111" }),
      storedAccount({ plaid_account_id: "s-4", name: "Savings", mask: "3333" }),
    ],
  });
  const result = await harness.send(v2Body([selected({ mask: "9999" })]));

  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [
      ambiguousReview(0, [
        { name: "Checking", subtype: "checking", mask: "1111" },
        { name: "Checking", subtype: "checking", mask: "2222" },
      ]),
    ],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("the candidate list is bounded", async () => {
  const accounts = Array.from(
    { length: 60 },
    (_, i) =>
      storedAccount({
        plaid_account_id: `s-${i}`,
        mask: String(1000 + i),
      }),
  );
  const harness = createHarness({
    institutions: [institution()],
    items: [item()],
    accounts,
  });
  const result = await harness.send(v2Body([selected({ mask: "9999" })]));

  assertEquals(result.json.status, "confirmation_required");
  assertEquals(result.json.accounts[0].candidates.length, 50);
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("multi-account Link keeps candidates on the matching selected account", async () => {
  const harness = createHarness(oneActiveAccount());
  const result = await harness.send(
    v2Body([
      selected({ account_id: "a", name: "Savings", mask: "1111", subtype: "savings" }),
      selected({ account_id: "b", mask: "9999" }),
    ]),
  );

  assertJsonEquals(result.json, {
    status: "confirmation_required",
    accounts: [{ index: 0, decision: "new" }, ambiguousReview(1)],
  });
  assertEquals(harness.exchangeCalls, 0);
});

Deno.test("24 duplicate decision touches only identity reads, never transactions", async () => {
  const harness = createHarness(oneActiveAccount());
  await harness.send(v2Body([selected()]));
  await harness.send(v2Body([selected({ name: "New", mask: "5555" })]));

  const allowed = new Set([
    "listInstitutions",
    "listPlaidItems",
    "listItemAccounts",
    "listInstitutionAccounts",
    "persistSandboxItem",
  ]);
  for (const member of harness.accessedDatabaseMembers) {
    assert(allowed.has(member), `unexpected database access: ${member}`);
  }

  const source = await Deno.readTextFile(
    new URL("./account_identity.ts", import.meta.url),
  );
  assert(!/^\s*import\s/m.test(source), "classifier imports nothing");
  assert(!source.includes("fetch("), "classifier performs no network call");
  assert(!source.includes(".from("), "classifier performs no table read");

  const handlerSource = await Deno.readTextFile(
    new URL("./handler.ts", import.meta.url),
  );
  for (const table of ["plaid_transactions", "operations", "projection"]) {
    assert(!handlerSource.includes(table), `handler reads ${table}`);
  }
});

Deno.test("classifier: replay identity beats any name or mask difference", () => {
  const decision = classifyAccount(
    {
      accountId: "same-id",
      name: "Different",
      mask: "1",
      type: "credit",
      subtype: "credit card",
    },
    [
      {
        plaidAccountId: "same-id",
        name: "Checking",
        officialName: null,
        mask: "0000",
        type: "depository",
        subtype: "checking",
        itemDisconnected: false,
      },
    ],
  );
  assertEquals(decision, "duplicate");
});

Deno.test("classifier: the same institution alone is never a duplicate", () => {
  const decision = classifyAccount(
    {
      accountId: "x",
      name: "Savings",
      mask: null,
      type: null,
      subtype: null,
    },
    [
      {
        plaidAccountId: "y",
        name: "Checking",
        officialName: "Gold Checking",
        mask: "0000",
        type: "depository",
        subtype: "checking",
        itemDisconnected: false,
      },
    ],
  );
  assertEquals(decision, "new");
});

Deno.test("classifier: mask, name and type rules", () => {
  const stored: ExistingAccount = {
    plaidAccountId: "stored",
    name: "Checking",
    officialName: "Gold Checking",
    mask: "0000",
    type: "depository",
    subtype: "checking",
    itemDisconnected: false,
  };
  const incoming = (overrides: Partial<IncomingAccount>): IncomingAccount => ({
    accountId: "incoming",
    name: "Checking",
    mask: "0000",
    type: "depository",
    subtype: "checking",
    ...overrides,
  });
  const cases: Array<[Partial<IncomingAccount>, ExistingAccount, AccountDecision]> = [
    [{}, stored, "duplicate"],
    [{ mask: "9999" }, stored, "ambiguous"],
    [{ mask: null }, stored, "ambiguous"],
    [{ subtype: "savings" }, stored, "ambiguous"],
    [{ mask: "9999", subtype: "savings" }, stored, "new"],
    [{ type: "credit" }, stored, "ambiguous"],
    [{ mask: "9999", type: "credit" }, stored, "new"],
    [{ name: "Everyday" }, stored, "new"],
    [{ name: "Everyday", mask: "9999" }, stored, "new"],
    [{ name: "Gold Checking" }, stored, "duplicate"],
    [{ name: "Gold Checking", mask: "9999" }, stored, "ambiguous"],
    [{ name: "CHECKING", mask: "9999" }, stored, "new"],
    [{ mask: "9999", type: null, subtype: null }, stored, "ambiguous"],
    [{}, { ...stored, itemDisconnected: true }, "disconnected_existing"],
    [{ mask: "9999" }, { ...stored, itemDisconnected: true }, "ambiguous"],
  ];

  for (const [overrides, candidate, expected] of cases) {
    assertEquals(
      classifyAccount(incoming(overrides), [candidate]),
      expected,
      JSON.stringify(overrides),
    );
  }
});

Deno.test("classifier: a strong candidate wins over a different-mask candidate", () => {
  const weak: ExistingAccount = {
    plaidAccountId: "weak",
    name: "Checking",
    officialName: null,
    mask: "1234",
    type: "depository",
    subtype: "checking",
    itemDisconnected: false,
  };
  const incoming: IncomingAccount = {
    accountId: "incoming",
    name: "Checking",
    mask: "0000",
    type: "depository",
    subtype: "checking",
  };

  assertEquals(
    classifyAccount(incoming, [weak, { ...weak, plaidAccountId: "s", mask: "0000" }]),
    "duplicate",
  );
  assertEquals(
    classifyAccount(incoming, [
      weak,
      { ...weak, plaidAccountId: "s", mask: "0000", itemDisconnected: true },
    ]),
    "disconnected_existing",
  );
  assertEquals(classifyAccount(incoming, [weak]), "ambiguous");
  assertEquals(
    classifyAccount(incoming, [weak, { ...weak, name: "Savings", mask: "5555" }]),
    "ambiguous",
  );
});

Deno.test("method and auth guards are unchanged", async () => {
  const handler = createPlaidExchangeHandler({
    authenticateRequest: async () => null,
    createDatabase: () => null,
  });
  const unauthorized = await handler(
    new Request("http://localhost", { method: "POST", body: "{}" }),
  );
  assertEquals(unauthorized.status, 401);

  const get = await handler(new Request("http://localhost", { method: "GET" }));
  assertEquals(get.status, 405);

  const options = await handler(
    new Request("http://localhost", { method: "OPTIONS" }),
  );
  assertEquals(options.status, 200);
});
