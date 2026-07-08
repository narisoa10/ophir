import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/current_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/controller/financial_recommendation_comparison_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_source.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialRuntimeRecommendationSelectionProvider', () {
    test('legacy mode uses legacy without reading comparison', () async {
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
          financialRecommendationComparisonProvider.overrideWith((ref) async {
            throw StateError('comparison should not be read in legacy mode');
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      final selection = _selectionValue(result);

      expect(selection.mode, FinancialRuntimeRecommendationMode.legacy);
      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });

    test('selection provider uses config provider override', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
      final container = ProviderContainer(
        overrides: [
          financialRuntimeRecommendationConfigProvider.overrideWithValue(
            const FinancialRuntimeRecommendationConfig(
              mode: FinancialRuntimeRecommendationMode.shadowOnly,
            ),
          ),
          legacyAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(legacy),
          ),
          financialRecommendationComparisonProvider.overrideWith((ref) async {
            throw StateError(
              'comparison should not be read in shadowOnly mode',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      final selection = _selectionValue(result);

      expect(selection.mode, FinancialRuntimeRecommendationMode.shadowOnly);
      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });

    test('intelligenceAllowlist uses aligned allowlist comparison', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final comparison = buildTestRecommendationComparison(
        legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
        shadowTypes: const [
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ],
        conflictLevel: FinancialRecommendationConflictLevel.aligned,
      );
      final container = ProviderContainer(
        overrides: [
          financialRuntimeRecommendationConfigProvider.overrideWithValue(
            const FinancialRuntimeRecommendationConfig(
              mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
            ),
          ),
          legacyAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(legacy),
          ),
          financialRecommendationComparisonProvider.overrideWith(
            (ref) async => Success(comparison),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      final selection = _selectionValue(result);

      expect(
        selection.mode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
      expect(
        selection.source,
        FinancialRuntimeRecommendationSource.intelligenceAllowlist,
      );
      expect(selection.recommendation, same(legacy));
    });

    test(
      'current recommendation provider exposes selected recommendation',
      () async {
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
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          currentAssistantRecommendationProvider.future,
        );
        final recommendation = _recommendationValue(result);

        expect(recommendation, same(legacy));
      },
    );

    test(
      'runtime recommendation providers resolve without provider cycle',
      () async {
        final legacy = buildTestFinancialRecommendation(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
        );
        final comparison = buildTestRecommendationComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.aligned,
        );
        final container = ProviderContainer(
          overrides: [
            financialRuntimeRecommendationConfigProvider.overrideWithValue(
              const FinancialRuntimeRecommendationConfig(
                mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
              ),
            ),
            legacyAssistantRecommendationProvider.overrideWith(
              (ref) async => Success(legacy),
            ),
            financialRecommendationComparisonProvider.overrideWith(
              (ref) async => Success(comparison),
            ),
          ],
        );
        addTearDown(container.dispose);

        final selectionResult = await container.read(
          financialRuntimeRecommendationSelectionProvider.future,
        );
        final recommendationResult = await container.read(
          currentAssistantRecommendationProvider.future,
        );

        expect(_selectionValue(selectionResult).recommendation, same(legacy));
        expect(_recommendationValue(recommendationResult), same(legacy));
      },
    );
  });
}

FinancialRuntimeRecommendationSelection _selectionValue(
  Result<FinancialRuntimeRecommendationSelection> result,
) {
  return switch (result) {
    Success(:final value) => value,
    Failure() => fail('Expected runtime recommendation selection'),
  };
}

FinancialRecommendation? _recommendationValue(
  Result<FinancialRecommendation?> result,
) {
  return switch (result) {
    Success(:final value) => value,
    Failure() => fail('Expected current recommendation'),
  };
}
