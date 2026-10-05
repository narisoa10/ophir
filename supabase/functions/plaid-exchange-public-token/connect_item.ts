import type { PlaidAccountPayload } from "../_shared/plaid_accounts_refresh.ts";
import {
  getInstitutionById,
  getItemAccounts,
  type PlaidClient,
  removeItem,
} from "../_shared/plaid_api.ts";
import { plaidFailureLogFields, readRecord } from "../_shared/plaid_http.ts";

export const PLAID_ENVIRONMENT = "sandbox";

export type ConnectItemParams = {
  userId: string;
  environment: string;
  plaidItemId: string;
  accessToken: string;
  plaidInstitutionId: string | null;
  institutionName: string | null;
  logoBase64: string | null;
  primaryColor: string | null;
  url: string | null;
  balanceFetchedAt: string;
  accounts: PlaidAccountPayload[];
};

export type ConnectItemResult =
  | { kind: "created"; connectionId: string; ambiguousCount: number }
  | { kind: "idempotent_existing"; connectionId: string }
  | { kind: "strong_duplicate"; blockingCount: number }
  // PostgREST reported an error that proves the RPC transaction ended without
  // committing.
  | { kind: "definitively_rejected"; code: string }
  // The RPC may still be running, or may have committed despite the error.
  | { kind: "uncertain"; code: string | null };

export type PlaidItemLookup =
  | { kind: "absent" }
  | { kind: "owned"; connectionId: string; disconnected: boolean }
  | { kind: "foreign" }
  | { kind: "failed" };

export type ConnectDatabase = {
  connectItem(params: ConnectItemParams): Promise<ConnectItemResult>;
  findPlaidItem(
    userId: string,
    environment: string,
    plaidItemId: string,
  ): Promise<PlaidItemLookup>;
};

export type ConnectOutcome =
  | { kind: "connected"; connectionId: string }
  | { kind: "duplicate" }
  | { kind: "failed"; status: number; code: string };

type Log = (message: string, fields: Record<string, unknown>) => void;

type CompensationReason =
  | "accounts_get_failed"
  | "item_id_mismatch"
  | "strong_duplicate"
  | "persist_rejected";

// Statement errors that a still-connected session reports: the transaction is
// aborted and can never commit. Connection loss (08), shutdown, resource and
// system classes, and 40003 statement_completion_unknown are left out because
// the transaction may have committed. 57014 is left out because a call that
// timed out waiting for the per-user advisory lock says nothing about the
// execution holding it, which may still commit the same Item.
const rolledBackSqlState = /^(?:22|23|42|P0)[0-9A-Z]{3}$|^(?:40001|40P01)$/;
// Schema cache and JWT errors are raised before any SQL of the request runs.
const preExecutionPostgrestCode = /^PGRST[23]\d{2}$/;
const diagnosticCode = /^(?:[0-9A-Z]{5}|PGRST[0-9A-Z]{3})$/;

const blockingDecisions: ReadonlySet<string> = new Set([
  "duplicate",
  "disconnected_existing",
]);
const knownDecisions: ReadonlySet<string> = new Set([
  "new",
  "ambiguous",
  ...blockingDecisions,
]);

function readNonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function readDecisions(value: unknown): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const decisions: string[] = [];
  for (const entry of value) {
    const decision = readRecord(entry)?.decision;
    if (typeof decision !== "string" || !knownDecisions.has(decision)) {
      return null;
    }
    decisions.push(decision);
  }
  return decisions;
}

const uncertain: ConnectItemResult = { kind: "uncertain", code: null };

// Any shape other than the three documented outcomes is not proof of what the
// RPC did, so it is uncertain rather than a failure.
export function parseConnectItemResult(data: unknown): ConnectItemResult {
  const record = readRecord(data);
  const connectionId = readNonEmptyString(record?.connection_id);

  switch (record?.outcome) {
    case "created": {
      const decisions = readDecisions(record.decisions);
      if (connectionId === null || decisions === null) {
        return uncertain;
      }
      return {
        kind: "created",
        connectionId,
        ambiguousCount: decisions.filter((d) => d === "ambiguous").length,
      };
    }
    case "idempotent_existing":
      return connectionId === null
        ? uncertain
        : { kind: "idempotent_existing", connectionId };
    case "strong_duplicate": {
      const decisions = readDecisions(record.decisions);
      const blockingCount = decisions?.filter((d) => blockingDecisions.has(d))
        .length ?? 0;
      return decisions === null || blockingCount === 0
        ? uncertain
        : { kind: "strong_duplicate", blockingCount };
    }
    default:
      return uncertain;
  }
}

