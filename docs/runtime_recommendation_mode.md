# Runtime Recommendation Mode

Runtime Recommendation Mode controls which recommendation source may participate
in the Assistant's current runtime recommendation selection.

It is a build-time runtime-safety switch for the recommendation path only. It
must not change Dashboard UI contracts, Supabase, persistence, operation storage,
category storage, or financial calculations.

## Build Flag

The application reads the mode from the Dart environment key:

```text
FINANCIAL_RUNTIME_MODE
```

Valid values are case-sensitive:

- `legacy`
- `intelligenceAllowlist`
- `shadowOnly`

Run the app with one of:

```bash
flutter run --dart-define=FINANCIAL_RUNTIME_MODE=legacy
```

```bash
flutter run --dart-define=FINANCIAL_RUNTIME_MODE=intelligenceAllowlist
```

```bash
flutter run --dart-define=FINANCIAL_RUNTIME_MODE=shadowOnly
```

Because this value is read with `String.fromEnvironment`, treat mode changes as
build/startup changes. Stop the app and rerun it with the new `--dart-define`
instead of expecting an in-session toggle.

## Modes

### `legacy`

What it does:

- Uses the legacy Assistant recommendation path as the runtime source.
- Does not use the recommendation comparison path for runtime selection.
- Keeps the selected recommendation source as `legacy`.

When to use:

- Production rollback.
- Baseline comparison before validating other modes.
- Any situation where the intelligence runtime path is suspected of affecting
  user-facing behavior.

Rollback behavior:

- This is the rollback target.
- Restart the app with
  `--dart-define=FINANCIAL_RUNTIME_MODE=legacy`.
- The Assistant should return to legacy recommendation behavior regardless of
  shadow diagnostics or comparison output.

Expected user-facing behavior:

- The Assistant recommendation should match the pre-runtime legacy behavior.
- Dashboard and Assistant screens should not expose new intelligence-runtime UI.
- Financial totals, categories, stored operations, and persistence state should
  remain unchanged.

### `intelligenceAllowlist`

What it does:

- Loads the legacy Assistant recommendation.
- Builds the legacy-vs-shadow recommendation comparison.
- Marks the selection source as `intelligenceAllowlist` only when the comparison
  is an aligned allowlist case with no blocking safety signals.
- Falls back to the legacy source for every non-allowlisted, missing, warning, or
  divergent case.

The allowlisted legacy recommendation types are:

- `reduceDiscretionarySpending`
- `deferOptionalSpending`
- `reviewExpenseStructure`
- `improveCategorization`
- `collectMoreData`

The allowlisted shadow diagnostic recommendation types are:

- `reviewOrdinarySpendingStructure`
- `reduceReducibleSpending`
- `deferOrReduceDiscretionarySpending`
- `improveCategoryCoverage`

The selection must remain legacy fallback when any of the following is true:

- There is no legacy recommendation.
- There is no comparison result.
- The comparison is not `aligned`.
- Any positive signal is present.
- Any context warning is present.
- Any coverage warning is present.
- Any blocking comparison flag is present.
- The legacy recommendation type is not allowlisted.
- Any shadow recommendation type is not allowlisted.
- The comparison legacy type does not match the selected legacy recommendation
  type.

When to use:

- Default staged rollout mode.
- Manual validation of aligned ordinary, reducible, discretionary, and category
  coverage recommendation paths.
- Production operation when legacy fallback must remain available for all unsafe
  cases.

Rollback behavior:

- Restart with `FINANCIAL_RUNTIME_MODE=legacy`.
- Any unsafe or unsupported case automatically falls back to legacy even while
  the app is running in `intelligenceAllowlist`.

Expected user-facing behavior:

- User-visible Assistant recommendation content should remain legacy-compatible.
- In the current runtime path, the selected `FinancialRecommendation` exposed to
  the Assistant is still the selected legacy recommendation object; the mode
  controls the internal source selection and fallback policy.
- If the selected recommendation id changes, the previous legacy explanation may
  be cleared; if the id is preserved, the legacy explanation may be preserved.
