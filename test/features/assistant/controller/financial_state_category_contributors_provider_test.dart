import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_behavior_compatibility_output_provider.dart';
import 'package:ophir/features/assistant/controller/financial_state_category_contributors_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_dashboard_briefing_provider.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_briefing.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_radar.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact_kind.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_expected_value.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/categories/domain/enums/category_financial_distribution_role.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('financialStateCategoryContributorsProvider', () {
    test(
      'returns snapshot when briefing and compatibility output succeed',
      () async {
        final briefing = _briefing(
          financialState: _state(FinancialStateType.deficit),
        );
        final output = _output(
          facts: [_behaviorFact(categoryId: 'restaurant', amount: 40)],
        );
        final container = _container(
          briefingResult: Success(briefing),
          outputResult: Success(output),
        );
        addTearDown(container.dispose);

        final result = await container.read(
          financialStateCategoryContributorsProvider.future,
        );
        final snapshot = _snapshotValue(result);

        expect(snapshot.stateType, briefing.financialState.type);
        expect(
          snapshot.contributors.map((contributor) => contributor.categoryId),
          ['restaurant'],
        );
      },
    );

    test('returns briefing failure', () async {
      const failure = UnknownFailure();
      final container = _container(
        briefingResult: const Failure<AssistantDashboardBriefing>(failure),
        outputResult: Success(_output()),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialStateCategoryContributorsProvider.future,
      );

      expect(
        result,
        isA<Failure<FinancialStateCategoryContributorsSnapshot>>(),
      );
      expect(
        (result as Failure<FinancialStateCategoryContributorsSnapshot>).failure,
        same(failure),
      );
    });

    test('returns compatibility output failure', () async {
      const failure = DatabaseFailure();
      final container = _container(
        briefingResult: Success(_briefing()),
        outputResult: const Failure<FinancialBehaviorCompatibilityOutput>(
          failure,
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialStateCategoryContributorsProvider.future,
      );

      expect(
        result,
        isA<Failure<FinancialStateCategoryContributorsSnapshot>>(),
      );
      expect(
        (result as Failure<FinancialStateCategoryContributorsSnapshot>).failure,
        same(failure),
      );
    });
  });
}

ProviderContainer _container({
  required Result<AssistantDashboardBriefing> briefingResult,
  required Result<FinancialBehaviorCompatibilityOutput> outputResult,
}) {
  return ProviderContainer(
    overrides: [
      legacyAssistantDashboardBriefingProvider.overrideWith(
        (ref) async => briefingResult,
      ),
      financialBehaviorCompatibilityOutputProvider.overrideWith(
        (ref) async => outputResult,
      ),
    ],
  );
}

AssistantDashboardBriefing _briefing({FinancialState? financialState}) {
  final state = financialState ?? _state(FinancialStateType.stable);
  final period = state.period;
  final factsSnapshot = FinancialFactsSnapshot(
    facts: [_financialFact(id: 'fact-restaurant', categoryId: 'restaurant')],
    dataGaps: const [],
  );
  final deviations = [
    _deviation(sourceFactIds: const ['fact-restaurant']),
  ];
  final primaryProblem = _problem(sourceDeviationIds: const ['deviation']);

  return AssistantDashboardBriefing(
    factsSnapshot: factsSnapshot,
    modelResults: const [],
    deviations: deviations,
    problems: [primaryProblem],
    decisionOptions: const [],
    recommendation: null,
    explanation: null,
    radar: const AssistantDashboardRadar(
      axes: [],
      isLowConfidence: false,
      evidenceModelIds: [],
    ),
    primaryProblem: primaryProblem,
    financialState: state,
    periodDistribution: FinancialPeriodDistribution(
      period: period,
      currencyCode: state.currencyCode,
      incomeTotal: state.income,
      expenseTotal: state.expenses,
      netCashFlow: state.net,
      items: const [],
      confidence: FinancialModelConfidence.high,
      evidenceModelIds: const [],
      limitations: const [],
    ),
  );
}