// supabase-js reports network failures as status 0, and relays any JSON body a
// gateway returns, so a code alone proves nothing: only PostgREST's own 4xx/500
// answers with a code from the allowlists prove the RPC ended uncommitted.
export function connectItemErrorResult(
  error: unknown,
  status: unknown,
): ConnectItemResult {
  const code = readRecord(error)?.code;
  if (typeof code !== "string") {
    return uncertain;
  }

  const answeredByPostgrest = typeof status === "number" && status >= 400 &&
    status <= 500;
  if (
    answeredByPostgrest &&
    (rolledBackSqlState.test(code) || preExecutionPostgrestCode.test(code))
  ) {
    return { kind: "definitively_rejected", code };
  }
  return { kind: "uncertain", code: diagnosticCode.test(code) ? code : null };
}

export function plaidItemLookupFromRows(
  data: unknown,
  error: unknown,
  userId: string,
): PlaidItemLookup {
  if (error !== null || !Array.isArray(data) || data.length > 1) {
    return { kind: "failed" };
  }
  if (data.length === 0) {
    return { kind: "absent" };
  }

  const row = readRecord(data[0]);
  const id = readNonEmptyString(row?.id);
  const ownerId = readNonEmptyString(row?.user_id);
  const disconnectedAt = row?.disconnected_at;
  if (
    id === null ||
    ownerId === null ||
    (disconnectedAt !== null && typeof disconnectedAt !== "string")
  ) {
    return { kind: "failed" };
  }

  return ownerId === userId
    ? { kind: "owned", connectionId: id, disconnected: disconnectedAt !== null }
    : { kind: "foreign" };
}

type ReadBack = PlaidItemLookup["kind"];

// The Item is reachable through every listed id; one non-absent answer means a
// stored row may depend on the Item, and one failed lookup means it is unknown.
async function readBack(
  database: ConnectDatabase,
  userId: string,
  plaidItemIds: readonly string[],
): Promise<{ kind: ReadBack; lookup: PlaidItemLookup }> {
  const lookups: PlaidItemLookup[] = [];
  for (const plaidItemId of new Set(plaidItemIds)) {
    let lookup: PlaidItemLookup;
    try {
      lookup = await database.findPlaidItem(
        userId,
        PLAID_ENVIRONMENT,
        plaidItemId,
      );
    } catch (_) {
      lookup = { kind: "failed" };
    }
    lookups.push(lookup);
  }

  for (const kind of ["failed", "foreign", "owned"] as const) {
    const match = lookups.find((lookup) => lookup.kind === kind);
    if (match !== undefined) {
      return { kind, lookup: match };
    }
  }
  return { kind: "absent", lookup: { kind: "absent" } };
}

type ConnectContext = {
  client: PlaidClient;
  database: ConnectDatabase;
  log: Log;
  userId: string;
  plaidItemId: string;
  accessToken: string;
  exchangeRequestId: string | null;
  now: () => Date;
};

function readBackLabel(state: { kind: ReadBack; lookup: PlaidItemLookup }) {
  return state.lookup.kind === "owned" && state.lookup.disconnected
    ? "owned_disconnected"
    : state.kind;
}

function compensationFields(context: ConnectContext, reason: string) {
  return {
    reason,
    user_id: context.userId,
    plaid_item_id: context.plaidItemId,
    exchange_request_id: context.exchangeRequestId,
  };
}

// Callers must only reach this when no RPC of this request can still commit:
// the RPC was never called, or it provably finished. The external outcome never
// depends on whether the removal itself succeeds.
async function compensate(
  context: ConnectContext,
  reason: CompensationReason,
  plaidItemIds: readonly string[],
): Promise<void> {
  const state = await readBack(context.database, context.userId, plaidItemIds);
  await removeIfAbsent(context, reason, state);
}

async function removeIfAbsent(
  context: ConnectContext,
  reason: CompensationReason,
  state: { kind: ReadBack; lookup: PlaidItemLookup },
): Promise<void> {
  const fields = compensationFields(context, reason);
  if (state.kind !== "absent") {
    context.log("plaid_connect_compensation_skipped", {
      ...fields,
      readback: readBackLabel(state),
    });
    return;
  }

  const removal = await removeItem(context.client, context.accessToken);
  if (removal.kind === "ok") {
    context.log("plaid_connect_compensation_removed", {
      ...fields,
      request_id: removal.requestId,
    });
    return;
  }

  if (
    removal.kind === "plaid_error" &&
    removal.error.errorCode === "ITEM_NOT_FOUND"
  ) {
    context.log("plaid_connect_compensation_removed", {
      ...fields,
      already_removed: true,
      request_id: removal.error.requestId,
    });
    return;
  }

  context.log("plaid_connect_compensation_failed", {
    ...fields,
    ...plaidFailureLogFields(removal),
  });
}

