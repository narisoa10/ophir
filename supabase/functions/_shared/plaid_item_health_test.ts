import {
  becameActive,
  fetchItemGetHealth,
  isItemLoginRequiredError,
  isItemUnavailableError,
  loginRequiredObservation,
  observationFromItemGet,
  readItemGetHealth,
  readPlaidErrorCode,
} from "./plaid_item_health.ts";

const connectionId = "22222222-2222-4222-8222-222222222222";
const observedAt = "2026-10-03T12:00:00.000Z";

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function itemPayload(
  error: unknown,
  consentExpirationTime: unknown = null,
): Record<string, unknown> {
  return {
    item: { item_id: "item", error, consent_expiration_time: consentExpirationTime },
  };
}

Deno.test("Plaid error code classification", () => {
  assertEquals(readPlaidErrorCode({ error_code: "ITEM_LOGIN_REQUIRED" }), "ITEM_LOGIN_REQUIRED");
  assertEquals(readPlaidErrorCode({ error_code: "" }), null);
  assertEquals(readPlaidErrorCode(null), null);
  assertEquals(readPlaidErrorCode(["ITEM_LOGIN_REQUIRED"]), null);
  assertEquals(isItemLoginRequiredError({ error_code: "ITEM_LOGIN_REQUIRED" }), true);
  assertEquals(isItemLoginRequiredError({ error_code: "INSTITUTION_DOWN" }), false);
  assertEquals(isItemUnavailableError({ error_code: "ITEM_NOT_FOUND" }), true);
  assertEquals(isItemUnavailableError({ error_code: "INVALID_ACCESS_TOKEN" }), true);
  assertEquals(isItemUnavailableError({ error_code: "ITEM_LOGIN_REQUIRED" }), false);
});

Deno.test("item/get healthy Item keeps consent as-is", () => {
  const withConsent = readItemGetHealth(itemPayload(null, "2026-12-01T00:00:00Z"));
  assertEquals(withConsent.kind, "healthy");
  if (withConsent.kind === "healthy") {
    assertEquals(withConsent.consentExpiresAt, "2026-12-01T00:00:00Z");
  }

  const withoutConsent = readItemGetHealth(itemPayload(null));
  assertEquals(withoutConsent.kind, "healthy");
  if (withoutConsent.kind === "healthy") {
    assertEquals(withoutConsent.consentExpiresAt, null);
  }
});

Deno.test("item/get login reasons map to Ophir reasons", () => {
  const cases: Array<[unknown, string]> = [
    ["OAUTH_CONSENT_EXPIRED", "consent_expired"],
    ["OAUTH_USER_REVOKED", "permission_revoked"],
    ["OAUTH_INVALID_TOKEN", "login_required"],
    [undefined, "login_required"],
    [null, "login_required"],
  ];

  for (const [reason, expected] of cases) {
    const health = readItemGetHealth(
      itemPayload({ error_code: "ITEM_LOGIN_REQUIRED", error_code_reason: reason }),
    );
    assertEquals(health.kind, "login_required");
    if (health.kind === "login_required") {
      assertEquals(health.reason, expected);
    }
  }
});

Deno.test("item/get other Item error is not a health change", () => {
  const health = readItemGetHealth(itemPayload({ error_code: "INSTITUTION_DOWN" }));
  assertEquals(health.kind, "other_item_error");
  assertEquals(observationFromItemGet(connectionId, observedAt, health, true), null);
});

Deno.test("malformed item/get payload fails closed", () => {
  assertEquals(readItemGetHealth({}).kind, "failed");
  assertEquals(readItemGetHealth({ item: "bad" }).kind, "failed");
  assertEquals(readItemGetHealth(itemPayload("bad")).kind, "failed");
  assertEquals(readItemGetHealth(itemPayload(null, "not-a-date")).kind, "failed");
  assertEquals(readItemGetHealth(itemPayload(null, 12345)).kind, "failed");
});

Deno.test("fetchItemGetHealth classifies HTTP outcomes", async () => {
  const respond = (status: number, body: unknown) => async () =>
    new Response(JSON.stringify(body), { status });
  const params = {
    url: "https://sandbox.plaid.com/item/get",
    clientId: "client-id",
    secret: "secret",
    accessToken: "access-token",
  };

  assertEquals(
    (await fetchItemGetHealth(respond(200, itemPayload(null)), params)).kind,
    "healthy",
  );
  assertEquals(
    (await fetchItemGetHealth(respond(400, { error_code: "ITEM_NOT_FOUND" }), params)).kind,
    "item_unavailable",
  );
  assertEquals(
    (await fetchItemGetHealth(respond(500, { error_code: "INTERNAL_SERVER_ERROR" }), params)).kind,
    "failed",
  );
  assertEquals(
    (await fetchItemGetHealth(async () => {
      throw new Error("network");
    }, params)).kind,
    "failed",
  );
  assertEquals(
    (await fetchItemGetHealth(async () => new Response("not json"), params)).kind,
    "failed",
  );
});

Deno.test("fetchItemGetHealth sends token only in the Plaid request body", async () => {
  let sentBody = "";
  let sentUrl = "";
  await fetchItemGetHealth(async (url, init) => {
    sentUrl = String(url);
    sentBody = String(init?.body);
    return new Response(JSON.stringify(itemPayload(null)));
  }, {
    url: "https://sandbox.plaid.com/item/get",
    clientId: "client-id",
    secret: "secret",
    accessToken: "access-token",
  });

  assertEquals(sentUrl, "https://sandbox.plaid.com/item/get");
  assertEquals(JSON.parse(sentBody).access_token, "access-token");
});

Deno.test("observations follow the timestamp model", () => {
  const healthy = observationFromItemGet(
    connectionId,
    observedAt,
    { kind: "healthy", consentExpiresAt: null },
    true,
  );
  assertEquals(healthy?.status, "active");
  assertEquals(healthy?.statusReason, null);
  assertEquals(healthy?.fromItemGet, true);
  assertEquals(healthy?.consentExpiresAt, null);
  assertEquals(healthy?.clearPendingDisconnect, true);

  const broken = observationFromItemGet(
    connectionId,
    observedAt,
    { kind: "login_required", reason: "consent_expired", consentExpiresAt: "2026-12-01T00:00:00Z" },
    true,
  );
  assertEquals(broken?.status, "login_required");
  assertEquals(broken?.statusReason, "consent_expired");
  assertEquals(broken?.consentExpiresAt, "2026-12-01T00:00:00Z");
  assertEquals(broken?.clearPendingDisconnect, false);

  const fromError = loginRequiredObservation(connectionId, observedAt);
  assertEquals(fromError.fromItemGet, false);
  assertEquals(fromError.consentExpiresAt, null);
  assertEquals(fromError.clearPendingDisconnect, false);
});

Deno.test("becameActive only for an applied login_required to active transition", () => {
  const base = { plaidItemId: "item" };
  assertEquals(
    becameActive({ ...base, applied: true, previousStatus: "login_required", status: "active" }),
    true,
  );
  assertEquals(
    becameActive({ ...base, applied: false, previousStatus: "login_required", status: "login_required" }),
    false,
  );
  assertEquals(
    becameActive({ ...base, applied: true, previousStatus: "active", status: "active" }),
    false,
  );
  assertEquals(becameActive("not_found"), false);
  assertEquals(becameActive(null), false);
});
