import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_runtime_recommendation_candidate.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_source.dart';
import 'package:ophir/features/assistant/domain/services/financial_runtime_shadow_diagnostics_service.dart';

import '../../helpers/financial_recommendation_test_helpers.dart';

void main() {
  const service = FinancialRuntimeShadowDiagnosticsService();
  final generatedAt = DateTime.utc(2035, 6);

  group('FinancialRuntimeShadowDiagnosticsService', () {
    test('builds legacy selection diagnostics without candidate', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final snapshot = service.build(
        legacyRecommendation: legacy,
        runtimeSelection: _selection(
          mode: FinancialRuntimeRecommendationMode.legacy,
          source: FinancialRuntimeRecommendationSource.legacy,
          recommendation: legacy,
        ),
        candidate: null,
        runtimeMode: FinancialRuntimeRecommendationMode.legacy,
        generatedAt: generatedAt,
      );

      expect(snapshot.legacyRecommendationId, legacy.recommendationId);
      expect(snapshot.intelligenceRecommendationId, isNull);
      expect(snapshot.runtimeMode, FinancialRuntimeRecommendationMode.legacy);
      expect(
        snapshot.selectedSource,
        FinancialRuntimeRecommendationSource.legacy,
      );
      expect(snapshot.adapterCandidateAvailable, isFalse);
      expect(snapshot.adapterEligible, isFalse);
      expect(snapshot.adapterUsed, isFalse);
      expect(snapshot.fallbackUsed, isFalse);
      expect(snapshot.fallbackReasons, isEmpty);
      expect(snapshot.generatedAt, generatedAt);
    });

    test(
      'builds intelligenceAllowlist diagnostics with eligible candidate',
      () {
        final legacy = buildTestFinancialRecommendation(
          FinancialDecisionOptionType.reviewExpenseStructure,
        );
        final adapted = buildTestFinancialRecommendation(
          FinancialDecisionOptionType.reviewExpenseStructure,
        );
        final candidate = _eligibleCandidate(adapted);

        final snapshot = service.build(
          legacyRecommendation: legacy,
          runtimeSelection: _selection(
            mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
            source: FinancialRuntimeRecommendationSource.intelligenceAllowlist,
            recommendation: adapted,
          ),
          candidate: candidate,
          runtimeMode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          generatedAt: generatedAt,
        );

        expect(snapshot.legacyRecommendationId, legacy.recommendationId);
        expect(snapshot.intelligenceRecommendationId, adapted.recommendationId);
        expect(
          snapshot.runtimeMode,
          FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        );
        expect(
          snapshot.selectedSource,
          FinancialRuntimeRecommendationSource.intelligenceAllowlist,
        );
        expect(snapshot.adapterCandidateAvailable, isTrue);
        expect(snapshot.adapterEligible, isTrue);
        expect(snapshot.adapterUsed, isTrue);
        expect(snapshot.fallbackUsed, isFalse);
        expect(snapshot.fallbackReasons, isEmpty);
        expect(snapshot.generatedAt, generatedAt);
      },
    );

    test('builds legacy selection diagnostics with blocked candidate', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.improveCategorization,
      );
      final candidate = _blockedCandidate(legacy);

      final snapshot = service.build(
        legacyRecommendation: legacy,
        runtimeSelection: _selection(
          mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          source: FinancialRuntimeRecommendationSource.legacy,
          recommendation: legacy,
        ),
        candidate: candidate,
        runtimeMode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        generatedAt: generatedAt,
      );

      expect(snapshot.legacyRecommendationId, legacy.recommendationId);
      expect(snapshot.intelligenceRecommendationId, isNull);
      expect(
        snapshot.runtimeMode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
      expect(
        snapshot.selectedSource,
        FinancialRuntimeRecommendationSource.legacy,
      );
      expect(snapshot.adapterCandidateAvailable, isTrue);
      expect(snapshot.adapterEligible, isFalse);
      expect(snapshot.adapterUsed, isFalse);
      expect(snapshot.fallbackUsed, isTrue);
      expect(snapshot.fallbackReasons, ['comparisonNotAligned']);
      expect(snapshot.generatedAt, generatedAt);
    });
  });
}

FinancialRuntimeRecommendationSelection _selection({
  required FinancialRuntimeRecommendationMode mode,
  required FinancialRuntimeRecommendationSource source,
  required FinancialRecommendation recommendation,
}) {
  return FinancialRuntimeRecommendationSelection(
    mode: mode,
    source: source,
    recommendation: recommendation,
    comparison: null,
    explanation: buildTestFinancialExplanation(recommendation),
  );
}

FinancialIntelligenceRuntimeRecommendationCandidate _eligibleCandidate(
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
