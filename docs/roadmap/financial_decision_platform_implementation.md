# Financial Decision Platform Implementation Roadmap

## Purpose

This document converts the existing architecture from
`docs/architecture/financial_knowledge_engine.md` and
`docs/architecture/financial_reasoning_engine.md` into an implementation
roadmap.

It does not introduce a new architecture. It defines the order in which the
Financial Decision Platform must be implemented.

The platform must be built strictly top-down:

```text
Financial Facts
-> Financial Models
-> Deviations
-> Problems
-> Decision Options
-> Recommendations
-> Explanations
-> Dashboard Consumer
```

Implementation must not skip layers.

- Problems must not be implemented before Financial Models exist.
- Recommendations must not be implemented before Problems and Decision Options exist.
- Dashboard must be the last consumer of prepared outputs, not the place where
  financial calculations or reasoning happen.

## Phase 1 Scope

Phase 1 starts now and includes only:

- Financial Facts Layer.

Phase 1 does not include:

- AI;
- Bank Integration;
- Budget;
- Goals;
- Forecast;
- Full Financial Health Score;
- Learning Loop.

## Global Rules

- Financial truth is calculated from financial facts.
- AI is not a source of financial truth.
- Dashboard is not a calculation or reasoning layer.
- Domain/services own formulas, financial meaning, and decision logic.
- Presentation prepares display-ready data only.
- Repository loads, saves, and maps data only.
- `Category.analyticsGroup` is used for analytics.
- `Category.uiGroup` is used only for UI grouping.
- Recorded balance and bank balance must not be mixed without reconciliation.
- Derived outputs must not become primary facts.
- Every future problem, option, recommendation, and explanation must be traceable
  to facts, model results, evidence, and confidence.

## 1. Financial Facts Layer

### Goal

Create a normalized, explicit representation of the user's currently available
financial facts.

This layer answers:

```text
What financial facts are available and safe to use for calculations?
```

It does not calculate financial models and does not create problems or advice.

### Input Data

Current inputs:

- manual recorded operations;
- operation amount;
- operation currency;
- operation type;
- operation occurred date;
- operation category;
- operation account links, when available;
- operation recurrence flags;
- operation recurrence rule;
- categories;
- `Category.analyticsGroup`;
- account initial balances, when available;
- active records only.

Future inputs:

- operation source: manual or bank imported;
- bank imported operations;
- bank account data;
- bank balances;
- pending/posted state;
- merchant/counterparty;
- category confidence;
- user settings;
- household context;
- budgets;
- goals;
- debts;
- investments;
- tax data;
- exchange rates.

### Output Data

Required outputs:

- normalized financial fact set;
- operation facts;
- category classification facts;
- recurring operation facts;
- account balance seed facts, when available;
- period context;
- data availability context;
- known limitations;
- source confidence;
- unresolved data gaps.

The output should be suitable for Financial Models, but must not contain model
results.

### Models / Classes / Services

Required domain models:

- `FinancialFactSet`;
- `FinancialFact`;
- `OperationFinancialFact`;
- `CategoryFinancialFact`;
- `RecurringFinancialFact`;
- `AccountBalanceSeedFact`;
- `FinancialFactSource`;
- `FinancialFactConfidence`;
- `FinancialDataGap`;
- `FinancialDataAvailability`;
- `FinancialPeriodContext`;
- `FinancialFactLimitations`.

Required services:

- `FinancialFactsService`;
- `OperationFactExtractor`;
- `CategoryFactExtractor`;
- `RecurringFactExtractor`;
- `AccountSeedFactExtractor`;
- `FinancialDataQualityInputService`.

The service responsibility is extraction and normalization only.

### Data Available Now

Available now:

- operations;
- categories;
- `Category.analyticsGroup`;
- recurrence flags and recurrence values;
- account initial balances, if present in current data flow;
- manual recorded data.

The layer must explicitly mark limitations when a fact depends on data that is
not available yet.

### Future Work

Leave for later:

- bank imported fact extraction;
- provider metadata normalization;
- reconciliation facts;
- budget facts;
- goal facts;
- debt facts;
- investment facts;
- tax facts;
- household facts;
- strategy facts;
- historical advice outcome facts.

### Forbidden In This Layer

Do not:

- calculate cash flow;
- calculate ratios;
- calculate burn rate;
- calculate forecast;
- detect deviations;
- create problems;
- create advice;
- rank recommendations;
- generate explanations;
- call AI;
- use `Category.uiGroup` for analytics;
- use bank/provider categories as analytical truth;
- mix recorded and bank balance;
- hide missing data;
- treat derived dashboard/statistics values as primary facts.

### Readiness Criteria

This layer is ready when:

- all current operations can be converted into normalized facts;
- category analytics meaning is available through `Category.analyticsGroup`;
- recurring operations are represented as facts, not forecasts;
- unavailable data is represented as explicit data gaps;
- confidence and source are explicit;
- archived records are excluded from active facts;
- the layer can be used without Dashboard;
- no problem, advice, or recommendation model exists in this layer.

### Required Tests

Tests required:

- extracts operation facts for income, expense, and transfer;
- preserves amount, currency, type, date, category, and account links;
- maps category facts with `analyticsGroup`;
- never uses `uiGroup` for analytical facts;
- extracts recurring facts from recurrence data;
- marks missing category as data gap;
- marks missing account seed as limitation when needed;
- excludes archived records from active facts;
- keeps manual recorded source explicit;
- does not calculate model results.

## 2. Financial Models Layer

### Goal

Convert normalized financial facts into reproducible financial model results.

This layer answers:

```text
What is financially true according to the available facts?
```

### Input Data

Inputs:

- `FinancialFactSet`;
- operation facts;
- category facts;
- recurring facts;
- account balance seed facts;
- period context;
- data availability context.

### Output Data

Outputs:

- `FinancialModelResult`;
- calculated metric values;
- model confidence;
- model evidence references;
- model limitations;
- model input coverage.

Phase 2 model results should include only models supported by current data:

- cash flow;
- income total;
- expense total;
- net cash flow;
- expense ratios;
- essential ratio;
- flexible ratio;
- lifestyle ratio;
- savings rate;
- recurring commitments;
- subscription load estimate;
- monthly fixed cost estimate;
- variable cost estimate;
- simple burn rate;
- data quality score.

### Models / Classes / Services

Required models:

- `FinancialModel`;
- `FinancialModelType`;
- `FinancialModelResult`;
- `FinancialMetric`;
- `FinancialMetricValue`;
- `FinancialModelEvidence`;
- `FinancialModelConfidence`;
- `FinancialModelLimitation`;
- `DataQualityScore`.

Required services:

- `FinancialModelCalculationService`;
- `CashFlowModelService`;
- `ExpenseRatioModelService`;
- `RecurringCommitmentModelService`;
- `BurnRateModelService`;
- `SavingsRateModelService`;
- `DataQualityModelService`.

### Data Available Now

Available now:

- operation facts;
- category analytics group facts;
- recurrence facts;
- period context;
- account initial balance facts, if available.

### Future Work

Leave for later:

- liquidity;
- emergency fund coverage;
- budget compliance;
- goal feasibility;
- debt ratio;
- debt-to-income;
- full forecast;
- full financial health score;
- net worth;
- tax reserve;
- investment allocation;
- bank sync freshness;
- reconciliation difference.

### Forbidden In This Layer

Do not:

- create user-facing advice;
- decide which problem matters most;
- rank actions;
- produce dashboard copy;
- call AI;
- infer budgets or goals that do not exist;
- calculate bank balance without bank data;
- treat low-confidence forecasts as reliable truth;
- create static insight cards.

### Readiness Criteria

This layer is ready when:

- every model result is reproducible from facts;
- every result has evidence;
- every result has confidence;
- every result has limitations where data is incomplete;
- unsupported models are absent or explicitly unavailable;
- no problem or recommendation exists yet.

