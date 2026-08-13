import { createPlaidSyncTransactionsHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const connectionId = "22222222-2222-4222-8222-222222222222";
const ownerToken = "33333333-3333-4333-8333-333333333333";
const accessToken = "access-token-secret-value";

type FetchResponse = {
  status: number;
  body: Record<string, unknown>;
};

type ApplyCall = {
  userId: string;
  connectionId: string;
  originalCursor: string | null;
  finalCursor: string;
  markInitialSyncCompleted: boolean;
  added: Array<Record<string, unknown>>;
  modified: Array<Record<string, unknown>>;
  removed: Array<Record<string, unknown>>;
};

type HarnessOptions = {
  authenticatedUserId?: string | null;
  requestConnectionId?: string;
  acquireResult?: "not_found" | "busy" | "failed" | "acquired";
  originalCursor?: string | null;
  plaidEnvironment?: string | null;
  accessTokenExists?: boolean;
  renewResults?: boolean[];
  fetchResponses?: FetchResponse[];
  applyResult?: "success" | "cursor_conflict" | "failed";
  releaseThrows?: boolean;
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

function transaction(overrides: Record<string, unknown> = {}) {
  return {
    account_id: "plaid-account-1",
    transaction_id: "transaction-1",
    pending: false,
    pending_transaction_id: null,
    date: "2026-08-10",
    authorized_date: "2026-08-09",
    datetime: null,
    authorized_datetime: null,
    amount: 12.34567,
    iso_currency_code: "CAD",
    unofficial_currency_code: null,
    name: "Coffee",
    merchant_name: "Cafe",
    payment_channel: "in store",
    merchant_entity_id: "merchant-entity-1",
    personal_finance_category: {
      primary: "FOOD_AND_DRINK",
      detailed: "FOOD_AND_DRINK_COFFEE",
      confidence_level: "VERY_HIGH",
      version: "v2",
    },
    ...overrides,
  };
}

function page(overrides: Record<string, unknown> = {}): FetchResponse {
  return {
    status: 200,
    body: {
      added: [],
      modified: [],
      removed: [],
      has_more: false,
      next_cursor: "cursor-next",
      request_id: "request-id",
      ...overrides,
    },
  };
}

function mutationError(): FetchResponse {
  return {
    status: 400,
    body: {
      error_type: "TRANSACTIONS_ERROR",
      error_code: "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION",
      request_id: "request-id",
    },
  };
}

function apiError(): FetchResponse {
  return {
    status: 500,
    body: {
      error_type: "API_ERROR",
      error_code: "INTERNAL_SERVER_ERROR",
      request_id: "request-id",
    },
  };
}

function createHarness(options: HarnessOptions = {}) {
  const calls: string[] = [];
  const fetchBodies: Array<Record<string, unknown>> = [];
  const applyCalls: ApplyCall[] = [];
  const releaseCalls: string[] = [];

  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const requestConnectionId = options.requestConnectionId ?? connectionId;
  const acquireResult = options.acquireResult ?? "acquired";
  const originalCursor = options.originalCursor === undefined
    ? null
    : options.originalCursor;
  const plaidEnvironment = options.plaidEnvironment === undefined
    ? "sandbox"
    : options.plaidEnvironment;
  const accessTokenExists = options.accessTokenExists ?? true;
  const renewResults = [...(options.renewResults ?? [])];
  const fetchResponses = [...(options.fetchResponses ?? [page()])];
  const applyResult = options.applyResult ?? "success";
  const releaseThrows = options.releaseThrows ?? false;

  const handler = createPlaidSyncTransactionsHandler({
    authenticateRequest: async () => {
      if (authenticatedUserId === null) {
        return null;
      }

      return { id: authenticatedUserId };
    },
    createDatabase: () => ({
      async acquireLease(receivedUserId, receivedConnectionId) {
        calls.push("acquire_lease");

        if (
          receivedUserId !== userId ||
          receivedConnectionId !== connectionId
        ) {
          return "not_found";
        }

        if (acquireResult === "not_found") {
          return "not_found";
        }

        if (acquireResult === "failed") {
          return null;
        }

        if (acquireResult === "busy") {
          return {
            acquired: false,
            originalCursor: null,
            plaidEnvironment: null,
          };
        }

        return {
          acquired: true,
          originalCursor,
          plaidEnvironment,
        };
      },
      async renewLease() {
        calls.push("renew_lease");
        return renewResults.length === 0 ? true : renewResults.shift()!;
      },
      async releaseLease() {
        calls.push("release_lease");
        releaseCalls.push("release");
        if (releaseThrows) {
          throw new Error("release failed");
        }
        return true;
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
      async applyTransactionsSyncBatch(args) {
        calls.push("apply_batch");
        applyCalls.push({
          userId: args.userId,
          connectionId: args.connectionId,
          originalCursor: args.originalCursor,
          finalCursor: args.finalCursor,
          markInitialSyncCompleted: args.markInitialSyncCompleted,
          added: args.added as unknown as Array<Record<string, unknown>>,
          modified: args.modified as unknown as Array<Record<string, unknown>>,
          removed: args.removed as unknown as Array<Record<string, unknown>>,
        });

        if (applyResult === "cursor_conflict") {
          return "cursor_conflict";
        }

        if (applyResult === "failed") {
          return null;
        }

        return {
          addedCount: args.added.length,
          modifiedCount: args.modified.length,
          removedCount: args.removed.length,
          cursorAdvanced: true,
          initialSyncCompleted: args.markInitialSyncCompleted,
        };
      },
    }),
    fetch: async (_url, init) => {
      calls.push("plaid_sync");
      fetchBodies.push(JSON.parse(String(init?.body)));
      const response = fetchResponses.shift() ?? apiError();
      return new Response(JSON.stringify(response.body), {
        status: response.status,
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
    randomUUID: () => ownerToken,
  });

  const request = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ connection_id: requestConnectionId }),
  });

  return { handler, request, calls, fetchBodies, applyCalls, releaseCalls };
}

Deno.test("auth required", async () => {
  const { handler, request, calls } = createHarness({
    authenticatedUserId: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("invalid connection UUID is rejected before lease", async () => {
  const { handler, request, calls } = createHarness({
    requestConnectionId: "not-a-uuid",
  });

  const response = await handler(request);

  assertEquals(response.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("foreign or missing connection returns safe 404", async () => {
  const { handler, request, calls } = createHarness({
    acquireResult: "not_found",
  });

  const response = await handler(request);

  assertEquals(response.status, 404);
  assertEquals(calls.includes("plaid_sync"), false);
});

Deno.test("concurrent second sync cannot start pagination", async () => {
  const { handler, request, calls } = createHarness({
    acquireResult: "busy",
  });

  const response = await handler(request);

  assertEquals(response.status, 409);
  assertEquals(calls.includes("plaid_sync"), false);
});

Deno.test("access token is never exposed", async () => {
  const { handler, request } = createHarness({
    fetchResponses: [page({ added: [transaction()] })],
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 200);
  assert(!text.includes(accessToken), "response exposed access token");
});

Deno.test("first single-page sync applies batch after final page", async () => {
  const { handler, request, calls, applyCalls } = createHarness({
    fetchResponses: [page({ added: [transaction()] })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(
    calls.join(","),
    [
      "acquire_lease",
      "get_access_token",
      "renew_lease",
      "plaid_sync",
      "renew_lease",
      "apply_batch",
      "release_lease",
    ].join(","),
  );
  assertEquals(applyCalls.length, 1);
  assertEquals(applyCalls[0].added.length, 1);
});

Deno.test("multi-page sync advances cursor between pages", async () => {
  const { handler, request, fetchBodies, applyCalls } = createHarness({
    originalCursor: "cursor-original",
    fetchResponses: [
      page({
        added: [transaction({ transaction_id: "t1" })],
        has_more: true,
        next_cursor: "cursor-page-2",
      }),
      page({
        modified: [transaction({ transaction_id: "t2" })],
        removed: [{ transaction_id: "t3" }],
        has_more: false,
        next_cursor: "cursor-final",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].cursor, "cursor-original");
  assertEquals(fetchBodies[1].cursor, "cursor-page-2");
  assertEquals(applyCalls.length, 1);
  assertEquals(applyCalls[0].finalCursor, "cursor-final");
  assertEquals(applyCalls[0].added.length, 1);
  assertEquals(applyCalls[0].modified.length, 1);
  assertEquals(applyCalls[0].removed.length, 1);
});

Deno.test("DB RPC is not called before final page", async () => {
  const { handler, request, calls } = createHarness({
    fetchResponses: [
      page({ has_more: true, next_cursor: "cursor-page-2" }),
      apiError(),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(calls.includes("apply_batch"), false);
});

Deno.test("full normalized batch is passed once", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        added: [transaction({ transaction_id: "added-id" })],
        modified: [transaction({ transaction_id: "modified-id" })],
        removed: [{ transaction_id: "removed-id" }],
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls.length, 1);
  assertEquals(applyCalls[0].added[0].plaid_account_id, "plaid-account-1");
  assertEquals(applyCalls[0].added[0].transaction_id, "added-id");
  assertEquals(
    applyCalls[0].added[0].personal_finance_category_version,
    "v2",
  );
  assertEquals(applyCalls[0].modified[0].transaction_id, "modified-id");
  assertEquals(applyCalls[0].removed[0].transaction_id, "removed-id");
});

Deno.test("PFC v2 option and max count are sent to Plaid", async () => {
  const { handler, request, fetchBodies } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].count, 500);
  assertEquals(
    (fetchBodies[0].options as Record<string, unknown>)
      .personal_finance_category_version,
    "v2",
  );
});

Deno.test("amount is not rounded", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({ added: [transaction({ amount: 12.3456789 })] }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].added[0].amount, 12.3456789);
});

Deno.test("nullable PFC is normalized to null fields", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({ added: [transaction({ personal_finance_category: null })] }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].added[0].personal_finance_category_primary, null);
  assertEquals(applyCalls[0].added[0].personal_finance_category_detailed, null);
});

Deno.test("empty initial response with empty next cursor is accepted", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        added: [],
        modified: [],
        removed: [],
        has_more: false,
        next_cursor: "",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls.length, 1);
  assertEquals(applyCalls[0].finalCursor, "");
  assertEquals(applyCalls[0].markInitialSyncCompleted, false);
});

Deno.test("empty original cursor is sent literally", async () => {
  const { handler, request, fetchBodies, applyCalls } = createHarness({
    originalCursor: "",
    fetchResponses: [page({ next_cursor: "cursor-next" })],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].cursor, "");
  assertEquals(applyCalls[0].originalCursor, "");
});

Deno.test("NOT_READY does not mark initial sync ready", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        transactions_update_status: "NOT_READY",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].markInitialSyncCompleted, false);
});

Deno.test("INITIAL_UPDATE_COMPLETE does not mark historical ready", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        transactions_update_status: "INITIAL_UPDATE_COMPLETE",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].markInitialSyncCompleted, false);
});

Deno.test("HISTORICAL_UPDATE_COMPLETE marks initial sync ready atomically", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        transactions_update_status: "HISTORICAL_UPDATE_COMPLETE",
      }),
    ],
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].markInitialSyncCompleted, true);
  assertEquals(body.initial_sync_completed, true);
});

