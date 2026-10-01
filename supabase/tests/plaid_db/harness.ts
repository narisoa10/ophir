// Plaid database integration test harness.
//
// Requires a throwaway PostgreSQL >= 15 server reachable through PLAID_DB_PG_URL
// (default postgres://postgres@127.0.0.1:55432/postgres). Every test creates and
// drops its own database; nothing is written to the server's existing databases.
//
// Supabase-managed objects (auth, storage, vault, pg_cron, pg_net, roles) are
// replaced by supabase_shims.psql. PLAID_DB_PG_URL must address a loopback host
// and a server without Supabase platform roles; anything else is refused.
//
// The shims file is not .sql: `supabase test db` runs every .sql/.pg file under
// supabase/tests through pg_prove.
//
// Run (the root package.json would otherwise force a manual node_modules dir):
//   deno test -A --no-lock --node-modules-dir=none supabase/tests/plaid_db/

import postgres from "npm:postgres@3.4.5";

export type Sql = ReturnType<typeof postgres>;

const LOCAL_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

// The harness creates and force-drops databases: it refuses any server that is
// not addressed as loopback, before opening a connection.
export function assertLocalPgUrl(raw: string): string {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("PLAID_DB_PG_URL is not a valid URL; the harness refuses to run");
  }
  if (url.protocol !== "postgres:" && url.protocol !== "postgresql:") {
    throw new Error(`PLAID_DB_PG_URL protocol '${url.protocol}' is not postgres; refusing to run`);
  }
  if (!LOCAL_HOSTS.has(url.hostname)) {
    throw new Error(
      `PLAID_DB_PG_URL host '${url.hostname}' is not a local loopback host ` +
        `(${[...LOCAL_HOSTS].join(", ")}); the harness creates and drops databases ` +
        "and refuses to run against it",
    );
  }
  for (const key of ["host", "hostaddr", "service"]) {
    if (url.searchParams.has(key)) {
      throw new Error(`PLAID_DB_PG_URL overrides '${key}' in its query string; refusing to run`);
    }
  }
  return url.toString();
}

export const ADMIN_URL = assertLocalPgUrl(
  Deno.env.get("PLAID_DB_PG_URL") ?? "postgres://postgres@127.0.0.1:55432/postgres",
);

const SUPABASE_PLATFORM_ROLES = ["supabase_admin", "supabase_auth_admin", "authenticator"];

// Second gate after connecting: a loopback address can still be a tunnel.
// A Supabase-managed server always has its platform roles; the throwaway
// server never does (supabase_shims.psql creates none of them).
async function assertThrowawayServer(admin: Sql): Promise<void> {
  const roles = SUPABASE_PLATFORM_ROLES.map((role) => `'${role}'`).join(", ");
  const [row] = await admin.unsafe(`
    select
      coalesce(host(inet_server_addr()) in ('127.0.0.1', '::1'), true) as loopback,
      exists (select 1 from pg_roles where rolname in (${roles})) as platform
  `);
  if (!row.loopback || row.platform) {
    throw new Error(
      "PLAID_DB_PG_URL server is not a throwaway local PostgreSQL " +
        `(loopback=${row.loopback}, supabase platform roles=${row.platform}); refusing to run`,
    );
  }
}

const MIGRATIONS_DIR = new URL("../../migrations/", import.meta.url);
const SHIMS_FILE = new URL("./supabase_shims.psql", import.meta.url);

const EXTENSIONS_PROVIDED_BY_SHIMS = [
  /create extension if not exists pg_cron;/i,
  /create extension if not exists pg_net with schema extensions;/i,
];

// Baseline file declares plaid_transactions%rowtype before that table exists.
const DEFERRED_BODY_CHECK_MIGRATIONS = new Set([
  "20260801190000_category_rules_and_smart_categorization.sql",
]);

const quiet = { onnotice: () => {} };

export function listMigrations(): string[] {
  return [...Deno.readDirSync(MIGRATIONS_DIR)]
    .filter((entry) => entry.isFile && entry.name.endsWith(".sql"))
    .map((entry) => entry.name)
    .sort();
}

export function readMigration(name: string): string {
  // Git stores migrations with LF; core.autocrlf checkouts add CR on Windows.
  let text = Deno.readTextFileSync(new URL(name, MIGRATIONS_DIR)).replaceAll("\r\n", "\n");

  for (const pattern of EXTENSIONS_PROVIDED_BY_SHIMS) {
    text = text.replace(pattern, "-- provided by supabase_shims.psql");
  }

  if (DEFERRED_BODY_CHECK_MIGRATIONS.has(name)) {
    text = `set check_function_bodies = off;\n${text}\n;reset check_function_bodies;`;
  }

  return text;
}

export interface TestDatabase {
  name: string;
  sql: Sql;
  connect(): Sql;
  drop(): Promise<void>;
}

export async function createDatabase(label: string): Promise<TestDatabase> {
  const name = `plaid_db_${label}_${crypto.randomUUID().replaceAll("-", "").slice(0, 10)}`;
  if (!/^plaid_db_[a-z0-9_]+$/.test(name)) {
    throw new Error(`invalid test database name ${name}`);
  }

  const admin = postgres(ADMIN_URL, { max: 1, ...quiet });
  try {
    await assertThrowawayServer(admin);
    await admin.unsafe(`create database ${name}`);
  } finally {
    await admin.end();
  }

  const url = new URL(ADMIN_URL);
  url.pathname = `/${name}`;

  const opened: Sql[] = [];
  const connect = () => {
    const connection = postgres(url.toString(), { max: 1, ...quiet });
    opened.push(connection);
    return connection;
  };

  const sql = connect();
  await sql.unsafe(Deno.readTextFileSync(SHIMS_FILE)).simple();

  return {
    name,
    sql,
    connect,
    async drop() {
      for (const connection of opened) {
        await connection.end({ timeout: 5 });
      }
      const dropper = postgres(ADMIN_URL, { max: 1, ...quiet });
      await dropper.unsafe(`drop database if exists ${name} with (force)`);
      await dropper.end();
    },
  };
}

// Same shape as `supabase db push`: BEGIN, the file, INSERT into
// supabase_migrations.schema_migrations, COMMIT; ROLLBACK on any error.
export async function applyMigration(sql: Sql, name: string): Promise<void> {
  const text = readMigration(name);
  const version = name.split("_")[0];
  try {
    await sql.begin(async (tx) => {
      await tx.unsafe(text).simple();
      await tx`
        insert into supabase_migrations.schema_migrations (version)
        values (${version})
        on conflict (version) do nothing`;
    });
  } catch (error) {
    const failure = error as Error & { migration?: string };
    failure.migration = name;
    failure.message = `[${name}] ${failure.message}`;
    throw failure;
  }
}

export async function applyAllMigrations(sql: Sql): Promise<void> {
  for (const name of listMigrations()) {
    await applyMigration(sql, name);
  }
}

export async function withDatabase(
  label: string,
  body: (db: TestDatabase) => Promise<void>,
): Promise<void> {
  const db = await createDatabase(label);
  try {
    await body(db);
  } finally {
    await db.drop();
  }
}
