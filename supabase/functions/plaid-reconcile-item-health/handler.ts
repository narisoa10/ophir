import { createClient } from "npm:@supabase/supabase-js@2.112.2";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";
import { authorizeInternalRequest } from "../_shared/internal_auth.ts";
import {
  becameActive,
  fetchItemGetHealth,
  observationFromItemGet,
  type PlaidApiEnvironment,
  plaidItemGetUrls,
  plaidSecretEnvNames,
  readPlaidApiEnvironment,
  recordItemHealthObservationRpc,
  type RecordItemHealthObservation,
} from "../_shared/plaid_item_health.ts";

const defaultLimit = 25;
const maxLimit = 100;

type ReconcileCandidate = {
  connectionId: string;
  userId: string;
};

type ReconcileItemHealthDatabase = {
  listItemsForHealthReconcile(
    limit: number,
  ): Promise<ReconcileCandidate[] | null>;
  getItemEnvironment(
    userId: string,
    connectionId: string,
  ): Promise<PlaidApiEnvironment | "not_found" | null>;
  getAccessTokenForItem(
    userId: string,
    connectionId: string,
  ): Promise<string | null>;
  recordItemHealthObservation: RecordItemHealthObservation;
  enqueueTransactionSyncJob(externalPlaidItemId: string): Promise<void>;
};

type HandlerDependencies = {
  createDatabase: () => ReconcileItemHealthDatabase | null;
  fetch: typeof fetch;
  getEnv: (name: string) => string | undefined;
  now: () => Date;
  log: (message: string) => void;
};

type ItemOutcome = "updated" | "unchanged" | "skipped" | "failed";

type ReconcileSummary = {
  checked: number;
  updated: number;
  unchanged: number;
  skipped: number;
  failed: number;
  recovered: number;
};

function readLimit(body: Record<string, unknown>): number | null {
  const limit = body.limit;
  if (limit === undefined) {
    return defaultLimit;
  }

  return typeof limit === "number" && Number.isInteger(limit) &&
      limit >= 1 && limit <= maxLimit
    ? limit
    : null;
}

function createDefaultDatabase(
  getEnv: (name: string) => string | undefined,
): ReconcileItemHealthDatabase | null {
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

  return {
    async listItemsForHealthReconcile(limit) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_list_items_for_health_reconcile",
        { p_limit: limit },
      );

      if (error !== null || !Array.isArray(data)) {
        return null;
      }

      const candidates: ReconcileCandidate[] = [];
      for (const row of data as Record<string, unknown>[]) {
        if (
          typeof row.connection_id !== "string" ||
          typeof row.user_id !== "string"
        ) {
          return null;
        }
        candidates.push({ connectionId: row.connection_id, userId: row.user_id });
      }

      return candidates;
    },

    async getItemEnvironment(userId, connectionId) {
      const { data, error } = await supabaseAdmin
        .from("plaid_items")
        .select("plaid_environment")
        .eq("id", connectionId)
        .eq("user_id", userId)
        .maybeSingle();

      if (error !== null) {
        return null;
      }
      if (data === null) {
        return "not_found";
      }

      return readPlaidApiEnvironment(
        (data as Record<string, unknown>).plaid_environment,
      );
    },

    async getAccessTokenForItem(userId, connectionId) {
      const { data, error } = await supabaseAdmin.rpc(
        "plaid_get_access_token_for_item",
        {
          p_user_id: userId,
          p_connection_id: connectionId,
        },
      );

      if (error !== null || typeof data !== "string" || data.length === 0) {
        return null;
      }

      return data;
    },

    recordItemHealthObservation(observation) {
      return recordItemHealthObservationRpc(supabaseAdmin, observation);
    },

    async enqueueTransactionSyncJob(externalPlaidItemId) {
      await supabaseAdmin.rpc("plaid_enqueue_transaction_sync_job", {
        p_external_plaid_item_id: externalPlaidItemId,
      });
    },
  };
}