- Dashboard totals, stored data, Supabase, and persistence behavior must not
  change.

### `shadowOnly`

What it does:

- Keeps the runtime Assistant recommendation source as `legacy`.
- Keeps intelligence diagnostics out of runtime recommendation selection.
- Does not use the comparison path to replace or approve the runtime
  recommendation.

When to use:

- Shadow validation where diagnostics can be observed separately from runtime
  recommendation behavior.
- Production safety checks when the intelligence path should not affect the
  current Assistant recommendation.
- Comparing diagnostic availability without changing user-facing recommendation
  selection.

Rollback behavior:

- User-facing recommendation behavior is already legacy.
- To disable even the shadow-mode configuration, restart with
  `FINANCIAL_RUNTIME_MODE=legacy`.

Expected user-facing behavior:

- Assistant recommendation behavior should match `legacy`.
- Dashboard and Assistant UI should not show a different recommendation because
  of shadow diagnostics.
- Financial totals, categories, stored operations, and persistence state should
  remain unchanged.

## Production Safety

- Default mode: `intelligenceAllowlist`.
- Missing `FINANCIAL_RUNTIME_MODE` value: falls back to the default mode,
  `intelligenceAllowlist`.
- Invalid `FINANCIAL_RUNTIME_MODE` value: falls back to the default mode,
  `intelligenceAllowlist`.
- Production rollback: deploy or run with
  `FINANCIAL_RUNTIME_MODE=legacy`.
- The mode is a local build/runtime selection switch. It must not introduce
  Supabase schema changes, persistence migrations, operation mutations, category
  mutations, or changes to financial calculations.
- `legacy` must remain available until a separate removal stage explicitly
  approves legacy removal after audit, parity, and regression coverage.

## Manual QA Plan

Use the same local data set for all three runs. For each scenario:

- Run once with `legacy`.
- Run once with `intelligenceAllowlist`.
- Run once with `shadowOnly`.
- Record the Assistant recommendation type/title, visible recommendation text,
  explanation presence, Dashboard totals, and whether any error state appears.
- If an internal debug hook is available, also record the runtime selection
  source: `legacy` or `intelligenceAllowlist`.

General pass criteria:

- `legacy` and `shadowOnly` must match user-facing behavior.
- `intelligenceAllowlist` must match user-facing legacy behavior unless the only
  observed difference is an internal selection source of `intelligenceAllowlist`
  for an aligned allowlist case.
- No mode may change stored operations, categories, Supabase data, persistence,
  or financial calculation results.
- Any warning, positive signal, context-required, coverage-gap, divergent,
  partial-overlap, not-comparable, missing-recommendation, or missing-comparison
  case must remain legacy fallback.

### Scenario Matrix

