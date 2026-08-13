import { createPlaidReverseInternalTransferHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const reconciliationId = "22222222-2222-4222-8222-222222222222";
const transferOperationId = "33333333-3333-4333-8333-333333333333";
const forgedUserId = "99999999-9999-4999-8999-999999999999";

type ReverseCall = {
  userId: string;
  reconciliationId: string;
};

type HarnessOptions = {
  authenticatedUserId?: string | null;
  method?: string;
  body?: unknown;
  rpcResult?: Record<string, unknown> | null;
  rpcErrorMessage?: string | null;
  databaseAvailable?: boolean;
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
  const reverseCalls: ReverseCall[] = [];
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const databaseAvailable = options.databaseAvailable ?? true;
  const rpcErrorMessage = options.rpcErrorMessage ?? null;
  const rpcResult = options.rpcResult === undefined
    ? {
      status: "reversed",
      reconciliation_id: reconciliationId,
      transfer_operation_id: transferOperationId,
    }
    : options.rpcResult;

  const handler = createPlaidReverseInternalTransferHandler({
    authenticateRequest: async () => {
      if (authenticatedUserId === null) {
        return null;
      }
      return { id: authenticatedUserId };
    },
    createDatabase: () => {
      if (!databaseAvailable) {
        return null;
      }

      return {
        async reverseInternalTransferResolution(
          receivedUserId,
          receivedReconciliationId,
        ) {
          reverseCalls.push({
            userId: receivedUserId,
            reconciliationId: receivedReconciliationId,
          });

          if (rpcErrorMessage !== null) {
            return { data: null, errorMessage: rpcErrorMessage };
          }

          if (rpcResult === null) {
            return { data: null, errorMessage: "invalid_rpc_payload" };
          }

          const status = rpcResult.status;
          if (typeof status !== "string") {
            return { data: null, errorMessage: "invalid_rpc_payload" };
          }

          return {
            data: {
              status,
              reconciliation_id: typeof rpcResult.reconciliation_id === "string"
                ? rpcResult.reconciliation_id
                : undefined,
              transfer_operation_id:
                typeof rpcResult.transfer_operation_id === "string"
                  ? rpcResult.transfer_operation_id
                  : rpcResult.transfer_operation_id === null
                  ? null
                  : undefined,
            },
            errorMessage: null,
          };
        },
      };
    },
  });

  const method = options.method ?? "POST";
  const upperMethod = method.toUpperCase();
  const omitBody = upperMethod === "GET" || upperMethod === "HEAD";
  const body = options.body === undefined
    ? { reconciliation_id: reconciliationId }
    : options.body;

  // Deno Web API forbids a body on GET/HEAD; keep R3 non-POST Request body-free.
  const request = omitBody || body === null
    ? new Request("https://example.com", { method })
    : new Request("https://example.com", {
      method,
      headers: { "Content-Type": "application/json" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    });

  return { handler, request, reverseCalls };
}

async function readJson(
  response: Response,
): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

Deno.test("R1 missing auth returns unauthorized", async () => {
  const { handler, request, reverseCalls } = createHarness({
    authenticatedUserId: null,
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 401);
  assertEquals((payload.error as { code: string }).code, "unauthorized");
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R2 wrong auth returns unauthorized", async () => {
  const { handler, request, reverseCalls } = createHarness({
    authenticatedUserId: null,
  });
  const response = await handler(request);
  assertEquals(response.status, 401);
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R3 non-POST rejected", async () => {
  const { handler, reverseCalls } = createHarness();
  const response = await handler(
    new Request("https://example.com", { method: "PUT" }),
  );
  const payload = await readJson(response);
  assertEquals(response.status, 405);
  assertEquals((payload.error as { code: string }).code, "method_not_allowed");
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R4 malformed JSON returns invalid_request", async () => {
  const { handler, reverseCalls } = createHarness();
  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      body: "{bad",
    }),
  );
  const payload = await readJson(response);
  assertEquals(response.status, 400);
  assertEquals((payload.error as { code: string }).code, "invalid_request");
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R5 missing reconciliation_id returns invalid_request", async () => {
  const { handler, request, reverseCalls } = createHarness({
    body: { user_id: forgedUserId },
  });
  const response = await handler(request);
  assertEquals(response.status, 400);
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R6 invalid UUID returns invalid_request", async () => {
  const { handler, request, reverseCalls } = createHarness({
    body: { reconciliation_id: "abc" },
  });
  const response = await handler(request);
  assertEquals(response.status, 400);
  assertEquals(reverseCalls.length, 0);
});

Deno.test("R7 forged user_id cannot influence p_user_id", async () => {
  const { handler, request, reverseCalls } = createHarness({
    body: {
      reconciliation_id: reconciliationId,
      user_id: forgedUserId,
    },
  });
  const response = await handler(request);
  assertEquals(response.status, 200);
  assertEquals(reverseCalls[0].userId, userId);
  assert(reverseCalls[0].userId !== forgedUserId, "forged user used");
});

Deno.test("R8 authenticated user ID passed", async () => {
  const { handler, request, reverseCalls } = createHarness();
  await handler(request);
  assertEquals(reverseCalls[0].userId, userId);
  assertEquals(reverseCalls[0].reconciliationId, reconciliationId);
});

Deno.test("R9 reversed success", async () => {
  const { handler, request } = createHarness();
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 200);
  assertEquals(payload.status, "reversed");
  assertEquals(payload.reconciliation_id, reconciliationId);
  assertEquals(payload.transfer_operation_id, transferOperationId);
});

Deno.test("R10 already_reversed", async () => {
  const { handler, request } = createHarness({
    rpcResult: {
      status: "already_reversed",
      reconciliation_id: reconciliationId,
      transfer_operation_id: transferOperationId,
    },
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 200);
  assertEquals(payload.status, "already_reversed");
});

Deno.test("R11 invalid_state", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "invalid_state",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 409);
  assertEquals((payload.error as { code: string }).code, "invalid_state");
});

Deno.test("R12 foreign/not_found safe", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "reconciliation_not_found",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 404);
  assertEquals((payload.error as { code: string }).code, "not_found");
  assert(!JSON.stringify(payload).includes(forgedUserId), "foreign id leaked");
});

Deno.test("R13 RPC throw safe", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "permission denied for table vault_secrets",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 500);
  assertEquals((payload.error as { code: string }).code, "internal_error");
  assert(!JSON.stringify(payload).includes("vault_secrets"), "detail leaked");
});

Deno.test("R14 no secrets/internal SQL details", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "Authorization Bearer secret-token SQLSTATE 42501",
  });
  const response = await handler(request);
  const text = JSON.stringify(await readJson(response));
  assert(!text.includes("secret-token"), "token leaked");
  assert(!text.includes("SQLSTATE"), "sqlstate leaked");
});
