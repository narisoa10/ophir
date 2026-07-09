import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_decision_options_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_model_parity_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_problems_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialIntelligenceDecisionOptionsProvider', () {
    test('builds decision options from allowed diagnostics inputs', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDecisionOptionsProvider.future,
      );
      final snapshot = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected intelligence decision options snapshot'),
      };

      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        ),
        isTrue,
      );
      expect(
        snapshot
            .optionsFor(
              FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
            )
            .single
            .parityMetric,
        FinancialIntelligenceModelParityMetric.reducibleSpending,
      );
    });

    test('provider reads only allowed providers', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_decision_options_provider.dart',
      ).readAsStringSync();

      expect(source, contains('financialIntelligenceProblemsProvider'));
      expect(source, contains('financialIntelligenceModelParityProvider'));
      expect(
        source,
        isNot(contains('financialIntelligenceDiagnosticsProvider')),
      );
      expect(
        source,
        isNot(contains('legacyAssistantDashboardBriefingProvider')),
      );
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(
        source,
        isNot(contains('financialRecommendationComparisonProvider')),
      );
      expect(
        source,
        isNot(contains('financialRuntimeRecommendationSelectionProvider')),
      );
      expect(source, isNot(contains('FinancialDecisionOptionsService')));
      expect(source, isNot(contains('FinancialRecommendationService')));
      expect(source, isNot(contains('FinancialExplanationService')));
    });

    test('resolves without provider cycle', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDecisionOptionsProvider.future,
      );

      expect(result, isA<Success>());
    });

    test('does not change runtime recommendation output', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
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
          financialIntelligenceProblemsProvider.overrideWith(
            (ref) async => Success(_problemsSnapshot()),
          ),
          financialIntelligenceModelParityProvider.overrideWith(
            (ref) async => Success(_paritySnapshot()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final beforeResult = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      await container.read(financialIntelligenceDecisionOptionsProvider.future);
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

    test('Dashboard and UI do not import decision option diagnostics', () {
      for (final file in _uiFiles()) {
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(contains('financialIntelligenceDecisionOptionsProvider')),
          reason: file.path,
        );
        expect(
          source,
          isNot(contains('FinancialIntelligenceDecisionOption')),
          reason: file.path,
        );
      }
    });
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      financialIntelligenceProblemsProvider.overrideWith(
        (ref) async => Success(_problemsSnapshot()),
      ),
      financialIntelligenceModelParityProvider.overrideWith(
        (ref) async => Success(_paritySnapshot()),
      ),
    ],
  );
}

FinancialIntelligenceProblemsSnapshot _problemsSnapshot() {
  return FinancialIntelligenceProblemsSnapshot(
    problems: [
      _problem(FinancialIntelligenceProblemType.reducibleSpendingPressure),
    ],
  );
}

FinancialIntelligenceProblem _problem(FinancialIntelligenceProblemType type) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceProblem(
    problemId: 'financial.intelligence.problem.${type.name}',
    type: type,
    period: period,
    severity: FinancialProblemSeverity.medium,
    impact: FinancialProblemImpact.spendingFlexibility,
    sourceDeviationIds: const ['source-deviation'],
    sourceDeviationTypes: const [],
    isPositiveSignal: false,
    isWarning: true,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceModelParitySnapshot _paritySnapshot() {
  final metricResults = [
    _parityResult(
      FinancialIntelligenceModelParityMetric.reducibleSpending,
      FinancialIntelligenceModelParityStatus.equivalent,
      legacyValue: 300,
      intelligenceValue: 300,
    ),
  ];

  return FinancialIntelligenceModelParitySnapshot(
    legacyModelValues: {
      for (final result in metricResults) result.metric: result.legacyValue,
    },
    intelligenceModelValues: {
      for (final result in metricResults)
        result.metric: result.intelligenceValue,
    },
    metricResults: metricResults,
    matchedMetrics: metricResults,
    missingMetrics: const [],
    intentionallyDivergentMetrics: const [],
  );
}

FinancialIntelligenceModelParityMetricResult _parityResult(
  FinancialIntelligenceModelParityMetric metric,
  FinancialIntelligenceModelParityStatus status, {
  required double? legacyValue,
  required double? intelligenceValue,
}) {
  return FinancialIntelligenceModelParityMetricResult(
    metric: metric,
    status: status,
    legacyValue: legacyValue,
    intelligenceValue: intelligenceValue,
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
