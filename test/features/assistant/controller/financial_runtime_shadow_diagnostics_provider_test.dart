import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_runtime_recommendation_candidate_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_shadow_diagnostics_provider.dart';
import 'package:ophir/features/assistant/controller/legacy_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_runtime_recommendation_candidate.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_shadow_diagnostics_snapshot.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialRuntimeShadowDiagnosticsProvider', () {
    test('builds snapshot with legacy fallback', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final container = _container(
        mode: FinancialRuntimeRecommendationMode.legacy,
        legacyRecommendation: legacy,
        runtimeSelection: _selection(
          mode: FinancialRuntimeRecommendationMode.legacy,
          source: FinancialRuntimeRecommendationSource.legacy,
          recommendation: legacy,
        ),
        candidateResult: const Failure(UnknownFailure()),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialRuntimeShadowDiagnosticsProvider.future,
      );
      final snapshot = _snapshotValue(result);

      expect(snapshot.legacyRecommendationId, isNotNull);
      expect(snapshot.intelligenceRecommendationId, isNull);
      expect(snapshot.selectedSource, FinancialRuntimeRecommendationSource.legacy);
      expect(snapshot.adapterCandidateAvailable, isFalse);
      expect(snapshot.adapterEligible, isFalse);
      expect(snapshot.adapterUsed, isFalse);
      expect(snapshot.fallbackUsed, isFalse);
      expect(snapshot.fallbackReasons, isEmpty);
    });

    test('builds snapshot when intelligence adapter is used', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final adapted = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final candidate = _candidate(adapted);
      final container = _container(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        runtimeSelection: _selection(
          mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          source: FinancialRuntimeRecommendationSource.intelligenceAllowlist,
          recommendation: adapted,
        ),
        candidateResult: Success(candidate),
      );
      addTearDown(container.dispose);
      await container.read(
        financialIntelligenceRuntimeRecommendationCandidateProvider.future,
      );

      final result = await container.read(
        financialRuntimeShadowDiagnosticsProvider.future,
      );
      final snapshot = _snapshotValue(result);

      expect(snapshot.legacyRecommendationId, isNotNull);
      expect(
        snapshot.intelligenceRecommendationId,
        adapted.recommendationId,
      );
      expect(snapshot.adapterCandidateAvailable, isTrue);
      expect(snapshot.adapterEligible, isTrue);
      expect(snapshot.adapterUsed, isTrue);
      expect(snapshot.fallbackUsed, isFalse);
    });

    test('builds fallback diagnostics when candidate is blocked', () async {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final candidate = _blockedCandidate(legacy);
      final container = _container(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        runtimeSelection: _selection(
          mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          source: FinancialRuntimeRecommendationSource.legacy,
          recommendation: legacy,
        ),
        candidateResult: Success(candidate),
      );
      addTearDown(container.dispose);
      await container.read(
        financialIntelligenceRuntimeRecommendationCandidateProvider.future,
      );

      final result = await container.read(
        financialRuntimeShadowDiagnosticsProvider.future,
      );
      final snapshot = _snapshotValue(result);

      expect(snapshot.adapterCandidateAvailable, isTrue);
      expect(snapshot.adapterEligible, isFalse);
      expect(snapshot.adapterUsed, isFalse);
      expect(snapshot.fallbackUsed, isTrue);
      expect(snapshot.fallbackReasons, contains('comparisonNotAligned'));
    });
  });
}

ProviderContainer _container({
  required FinancialRuntimeRecommendationMode mode,
  required FinancialRecommendation? legacyRecommendation,
  required FinancialRuntimeRecommendationSelection runtimeSelection,
  required Result<FinancialIntelligenceRuntimeRecommendationCandidate>
  candidateResult,
}) {
  return ProviderContainer(
    overrides: [
      financialRuntimeRecommendationConfigProvider.overrideWithValue(
        FinancialRuntimeRecommendationConfig(mode: mode),
      ),
      legacyAssistantRecommendationProvider.overrideWith(
        (ref) async => Success(legacyRecommendation),
      ),
      financialRuntimeRecommendationSelectionProvider.overrideWith(
        (ref) async => Success(runtimeSelection),
      ),
      financialIntelligenceRuntimeRecommendationCandidateProvider.overrideWith(
        (ref) async => candidateResult,
      ),
    ],
  );
}

FinancialRuntimeRecommendationSelection _selection({
  required FinancialRuntimeRecommendationMode mode,
  required FinancialRuntimeRecommendationSource source,
  required FinancialRecommendation? recommendation,
}) {
  return FinancialRuntimeRecommendationSelection(
    mode: mode,
    source: source,
    recommendation: recommendation,
    comparison: null,
    explanation: recommendation == null
        ? null
        : buildTestFinancialExplanation(recommendation),
  );
}

FinancialIntelligenceRuntimeRecommendationCandidate _candidate(
  FinancialRecommendation recommendation,
) {
  return FinancialIntelligenceRuntimeRecommendationCandidate(
    adaptedRecommendation: recommendation,
    adaptedExplanation: buildTestFinancialExplanation(recommendation),
    sourceIntelligenceOptionIds: const ['intelligence.option'],
    rejectedIntelligenceOptionIds: const [],
    isEligibleForRuntime: true,
    blockReasons: const [],
    confidence: recommendation.confidence,
    priority: recommendation.priority,
    isDiagnosticsOnlySource: true,
  );
}

FinancialIntelligenceRuntimeRecommendationCandidate _blockedCandidate(
  FinancialRecommendation recommendation,
) {
  return FinancialIntelligenceRuntimeRecommendationCandidate(
    adaptedRecommendation: null,
    adaptedExplanation: null,
    sourceIntelligenceOptionIds: const ['intelligence.option'],
    rejectedIntelligenceOptionIds: const [],
    isEligibleForRuntime: false,
    blockReasons: const ['comparisonNotAligned'],
    confidence: recommendation.confidence,
    priority: recommendation.priority,
    isDiagnosticsOnlySource: true,
  );
}

FinancialRuntimeShadowDiagnosticsSnapshot _snapshotValue(
  Result<FinancialRuntimeShadowDiagnosticsSnapshot> result,
) {
  return switch (result) {
    Success(:final value) => value,
    Failure() => fail('Expected runtime shadow diagnostics snapshot'),
  };
}
