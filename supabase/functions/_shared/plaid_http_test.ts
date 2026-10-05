import {
  plaidApiUrl,
  type PlaidFailure,
  plaidFailureLogFields,
  type PlaidHttpResult,
  postPlaid,
} from "./plaid_http.ts";

const clientId = "client-id-value";
const plaidSecret = "plaid-secret-value";
const accessToken = "access-sandbox-0f1e2d3c-4b5a";
const url = "https://sandbox.plaid.com/accounts/get";

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

function assertNoSecrets(value: unknown): void {
  const text = JSON.stringify(value);
  for (const secret of [clientId, plaidSecret, accessToken]) {
    assert(!text.includes(secret), `output must not contain ${secret}`);
  }
}

type FetchCall = { url: string; init: RequestInit | undefined };

function respondWith(
  status: number,
  body: string,
  calls: FetchCall[] = [],
): typeof fetch {
  return ((input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: input.toString(), init });
    return Promise.resolve(new Response(body, { status }));
  }) as typeof fetch;
}

function post(
  fetchImpl: typeof fetch,
  timeoutMs?: number,
): Promise<PlaidHttpResult> {
  return postPlaid({
    fetchImpl,
    url,
    credentials: { clientId, secret: plaidSecret },
    body: { access_token: accessToken },
    timeoutMs,
  });
}

function expectFailure(
  result: PlaidHttpResult,
  kind: PlaidFailure["kind"],
): PlaidFailure {
  assertEquals(result.kind, kind);
  return result as PlaidFailure;
}

Deno.test("plaidApiUrl joins the environment host and path", () => {
  assertEquals(
    plaidApiUrl("sandbox", "/item/public_token/exchange"),
    "https://sandbox.plaid.com/item/public_token/exchange",
  );
  assertEquals(
    plaidApiUrl("production", "/accounts/get"),
    "https://production.plaid.com/accounts/get",
  );
});

Deno.test("success returns the payload, status and request id", async () => {
  const calls: FetchCall[] = [];
  const result = await post(
    respondWith(
      200,
      JSON.stringify({ accounts: [], request_id: "req-1" }),
      calls,
    ),
  );

  assertEquals(result.kind, "ok");
  if (result.kind !== "ok") return;
  assertEquals(result.operation, "/accounts/get");
  assertEquals(result.status, 200);
  assertEquals(result.requestId, "req-1");
  assertEquals(Array.isArray(result.payload.accounts), true);

  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, url);
  assertEquals(calls[0].init?.method, "POST");
  const headers = calls[0].init?.headers as Record<string, string>;
  assertEquals(headers["PLAID-CLIENT-ID"], clientId);
  assertEquals(headers["PLAID-SECRET"], plaidSecret);
  assertEquals(
    JSON.parse(String(calls[0].init?.body)).access_token,
    accessToken,
  );
  assert(calls[0].init?.signal instanceof AbortSignal, "request is abortable");
});

Deno.test("Plaid API error keeps non-secret diagnostics", async () => {
  const result = await post(respondWith(
    400,
    JSON.stringify({
      error_type: "ITEM_ERROR",
      error_code: "ITEM_LOGIN_REQUIRED",
      error_message: "the login details of this item have changed",
      display_message: "Please log in again",
      request_id: "req-2",
    }),
  ));

  const failure = expectFailure(result, "plaid_error");
  if (failure.kind !== "plaid_error") return;
  assertEquals(failure.error.operation, "/accounts/get");
  assertEquals(failure.error.status, 400);
  assertEquals(failure.error.errorType, "ITEM_ERROR");
  assertEquals(failure.error.errorCode, "ITEM_LOGIN_REQUIRED");
  assertEquals(
    failure.error.errorMessage,
    "the login details of this item have changed",
  );
  assertEquals(failure.error.displayMessage, "Please log in again");
  assertEquals(failure.error.requestId, "req-2");
});

Deno.test("Plaid error with a 2xx status is still an error", async () => {
  const result = await post(respondWith(
    200,
    JSON.stringify({
      error_type: "API_ERROR",
      error_code: "INTERNAL_SERVER_ERROR",
    }),
  ));

  expectFailure(result, "plaid_error");
});