| Scenario | Manual setup | Expected in `legacy` | Expected in `intelligenceAllowlist` | Expected in `shadowOnly` | Coincide / fallback rule |
| --- | --- | --- | --- | --- | --- |
| Ordinary expenses | Add normal current-month expenses such as rent, groceries, utilities, or transport with stable taxonomy categories. | Assistant uses the legacy recommendation path. Ordinary expenses remain ordinary spending. | If ordinary spending pressure aligns with `reviewExpenseStructure` and shadow diagnostics are allowlisted with no warnings, internal source may be `intelligenceAllowlist`; otherwise source remains legacy. User-facing recommendation should stay legacy-compatible. | Same user-facing behavior as `legacy`. | User-facing behavior should coincide in all modes. Fallback when there is no aligned allowlist comparison. |
| Discretionary spending | Add high wants/discretionary expenses, such as dining, entertainment, or optional shopping, enough to trigger discretionary pressure. | Legacy may recommend `reduceDiscretionarySpending` or `deferOptionalSpending` depending on the existing decision engine output. | May use internal `intelligenceAllowlist` only when legacy type is `reduceDiscretionarySpending` or `deferOptionalSpending`, shadow type is `reduceReducibleSpending` or `deferOrReduceDiscretionarySpending`, comparison is aligned, and no warning or positive signal exists. | Same user-facing behavior as `legacy`. | Coincide at the UI level. Legacy fallback for mandatory-only, divergent, warning, or non-allowlisted cases. |
| Category coverage | Create a month where categorization quality is incomplete enough for coverage diagnostics to appear. | Legacy recommendation remains the runtime recommendation. | Real coverage warnings are blocking, so runtime should remain legacy fallback even if shadow diagnostics suggest `improveCategoryCoverage`. A synthetic aligned comparison without a coverage warning may be allowlisted, but manual app behavior should treat coverage warnings as fallback. | Same user-facing behavior as `legacy`. | Coincide at the UI level. Fallback whenever coverage warnings are present. |
| Asset building | Add savings, investment, TFSA/RRSP/RESP, or emergency-fund contribution expenses with stable taxonomy categories. | Legacy behavior remains the runtime baseline. Asset-building amounts should not be treated as ordinary spending. | Legacy fallback. Shadow `maintainAssetBuildingMomentum` is a positive signal and is not an allowlisted runtime recommendation. | Same user-facing behavior as `legacy`. | Coincide in all modes. Positive signals must remain legacy fallback. |
| Debt reduction | Add debt repayment expenses with stable debt repayment categories. | Legacy behavior remains the runtime baseline. Debt repayment should contribute to debt-reduction behavior, not ordinary spending. | Legacy fallback. Shadow `maintainDebtReductionMomentum` is a positive signal and is not an allowlisted runtime recommendation. | Same user-facing behavior as `legacy`. | Coincide in all modes. Positive signals must remain legacy fallback. |
| Credit card payment | Add credit card payment and/or loan payment expenses with stable taxonomy categories. | Legacy recommendation remains the runtime recommendation. Payments should not inflate ordinary spending. | Legacy fallback because these payments require transaction context and produce context-warning diagnostics. | Same user-facing behavior as `legacy`. | Coincide in all modes. Context-required cases must remain legacy fallback. |
| Cash withdrawal | Add a cash withdrawal expense with the stable cash-withdrawal category. | Legacy recommendation remains the runtime recommendation. Cash withdrawal should be cash movement, not ordinary spending. | Legacy fallback because cash withdrawal requires transaction context. | Same user-facing behavior as `legacy`. | Coincide in all modes. Context-required cash movement must remain legacy fallback. |
| Adjustment | Add a data adjustment expense with the stable adjustment category. | Legacy recommendation remains the runtime recommendation. Adjustment should be data adjustment, not ordinary spending. | Legacy fallback because adjustments require transaction context and are not allowlisted runtime recommendations. | Same user-facing behavior as `legacy`. | Coincide in all modes. Data adjustment/context-required cases must remain legacy fallback. |
| Unresolved or broad legacy category | Add an operation in a broad legacy category without a stable key, or with an invalid stable key. | Legacy path should not crash and remains the runtime recommendation. | Legacy fallback. The intelligence behavior layer should mark the behavior unresolved and coverage diagnostics should not replace the runtime recommendation. | Same user-facing behavior as `legacy`. | Coincide in all modes. Coverage gaps and unresolved behavior must remain legacy fallback. |
| Context-required-heavy month | Build a month dominated by credit card payments, loan payments, cash withdrawals, currency exchange, adjustments, or other context-dependent actions. | Legacy recommendation remains the runtime recommendation. | Legacy fallback because `reviewTransactionContext` / context warnings are blocking. No context-heavy month should switch the runtime recommendation to intelligence. | Same user-facing behavior as `legacy`. | Coincide in all modes. Context warnings must remain legacy fallback. |

### Manual QA Failure Conditions

Treat any of the following as a failure:

- `legacy` and `shadowOnly` produce different user-facing recommendations for
  the same data.
- `intelligenceAllowlist` changes user-facing recommendation content for a case
  that has warnings, positive signals, context requirements, coverage gaps,
  partial overlap, divergence, or non-allowlisted recommendation types.
- Any mode changes Dashboard totals or special-action totals.
- Any mode writes different persisted data, changes Supabase state, mutates
  categories, or mutates operations.
- Any scenario crashes, loops providers, or leaves the Assistant without the
  legacy fallback when one is expected.