// A persistence error is not proof that nothing was stored: a lost response may
// hide a committed connection, which read-back turns back into success.
//
// An uncertain RPC may still be running and commit after any number of
// READ COMMITTED reads, so its Item is never removed; a leaked Plaid Item is
// recoverable, a stored connection with a revoked token is not. A rejected RPC
// has ended uncommitted, and only this request holds the new access token, so
// one read-back is final.
async function resolveFailedPersist(
  context: ConnectContext,
  result: Extract<
    ConnectItemResult,
    { kind: "definitively_rejected" | "uncertain" }
  >,
): Promise<ConnectOutcome> {
  const state = await readBack(context.database, context.userId, [
    context.plaidItemId,
  ]);
  if (state.lookup.kind === "owned" && !state.lookup.disconnected) {
    context.log("plaid_connect_persist_recovered", {
      user_id: context.userId,
      exchange_request_id: context.exchangeRequestId,
    });
    return { kind: "connected", connectionId: state.lookup.connectionId };
  }

  if (result.kind === "uncertain") {
    context.log("plaid_connect_compensation_skipped", {
      ...compensationFields(context, "persist_uncertain"),
      readback: readBackLabel(state),
    });
  } else {
    await removeIfAbsent(context, "persist_rejected", state);
  }
  return { kind: "failed", status: 500, code: "persist_failed" };
}

async function callConnectItem(
  database: ConnectDatabase,
  params: ConnectItemParams,
): Promise<ConnectItemResult> {
  try {
    return await database.connectItem(params);
  } catch (_) {
    return uncertain;
  }
}

// Everything after a successful exchange. Only the exchange and /accounts/get
// are authoritative; institution metadata is optional and never taken from the
// client.
export async function connectExchangedItem(params: {
  client: PlaidClient;
  database: ConnectDatabase;
  log: Log;
  userId: string;
  exchange: { accessToken: string; itemId: string; requestId: string | null };
  now?: () => Date;
}): Promise<ConnectOutcome> {
  const context: ConnectContext = {
    client: params.client,
    database: params.database,
    log: params.log,
    userId: params.userId,
    plaidItemId: params.exchange.itemId,
    accessToken: params.exchange.accessToken,
    exchangeRequestId: params.exchange.requestId,
    now: params.now ?? (() => new Date()),
  };

  const accounts = await getItemAccounts(context.client, context.accessToken);
  if (accounts.kind !== "ok") {
    context.log("plaid_accounts_get_failed", plaidFailureLogFields(accounts));
    await compensate(context, "accounts_get_failed", [context.plaidItemId]);
    return { kind: "failed", status: 502, code: "plaid_request_failed" };
  }
  const balanceFetchedAt = context.now().toISOString();

  if (accounts.itemId !== context.plaidItemId) {
    context.log("plaid_item_id_mismatch", {
      user_id: context.userId,
      exchange_request_id: context.exchangeRequestId,
      accounts_request_id: accounts.requestId,
    });
    await compensate(context, "item_id_mismatch", [
      context.plaidItemId,
      accounts.itemId,
    ]);
    return { kind: "failed", status: 500, code: "persist_failed" };
  }

  let institution: {
    name: string | null;
    logoBase64: string | null;
    primaryColor: string | null;
    url: string | null;
  } = {
    name: accounts.institutionName,
    logoBase64: null,
    primaryColor: null,
    url: null,
  };
  if (accounts.institutionId !== null) {
    const lookup = await getInstitutionById(
      context.client,
      accounts.institutionId,
    );
    if (lookup.kind === "ok") {
      institution = {
        name: lookup.name ?? accounts.institutionName,
        logoBase64: lookup.logoBase64,
        primaryColor: lookup.primaryColor,
        url: lookup.url,
      };
    } else {
      context.log(
        "plaid_institution_lookup_failed",
        plaidFailureLogFields(lookup),
      );
    }
  }

  const result = await callConnectItem(context.database, {
    userId: context.userId,
    environment: PLAID_ENVIRONMENT,
    plaidItemId: context.plaidItemId,
    accessToken: context.accessToken,
    plaidInstitutionId: accounts.institutionId,
    institutionName: institution.name,
    logoBase64: institution.logoBase64,
    primaryColor: institution.primaryColor,
    url: institution.url,
    balanceFetchedAt,
    accounts: accounts.accounts,
  });

  switch (result.kind) {
    case "created":
      if (result.ambiguousCount > 0) {
        context.log("plaid_connect_ambiguous_accounts", {
          user_id: context.userId,
          ambiguous_count: result.ambiguousCount,
        });
      }
      return { kind: "connected", connectionId: result.connectionId };
    case "idempotent_existing":
      context.log("plaid_connect_idempotent_existing", {
        user_id: context.userId,
        exchange_request_id: context.exchangeRequestId,
      });
      return { kind: "connected", connectionId: result.connectionId };
    case "strong_duplicate":
      context.log("plaid_connect_strong_duplicate", {
        user_id: context.userId,
        blocking_count: result.blockingCount,
      });
      await compensate(context, "strong_duplicate", [context.plaidItemId]);
      return { kind: "duplicate" };
    case "definitively_rejected":
    case "uncertain":
      context.log("plaid_connect_persist_failed", {
        user_id: context.userId,
        result: result.kind,
        code: result.code,
      });
      return await resolveFailedPersist(context, result);
  }
}
