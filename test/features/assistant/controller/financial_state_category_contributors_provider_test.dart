import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_behavior_compatibility_output_provider.dart';
import 'package:ophir/features/assistant/controller/financial_state_category_contributors_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_dashboard_briefing_provider.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_briefing.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_radar.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/assistant/domain/entities/financial_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';

void main() {
  group('financialStateCategoryContributorsProvider', () {
    test(
      'returns snapshot when briefing and compatibility output succeed',
      () async {
        final briefing = _briefing(
          financialState: _state(FinancialStateType.deficit),
        );
        final output = _output();
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

  return AssistantDashboardBriefing(
    factsSnapshot: const FinancialFactsSnapshot(facts: [], dataGaps: []),
    modelResults: const [],
    deviations: const [],
    problems: const [],
    decisionOptions: const [],
    recommendation: null,
    explanation: null,
    radar: const AssistantDashboardRadar(
      axes: [],
      isLowConfidence: false,
      evidenceModelIds: [],
    ),
    primaryProblem: null,
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

FinancialBehaviorCompatibilityOutput _output() {
  return FinancialBehaviorCompatibilityOutput(
    snapshot: FinancialBehaviorFactsSnapshot(facts: []),
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
