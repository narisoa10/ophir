import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_model_parity_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_problems_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_explanation_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialIntelligenceRecommendationExplanationProvider', () {
    test('builds explanation from allowed diagnostics inputs', () async {
      final problem = _problem(
        FinancialIntelligenceProblemType.reducibleSpendingPressure,
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        problem: problem,
        parityMetric: FinancialIntelligenceModelParityMetric.reducibleSpending,
      );
      final container = _container(option: option, problems: [problem]);
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRecommendationExplanationProvider.future,
      );
      final snapshot = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected recommendation explanation snapshot'),
      };

      expect(snapshot.explanation.selectedRecommendation, same(option));
      expect(snapshot.explanation.supportingProblems, [problem]);
      expect(
        snapshot.explanation.supportingParityMetrics.single.metric,
        FinancialIntelligenceModelParityMetric.reducibleSpending,
      );
      expect(snapshot.explanation.isDiagnosticsOnly, isTrue);
    });

    test('provider reads only allowed providers', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_recommendation_explanation_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('financialIntelligenceRecommendationSelectionProvider'),
      );
      expect(source, contains('financialIntelligenceProblemsProvider'));
      expect(source, contains('financialIntelligenceModelParityProvider'));
      expect(
        source,
        isNot(contains('financialIntelligenceDecisionOptionsProvider')),
      );
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(source, isNot(contains('AssistantDashboardBriefing')));
      expect(source, isNot(contains('currentAssistantRecommendationProvider')));
      expect(source, isNot(contains('FinancialExplanationService')));
      expect(source, isNot(contains('FinancialRecommendationService')));
      expect(source, isNot(contains('FinancialDecisionOptionsService')));
    });

    test('resolves without provider cycle', () async {
      final problem = _problem(
        FinancialIntelligenceProblemType.transactionContextRequired,
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        problem: problem,
      );
      final container = _container(option: option, problems: [problem]);
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRecommendationExplanationProvider.future,
      );

      expect(result, isA<Success>());
    });

    test('does not change runtime recommendation output', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final problem = _problem(
        FinancialIntelligenceProblemType.transactionContextRequired,
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        problem: problem,
      );
      final container = ProviderContainer(
        overrides: [
          financialRuntimeRecommendationConfigProvider.overrideWithValue(
            const FinancialRuntimeRecommendationConfig(
              mode: FinancialRuntimeRecommendationMode.legacy,
            ),
          ),
          legacyAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(legacy),
          ),
          ..._explanationOverrides(option: option, problems: [problem]),
        ],
      );
      addTearDown(container.dispose);

      final beforeResult = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      await container.read(
        financialIntelligenceRecommendationExplanationProvider.future,
      );
      final afterResult = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      final before = switch (beforeResult) {
        Success(:final value) => value,
        Failure() => fail('Expected runtime recommendation selection'),
      };
      final after = switch (afterResult) {
        Success(:final value) => value,
        Failure() => fail('Expected runtime recommendation selection'),
      };

      expect(after.recommendation, same(before.recommendation));
      expect(after.source, before.source);
      expect(after.mode, before.mode);
    });

    test('Dashboard and UI do not import explanation diagnostics', () {
      for (final file in _uiFiles()) {
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(
            contains('financialIntelligenceRecommendationExplanationProvider'),
          ),
          reason: file.path,
        );
        expect(
          source,
          isNot(contains('FinancialIntelligenceRecommendationExplanation')),
          reason: file.path,
        );
      }
    });
  });
}

ProviderContainer _container({
  required FinancialIntelligenceDecisionOption option,
  required List<FinancialIntelligenceProblem> problems,
}) {
  return ProviderContainer(
    overrides: _explanationOverrides(option: option, problems: problems),
  );
}

List<Override> _explanationOverrides({
  required FinancialIntelligenceDecisionOption option,
  required List<FinancialIntelligenceProblem> problems,
}) {
  return [
    financialIntelligenceRecommendationSelectionProvider.overrideWith(
      (ref) async => Success(_selection(option)),
    ),
    financialIntelligenceProblemsProvider.overrideWith(
      (ref) async =>
          Success(FinancialIntelligenceProblemsSnapshot(problems: problems)),
    ),
    financialIntelligenceModelParityProvider.overrideWith(
      (ref) async => Success(_paritySnapshot()),
    ),
  ];
}

FinancialIntelligenceRecommendationSelectionSnapshot _selection(
  FinancialIntelligenceDecisionOption selected,
) {
  return FinancialIntelligenceRecommendationSelectionSnapshot(
    selection: FinancialIntelligenceRecommendationSelection(
      selectedOption: selected,
      rejectedOptions: const [],
      selectionReason:
          FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
      isDiagnosticsOnly: true,
    ),
  );
}

FinancialIntelligenceDecisionOption _option(
  FinancialIntelligenceDecisionOptionType type, {
  required FinancialIntelligenceProblem problem,
  FinancialIntelligenceModelParityMetric? parityMetric,
}) {
  final isPositiveSignal =
      type ==
          FinancialIntelligenceDecisionOptionType
              .maintainAssetBuildingMomentum ||
      type ==
          FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum;

  return FinancialIntelligenceDecisionOption(
    optionId: 'financial.intelligence.decisionOption.${type.name}',
    type: type,
    period: problem.period,
    sourceProblemIds: [problem.problemId],
    sourceProblemTypes: [problem.type],
    parityMetric: parityMetric,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceProblem _problem(FinancialIntelligenceProblemType type) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );
  final isPositiveSignal =
      type == FinancialIntelligenceProblemType.positiveAssetBuildingSignal ||
      type == FinancialIntelligenceProblemType.debtReductionSignal;

  return FinancialIntelligenceProblem(
    problemId: 'financial.intelligence.problem.${type.name}',
    type: type,
    period: period,
    severity: FinancialProblemSeverity.medium,
    impact: isPositiveSignal
        ? FinancialProblemImpact.savingsCapacity
        : FinancialProblemImpact.spendingFlexibility,
    sourceDeviationIds: const ['source-deviation'],
    sourceDeviationTypes: const [],
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceModelParitySnapshot _paritySnapshot() {
  final result = FinancialIntelligenceModelParityMetricResult(
    metric: FinancialIntelligenceModelParityMetric.reducibleSpending,
    status: FinancialIntelligenceModelParityStatus.equivalent,
    legacyValue: 300,
    intelligenceValue: 300,
  );

  return FinancialIntelligenceModelParitySnapshot(
    legacyModelValues: {result.metric: result.legacyValue},
    intelligenceModelValues: {result.metric: result.intelligenceValue},
    metricResults: [result],
    matchedMetrics: [result],
    missingMetrics: const [],
    intentionallyDivergentMetrics: const [],
  );
}

List<File> _uiFiles() {
  final files = <File>[];
  final dashboard = Directory('lib/features/dashboard');
  if (dashboard.existsSync()) {
    files.addAll(dashboard.listSync(recursive: true).whereType<File>());
  }
  final features = Directory('lib/features');
  if (features.existsSync()) {
    files.addAll(
      features
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path
                .split(Platform.pathSeparator)
                .contains('presentation'),
          ),
    );
  }
  return files.toSet().toList(growable: false);
}