Deno.test("error messages never echo credentials or tokens", async () => {
  const result = await post(respondWith(
    400,
    JSON.stringify({
      error_type: "INVALID_INPUT",
      error_code: "INVALID_ACCESS_TOKEN",
      error_message:
        `bad token ${accessToken} for ${clientId} with ${plaidSecret}; also public-sandbox-aaaa-bbbb`,
      display_message: `token ${accessToken}`,
    }),
  ));

  const failure = expectFailure(result, "plaid_error");
  assertNoSecrets(failure);
  assert(
    !JSON.stringify(failure).includes("public-sandbox-aaaa-bbbb"),
    "Plaid-shaped tokens are redacted",
  );
  assertNoSecrets(plaidFailureLogFields(failure));
});

Deno.test("long error messages are bounded", async () => {
  const result = await post(respondWith(
    500,
    JSON.stringify({
      error_type: "API_ERROR",
      error_code: "INTERNAL_SERVER_ERROR",
      error_message: "x".repeat(5000),
    }),
  ));

  const failure = expectFailure(result, "plaid_error");
  if (failure.kind !== "plaid_error") return;
  assertEquals(failure.error.errorMessage?.length, 300);
});

Deno.test("network failure is a transport error, not a Plaid error", async () => {
  const fetchImpl =
    (() => Promise.reject(new TypeError("dns failure"))) as typeof fetch;

  const failure = expectFailure(await post(fetchImpl), "transport_error");
  if (failure.kind !== "transport_error") return;
  assertEquals(failure.reason, "network");
  assertEquals(failure.operation, "/accounts/get");
});

Deno.test("a fetch that honours the abort signal times out", async () => {
  let aborted = false;
  const fetchImpl =
    ((_input: RequestInfo | URL, init?: RequestInit) =>
      new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          aborted = true;
          reject(new DOMException("aborted", "AbortError"));
        });
      })) as typeof fetch;

  const failure = expectFailure(await post(fetchImpl, 10), "transport_error");
  if (failure.kind !== "transport_error") return;
  assertEquals(failure.reason, "timeout");
  assertEquals(aborted, true);
});

Deno.test("a fetch that ignores the abort signal still times out", async () => {
  const fetchImpl = (() => new Promise<Response>(() => {})) as typeof fetch;

  const failure = expectFailure(await post(fetchImpl, 10), "transport_error");
  if (failure.kind !== "transport_error") return;
  assertEquals(failure.reason, "timeout");
});

Deno.test("a body that never finishes times out", async () => {
  const fetchImpl = (() =>
    Promise.resolve(
      new Response(new ReadableStream({ start() {} }), { status: 200 }),
    )) as typeof fetch;

  const failure = expectFailure(await post(fetchImpl, 10), "transport_error");
  if (failure.kind !== "transport_error") return;
  assertEquals(failure.reason, "timeout");
});

Deno.test("non-JSON and non-object bodies are malformed responses", async () => {
  for (
    const [status, body] of [
      [200, "<html>gateway</html>"],
      [200, "[]"],
      [200, "null"],
      [502, "Bad Gateway"],
      [500, ""],
      [200, ""],
    ] as const
  ) {
    const failure = expectFailure(
      await post(respondWith(status, body)),
      "malformed_response",
    );
    if (failure.kind !== "malformed_response") return;
    assertEquals(failure.status, status);
  }
});

Deno.test("an error status without Plaid error fields is malformed", async () => {
  const failure = expectFailure(
    await post(respondWith(503, JSON.stringify({ request_id: "req-3" }))),
    "malformed_response",
  );
  if (failure.kind !== "malformed_response") return;
  assertEquals(failure.requestId, "req-3");
});

Deno.test("log fields carry codes and ids only", async () => {
  const plaidFailure = expectFailure(
    await post(respondWith(
      400,
      JSON.stringify({
        error_type: "INVALID_INPUT",
        error_code: "INVALID_PUBLIC_TOKEN",
        error_message: "message text",
        display_message: "display text",
        request_id: "req-4",
      }),
    )),
    "plaid_error",
  );

  const fields = plaidFailureLogFields(plaidFailure);
  assertEquals(
    JSON.stringify(fields),
    JSON.stringify({
      operation: "/accounts/get",
      failure: "plaid_error",
      status: 400,
      error_type: "INVALID_INPUT",
      error_code: "INVALID_PUBLIC_TOKEN",
      request_id: "req-4",
    }),
  );

  const timeoutFields = plaidFailureLogFields({
    kind: "transport_error",
    operation: "/accounts/get",
    reason: "timeout",
  });
  assertEquals(timeoutFields.reason, "timeout");
});
