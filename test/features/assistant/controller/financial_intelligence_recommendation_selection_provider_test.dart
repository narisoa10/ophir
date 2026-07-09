import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_decision_options_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_options_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialIntelligenceRecommendationSelectionProvider', () {
    test(
      'builds selection from intelligence decision options provider',
      () async {
        final context = _option(
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        );
        final spending = _option(
          FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        );
        final container = _container(options: [spending, context]);
        addTearDown(container.dispose);

        final result = await container.read(
          financialIntelligenceRecommendationSelectionProvider.future,
        );
        final snapshot = switch (result) {
          Success(:final value) => value,
          Failure() => fail('Expected intelligence recommendation selection'),
        };

        expect(snapshot.selectedOption, same(context));
        expect(snapshot.rejectedOptions, [spending]);
        expect(snapshot.isDiagnosticsOnly, isTrue);
      },
    );

    test(
      'provider reads only financialIntelligenceDecisionOptionsProvider',
      () {
        final source = File(
          'lib/features/assistant/controller/'
          'financial_intelligence_recommendation_selection_provider.dart',
        ).readAsStringSync();

        expect(
          source,
          contains('financialIntelligenceDecisionOptionsProvider'),
        );
        expect(
          source,
          isNot(contains('financialIntelligenceProblemsProvider')),
        );
        expect(
          source,
          isNot(contains('financialIntelligenceModelParityProvider')),
        );
        expect(
          source,
          isNot(contains('financialIntelligenceDiagnosticsProvider')),
        );
        expect(source, isNot(contains('assistantDashboardBriefingProvider')));
        expect(
          source,
          isNot(contains('currentAssistantRecommendationProvider')),
        );
        expect(source, isNot(contains('FinancialRecommendationService')));
        expect(source, isNot(contains('FinancialRecommendation')));
      },
    );

    test('resolves without provider cycle', () async {
      final container = _container(
        options: [
          _option(
            FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRecommendationSelectionProvider.future,
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
          financialIntelligenceDecisionOptionsProvider.overrideWith(
            (ref) async => Success(
              FinancialIntelligenceDecisionOptionsSnapshot(
                options: [
                  _option(
                    FinancialIntelligenceDecisionOptionType
                        .reviewTransactionContext,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final beforeResult = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      await container.read(
        financialIntelligenceRecommendationSelectionProvider.future,
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

    test(
      'Dashboard and UI do not import recommendation selection diagnostics',
      () {
        for (final file in _uiFiles()) {
          final source = file.readAsStringSync();

          expect(
            source,
            isNot(
              contains('financialIntelligenceRecommendationSelectionProvider'),
            ),
            reason: file.path,
          );
          expect(
            source,
            isNot(contains('FinancialIntelligenceRecommendationSelection')),
            reason: file.path,
          );
        }
      },
    );
  });
}

ProviderContainer _container({
  required List<FinancialIntelligenceDecisionOption> options,
}) {
  return ProviderContainer(
    overrides: [
      financialIntelligenceDecisionOptionsProvider.overrideWith(
        (ref) async => Success(
          FinancialIntelligenceDecisionOptionsSnapshot(options: options),
        ),
      ),
    ],
  );
}

FinancialIntelligenceDecisionOption _option(
  FinancialIntelligenceDecisionOptionType type,
) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );
  final isPositiveSignal =
      type ==
          FinancialIntelligenceDecisionOptionType
              .maintainAssetBuildingMomentum ||
      type ==
          FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum;

  return FinancialIntelligenceDecisionOption(
    optionId: 'financial.intelligence.decisionOption.${type.name}',
    type: type,
    period: period,
    sourceProblemIds: ['problem.${type.name}'],
    sourceProblemTypes: const [
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    ],
    parityMetric: null,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
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