async function reconcileItem(
  deps: HandlerDependencies,
  database: ReconcileItemHealthDatabase,
  clientId: string,
  candidate: ReconcileCandidate,
): Promise<{ outcome: ItemOutcome; recovered: boolean }> {
  const environment = await database.getItemEnvironment(
    candidate.userId,
    candidate.connectionId,
  );
  if (environment === "not_found") {
    return { outcome: "skipped", recovered: false };
  }
  if (environment === null) {
    return { outcome: "failed", recovered: false };
  }

  const secret = deps.getEnv(plaidSecretEnvNames[environment]);
  if (typeof secret !== "string" || secret.length === 0) {
    return { outcome: "skipped", recovered: false };
  }

  const accessToken = await database.getAccessTokenForItem(
    candidate.userId,
    candidate.connectionId,
  );
  if (accessToken === null) {
    return { outcome: "failed", recovered: false };
  }

  const observedAt = deps.now().toISOString();
  const health = await fetchItemGetHealth(deps.fetch, {
    url: plaidItemGetUrls[environment],
    clientId,
    secret,
    accessToken,
  });

  if (health.kind === "failed") {
    return { outcome: "failed", recovered: false };
  }

  const observation = observationFromItemGet(
    candidate.connectionId,
    observedAt,
    health,
    false,
  );
  if (observation === null) {
    return { outcome: "skipped", recovered: false };
  }

  const result = await database.recordItemHealthObservation(observation);
  if (result === null) {
    return { outcome: "failed", recovered: false };
  }
  if (result === "not_found") {
    return { outcome: "skipped", recovered: false };
  }

  const recovered = becameActive(result);
  if (recovered) {
    try {
      await database.enqueueTransactionSyncJob(result.plaidItemId);
    } catch (_) {
      // The next webhook or manual sync catches up.
    }
  }

  return {
    outcome: result.applied && result.previousStatus !== result.status
      ? "updated"
      : "unchanged",
    recovered,
  };
}

// One-off backfill and operator recovery only; deliberately not scheduled.
export function createPlaidReconcileItemHealthHandler(
  dependencies: Partial<HandlerDependencies> = {},
): (request: Request) => Promise<Response> {
  const getEnv = dependencies.getEnv ??
    ((name: string) => Deno.env.get(name) ?? undefined);
  const deps: HandlerDependencies = {
    createDatabase: dependencies.createDatabase ??
      (() => createDefaultDatabase(getEnv)),
    fetch: dependencies.fetch ?? fetch,
    getEnv,
    now: dependencies.now ?? (() => new Date()),
    log: dependencies.log ?? ((message) => console.log(message)),
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (request.method !== "POST") {
      return methodNotAllowed();
    }

    const auth = authorizeInternalRequest(request, deps.getEnv);
    if (auth === "unauthorized") {
      return errorResponse(401, "unauthorized");
    }
    if (auth === "config_missing") {
      return errorResponse(500, "internal_auth_config_missing");
    }

    const body = await readJsonObject(request);
    if (body === null) {
      return errorResponse(400, "invalid_request");
    }

    const limit = readLimit(body);
    if (limit === null) {
      return errorResponse(400, "invalid_request");
    }

    const clientId = deps.getEnv("PLAID_CLIENT_ID");
    if (typeof clientId !== "string" || clientId.length === 0) {
      return errorResponse(500, "plaid_config_missing");
    }

    const database = deps.createDatabase();
    if (database === null) {
      return errorResponse(500, "supabase_config_missing");
    }

    const candidates = await database.listItemsForHealthReconcile(limit);
    if (candidates === null) {
      return errorResponse(500, "internal_error");
    }

    const summary: ReconcileSummary = {
      checked: 0,
      updated: 0,
      unchanged: 0,
      skipped: 0,
      failed: 0,
      recovered: 0,
    };

    for (const candidate of candidates) {
      summary.checked += 1;
      let outcome: ItemOutcome = "failed";
      let recovered = false;
      try {
        ({ outcome, recovered } = await reconcileItem(
          deps,
          database,
          clientId,
          candidate,
        ));
      } catch (_) {
        outcome = "failed";
      }

      summary[outcome] += 1;
      if (recovered) {
        summary.recovered += 1;
      }
    }

    deps.log(
      JSON.stringify({ event: "plaid_item_health_reconcile", ...summary }),
    );

    return jsonResponse(200, { status: "ok", ...summary });
  };
}