FinancialState _state(FinancialStateType type) {
  return FinancialState(
    type: type,
    confidence: FinancialStateConfidence.high,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    currencyCode: 'CAD',
    income: 1000,
    expenses: 800,
    net: type == FinancialStateType.deficit ? -100 : 200,
    evidenceModelIds: const [],
    limitations: const [],
  );
}

FinancialBehaviorCompatibilityOutput _output({
  List<FinancialBehaviorFact> facts = const [],
}) {
  return FinancialBehaviorCompatibilityOutput(
    snapshot: FinancialBehaviorFactsSnapshot(facts: facts),
    totals: const FinancialBehaviorTotals(
      legacyExpenseTotal: 0,
      ordinarySpendingTotal: 0,
      assetBuildingTotal: 0,
      debtReductionTotal: 0,
      cashMovementTotal: 0,
      dataAdjustmentTotal: 0,
      contextRequiredTotal: 0,
      behavioralSavingsTotal: 0,
      legacyVsIntelligenceDifference: 0,
      unresolvedCount: 0,
    ),
  );
}

FinancialStateCategoryContributorsSnapshot _snapshotValue(
  Result<FinancialStateCategoryContributorsSnapshot> result,
) {
  return switch (result) {
    Success(:final value) => value,
    Failure() => fail(
      'Expected financial state category contributors snapshot',
    ),
  };
}

FinancialBehaviorFact _behaviorFact({
  required String categoryId,
  required double amount,
}) {
  return FinancialBehaviorFact(
    operationId: 'operation',
    operationType: OperationType.expense,
    categoryId: categoryId,
    stableKey: CategoryStableKey.expenseFoodRestaurant,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: DateTime.utc(2035, 6, 10),
    kind: FinancialBehaviorFactKind.ordinarySpending,
    distributionRole: CategoryFinancialDistributionRole.wants,
    requiresTransactionContext: false,
  );
}

FinancialProblem _problem({required List<String> sourceDeviationIds}) {
  return FinancialProblem(
    problemId: 'problem',
    problemType: FinancialProblemType.cashFlowDeficit,
    status: FinancialProblemStatus.detected,
    severity: FinancialProblemSeverity.high,
    confidence: FinancialProblemConfidence.high,
    impact: FinancialProblemImpact.cashFlow,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    signals: const [],
    evidence: FinancialProblemEvidence(
      sourceDeviationIds: sourceDeviationIds,
      sourceDeviationTypes: const [FinancialDeviationType.negativeNetCashFlow],
      sourceModelIds: const ['model'],
    ),
    limitations: const [],
    metadata: FinancialProblemMetadata(
      calculatedAt: DateTime.utc(2035, 6, 30),
      engineVersion: 'test',
      ruleId: 'rule',
    ),
  );
}

FinancialDeviation _deviation({required List<String> sourceFactIds}) {
  return FinancialDeviation(
    deviationId: 'deviation',
    deviationType: FinancialDeviationType.negativeNetCashFlow,
    status: FinancialDeviationStatus.calculated,
    severity: FinancialDeviationSeverity.high,
    actualValue: -100,
    expectedValue: const FinancialDeviationExpectedValue(
      thresholdValue: 0,
      unit: FinancialModelUnit.money,
      isUpperBound: false,
    ),
    deviationAmount: 100,
    unit: FinancialModelUnit.money,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    confidence: FinancialDeviationConfidence.high,
    evidence: FinancialDeviationEvidence(
      sourceModelIds: const ['model'],
      sourceModelEvidenceFactIds: sourceFactIds,
    ),
    limitations: const [],
    metadata: FinancialDeviationMetadata(
      calculatedAt: DateTime.utc(2035, 6, 30),
      engineVersion: 'test',
      thresholdId: 'threshold',
    ),
  );
}

FinancialFact _financialFact({required String id, required String categoryId}) {
  return FinancialFact(
    id: id,
    type: FinancialFactType.expenseOperation,
    source: FinancialFactSource.manualRecorded,
    confidence: FinancialFactConfidence.high,
    categoryId: categoryId,
  );
}
