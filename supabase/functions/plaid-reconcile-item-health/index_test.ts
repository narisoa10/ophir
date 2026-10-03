import { createPlaidReconcileItemHealthHandler } from "./handler.ts";

const internalSecret = "internal-secret-value";
const sandboxSecret = "sandbox-secret-value";
const accessTokenPrefix = "access-token-secret-";

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

type Candidate = { connectionId: string; userId: string };
type FakeResponse = { status: number; body: Record<string, unknown> };

function candidate(index: number): Candidate {
  return {
    connectionId: `00000000-0000-4000-8000-00000000000${index}`,
    userId: `11111111-1111-4111-8111-11111111111${index}`,
  };
}

function itemGet(error: Record<string, unknown> | null): FakeResponse {
  return {
    status: 200,
    body: { item: { item_id: "item", error, consent_expiration_time: null } },
  };
}

function createHarness(options: {
  secretHeader?: string | null;
  requestBody?: Record<string, unknown>;
  candidates?: Candidate[] | null;
  itemGetResponses?: Record<string, FakeResponse>;
  throwFor?: string;
  previousStatus?: "active" | "login_required";
} = {}) {
  const listLimits: number[] = [];
  const observations: Array<Record<string, unknown>> = [];
  const enqueueCalls: string[] = [];
  const logs: string[] = [];
  const candidates = options.candidates === undefined
    ? [candidate(1), candidate(2)]
    : options.candidates;
  const previousStatus = options.previousStatus ?? "active";

  const handler = createPlaidReconcileItemHealthHandler({
    createDatabase: () => ({
      async listItemsForHealthReconcile(limit) {
        listLimits.push(limit);
        return candidates;
      },
      async getItemEnvironment(_userId, connectionId) {
        if (connectionId === options.throwFor) {
          throw new Error("lookup exploded");
        }
        return "sandbox";
      },
      async getAccessTokenForItem(_userId, connectionId) {
        return `${accessTokenPrefix}${connectionId}`;
      },
      async recordItemHealthObservation(observation) {
        observations.push({ ...observation });
        return {
          applied: true,
          previousStatus,
          status: observation.status,
          plaidItemId: `external-${observation.connectionId}`,
        };
      },
      async enqueueTransactionSyncJob(externalPlaidItemId) {
        enqueueCalls.push(externalPlaidItemId);
      },
    }),
    fetch: async (_url, init) => {
      const token = String(JSON.parse(String(init?.body)).access_token);
      const connectionId = token.slice(accessTokenPrefix.length);
      const fake = options.itemGetResponses?.[connectionId] ?? itemGet(null);
      return new Response(JSON.stringify(fake.body), { status: fake.status });
    },
    getEnv: (name) => {
      if (name === "OPHIR_INTERNAL_WORKER_SECRET") {
        return internalSecret;
      }
      if (name === "PLAID_CLIENT_ID") {
        return "client-id";
      }
      if (name === "PLAID_SANDBOX_SECRET") {
        return sandboxSecret;
      }
      return undefined;
    },
    now: () => new Date("2026-10-03T12:00:00.000Z"),
    log: (message) => logs.push(message),
  });

  const headers: Record<string, string> = {};
  const secretHeader = options.secretHeader === undefined
    ? internalSecret
    : options.secretHeader;
  if (secretHeader !== null) {
    headers["x-ophir-internal-secret"] = secretHeader;
  }

  const request = new Request("https://example.com", {
    method: "POST",
    headers,
    body: JSON.stringify(options.requestBody ?? {}),
  });

  return { handler, request, listLimits, observations, enqueueCalls, logs };
}

Deno.test("missing or wrong internal secret is rejected before DB access", async () => {
  for (const secretHeader of [null, "wrong-secret"]) {
    const { handler, request, listLimits } = createHarness({ secretHeader });

    const response = await handler(request);

    assertEquals(response.status, 401);
    assertEquals(listLimits.length, 0);
  }
});

Deno.test("default and explicit limits are bounded", async () => {
  const defaults = createHarness();
  await defaults.handler(defaults.request);
  assertEquals(defaults.listLimits[0], 25);

  const explicit = createHarness({ requestBody: { limit: 100 } });
  await explicit.handler(explicit.request);
  assertEquals(explicit.listLimits[0], 100);

  for (const limit of [0, 101, 2.5, "10"]) {
    const invalid = createHarness({ requestBody: { limit } });
    const response = await invalid.handler(invalid.request);
    assertEquals(response.status, 400);
    assertEquals(invalid.listLimits.length, 0);
  }
});

Deno.test("reconcile records item/get observations without clearing pending disconnect", async () => {
  const first = candidate(1).connectionId;
  const { handler, request, observations } = createHarness({
    itemGetResponses: {
      [first]: itemGet({ error_code: "ITEM_LOGIN_REQUIRED" }),
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.status, "ok");
  assertEquals(body.checked, 2);
  assertEquals(observations.length, 2);
  for (const observation of observations) {
    assertEquals(observation.fromItemGet, true);
    assertEquals(observation.clearPendingDisconnect, false);
  }
  assertEquals(observations[0].status, "login_required");
  assertEquals(observations[1].status, "active");
});

Deno.test("one failing Item does not stop the batch", async () => {
  const first = candidate(1).connectionId;
  const second = candidate(2).connectionId;
  const { handler, request, observations } = createHarness({
    candidates: [candidate(1), candidate(2), candidate(3)],
    throwFor: first,
    itemGetResponses: {
      [second]: { status: 500, body: { error_code: "INTERNAL_SERVER_ERROR" } },
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.checked, 3);
  assertEquals(body.failed, 2);
  assertEquals(observations.length, 1);
});

Deno.test("other Item errors are skipped without health write", async () => {
  const { handler, request, observations } = createHarness({
    candidates: [candidate(1)],
    itemGetResponses: {
      [candidate(1).connectionId]: itemGet({ error_code: "INSTITUTION_DOWN" }),
    },
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(body.skipped, 1);
  assertEquals(observations.length, 0);
});

Deno.test("recovered Item is counted and enqueued", async () => {
  const { handler, request, enqueueCalls } = createHarness({
    candidates: [candidate(1)],
    previousStatus: "login_required",
  });

  const response = await handler(request);
  const body = await response.json();

  assertEquals(body.recovered, 1);
  assertEquals(body.updated, 1);
  assertEquals(enqueueCalls.length, 1);
});

Deno.test("list failure returns 500", async () => {
  const { handler, request } = createHarness({ candidates: null });

  const response = await handler(request);

  assertEquals(response.status, 500);
});

Deno.test("response and logs contain counts only, no tokens or ids", async () => {
  const { handler, request, logs } = createHarness();

  const response = await handler(request);
  const text = await response.text();

  for (const output of [text, ...logs]) {
    assert(!output.includes(accessTokenPrefix), "output exposed access token");
    assert(!output.includes(sandboxSecret), "output exposed Plaid secret");
    assert(!output.includes(internalSecret), "output exposed internal secret");
    assert(
      !output.includes(candidate(1).connectionId),
      "output exposed connection id",
    );
  }
  assertEquals(logs.length, 1);
});
