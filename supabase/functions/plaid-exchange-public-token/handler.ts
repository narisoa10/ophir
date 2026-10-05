import { createClient } from "npm:@supabase/supabase-js@2.112.2";
import type { AuthenticatedUser } from "../_shared/auth.ts";
import { authenticateRequest as defaultAuthenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import { exchangePublicToken } from "../_shared/plaid_api.ts";
import { plaidFailureLogFields } from "../_shared/plaid_http.ts";
import {
  type ConnectDatabase,
  connectExchangedItem,
  connectItemErrorResult,
  parseConnectItemResult,
  plaidItemLookupFromRows,
} from "./connect_item.ts";
import {
  ambiguousCandidates,
  classifyLink as defaultClassifyLink,
  type ExistingAccount,
  type IncomingAccount,
  type LinkClassification,
  normalizeIdentityText,
} from "./account_identity.ts";

const CONTRACT_VERSION = 2;
const MAX_SELECTED_ACCOUNTS = 50;
const MAX_ACCOUNT_ID_LENGTH = 256;
const MAX_NAME_LENGTH = 256;
const MAX_MASK_LENGTH = 8;
const MAX_TYPE_LENGTH = 256;
const MAX_DISPLAY_CANDIDATES = 50;

const blockingStatuses: ReadonlySet<string> = new Set([
  "duplicate",
  "partial_duplicate",
  "confirmation_required",
  "disconnected_existing",
]);

type DatabaseRow = Record<string, unknown>;

export type ExchangeDatabase = ConnectDatabase & {
  listInstitutions(
    userId: string,
    plaidInstitutionId: string,
  ): Promise<DatabaseRow[] | null>;
  listPlaidItems(
    userId: string,
    itemIds: string[],
  ): Promise<DatabaseRow[] | null>;
  listItemAccounts(
    userId: string,
    itemIds: string[],
  ): Promise<DatabaseRow[] | null>;
  listInstitutionAccounts(
    userId: string,
    institutionIds: string[],
  ): Promise<DatabaseRow[] | null>;
};

type HandlerDependencies = {
  authenticateRequest: (request: Request) => Promise<AuthenticatedUser | null>;
  createDatabase: () => ExchangeDatabase | null;
  fetch: typeof fetch;
  plaidTimeoutMs: number | undefined;
  getEnv: (name: string) => string | undefined;
  classifyLink: (
    incoming: readonly IncomingAccount[],
    existing: readonly ExistingAccount[],
    confirmAmbiguous: boolean,
  ) => LinkClassification | null;
  log: (message: string, fields: Record<string, unknown>) => void;
};

type LegacySelectedAccount = {
  name: string;
  mask: string;
};

type LegacyRequest = {
  version: 1;
  publicToken: string;
  institutionId: string;
  selectedAccounts: LegacySelectedAccount[];
};

type V2Request = {
  version: 2;
  publicToken: string;
  institutionId: string;
  selectedAccounts: IncomingAccount[];
  confirmAmbiguous: boolean;
};

type ExchangeRequest = LegacyRequest | V2Request;

type CandidateDisplay = {
  name: string;
  subtype: string | null;
  mask: string | null;
};

type AccountReview =
  | { index: number; decision: string }
  | { index: number; decision: "ambiguous"; candidates: CandidateDisplay[] };

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readBoundedString(value: unknown, maxLength: number): string | null {
  const text = readNonEmptyString(value);
  return text !== null && text.length <= maxLength ? text : null;
}

// undefined: the value is malformed; null: absent or blank.
function readOptionalString(
  value: unknown,
  maxLength: number,
): string | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string") {
    return undefined;
  }

  const text = normalizeIdentityText(value);
  if (text !== null && text.length > maxLength) {
    return undefined;
  }
  return text;
}

function readLegacyRequest(body: Record<string, unknown>): LegacyRequest | null {
  const publicToken = readNonEmptyString(body.public_token);
  const institutionId = readNonEmptyString(body.institution_id);
  const selectedAccounts = body.selected_accounts;

  if (
    publicToken === null ||
    institutionId === null ||
    !Array.isArray(selectedAccounts)
  ) {
    return null;
  }

  const accounts: LegacySelectedAccount[] = [];
  for (const selectedAccount of selectedAccounts) {
    if (
      !selectedAccount ||
      typeof selectedAccount !== "object" ||
      Array.isArray(selectedAccount)
    ) {
      return null;
    }

    const record = selectedAccount as Record<string, unknown>;
    const name = readNonEmptyString(record.name);
    const mask = readNonEmptyString(record.mask);
    if (name === null || mask === null) {
      return null;
    }

    accounts.push({ name, mask });
  }

  if (accounts.length === 0) {
    return null;
  }

  return {
    version: 1,
    publicToken,
    institutionId,
    selectedAccounts: accounts,
  };
}

