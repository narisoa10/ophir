import { createPlaidRemoveItemHandler } from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const strangerId = "55555555-5555-4555-8555-555555555555";
const connectionId = "22222222-2222-4222-8222-222222222222";
const secretId = "44444444-4444-4444-8444-444444444444";
const accessToken = "access-token-secret-value";
const plaidClientId = "client-id-value";
const plaidSecret = "sandbox-secret-value";

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

type ItemState = "active" | "disconnected" | "deleted";

type PlaidReply = "ok" | "throw" | "not_json" | {
  status: number;
  errorType: string;
  errorCode: string;
};

// Simulates the Step 1 RPC contracts and a Plaid Item that disappears once
// /item/remove succeeded (later calls answer ITEM_NOT_FOUND).
class LifecycleWorld {
  state: ItemState = "active";
  plaidItemExists = true;
  calls: string[] = [];
  removeBodies: Record<string, unknown>[] = [];
  plaidReplies: PlaidReply[] = [];
  lookupFails = false;
  tokenMissing = false;
  disconnectBeforeTokenRead = false;
  disconnectFailures = 0;
  deleteFailures = 0;
  legacyFactoryCalls = 0;

  handler(options: { withPlaidConfig?: boolean } = {}) {
    const withPlaidConfig = options.withPlaidConfig ?? true;
    return createPlaidRemoveItemHandler({
      authenticateRequest: (request) => {
        const user = request.headers.get("x-test-user");
        return Promise.resolve(user === null ? null : { id: user });
      },
      createDatabase: () => {
        this.legacyFactoryCalls += 1;
        return null;
      },
      createLifecycleDatabase: () => ({
        getItemLifecycleState: (receivedUserId, receivedConnectionId) => {
          this.calls.push("get_state");
          if (this.lookupFails) {
            return Promise.resolve("failed");
          }
          if (
            receivedUserId !== userId ||
            receivedConnectionId !== connectionId ||
            this.state === "deleted"
          ) {
            return Promise.resolve(null);
          }
          return Promise.resolve({
            plaid_environment: "sandbox",
            disconnected_at: this.state === "disconnected"
              ? "2026-10-03T12:00:00.000Z"
              : null,
          });
        },
        getAccessTokenForItem: (receivedUserId, receivedConnectionId) => {
          this.calls.push("get_token");
          if (this.disconnectBeforeTokenRead) {
            this.state = "disconnected";
          }
          const available = !this.tokenMissing &&
            this.state === "active" &&
            receivedUserId === userId &&
            receivedConnectionId === connectionId;
          return Promise.resolve(available ? accessToken : null);
        },
        disconnectItemLocal: (receivedUserId, receivedConnectionId) => {
          this.calls.push("disconnect_local");
          if (this.disconnectFailures > 0) {
            this.disconnectFailures -= 1;
            return Promise.resolve(null);
          }
          if (
            receivedUserId !== userId ||
            receivedConnectionId !== connectionId ||
            this.state === "deleted"
          ) {
            return Promise.resolve("not_found");
          }
          if (this.state === "disconnected") {
            return Promise.resolve("already_disconnected");
          }
          this.state = "disconnected";
          return Promise.resolve("disconnected");
        },
        deleteItemLocal: (receivedUserId, receivedConnectionId) => {
          this.calls.push("delete_local");
          if (this.deleteFailures > 0) {
            this.deleteFailures -= 1;
            return Promise.resolve(null);
          }
          if (
            receivedUserId !== userId ||
            receivedConnectionId !== connectionId ||
            this.state === "deleted"
          ) {
            return Promise.resolve("not_found");
          }
          this.state = "deleted";
          return Promise.resolve("deleted");
        },
      }),
      fetch: (_url, init) => {
        this.calls.push("plaid_remove");
        this.removeBodies.push(JSON.parse(String(init?.body)));
        const reply = this.plaidReplies.shift() ?? "ok";
        if (reply === "throw") {
          return Promise.reject(new Error("network timeout"));
        }
        if (reply === "not_json") {
          return Promise.resolve(new Response("<html>gateway</html>", { status: 504 }));
        }
        if (reply !== "ok") {
          return Promise.resolve(
            new Response(
              JSON.stringify({ error_type: reply.errorType, error_code: reply.errorCode }),
              { status: reply.status },
            ),
          );
        }
        if (!this.plaidItemExists) {
          return Promise.resolve(
            new Response(
              JSON.stringify({ error_type: "ITEM_ERROR", error_code: "ITEM_NOT_FOUND" }),
              { status: 400 },
            ),
          );
        }
        this.plaidItemExists = false;
        return Promise.resolve(
          new Response(JSON.stringify({ request_id: "request-id" }), { status: 200 }),
        );
      },
      getEnv: (name) => {
        if (!withPlaidConfig) {
          return undefined;
        }
        if (name === "PLAID_CLIENT_ID") {
          return plaidClientId;
        }
        if (name === "PLAID_SANDBOX_SECRET") {
          return plaidSecret;
        }
        return undefined;
      },
    });
  }
}

