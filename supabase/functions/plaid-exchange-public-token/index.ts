import { createClient } from "npm:@supabase/supabase-js@2";
import { authenticateRequest } from "../_shared/auth.ts";
import {
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  optionsResponse,
  readJsonObject,
} from "../_shared/http.ts";

const PLAID_SANDBOX_PUBLIC_TOKEN_EXCHANGE_URL =
  "https://sandbox.plaid.com/item/public_token/exchange";

type IncomingSelectedAccount = {
  name: string;
  mask: string;
};

type IncomingDuplicateMetadata = {
  institutionId: string;
  selectedAccounts: IncomingSelectedAccount[];
};

function readPublicToken(body: Record<string, unknown>): string | null {
  const publicToken = body.public_token;
  if (typeof publicToken === "string" && publicToken.trim().length > 0) {
    return publicToken.trim();
  }

  return null;
}

function readNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readDuplicateMetadata(
  body: Record<string, unknown>,
): IncomingDuplicateMetadata | null {
  const institutionId = readNonEmptyString(body.institution_id);
  const selectedAccounts = body.selected_accounts;

  if (institutionId === null || !Array.isArray(selectedAccounts)) {
    return null;
  }

  const accounts: IncomingSelectedAccount[] = [];

  for (const selectedAccount of selectedAccounts) {
    if (
      !selectedAccount ||
      typeof selectedAccount !== "object" ||
      Array.isArray(selectedAccount)
    ) {
      return null;
    }

    const accountRecord = selectedAccount as Record<string, unknown>;
    const name = readNonEmptyString(accountRecord.name);
    const mask = readNonEmptyString(accountRecord.mask);

    if (name === null || mask === null) {
      return null;
    }

    accounts.push({ name, mask });
  }

  if (accounts.length === 0) {
    return null;
  }

  return {
    institutionId,
    selectedAccounts: accounts,
  };
}

async function hasDuplicateSelectedAccount(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  metadata: IncomingDuplicateMetadata,
): Promise<boolean | null> {
  const { data: institutions, error: institutionsError } = await supabaseAdmin
    .from("institutions")
    .select("id")
    .eq("user_id", userId)
    .eq("plaid_institution_id", metadata.institutionId);

  if (institutionsError !== null || !Array.isArray(institutions)) {
    return null;
  }

  const institutionIds = institutions
    .map((institution) => readNonEmptyString(institution.id))
    .filter((id): id is string => id !== null);

  if (institutionIds.length === 0) {
    return false;
  }

  const { data: accounts, error: accountsError } = await supabaseAdmin
    .from("accounts")
    .select("name, mask")
    .eq("user_id", userId)
    .in("institution_id", institutionIds);

  if (accountsError !== null || !Array.isArray(accounts)) {
    return null;
  }

  const existingAccountKeys = new Set<string>();
  for (const account of accounts) {
    const name = readNonEmptyString(account.name);
    const mask = readNonEmptyString(account.mask);
    if (name === null || mask === null) {
      continue;
    }

    existingAccountKeys.add(accountIdentityKey(name, mask));
  }

  return metadata.selectedAccounts.some((account) => {
    return existingAccountKeys.has(
      accountIdentityKey(account.name, account.mask),
    );
  });
}

function accountIdentityKey(name: string, mask: string): string {
  return `${name}\u0000${mask}`;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  if (request.method !== "POST") {
    return methodNotAllowed();
  }

  const user = await authenticateRequest(request);
  if (user === null) {
    return errorResponse(401, "unauthorized");
  }

  const body = await readJsonObject(request);
  if (body === null) {
    return errorResponse(400, "invalid_request");
  }

  const publicToken = readPublicToken(body);
  if (publicToken === null) {
    return errorResponse(400, "invalid_request");
  }

  const duplicateMetadata = readDuplicateMetadata(body);
  if (duplicateMetadata === null) {
    return errorResponse(400, "invalid_request");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (
    typeof supabaseUrl !== "string" ||
    supabaseUrl.length === 0 ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.length === 0
  ) {
    return errorResponse(500, "supabase_config_missing");
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isDuplicate = await hasDuplicateSelectedAccount(
    supabaseAdmin,
    user.id,
    duplicateMetadata,
  );

  if (isDuplicate === null) {
    return errorResponse(500, "duplicate_check_failed");
  }

  if (isDuplicate) {
    return jsonResponse(200, {
      status: "duplicate",
    });
  }

  const clientId = Deno.env.get("PLAID_CLIENT_ID");
  const sandboxSecret = Deno.env.get("PLAID_SANDBOX_SECRET");

  if (
    typeof clientId !== "string" ||
    clientId.length === 0 ||
    typeof sandboxSecret !== "string" ||
    sandboxSecret.length === 0
  ) {
    return errorResponse(500, "plaid_config_missing");
  }

  let plaidResponse: Response;

  try {
    plaidResponse = await fetch(PLAID_SANDBOX_PUBLIC_TOKEN_EXCHANGE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": sandboxSecret,
      },
      body: JSON.stringify({
        public_token: publicToken,
      }),
    });
  } catch (_) {
    return errorResponse(502, "plaid_request_failed");
  }

  let plaidPayload: Record<string, unknown>;

  try {
    const parsed = await plaidResponse.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return errorResponse(502, "plaid_request_failed");
    }
    plaidPayload = parsed as Record<string, unknown>;
  } catch (_) {
    return errorResponse(502, "plaid_request_failed");
  }

  if (!plaidResponse.ok) {
    return errorResponse(502, "plaid_request_failed");
  }

  const accessToken = plaidPayload.access_token;
  const itemId = plaidPayload.item_id;

  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    typeof itemId !== "string" ||
    itemId.length === 0
  ) {
    return errorResponse(502, "plaid_request_failed");
  }

  const { data: connectionId, error: persistError } = await supabaseAdmin.rpc(
    "plaid_persist_sandbox_item",
    {
      p_user_id: user.id,
      p_plaid_item_id: itemId,
      p_access_token: accessToken,
    },
  );

  if (
    persistError !== null ||
    typeof connectionId !== "string" ||
    connectionId.length === 0
  ) {
    return errorResponse(500, "persist_failed");
  }

  return jsonResponse(200, {
    connection_id: connectionId,
  });
});