### Required Tests

Tests required:

- cash flow totals are correct by period;
- transfer handling does not distort income/expense;
- expense ratios use `analyticsGroup`;
- recurring load uses recurrence facts only;
- savings rate handles zero income safely;
- burn rate uses available period data;
- data quality score reacts to missing categories and limited history;
- model confidence decreases when data is incomplete;
- unsupported models are not silently calculated.

## 3. Deviation Layer

### Goal

Compare model results with norms, expected ranges, baselines, or safe thresholds.

This layer answers:

```text
What differs from expected, safe, or normal financial behavior?
```

### Input Data

Inputs:

- `FinancialModelResult`;
- model confidence;
- benchmarks;
- simple thresholds;
- period context;
- data quality score.

### Output Data

Outputs:

- `FinancialDeviation`;
- deviation type;
- actual value;
- expected value or expected range;
- deviation amount;
- severity candidate;
- confidence;
- evidence;
- limitations.

### Models / Classes / Services

Required models:

- `FinancialDeviation`;
- `FinancialDeviationType`;
- `FinancialThreshold`;
- `FinancialBenchmark`;
- `DeviationSeverity`;
- `DeviationEvidence`.

Required services:

- `DeviationDetectionService`;
- `CashFlowDeviationService`;
- `RatioDeviationService`;
- `RecurringLoadDeviationService`;
- `DataQualityDeviationService`.

### Data Available Now

Available now:

- model results from current data;
- simple thresholds;
- period comparison only if enough history exists.

### Future Work

Leave for later:

- strategy-specific benchmarks;
- personalized thresholds;
- household benchmarks;
- budget-based deviation;
- goal-based deviation;
- debt/liquidity deviations;
- bank reconciliation deviations;
- tax/investment deviations.

### Forbidden In This Layer

Do not:

- call a deviation a problem automatically;
- create advice;
- rank recommendations;
- produce dashboard messages;
- hide low confidence;
- use thresholds without making them explicit;
- infer user strategy without strategy data.

### Readiness Criteria

This layer is ready when:

- deviations are generated only from model results;
- expected values/ranges are explicit;
- severity is a candidate, not final recommendation priority;
- low confidence deviations remain visible as low confidence;
- no decision option or recommendation exists yet.

### Required Tests

Tests required:

- detects negative cash flow deviation;
- detects high ratio deviation;
- detects recurring load pressure when threshold is exceeded;
- detects weak data quality;
- does not create deviation when model is unavailable;
- includes expected value/range;
- includes evidence and confidence;
- handles limited history without false precision.

## 4. Problem Detection Layer

### Goal

Convert meaningful deviations into financial problems.

This layer answers:

```text
Which deviations represent actual financial problems that deserve attention?
```

### Input Data

Inputs:

- financial deviations;
- financial model results;
- evidence;
- confidence;
- data quality;
- known limitations.

### Output Data

Outputs:

- `FinancialProblem`;
- problem type;
- severity;
- root evidence;
- affected models;
- probable cause candidates;
- confidence;
- limitations.

### Models / Classes / Services

Required models:

- `FinancialProblem`;
- `FinancialProblemType`;
- `FinancialProblemSeverity`;
- `ProblemEvidence`;
- `ProblemCauseCandidate`;
- `ProblemConfidence`.

Required services:

- `ProblemDetectionService`;
- `CashFlowProblemService`;
- `SpendingStructureProblemService`;
- `RecurringCommitmentProblemService`;
- `DataQualityProblemService`.

### Data Available Now

Problems available now:

- negative cash flow;
- high expense pressure;
- high lifestyle/flexible spending share;
- uncategorized operations;
- large operation requiring review;
- weak data quality;
- recurring commitment load.

### Future Work

Leave for later:

- budget overspending problems;
- goal feasibility problems;
- debt burden problems;
- liquidity problems;
- reconciliation problems;
- tax reserve problems;
- investment allocation problems;
- full forecast risk problems.