function lifecycleRequest(
  body: Record<string, unknown>,
  user: string | null = userId,
): Request {
  const headers = new Headers();
  if (user !== null) {
    headers.set("x-test-user", user);
  }
  return new Request("https://example.com", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

async function call(
  world: LifecycleWorld,
  body: Record<string, unknown>,
  options: { user?: string | null; withPlaidConfig?: boolean } = {},
): Promise<{ status: number; text: string; json: Record<string, unknown> }> {
  const response = await world.handler({
    withPlaidConfig: options.withPlaidConfig,
  })(lifecycleRequest(body, options.user === undefined ? userId : options.user));
  const text = await response.text();
  assertNoSecrets(text);
  return { status: response.status, text, json: JSON.parse(text) };
}

function assertNoSecrets(text: string): void {
  for (const secret of [accessToken, secretId, plaidSecret, plaidClientId]) {
    assert(!text.includes(secret), "response exposed a secret");
  }
}

function errorCode(json: Record<string, unknown>): unknown {
  return (json.error as Record<string, unknown> | undefined)?.code;
}

const disconnectBody = { connection_id: connectionId, action: "disconnect" };
const deleteBody = { connection_id: connectionId, action: "delete" };

// ---------------------------------------------------------------------------
// Request contract
// ---------------------------------------------------------------------------

Deno.test("lifecycle: unauthenticated request touches nothing", async () => {
  const world = new LifecycleWorld();
  for (const body of [disconnectBody, deleteBody]) {
    const result = await call(world, body, { user: null });
    assertEquals(result.status, 401);
    assertEquals(errorCode(result.json), "unauthorized");
  }
  assertEquals(world.calls.length, 0);
});

Deno.test("lifecycle: unknown action or invalid connection id is rejected before any call", async () => {
  const world = new LifecycleWorld();
  for (
    const body of [
      { connection_id: connectionId, action: "remove" },
      { connection_id: connectionId, action: "DISCONNECT" },
      { connection_id: connectionId, action: null },
      { connection_id: connectionId, action: 1 },
      { connection_id: "not-a-uuid", action: "disconnect" },
      { action: "delete" },
    ]
  ) {
    const result = await call(world, body);
    assertEquals(result.status, 400, JSON.stringify(body));
    assertEquals(errorCode(result.json), "invalid_request");
  }
  assertEquals(world.calls.length, 0);
  assertEquals(world.legacyFactoryCalls, 0);
});

Deno.test("lifecycle: a request without action keeps the original remove path", async () => {
  const world = new LifecycleWorld();
  const result = await call(world, { connection_id: connectionId });
  assertEquals(result.status, 500);
  assertEquals(errorCode(result.json), "supabase_config_missing");
  assertEquals(world.legacyFactoryCalls, 1);
  assertEquals(world.calls.length, 0, "lifecycle database must not be used");
});

// ---------------------------------------------------------------------------
// Disconnect
// ---------------------------------------------------------------------------

Deno.test("disconnect: active owned Item removes the Plaid Item first, then the local transition", async () => {
  const world = new LifecycleWorld();
  const result = await call(world, disconnectBody);

  assertEquals(result.status, 200);
  assertEquals(JSON.stringify(result.json), JSON.stringify({ status: "disconnected" }));
  assertEquals(world.calls.join(","), "get_state,get_token,plaid_remove,disconnect_local");
  assertEquals(world.removeBodies.length, 1);
  assertEquals(world.removeBodies[0].access_token, accessToken);
  assertEquals(world.state, "disconnected");
  assertEquals(world.calls.includes("delete_local"), false, "history is never deleted");
});

Deno.test("disconnect: repeated Disconnect is a no-op success without Plaid", async () => {
  const world = new LifecycleWorld();
  assertEquals((await call(world, disconnectBody)).status, 200);
  world.calls = [];

  const repeat = await call(world, disconnectBody);
  assertEquals(repeat.status, 200);
  assertEquals(JSON.stringify(repeat.json), JSON.stringify({ status: "already_disconnected" }));
  assertEquals(world.calls.join(","), "get_state");
  assertEquals(world.removeBodies.length, 1);
});

Deno.test("disconnect: foreign or missing Item is not found and untouched", async () => {
  const foreign = new LifecycleWorld();
  const foreignResult = await call(foreign, disconnectBody, { user: strangerId });
  assertEquals(foreignResult.status, 404);
  assertEquals(errorCode(foreignResult.json), "connection_not_found");
  assertEquals(foreign.calls.join(","), "get_state");
  assertEquals(foreign.state, "active");

  const missing = new LifecycleWorld();
  missing.state = "deleted";
  const missingResult = await call(missing, disconnectBody);
  assertEquals(missingResult.status, 404);
  assertEquals(missing.calls.join(","), "get_state");
});

Deno.test("disconnect: Plaid errors leave the Item connected with its token", async () => {
  for (
    const reply of [
      { status: 500, errorType: "API_ERROR", errorCode: "INTERNAL_SERVER_ERROR" },
      { status: 400, errorType: "ITEM_ERROR", errorCode: "ITEM_LOGIN_REQUIRED" },
      { status: 400, errorType: "INVALID_INPUT", errorCode: "INVALID_ACCESS_TOKEN" },
    ]
  ) {
    const world = new LifecycleWorld();
    world.plaidReplies = [reply];
    const result = await call(world, disconnectBody);
    assertEquals(result.status, 502, reply.errorCode);
    assertEquals(errorCode(result.json), "plaid_request_failed");
    assertEquals(world.calls.includes("disconnect_local"), false);
    assertEquals(world.state, "active");
  }
});

Deno.test("disconnect: unknown Plaid outcome never claims removal and changes nothing locally", async () => {
  for (const reply of ["throw", "not_json"] as const) {
    const world = new LifecycleWorld();
    world.plaidReplies = [reply];
    const result = await call(world, disconnectBody);
    assertEquals(result.status, 502, reply);
    assertEquals(errorCode(result.json), "plaid_outcome_unknown");
    assertEquals(world.calls.includes("disconnect_local"), false);
    assertEquals(world.state, "active");
  }
});

Deno.test("disconnect: retry after an unknown outcome converges via ITEM_NOT_FOUND", async () => {
  const world = new LifecycleWorld();
  // Plaid removed the Item but the answer was lost.
  world.plaidItemExists = false;
  world.plaidReplies = ["throw"];
  assertEquals((await call(world, disconnectBody)).status, 502);
  assertEquals(world.state, "active");

  const retry = await call(world, disconnectBody);
  assertEquals(retry.status, 200);
  assertEquals(retry.json.status, "disconnected");
  assertEquals(world.state, "disconnected");
});

Deno.test("disconnect: local failure after Plaid removal is reported and recovered by retry", async () => {
  const world = new LifecycleWorld();
  world.disconnectFailures = 1;

  const first = await call(world, disconnectBody);
  assertEquals(first.status, 500);
  assertEquals(errorCode(first.json), "local_lifecycle_failed");
  assertEquals(world.state, "active");
  assertEquals(world.plaidItemExists, false);

  world.calls = [];
  const retry = await call(world, disconnectBody);
  assertEquals(retry.status, 200);
  assertEquals(retry.json.status, "disconnected");
  assertEquals(world.calls.join(","), "get_state,get_token,plaid_remove,disconnect_local");
  assertEquals(world.state, "disconnected");
});

Deno.test("disconnect: lookup failure and missing Plaid config stop before Plaid", async () => {
  const lookup = new LifecycleWorld();
  lookup.lookupFails = true;
  const lookupResult = await call(lookup, disconnectBody);
  assertEquals(lookupResult.status, 500);
  assertEquals(errorCode(lookupResult.json), "local_lifecycle_failed");
  assertEquals(lookup.calls.join(","), "get_state");

  const config = new LifecycleWorld();
  const configResult = await call(config, disconnectBody, { withPlaidConfig: false });
  assertEquals(configResult.status, 500);
  assertEquals(errorCode(configResult.json), "plaid_config_missing");
  assertEquals(config.calls.join(","), "get_state");
  assertEquals(config.state, "active");
});

Deno.test("disconnect: a concurrent Disconnect that deleted the token is reported as already disconnected", async () => {
  const world = new LifecycleWorld();
  world.disconnectBeforeTokenRead = true;
  const result = await call(world, disconnectBody);
  assertEquals(result.status, 200);
  assertEquals(result.json.status, "already_disconnected");
  assertEquals(world.calls.join(","), "get_state,get_token,get_state");
});

Deno.test("disconnect: a connected Item without a readable token fails closed", async () => {
  const world = new LifecycleWorld();
  world.tokenMissing = true;
  const result = await call(world, disconnectBody);
  assertEquals(result.status, 500);
  assertEquals(errorCode(result.json), "local_lifecycle_failed");
  assertEquals(world.calls.includes("plaid_remove"), false);
  assertEquals(world.calls.includes("disconnect_local"), false);
});

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

Deno.test("delete: active Item is removed at Plaid, disconnected, then deleted locally", async () => {
  const world = new LifecycleWorld();
  const result = await call(world, deleteBody);

  assertEquals(result.status, 200);
  assertEquals(JSON.stringify(result.json), JSON.stringify({ status: "deleted" }));
  assertEquals(
    world.calls.join(","),
    "get_state,get_token,plaid_remove,disconnect_local,delete_local",
  );
  assertEquals(world.state, "deleted");
});

Deno.test("delete: already disconnected Item is deleted without token or Plaid", async () => {
  const world = new LifecycleWorld();
  world.state = "disconnected";
  world.plaidItemExists = false;
  const result = await call(world, deleteBody);

  assertEquals(result.status, 200);
  assertEquals(result.json.status, "deleted");
  assertEquals(world.calls.join(","), "get_state,delete_local");
  assertEquals(world.removeBodies.length, 0);
});

Deno.test("delete: repeated Delete is a stable not found without mutation", async () => {
  const world = new LifecycleWorld();
  assertEquals((await call(world, deleteBody)).status, 200);
  world.calls = [];

  const repeat = await call(world, deleteBody);
  assertEquals(repeat.status, 404);
  assertEquals(errorCode(repeat.json), "connection_not_found");
  assertEquals(world.calls.join(","), "get_state");
});

Deno.test("delete: foreign Item is not found and untouched", async () => {
  const world = new LifecycleWorld();
  const result = await call(world, deleteBody, { user: strangerId });
  assertEquals(result.status, 404);
  assertEquals(world.calls.join(","), "get_state");
  assertEquals(world.state, "active");
});

Deno.test("delete: Plaid failure or unknown outcome changes nothing locally", async () => {
  for (
    const [reply, code] of [
      [{ status: 500, errorType: "API_ERROR", errorCode: "INTERNAL_SERVER_ERROR" }, "plaid_request_failed"],
      ["throw", "plaid_outcome_unknown"],
    ] as const
  ) {
    const world = new LifecycleWorld();
    world.plaidReplies = [reply];
    const result = await call(world, deleteBody);
    assertEquals(result.status, 502);
    assertEquals(errorCode(result.json), code);
    assertEquals(world.calls.includes("disconnect_local"), false);
    assertEquals(world.calls.includes("delete_local"), false);
    assertEquals(world.state, "active");
  }
});

Deno.test("delete: local Delete failure leaves a disconnected Item that a retry deletes", async () => {
  const world = new LifecycleWorld();
  world.deleteFailures = 1;
  const first = await call(world, deleteBody);
  assertEquals(first.status, 500);
  assertEquals(errorCode(first.json), "local_lifecycle_failed");
  assertEquals(world.state, "disconnected");

  world.calls = [];
  const retry = await call(world, deleteBody);
  assertEquals(retry.status, 200);
  assertEquals(world.calls.join(","), "get_state,delete_local");
  assertEquals(world.removeBodies.length, 1);
});

Deno.test("delete: lookup failure and missing Plaid config stop before Plaid", async () => {
  const lookup = new LifecycleWorld();
  lookup.lookupFails = true;
  const lookupResult = await call(lookup, deleteBody);
  assertEquals(lookupResult.status, 500);
  assertEquals(errorCode(lookupResult.json), "local_lifecycle_failed");
  assertEquals(lookup.calls.join(","), "get_state");

  const config = new LifecycleWorld();
  const configResult = await call(config, deleteBody, { withPlaidConfig: false });
  assertEquals(configResult.status, 500);
  assertEquals(errorCode(configResult.json), "plaid_config_missing");
  assertEquals(config.calls.join(","), "get_state");
  assertEquals(config.state, "active");
});