Deno.test("existing item can become ready on later sync", async () => {
  const { handler, request, applyCalls } = createHarness({
    originalCursor: "cursor-existing",
    fetchResponses: [
      page({
        transactions_update_status: "HISTORICAL_UPDATE_COMPLETE",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls[0].originalCursor, "cursor-existing");
  assertEquals(applyCalls[0].markInitialSyncCompleted, true);
});

Deno.test("unknown transactions update status is malformed", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        transactions_update_status: "SOMETHING_NEW",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("null original cursor omits cursor from first Plaid request", async () => {
  const { handler, request, fetchBodies } = createHarness({
    originalCursor: null,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals("cursor" in fetchBodies[0], false);
});

Deno.test("mutation on later page discards previously collected pages", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        added: [transaction({ transaction_id: "discarded" })],
        has_more: true,
        next_cursor: "cursor-page-2",
      }),
      mutationError(),
      page({
        added: [transaction({ transaction_id: "kept" })],
        has_more: false,
        next_cursor: "cursor-final",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(applyCalls.length, 1);
  assertEquals(applyCalls[0].added.length, 1);
  assertEquals(applyCalls[0].added[0].transaction_id, "kept");
});

Deno.test("mutation restart starts again from original cursor", async () => {
  const { handler, request, fetchBodies } = createHarness({
    originalCursor: "cursor-original",
    fetchResponses: [
      page({ has_more: true, next_cursor: "cursor-page-2" }),
      mutationError(),
      page({ has_more: false, next_cursor: "cursor-final" }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(fetchBodies[0].cursor, "cursor-original");
  assertEquals(fetchBodies[1].cursor, "cursor-page-2");
  assertEquals(fetchBodies[2].cursor, "cursor-original");
});

Deno.test("bounded mutation restart exhaustion does not call RPC", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      mutationError(),
      mutationError(),
      mutationError(),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("other Plaid ITEM or API error does not call RPC", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      {
        status: 400,
        body: {
          error_type: "ITEM_ERROR",
          error_code: "ITEM_LOGIN_REQUIRED",
          request_id: "request-id",
        },
      },
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("Plaid 5xx does not call RPC", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [apiError()],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("malformed response does not call RPC", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({
        added: "not-array",
      }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("invalid transaction payload does not call RPC", async () => {
  const { handler, request, applyCalls } = createHarness({
    fetchResponses: [
      page({ added: [transaction({ transaction_id: "" })] }),
    ],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(applyCalls.length, 0);
});

Deno.test("RPC failure returns safe error", async () => {
  const { handler, request } = createHarness({
    applyResult: "failed",
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 500);
  assert(!text.includes(accessToken), "response exposed access token");
});

Deno.test("cursor conflict is handled without replay", async () => {
  const { handler, request, calls, applyCalls } = createHarness({
    applyResult: "cursor_conflict",
  });

  const response = await handler(request);

  assertEquals(response.status, 409);
  assertEquals(applyCalls.length, 1);
  assertEquals(calls.filter((call) => call === "apply_batch").length, 1);
});

Deno.test("expired or stale lease can recover through acquire", async () => {
  const { handler, request, calls } = createHarness({
    acquireResult: "acquired",
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(calls[0], "acquire_lease");
});

Deno.test("lease release happens on success", async () => {
  const { handler, request, releaseCalls } = createHarness();

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(releaseCalls.length, 1);
});

Deno.test("lease release is best-effort on failure", async () => {
  const { handler, request, releaseCalls } = createHarness({
    fetchResponses: [apiError()],
  });

  const response = await handler(request);

  assertEquals(response.status, 502);
  assertEquals(releaseCalls.length, 1);
});

Deno.test("lease release error does not override success response", async () => {
  const { handler, request, releaseCalls } = createHarness({
    releaseThrows: true,
  });

  const response = await handler(request);

  assertEquals(response.status, 200);
  assertEquals(releaseCalls.length, 1);
});

Deno.test("lost lease stops before Plaid request and RPC", async () => {
  const { handler, request, calls, applyCalls } = createHarness({
    renewResults: [false],
  });

  const response = await handler(request);

  assertEquals(response.status, 409);
  assertEquals(calls.includes("plaid_sync"), false);
  assertEquals(applyCalls.length, 0);
});

Deno.test("lost lease before RPC does not persist collected batch", async () => {
  const { handler, request, calls, applyCalls } = createHarness({
    renewResults: [true, false],
    fetchResponses: [page({ added: [transaction()] })],
  });

  const response = await handler(request);

  assertEquals(response.status, 409);
  assertEquals(calls.includes("plaid_sync"), true);
  assertEquals(applyCalls.length, 0);
});

Deno.test("no secrets in any error response", async () => {
  const { handler, request } = createHarness({
    fetchResponses: [apiError()],
  });

  const response = await handler(request);
  const text = await response.text();

  assertEquals(response.status, 502);
  assert(!text.includes(accessToken), "response exposed access token");
  assert(!text.includes("sandbox-secret"), "response exposed Plaid secret");
});