### Forbidden In This Layer

Do not:

- create problems without model result and deviation;
- create manually curated dashboard cards;
- create recommendations;
- choose the next best action;
- use AI to determine problem existence;
- hide that a problem is low confidence;
- treat every deviation as a problem.

### Readiness Criteria

This layer is ready when:

- every problem references one or more deviations;
- every problem references model evidence;
- every problem has confidence;
- every problem has clear limitations;
- low-confidence problems are represented without exaggeration;
- no recommendations exist yet.

### Required Tests

Tests required:

- creates negative cash flow problem from negative cash flow deviation;
- creates uncategorized data quality problem;
- creates recurring load problem from recurring deviation;
- does not create problem from unsupported model;
- does not create problem from low-signal deviation unless policy allows it;
- preserves evidence and confidence;
- distinguishes problem severity from recommendation priority.

## 5. Decision Options Layer

### Goal

Generate possible actions for each detected problem before choosing a recommendation.

This layer answers:

```text
What valid actions could the user take?
```

### Input Data

Inputs:

- financial problems;
- model results;
- deviations;
- evidence;
- data quality;
- current data limitations.

### Output Data

Outputs:

- `DecisionOptionSet`;
- `DecisionOption`;
- expected effect estimate;
- effort estimate;
- risk estimate;
- reversibility;
- confidence;
- measurement target;
- rejected or unavailable options with reason.

### Models / Classes / Services

Required models:

- `DecisionOptionSet`;
- `DecisionOption`;
- `DecisionOptionType`;
- `DecisionOptionEffect`;
- `DecisionOptionRisk`;
- `DecisionOptionEffort`;
- `DecisionOptionAvailability`;
- `UnavailableOptionReason`.

Required services:

- `DecisionOptionGenerationService`;
- `CashFlowOptionService`;
- `SpendingReviewOptionService`;
- `CategorizationOptionService`;
- `RecurringOperationOptionService`;
- `DataQualityOptionService`.

### Data Available Now

Options available now:

- categorize uncategorized operations;
- review top expense analytics group;
- review largest operation;
- reduce flexible or lifestyle spending;
- add or confirm recurring operation;
- monitor and collect more data when confidence is low.

### Future Work

Leave for later:

- adjust budget;
- delay goal;
- increase goal contribution;
- debt payoff options;
- investment rebalancing;
- tax reserve action;
- bank reconciliation action;
- subscription cancellation detection;
- scenario comparison.

### Forbidden In This Layer

Do not:

- choose a final recommendation;
- show actions on Dashboard directly;
- create static advice without problem linkage;
- generate options unsupported by available data;
- pretend future features exist;
- call AI to invent actions;
- skip rejected/unavailable option reasoning when relevant.

### Readiness Criteria

This layer is ready when:

- every option is linked to a problem;
- every option has expected effect or explains why effect is qualitative;
- every option has confidence;
- unavailable future options can be represented as unavailable, not recommended;
- no final recommendation exists yet.

### Required Tests

Tests required:

- generates categorization option for uncategorized problem;
- generates spending review option for spending structure problem;
- generates recurring setup option for missing recurring data;
- generates monitor option for low confidence;
- does not generate budget option when budgets are unavailable;
- does not generate bank reconciliation option before bank integration;
- includes expected effect, effort, risk, and confidence.

## 6. Recommendation Layer

### Goal

Select the most appropriate action from available decision options.

This layer answers:

```text
What should the user do next, and why this option?
```

### Input Data

Inputs:

- decision option sets;
- financial problems;
- model results;
- deviations;
- data quality;
- option confidence;
- expected effect;
- urgency;
- effort;
- reversibility;
- risk.

### Output Data

Outputs:

- `FinancialRecommendation`;
- selected option;
- recommendation priority;
- recommendation rationale;
- expected outcome;
- rejected alternatives;
- confidence;
- measurement plan.

### Models / Classes / Services

Required models:

- `FinancialRecommendation`;
- `RecommendationPriority`;
- `RecommendationRationale`;
- `ExpectedOutcome`;
- `RejectedOptionReason`;
- `TradeOffEvaluation`;
- `MeasurementPlan`.

Required services:

- `RecommendationSelectionService`;
- `TradeOffEvaluationService`;
- `RecommendationPriorityService`;
- `MeasurementPlanService`.

### Data Available Now

Recommendations available now:

- review uncategorized operations;
- inspect negative cash flow;
- review top expense analytics group;
- review largest operation;
- add or confirm recurring operation;
- collect more data before acting.

### Future Work

Leave for later:

- personalized user fit;
- strategy alignment;
- budget adjustment recommendation;
- goal trade-off recommendation;
- debt payoff recommendation;
- tax recommendation;
- investment recommendation;
- AI-personalized wording;
- learning-based ranking.

### Forbidden In This Layer

Do not:

- recommend without problem and option;
- recommend without comparing options;
- recommend without expected outcome;
- recommend measurable action without measurement plan;
- hide low confidence;
- let AI choose priority;
- recommend future-feature actions as if executable now.

### Readiness Criteria

This layer is ready when:

- every recommendation references a selected decision option;
- every recommendation has rationale;
- every recommendation has confidence;
- rejected alternatives are available when multiple options exist;
- every measurable recommendation has measurement plan;
- Dashboard is still not involved.

### Required Tests

Tests required:

- selects highest-priority option by deterministic policy;
- prefers data quality action when missing data blocks reliable advice;
- does not recommend low-confidence aggressive action;
- includes rejected alternative reason;
- includes expected outcome;
- includes measurement plan;
- preserves problem and evidence references.

## 7. Explanation Layer

### Goal

Convert facts, models, deviations, problems, options, and recommendations into a
structured explanation graph.

This layer answers:

```text
How did the system reach this conclusion?
```

### Input Data

Inputs:

- financial facts;
- model results;
- deviations;
- problems;
- decision options;
- recommendations;
- rejected alternatives;
- confidence;
- limitations;
- measurement plan.

### Output Data

Outputs:

- `ExplanationGraph`;
- `ReasoningStep`;
- explanation nodes;
- explanation edges;
- assumptions;
- evidence references;
- limitations;
- human-readable explanation payload for presentation.

### Models / Classes / Services

Required models:

- `ExplanationGraph`;
- `ExplanationNode`;
- `ExplanationEdge`;
- `ReasoningStep`;
- `ReasoningStepType`;
- `ExplanationEvidence`;
- `ExplanationAssumption`;
- `ExplanationLimitation`.

Required services:

- `ExplanationGraphService`;
- `ReasoningTraceService`;
- `ExplanationSummaryService`.

### Data Available Now

Available now:

- fact references;
- model result references;
- deviations;
- problems;
- options;
- recommendation rationale;
- confidence;
- limitations.

### Future Work

Leave for later:

- AI-generated natural language explanation;
- conversational Q&A;
- personalized tone;
- education content;
- learning feedback;
- scenario explanation.

### Forbidden In This Layer

Do not:

- calculate financial truth;
- change model results;
- create new problems;
- create new recommendations;
- hide evidence;
- replace structured explanation with plain text only;
- call AI as source of logic;
- obscure low confidence.

### Readiness Criteria

This layer is ready when:

- every recommendation can be traced back to facts and models;
- every explanation includes evidence;
- every explanation includes confidence;
- every limitation is visible;
- plain text is derived from structured reasoning, not the source of reasoning;
- AI can be added later without changing financial truth.

### Required Tests

Tests required:

- creates graph from fact to model result;
- links model result to deviation;
- links deviation to problem;
- links problem to option;
- links option to recommendation;
- includes rejected alternatives;
- includes limitations and confidence;
- explanation does not mutate financial results.

## 8. Dashboard Consumer Layer

### Goal

Display prepared Assistant Core outputs on Dashboard.

This layer answers:

```text
How should the already calculated and reasoned financial summary be shown?
```

Dashboard is the last consumer. It must not calculate financial truth or perform
reasoning.

### Input Data

Inputs:

- assistant financial summary;
- model summaries;
- problems;
- recommendations;
- explanation payload;
- confidence;
- measurement plans;
- display formatting preferences.

### Output Data

Outputs:

- dashboard presentation models;
- formatted amounts;
- localized labels;
- UI ordering;
- visual severity;
- empty states;
- navigation targets.

### Models / Classes / Services

Required models:

- `DashboardAssistantSummaryPresentation`;
- `DashboardProblemPresentation`;
- `DashboardRecommendationPresentation`;
- `DashboardExplanationPresentation`;
- `DashboardMeasurementPresentation`.

Required services/adapters:

- `DashboardAssistantPresentationAdapter`;
- `DashboardRecommendationPresentationAdapter`;
- `DashboardExplanationPresentationAdapter`.

### Data Available Now

Dashboard can consume:

- current recorded financial summary;
- current Assistant Core V1 outputs once layers 1-7 exist;
- no bank balance;
- no AI output;
- no budget/goal-aware outputs.

### Future Work

Leave for later:

- bank reconciliation dashboard state;
- budget-aware cards;
- goal-aware cards;
- forecast-aware cards;
- AI conversational explanation;
- notification entry points;
- learning outcome display.

### Forbidden In This Layer

Do not:

- calculate balance;
- calculate cash flow;
- calculate ratios;
- detect deviations;
- create problems;
- generate options;
- select recommendations;
- generate financial explanations;
- call AI for financial truth;
- use provider-specific bank logic;
- use bank categories as analytics;
- use `uiGroup` for analytics.

### Readiness Criteria

This layer is ready when:

- Dashboard receives prepared outputs only;
- Dashboard can render problems and recommendations without knowing formulas;
- Dashboard can show confidence and limitations;
- Dashboard can show explanation/rationale;
- Dashboard has empty states for insufficient data;
- Dashboard does not duplicate Assistant Core logic.

### Required Tests

Tests required:

- presentation adapter formats recommendations without recalculating them;
- low confidence is visible;
- insufficient data state is visible;
- amounts are formatted in presentation only;
- dashboard ordering does not change recommendation priority semantics;
- no financial formulas are present in Dashboard UI.

## Implementation Phases

### Phase 1: Financial Facts Layer

Implement only the Financial Facts Layer.

Deliverables:

- normalized fact models;
- fact extraction services;
- source/confidence/gap models;
- active data filtering rules;
- tests for fact extraction and limitations.

Do not implement:

- financial model calculations;
- deviations;
- problems;
- options;
- recommendations;
- explanations;
- dashboard integration.

### Phase 2: Financial Models Layer

Implement reproducible model results from facts.

Do not start Phase 2 until Phase 1 is complete.

### Phase 3: Deviation Layer

Implement deviations from model results.

Do not start Phase 3 until Phase 2 is complete.

### Phase 4: Problem Detection Layer

Implement problems from deviations.

Do not start Phase 4 until Phase 3 is complete.

### Phase 5: Decision Options Layer

Implement options from problems.

Do not start Phase 5 until Phase 4 is complete.

### Phase 6: Recommendation Layer

Implement recommendation selection from options.

Do not start Phase 6 until Phase 5 is complete.

### Phase 7: Explanation Layer

Implement structured explanation and reasoning trace.

Do not start Phase 7 until Phase 6 is complete.

### Phase 8: Dashboard Consumer Layer

Connect Dashboard to Assistant Core outputs.

Do not start Phase 8 until Phase 7 is complete.

## Not In Current Implementation

The following are explicitly out of scope for the current implementation start:

- AI;
- Bank Integration;
- Budget;
- Goals;
- Forecast;
- Full Financial Health Score;
- Learning Loop.

These features must be added only after the lower layers can support them with
facts, models, deviations, problems, options, recommendations, and explanations.
