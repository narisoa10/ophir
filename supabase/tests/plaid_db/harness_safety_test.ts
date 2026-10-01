// The harness creates and force-drops databases, so it must refuse (fail closed)
// anything that is not the throwaway local server.

import { assertEquals, assertMatch, assertRejects, assertThrows } from "jsr:@std/assert@1";
import postgres from "npm:postgres@3.4.5";
import { ADMIN_URL, assertLocalPgUrl, createDatabase } from "./harness.ts";

const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test("assertLocalPgUrl accepts only loopback postgres URLs", () => {
  for (
    const url of [
      "postgres://postgres@127.0.0.1:55432/postgres",
      "postgresql://postgres@localhost:5432/postgres",
      "postgres://postgres@[::1]:55432/postgres",
    ]
  ) {
    assertLocalPgUrl(url);
  }

  for (
    const url of [
      "postgres://postgres@db.abcdefghijkl.supabase.co:5432/postgres",
      "postgres://postgres.abcdefghijkl@aws-0-ca-central-1.pooler.supabase.com:6543/postgres",
      "postgres://postgres@10.0.0.5:5432/postgres",
      "postgres://postgres@127.0.0.2:5432/postgres",
      "postgres://postgres@127.0.0.1,db.example.com:5432/postgres",
      "postgres://postgres@127.0.0.1:5432/postgres?host=db.example.com",
      "postgres://postgres@127.0.0.1:5432/postgres?hostaddr=10.0.0.5",
      "postgres://postgres@127.0.0.1:5432/postgres?service=live",
      "postgres:///postgres?host=/var/run/postgresql",
      "http://127.0.0.1:5432/postgres",
      "not a url",
    ]
  ) {
    assertThrows(() => assertLocalPgUrl(url), Error, undefined, url);
  }
});

Deno.test("importing the harness with a remote PLAID_DB_PG_URL fails before any connection", async () => {
  const harness = new URL("./harness.ts", import.meta.url).href;
  const { code, stderr } = await new Deno.Command(Deno.execPath(), {
    args: [
      "eval",
      "--no-lock",
      "--node-modules-dir=none",
      `await import(${JSON.stringify(harness)});`,
    ],
    env: {
      // .invalid never resolves (RFC 2606): a connection attempt could not succeed.
      PLAID_DB_PG_URL: "postgres://postgres@db.plaid-db-refusal.invalid:5432/postgres",
    },
    stdout: "null",
    stderr: "piped",
  }).output();
  const message = new TextDecoder().decode(stderr);
  assertEquals(code === 0, false, "import must fail");
  assertMatch(message, /host 'db\.plaid-db-refusal\.invalid' is not a local loopback host/);
  assertEquals(/ENOTFOUND|getaddrinfo|ECONNREFUSED/.test(message), false, "no connection attempted");
});

Deno.test("createDatabase refuses a loopback server that has Supabase platform roles", options, async () => {
  const admin = postgres(ADMIN_URL, { max: 1, onnotice: () => {} });
  const probeDatabases = async () =>
    (await admin`select count(*)::int as n from pg_database where datname like 'plaid_db_refusal_%'`)[0].n;
  try {
    await admin.unsafe("create role supabase_admin nologin");
    await assertRejects(
      () => createDatabase("refusal"),
      Error,
      "supabase platform roles=true",
    );
    assertEquals(await probeDatabases(), 0, "no database created");
  } finally {
    await admin.unsafe("drop role if exists supabase_admin");
    await admin.end();
  }
});
