import { createPlaidConfirmInternalTransferHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const reconciliationId = "22222222-2222-4222-8222-222222222222";
const transferOperationId = "33333333-3333-4333-8333-333333333333";
const forgedUserId = "99999999-9999-4999-8999-999999999999";

type ConfirmCall = {
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
  const confirmCalls: ConfirmCall[] = [];
  const authenticatedUserId = options.authenticatedUserId === undefined
    ? userId
    : options.authenticatedUserId;
  const databaseAvailable = options.databaseAvailable ?? true;
  const rpcErrorMessage = options.rpcErrorMessage ?? null;
  const rpcResult = options.rpcResult === undefined
    ? {
      status: "confirmed",
      reconciliation_id: reconciliationId,
      transfer_operation_id: transferOperationId,
    }
    : options.rpcResult;

  const handler = createPlaidConfirmInternalTransferHandler({
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
        async confirmInternalTransferCandidate(
          receivedUserId,
          receivedReconciliationId,
        ) {
          confirmCalls.push({
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
              reason: typeof rpcResult.reason === "string"
                ? rpcResult.reason
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

  // Deno Web API forbids a body on GET/HEAD; match reverse R3 safe Request pattern.
  const request = omitBody || body === null
    ? new Request("https://example.com", { method })
    : new Request("https://example.com", {
      method,
      headers: { "Content-Type": "application/json" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    });

  return { handler, request, confirmCalls };
}

async function readJson(
  response: Response,
): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

Deno.test("C1 missing auth returns unauthorized", async () => {
  const { handler, request, confirmCalls } = createHarness({
    authenticatedUserId: null,
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 401);
  assertEquals((payload.error as { code: string }).code, "unauthorized");
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C2 wrong auth returns unauthorized", async () => {
  const { handler, request, confirmCalls } = createHarness({
    authenticatedUserId: null,
  });
  const response = await handler(request);
  assertEquals(response.status, 401);
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C3 non-POST rejected", async () => {
  // Same pattern as reverse R3: default harness + non-POST Request without body.
  const { handler, confirmCalls } = createHarness();
  const response = await handler(
    new Request("https://example.com", { method: "PUT" }),
  );
  const payload = await readJson(response);
  assertEquals(response.status, 405);
  assertEquals((payload.error as { code: string }).code, "method_not_allowed");
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C4 malformed JSON returns invalid_request", async () => {
  const { handler, confirmCalls } = createHarness({
    body: "{not-json",
  });
  const response = await handler(
    new Request("https://example.com", {
      method: "POST",
      body: "{not-json",
    }),
  );
  const payload = await readJson(response);
  assertEquals(response.status, 400);
  assertEquals((payload.error as { code: string }).code, "invalid_request");
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C5 missing reconciliation_id returns invalid_request", async () => {
  const { handler, request, confirmCalls } = createHarness({
    body: {},
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 400);
  assertEquals((payload.error as { code: string }).code, "invalid_request");
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C6 invalid UUID returns invalid_request", async () => {
  const { handler, request, confirmCalls } = createHarness({
    body: { reconciliation_id: "not-a-uuid" },
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 400);
  assertEquals((payload.error as { code: string }).code, "invalid_request");
  assertEquals(confirmCalls.length, 0);
});

Deno.test("C7 forged user_id cannot influence RPC p_user_id", async () => {
  const { handler, request, confirmCalls } = createHarness({
    body: {
      reconciliation_id: reconciliationId,
      user_id: forgedUserId,
      p_user_id: forgedUserId,
    },
  });
  const response = await handler(request);
  assertEquals(response.status, 200);
  assertEquals(confirmCalls.length, 1);
  assertEquals(confirmCalls[0].userId, userId);
  assert(confirmCalls[0].userId !== forgedUserId, "forged user used");
});

Deno.test("C8 authenticated user ID passed to RPC", async () => {
  const { handler, request, confirmCalls } = createHarness();
  await handler(request);
  assertEquals(confirmCalls.length, 1);
  assertEquals(confirmCalls[0].userId, userId);
  assertEquals(confirmCalls[0].reconciliationId, reconciliationId);
});

Deno.test("C9 confirmed success forwarding", async () => {
  const { handler, request } = createHarness();
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 200);
  assertEquals(payload.status, "confirmed");
  assertEquals(payload.reconciliation_id, reconciliationId);
  assertEquals(payload.transfer_operation_id, transferOperationId);
});

Deno.test("C10 already_confirmed forwarding", async () => {
  const { handler, request } = createHarness({
    rpcResult: {
      status: "already_confirmed",
      reconciliation_id: reconciliationId,
      transfer_operation_id: transferOperationId,
    },
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 200);
  assertEquals(payload.status, "already_confirmed");
  assertEquals(payload.transfer_operation_id, transferOperationId);
});

Deno.test("C11 stale_candidate safe mapping", async () => {
  const { handler, request } = createHarness({
    rpcResult: {
      status: "rejected",
      reason: "stale_candidate",
      reconciliation_id: reconciliationId,
    },
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 409);
  assertEquals((payload.error as { code: string }).code, "stale_candidate");
  assert(!JSON.stringify(payload).includes("SQLSTATE"), "sqlstate leaked");
});

Deno.test("C12 invalid_state safe mapping", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "invalid_state",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 409);
  assertEquals((payload.error as { code: string }).code, "invalid_state");
});

Deno.test("C13 reversed safe mapping", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "reversed",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 409);
  assertEquals((payload.error as { code: string }).code, "reversed");
});

Deno.test("C14 RPC throw maps to safe internal_error", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: 'relation "secret_table" does not exist SQLSTATE 42P01',
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 500);
  assertEquals((payload.error as { code: string }).code, "internal_error");
  assert(
    !JSON.stringify(payload).includes("secret_table"),
    "sql detail leaked",
  );
  assert(!JSON.stringify(payload).includes("SQLSTATE"), "sqlstate leaked");
});

Deno.test("C15 response does not expose secrets or SQL details", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "access_token=super-secret authorization=Bearer xyz",
  });
  const response = await handler(request);
  const text = JSON.stringify(await readJson(response));
  assert(!text.includes("super-secret"), "secret leaked");
  assert(!text.includes("Bearer"), "auth leaked");
  assertEquals(response.status, 500);
});

Deno.test("C16 body cannot override credentials or RPC identity", async () => {
  const { handler, request, confirmCalls } = createHarness({
    body: {
      reconciliation_id: reconciliationId,
      user_id: forgedUserId,
      SUPABASE_SERVICE_ROLE_KEY: "attacker-key",
      rpc: "other_rpc",
    },
  });
  const response = await handler(request);
  assertEquals(response.status, 200);
  assertEquals(confirmCalls[0].userId, userId);
  assertEquals(confirmCalls[0].reconciliationId, reconciliationId);
});

Deno.test("not_found maps reconciliation_not_found", async () => {
  const { handler, request } = createHarness({
    rpcErrorMessage: "reconciliation_not_found",
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 404);
  assertEquals((payload.error as { code: string }).code, "not_found");
});

Deno.test("missing supabase config returns supabase_config_missing", async () => {
  const { handler, request } = createHarness({
    databaseAvailable: false,
  });
  const response = await handler(request);
  const payload = await readJson(response);
  assertEquals(response.status, 500);
  assertEquals(
    (payload.error as { code: string }).code,
    "supabase_config_missing",
  );
});
