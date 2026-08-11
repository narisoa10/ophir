import { authorizeInternalRequest } from "./internal_auth.ts";

const secret =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  if (actual !== expected) {
    throw new Error(message ?? `Expected ${expected}, got ${actual}`);
  }
}

function request(headers: Record<string, string> = {}): Request {
  return new Request("https://example.com", {
    method: "POST",
    headers,
  });
}

function requestWithRawInternalSecret(value: string): Request {
  return {
    headers: {
      get(name: string): string | null {
        return name.toLowerCase() === "x-ophir-internal-secret" ? value : null;
      },
    },
  } as Request;
}

Deno.test("missing env remains config missing", () => {
  const auth = authorizeInternalRequest(
    request({ "x-ophir-internal-secret": secret }),
    () => undefined,
  );

  assertEquals(auth, "config_missing");
});

Deno.test("empty env remains config missing", () => {
  const auth = authorizeInternalRequest(
    request({ "x-ophir-internal-secret": secret }),
    () => "",
  );

  assertEquals(auth, "config_missing");
});

Deno.test("missing header remains unauthorized", () => {
  const auth = authorizeInternalRequest(
    request(),
    () => secret,
  );

  assertEquals(auth, "unauthorized");
});

Deno.test("wrong secret remains unauthorized", () => {
  const auth = authorizeInternalRequest(
    request({ "x-ophir-internal-secret": "wrong" }),
    () => secret,
  );

  assertEquals(auth, "unauthorized");
});

Deno.test("correct secret remains authorized", () => {
  const auth = authorizeInternalRequest(
    request({ "x-ophir-internal-secret": secret }),
    () => secret,
  );

  assertEquals(auth, "authorized");
});

Deno.test("auth does not trim env or header values", () => {
  const headerWithWhitespace = authorizeInternalRequest(
    requestWithRawInternalSecret(` ${secret} `),
    () => secret,
  );
  const envWithWhitespace = authorizeInternalRequest(
    request({ "x-ophir-internal-secret": secret }),
    () => ` ${secret} `,
  );
  const bothWithSameWhitespace = authorizeInternalRequest(
    requestWithRawInternalSecret(` ${secret} `),
    () => ` ${secret} `,
  );

  assertEquals(headerWithWhitespace, "unauthorized");
  assertEquals(envWithWhitespace, "unauthorized");
  assertEquals(bothWithSameWhitespace, "authorized");
});
