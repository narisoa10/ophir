// Level 1 duplicate protection: decides from Link metadata and the user's
// stored Plaid accounts alone, before /item/public_token/exchange. Never reads
// transactions, operations, amounts or balances.

export type AccountDecision =
  | "new"
  | "duplicate"
  | "ambiguous"
  | "disconnected_existing";

export type LinkStatus =
  | "proceed"
  | "duplicate"
  | "partial_duplicate"
  | "confirmation_required"
  | "disconnected_existing";

export type IncomingAccount = {
  accountId: string;
  name: string;
  mask: string | null;
  type: string | null;
  subtype: string | null;
};

export type ExistingAccount = {
  plaidAccountId: string | null;
  name: string | null;
  officialName: string | null;
  mask: string | null;
  type: string | null;
  subtype: string | null;
  itemDisconnected: boolean;
};

export type LinkClassification = {
  status: LinkStatus;
  decisions: AccountDecision[];
};

type CandidateMatch = "none" | "strong" | "ambiguous";

const accountDecisions: ReadonlySet<string> = new Set([
  "new",
  "duplicate",
  "ambiguous",
  "disconnected_existing",
]);

export function normalizeIdentityText(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function conflicts(incoming: string | null, existing: string | null): boolean {
  return incoming !== null && existing !== null && incoming !== existing;
}

function matchCandidate(
  incoming: IncomingAccount,
  candidate: ExistingAccount,
): CandidateMatch {
  if (
    candidate.plaidAccountId !== null &&
    candidate.plaidAccountId === incoming.accountId
  ) {
    return "strong";
  }

  const nameMatches = incoming.name === candidate.name ||
    incoming.name === candidate.officialName;
  if (!nameMatches) {
    return "none";
  }

  if (incoming.mask === null || candidate.mask === null) {
    return "ambiguous";
  }

  const typesConflict = conflicts(incoming.type, candidate.type) ||
    conflicts(incoming.subtype, candidate.subtype);

  // Plaid can report a different mask for the same account on another Item,
  // so a differing mask alone never proves a different account.
  if (incoming.mask !== candidate.mask) {
    return typesConflict ? "none" : "ambiguous";
  }

  return typesConflict ? "ambiguous" : "strong";
}

export function classifyAccount(
  incoming: IncomingAccount,
  existing: readonly ExistingAccount[],
): AccountDecision {
  let activeStrong = false;
  let disconnectedStrong = false;
  let ambiguous = false;

  for (const candidate of existing) {
    switch (matchCandidate(incoming, candidate)) {
      case "strong":
        if (candidate.itemDisconnected) {
          disconnectedStrong = true;
        } else {
          activeStrong = true;
        }
        break;
      case "ambiguous":
        ambiguous = true;
        break;
      case "none":
        break;
    }
  }

  if (activeStrong) {
    return "duplicate";
  }
  if (disconnectedStrong) {
    return "disconnected_existing";
  }
  return ambiguous ? "ambiguous" : "new";
}

// The stored accounts that make an "ambiguous" decision, so the user can
// compare them. Says nothing about which of them, if any, is the same account.
export function ambiguousCandidates(
  incoming: IncomingAccount,
  existing: readonly ExistingAccount[],
): ExistingAccount[] {
  return existing.filter((candidate) =>
    matchCandidate(incoming, candidate) === "ambiguous"
  );
}

// Returns null for anything it cannot classify, so the caller fails closed.
export function aggregateLink(
  decisions: readonly AccountDecision[],
  confirmAmbiguous: boolean,
): LinkStatus | null {
  if (decisions.length === 0) {
    return null;
  }

  let blocking = 0;
  let disconnected = 0;
  let ambiguous = 0;

  for (const decision of decisions) {
    if (!accountDecisions.has(decision)) {
      return null;
    }
    if (decision === "duplicate" || decision === "disconnected_existing") {
      blocking += 1;
    }
    if (decision === "disconnected_existing") {
      disconnected += 1;
    }
    if (decision === "ambiguous") {
      ambiguous += 1;
    }
  }

  if (blocking > 0 && blocking < decisions.length) {
    return "partial_duplicate";
  }
  if (blocking > 0) {
    return disconnected === blocking ? "disconnected_existing" : "duplicate";
  }
  if (ambiguous > 0 && !confirmAmbiguous) {
    return "confirmation_required";
  }
  return "proceed";
}

export function classifyLink(
  incoming: readonly IncomingAccount[],
  existing: readonly ExistingAccount[],
  confirmAmbiguous: boolean,
): LinkClassification | null {
  const decisions = incoming.map((account) =>
    classifyAccount(account, existing)
  );
  const status = aggregateLink(decisions, confirmAmbiguous);
  return status === null ? null : { status, decisions };
}