function readV2Request(body: Record<string, unknown>): V2Request | null {
  const publicToken = readNonEmptyString(body.public_token);
  const institutionId = readNonEmptyString(body.institution_id);
  const selectedAccounts = body.selected_accounts;
  const confirmAmbiguous = body.confirm_ambiguous === undefined
    ? false
    : body.confirm_ambiguous;

  if (
    publicToken === null ||
    institutionId === null ||
    !Array.isArray(selectedAccounts) ||
    selectedAccounts.length === 0 ||
    selectedAccounts.length > MAX_SELECTED_ACCOUNTS ||
    typeof confirmAmbiguous !== "boolean"
  ) {
    return null;
  }

  const accounts: IncomingAccount[] = [];
  const accountIds = new Set<string>();
  for (const selectedAccount of selectedAccounts) {
    if (
      !selectedAccount ||
      typeof selectedAccount !== "object" ||
      Array.isArray(selectedAccount)
    ) {
      return null;
    }

    const record = selectedAccount as Record<string, unknown>;
    const accountId = readBoundedString(
      record.account_id,
      MAX_ACCOUNT_ID_LENGTH,
    );
    const name = readBoundedString(record.name, MAX_NAME_LENGTH);
    const mask = readOptionalString(record.mask, MAX_MASK_LENGTH);
    const type = readOptionalString(record.type, MAX_TYPE_LENGTH);
    const subtype = readOptionalString(record.subtype, MAX_TYPE_LENGTH);

    if (
      accountId === null ||
      name === null ||
      mask === undefined ||
      type === undefined ||
      subtype === undefined ||
      accountIds.has(accountId)
    ) {
      return null;
    }

    accountIds.add(accountId);
    accounts.push({ accountId, name, mask, type, subtype });
  }

  return {
    version: 2,
    publicToken,
    institutionId,
    selectedAccounts: accounts,
    confirmAmbiguous,
  };
}

function readExchangeRequest(
  body: Record<string, unknown>,
): ExchangeRequest | null {
  if (!("contract_version" in body)) {
    return readLegacyRequest(body);
  }

  return body.contract_version === CONTRACT_VERSION ? readV2Request(body) : null;
}

function legacyAccountKey(name: string, mask: string): string {
  return `${name}\u0000${mask}`;
}

// The original v1 rule, unchanged: one selected (name, mask) already present
// under any institution row of this Plaid institution blocks the whole Link.
async function hasLegacyDuplicate(
  database: ExchangeDatabase,
  userId: string,
  request: LegacyRequest,
): Promise<boolean | null> {
  try {
    const institutions = await database.listInstitutions(
      userId,
      request.institutionId,
    );
    if (institutions === null) {
      return null;
    }

    const institutionIds = institutions
      .map((institution) => readNonEmptyString(institution.id))
      .filter((id): id is string => id !== null);

    if (institutionIds.length === 0) {
      return false;
    }

    const accounts = await database.listInstitutionAccounts(
      userId,
      institutionIds,
    );
    if (accounts === null) {
      return null;
    }

    const existingKeys = new Set<string>();
    for (const account of accounts) {
      const name = readNonEmptyString(account.name);
      const mask = readNonEmptyString(account.mask);
      if (name === null || mask === null) {
        continue;
      }
      existingKeys.add(legacyAccountKey(name, mask));
    }

    return request.selectedAccounts.some((account) =>
      existingKeys.has(legacyAccountKey(account.name, account.mask))
    );
  } catch (_) {
    return null;
  }
}

function readNullableText(
  row: DatabaseRow,
  column: string,
): string | null | undefined {
  const value = row[column];
  if (value === null || value === undefined) {
    return null;
  }
  return typeof value === "string" ? normalizeIdentityText(value) : undefined;
}

function boundedOrNull(value: string | null, maxLength: number): string | null {
  return value !== null && value.length <= maxLength ? value : null;
}

// Only what Ophir already shows the user for their own account. Never IDs,
// and never anything longer than a mask in the mask field.
function candidateDisplays(
  incoming: IncomingAccount,
  existing: readonly ExistingAccount[],
): CandidateDisplay[] {
  const displays: CandidateDisplay[] = [];
  const seen = new Set<string>();
  for (const candidate of ambiguousCandidates(incoming, existing)) {
    const display: CandidateDisplay = {
      name: boundedOrNull(candidate.name, MAX_NAME_LENGTH) ?? incoming.name,
      subtype: boundedOrNull(candidate.subtype, MAX_TYPE_LENGTH),
      mask: boundedOrNull(candidate.mask, MAX_MASK_LENGTH),
    };
    const key = JSON.stringify([display.name, display.subtype, display.mask]);
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    displays.push(display);
    if (displays.length === MAX_DISPLAY_CANDIDATES) {
      break;
    }
  }
  return displays;
}

