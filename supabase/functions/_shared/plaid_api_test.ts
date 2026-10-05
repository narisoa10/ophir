import {
  exchangePublicToken,
  getInstitutionById,
  getItemAccounts,
  type PlaidClient,
  removeItem,
} from "./plaid_api.ts";
import { plaidFailureLogFields } from "./plaid_http.ts";

const clientId = "client-id-value";
const plaidSecret = "plaid-secret-value";
const publicToken = "public-sandbox-11112222-3333";
const accessToken = "access-sandbox-44445555-6666";

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

type FetchCall = { url: string; body: Record<string, unknown> };

function client(
  status: number,
  body: unknown,
  calls: FetchCall[] = [],
): PlaidClient {
  return {
    fetchImpl: ((input: RequestInfo | URL, init?: RequestInit) => {
      calls.push({
        url: input.toString(),
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      return Promise.resolve(
        new Response(JSON.stringify(body), { status }),
      );
    }) as typeof fetch,
    environment: "sandbox",
    credentials: { clientId, secret: plaidSecret },
  };
}

function account(accountId: string, overrides: Record<string, unknown> = {}) {
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

// --- /item/public_token/exchange -------------------------------------------

Deno.test("exchange returns the access token and item id", async () => {
  const calls: FetchCall[] = [];
  const result = await exchangePublicToken(
    client(200, {
      access_token: accessToken,
      item_id: "item-1",
      request_id: "req-1",
    }, calls),
    publicToken,
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.accessToken, accessToken);
  assertEquals(result.itemId, "item-1");
  assertEquals(result.requestId, "req-1");
  assertEquals(
    calls[0].url,
    "https://sandbox.plaid.com/item/public_token/exchange",
  );
  assertEquals(calls[0].body.public_token, publicToken);
});

Deno.test("exchange without access token or item id is malformed", async () => {
  for (
    const body of [
      { item_id: "item-1" },
      { access_token: accessToken },
      { access_token: "", item_id: "item-1" },
      { access_token: accessToken, item_id: 42 },
    ]
  ) {
    const result = await exchangePublicToken(client(200, body), publicToken);
    assertEquals(result.kind, "malformed_response");
    assert(
      !JSON.stringify(result).includes(accessToken),
      "malformed result never carries the access token",
    );
  }
});

Deno.test("exchange Plaid error never carries the public token", async () => {
  const result = await exchangePublicToken(
    client(400, {
      error_type: "INVALID_INPUT",
      error_code: "INVALID_PUBLIC_TOKEN",
      error_message: `provided token ${publicToken} is invalid`,
    }),
    publicToken,
  );

  assertEquals(result.kind, "plaid_error");
  assert(!JSON.stringify(result).includes(publicToken), "token is redacted");
});

// --- /accounts/get -----------------------------------------------------------

Deno.test("accounts/get returns every account of the Item", async () => {
  const calls: FetchCall[] = [];
  const result = await getItemAccounts(
    client(200, {
      accounts: [
        account("a-1"),
        account("a-2", { mask: null, subtype: null }),
        account("a-3", { type: "credit", subtype: "credit card" }),
      ],
      item: {
        item_id: "item-1",
        institution_id: "ins_1",
        institution_name: "Bank",
      },
      request_id: "req-2",
    }, calls),
    accessToken,
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.itemId, "item-1");
  assertEquals(result.institutionId, "ins_1");
  assertEquals(result.institutionName, "Bank");
  assertEquals(result.requestId, "req-2");
  assertEquals(
    result.accounts.map((a) => a.plaid_account_id).join(","),
    "a-1,a-2,a-3",
  );
  assertEquals(result.accounts[1].mask, null);
  assertEquals(result.accounts[2].plaid_type, "credit");
  assertEquals(calls[0].url, "https://sandbox.plaid.com/accounts/get");
  assertEquals(
    JSON.stringify(Object.keys(calls[0].body)),
    JSON.stringify(["access_token"]),
    "no account filter is sent",
  );
});

Deno.test("accounts/get keeps an empty account list", async () => {
  const result = await getItemAccounts(
    client(200, { accounts: [], item: { item_id: "item-1" } }),
    accessToken,
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.accounts.length, 0);
  assertEquals(result.institutionId, null);
});

Deno.test("accounts/get fails as a whole instead of dropping a bad account", async () => {
  for (
    const body of [
      {
        accounts: [account("a-1"), { name: "no id", type: "depository" }],
        item: { item_id: "item-1" },
      },
      {
        accounts: [account("a-1", { balances: {} })],
        item: { item_id: "item-1" },
      },
      { accounts: "nope", item: { item_id: "item-1" } },
      { accounts: [account("a-1")] },
      { accounts: [account("a-1")], item: { institution_id: "ins_1" } },
    ]
  ) {
    const result = await getItemAccounts(client(200, body), accessToken);
    assertEquals(result.kind, "malformed_response");
  }
});

Deno.test("accounts/get Plaid error is returned with its code", async () => {
  const result = await getItemAccounts(
    client(400, {
      error_type: "ITEM_ERROR",
      error_code: "ITEM_LOGIN_REQUIRED",
    }),
    accessToken,
  );

  assertEquals(result.kind, "plaid_error");
  if (result.kind !== "plaid_error") return;
  assertEquals(result.error.errorCode, "ITEM_LOGIN_REQUIRED");
  assert(!JSON.stringify(result).includes(accessToken), "no access token");
});

// --- /institutions/get_by_id -------------------------------------------------

Deno.test("institution lookup returns optional metadata", async () => {
  const calls: FetchCall[] = [];
  const result = await getInstitutionById(
    client(200, {
      institution: {
        institution_id: "ins_1",
        name: "Bank",
        logo: "logo-data",
        primary_color: "#123456",
        url: "https://bank.example",
      },
      request_id: "req-3",
    }, calls),
    "ins_1",
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.institutionId, "ins_1");
  assertEquals(result.name, "Bank");
  assertEquals(result.logoBase64, "logo-data");
  assertEquals(result.primaryColor, "#123456");
  assertEquals(result.url, "https://bank.example");
  assertEquals(
    calls[0].url,
    "https://sandbox.plaid.com/institutions/get_by_id",
  );
  assertEquals(
    JSON.stringify(calls[0].body),
    JSON.stringify({
      institution_id: "ins_1",
      country_codes: ["CA"],
      options: { include_optional_metadata: true },
    }),
  );
});

Deno.test("institution lookup without metadata keeps nulls", async () => {
  const result = await getInstitutionById(
    client(200, { institution: {} }),
    "ins_1",
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.name, null);
  assertEquals(result.logoBase64, null);
});

Deno.test("institution lookup failures are reported, not thrown", async () => {
  assertEquals(
    (await getInstitutionById(client(200, { request_id: "x" }), "ins_1")).kind,
    "malformed_response",
  );
  assertEquals(
    (await getInstitutionById(
      client(400, {
        error_type: "INVALID_INPUT",
        error_code: "INVALID_INSTITUTION",
      }),
      "ins_1",
    )).kind,
    "plaid_error",
  );
});

// --- /item/remove ------------------------------------------------------------

Deno.test("item remove sends only the access token and returns the request id", async () => {
  const calls: FetchCall[] = [];
  const result = await removeItem(
    client(200, { request_id: "req-remove" }, calls),
    accessToken,
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.requestId, "req-remove");
  assertEquals(calls[0].url, "https://sandbox.plaid.com/item/remove");
  assertEquals(
    JSON.stringify(calls[0].body),
    JSON.stringify({ access_token: accessToken }),
  );
  assert(!JSON.stringify(result).includes(accessToken), "no access token");
});

Deno.test("item remove Plaid error carries codes but never the access token", async () => {
  const result = await removeItem(
    client(400, {
      error_type: "ITEM_ERROR",
      error_code: "ITEM_NOT_FOUND",
      error_message: `item for ${accessToken} not found`,
      request_id: "req-remove-error",
    }),
    accessToken,
  );

  assertEquals(result.kind, "plaid_error");
  if (result.kind !== "plaid_error") return;
  assertEquals(result.error.operation, "/item/remove");
  assertEquals(result.error.errorCode, "ITEM_NOT_FOUND");
  assertEquals(result.error.requestId, "req-remove-error");
  const serialized = JSON.stringify([result, plaidFailureLogFields(result)]);
  for (const secret of [accessToken, clientId, plaidSecret]) {
    assert(!serialized.includes(secret), `leaked ${secret}`);
  }
});

Deno.test("item remove network failure and timeout are transport errors", async () => {
  const network = await removeItem(
    {
      ...client(200, {}),
      fetchImpl: (() => Promise.reject(new TypeError("down"))) as typeof fetch,
    },
    accessToken,
  );
  assertEquals(network.kind, "transport_error");
  if (network.kind === "transport_error") {
    assertEquals(network.reason, "network");
    assertEquals(network.operation, "/item/remove");
  }

  const hung = await removeItem(
    {
      ...client(200, {}),
      fetchImpl: (() => new Promise<Response>(() => {})) as typeof fetch,
      timeoutMs: 20,
    },
    accessToken,
  );
  assertEquals(hung.kind, "transport_error");
  if (hung.kind === "transport_error") {
    assertEquals(hung.reason, "timeout");
  }
});

Deno.test("item remove without a confirmed answer is malformed", async () => {
  for (
    const [status, body] of [
      [200, {}],
      [200, { request_id: "" }],
      [200, ["removed"]],
      [500, { request_id: "req-5xx" }],
    ] as const
  ) {
    const result = await removeItem(client(status, body), accessToken);
    assertEquals(result.kind, "malformed_response", JSON.stringify(body));
    assert(!JSON.stringify(result).includes(accessToken), "no access token");
  }

  const notJson = await removeItem(
    {
      ...client(200, {}),
      fetchImpl:
        (() =>
          Promise.resolve(new Response("OK", { status: 200 }))) as typeof fetch,
    },
    accessToken,
  );
  assertEquals(notJson.kind, "malformed_response");
});

Deno.test("operations use the configured environment host", async () => {
  const calls: FetchCall[] = [];
  const production: PlaidClient = {
    ...client(200, { access_token: accessToken, item_id: "item-1" }, calls),
    environment: "production",
  };

  await exchangePublicToken(production, publicToken);
  assertEquals(
    calls[0].url,
    "https://production.plaid.com/item/public_token/exchange",
  );
});