// Existing Plaid accounts of this Plaid institution, linked through their
// Item. Any inconsistency returns null so the caller fails closed.
async function loadExistingAccounts(
  database: ExchangeDatabase,
  userId: string,
  plaidInstitutionId: string,
): Promise<ExistingAccount[] | null> {
  try {
    const institutions = await database.listInstitutions(
      userId,
      plaidInstitutionId,
    );
    if (institutions === null) {
      return null;
    }

    const itemIds: string[] = [];
    for (const institution of institutions) {
      const itemId = readNonEmptyString(institution.plaid_item_id);
      if (itemId === null) {
        return null;
      }
      if (!itemIds.includes(itemId)) {
        itemIds.push(itemId);
      }
    }

    if (itemIds.length === 0) {
      return [];
    }

    const items = await database.listPlaidItems(userId, itemIds);
    if (items === null) {
      return null;
    }

    const disconnectedByItem = new Map<string, boolean>();
    for (const item of items) {
      const id = readNonEmptyString(item.id);
      const disconnectedAt = item.disconnected_at;
      if (
        id === null ||
        !itemIds.includes(id) ||
        (disconnectedAt !== null && typeof disconnectedAt !== "string")
      ) {
        return null;
      }
      disconnectedByItem.set(id, disconnectedAt !== null);
    }

    if (itemIds.some((itemId) => !disconnectedByItem.has(itemId))) {
      return null;
    }

    const accounts = await database.listItemAccounts(userId, itemIds);
    if (accounts === null) {
      return null;
    }

    const existing: ExistingAccount[] = [];
    for (const account of accounts) {
      const itemId = readNonEmptyString(account.plaid_item_id);
      const itemDisconnected = itemId === null
        ? undefined
        : disconnectedByItem.get(itemId);
      const plaidAccountId = readNullableText(account, "plaid_account_id");
      const name = readNullableText(account, "name");
      const officialName = readNullableText(account, "official_name");
      const mask = readNullableText(account, "mask");
      const type = readNullableText(account, "plaid_type");
      const subtype = readNullableText(account, "plaid_subtype");

      if (
        itemDisconnected === undefined ||
        plaidAccountId === undefined ||
        name === undefined ||
        officialName === undefined ||
        mask === undefined ||
        type === undefined ||
        subtype === undefined
      ) {
        return null;
      }

      existing.push({
        plaidAccountId,
        name,
        officialName,
        mask,
        type,
        subtype,
        itemDisconnected,
      });
    }

    return existing;
  } catch (_) {
    return null;
  }
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): ExchangeDatabase | null {
  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

  if (
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return null;
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const rows = (result: { data: unknown; error: unknown }) =>
    result.error === null && Array.isArray(result.data)
      ? result.data as DatabaseRow[]
      : null;

  return {
    async listInstitutions(userId, plaidInstitutionId) {
      return rows(
        await supabaseAdmin
          .from("institutions")
          .select("id, plaid_item_id")
          .eq("user_id", userId)
          .eq("plaid_institution_id", plaidInstitutionId),
      );
    },
    async listPlaidItems(userId, itemIds) {
      return rows(
        await supabaseAdmin
          .from("plaid_items")
          .select("id, disconnected_at")
          .eq("user_id", userId)
          .in("id", itemIds),
      );
    },
    async listItemAccounts(userId, itemIds) {
      return rows(
        await supabaseAdmin
          .from("accounts")
          .select(
            "plaid_item_id, plaid_account_id, name, official_name, mask, plaid_type, plaid_subtype",
          )
          .eq("user_id", userId)
          .in("plaid_item_id", itemIds),
      );
    },
    async listInstitutionAccounts(userId, institutionIds) {
      return rows(
        await supabaseAdmin
          .from("accounts")
          .select("name, mask")
          .eq("user_id", userId)
          .in("institution_id", institutionIds),
      );
    },
    async connectItem(params) {
      const { data, error, status } = await supabaseAdmin.rpc(
        "plaid_connect_item",
        {
          p_user_id: params.userId,
          p_plaid_environment: params.environment,
          p_plaid_item_id: params.plaidItemId,
          p_access_token: params.accessToken,
          p_plaid_institution_id: params.plaidInstitutionId,
          p_institution_name: params.institutionName,
          p_logo_base64: params.logoBase64,
          p_primary_color: params.primaryColor,
          p_url: params.url,
          p_balance_fetched_at: params.balanceFetchedAt,
          p_accounts: params.accounts,
        },
      );

      return error === null
        ? parseConnectItemResult(data)
        : connectItemErrorResult(error, status);
    },
    async findPlaidItem(userId, environment, plaidItemId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("id, user_id, disconnected_at")
        .eq("plaid_environment", environment)
        .eq("plaid_item_id", plaidItemId);

      return plaidItemLookupFromRows(data, error, userId);
    },
  };
}

export function createPlaidExchangeHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const deps: HandlerDependencies = {
    authenticateRequest: dependencies.authenticateRequest ??
      defaultAuthenticateRequest,
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    fetch: dependencies.fetch ?? fetch,
    plaidTimeoutMs: dependencies.plaidTimeoutMs,
    getEnv,
    classifyLink: dependencies.classifyLink ?? defaultClassifyLink,
    log: dependencies.log ??
      ((message, fields) => console.log(message, JSON.stringify(fields))),
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (request.method !== "POST") {
      return methodNotAllowed();
    }

    const user = await deps.authenticateRequest(request);
    if (user === null) {
      return errorResponse(401, "unauthorized");
    }

    const body = await readJsonObject(request);
    if (body === null) {
      return errorResponse(400, "invalid_request");
    }

    const exchangeRequest = readExchangeRequest(body);
    if (exchangeRequest === null) {
      return errorResponse(400, "invalid_request");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    if (exchangeRequest.version === 1) {
      const isDuplicate = await hasLegacyDuplicate(
        database,
        user.id,
        exchangeRequest,
      );
      if (isDuplicate === null) {
        return errorResponse(500, "duplicate_check_failed");
      }
      if (isDuplicate) {
        return jsonResponse(200, { status: "duplicate" });
      }
    } else {
      const existing = await loadExistingAccounts(
        database,
        user.id,
        exchangeRequest.institutionId,
      );
      if (existing === null) {
        return errorResponse(500, "duplicate_check_failed");
      }

      let classification: LinkClassification | null;
      try {
        classification = deps.classifyLink(
          exchangeRequest.selectedAccounts,
          existing,
          exchangeRequest.confirmAmbiguous,
        );
      } catch (_) {
        classification = null;
      }

      if (
        classification === null ||
        classification.decisions.length !==
          exchangeRequest.selectedAccounts.length
      ) {
        return errorResponse(500, "duplicate_check_failed");
      }

      if (blockingStatuses.has(classification.status)) {
        const accounts: AccountReview[] = [];
        for (const [index, decision] of classification.decisions.entries()) {
          if (decision !== "ambiguous") {
            accounts.push({ index, decision });
            continue;
          }
          const candidates = candidateDisplays(
            exchangeRequest.selectedAccounts[index],
            existing,
          );
          if (candidates.length === 0) {
            return errorResponse(500, "duplicate_check_failed");
          }
          accounts.push({ index, decision, candidates });
        }
        return jsonResponse(200, { status: classification.status, accounts });
      }

      if (classification.status !== "proceed") {
        return errorResponse(500, "duplicate_check_failed");
      }
    }

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    const sandboxSecret = deps.getEnv("PLAID_SANDBOX_SECRET");
    if (
      typeof clientId !== "string" ||
      clientId.length === 0 ||
      typeof sandboxSecret !== "string" ||
      sandboxSecret.length === 0
    ) {
      return errorResponse(500, "plaid_config_missing");
    }

    const client = {
      fetchImpl: deps.fetch,
      environment: "sandbox",
      credentials: { clientId, secret: sandboxSecret },
      timeoutMs: deps.plaidTimeoutMs,
    } as const;
    const exchange = await exchangePublicToken(
      client,
      exchangeRequest.publicToken,
    );
    if (exchange.kind !== "ok") {
      deps.log("plaid_exchange_failed", plaidFailureLogFields(exchange));
      return errorResponse(502, "plaid_request_failed");
    }

    const outcome = await connectExchangedItem({
      client,
      database,
      log: deps.log,
      userId: user.id,
      exchange,
    });
    switch (outcome.kind) {
      case "connected":
        return jsonResponse(200, { connection_id: outcome.connectionId });
      case "duplicate":
        // Snapshot indexes from the RPC do not address the Link selection, so
        // the post-exchange duplicate is reported without per-account reviews.
        return jsonResponse(200, { status: "duplicate" });
      case "failed":
        return errorResponse(outcome.status, outcome.code);
    }
  };
}
