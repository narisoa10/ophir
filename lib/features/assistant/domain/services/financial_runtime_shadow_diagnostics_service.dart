import '../entities/financial_intelligence_runtime_recommendation_candidate.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_runtime_recommendation_mode.dart';
import '../entities/financial_runtime_recommendation_selection.dart';
import '../entities/financial_runtime_recommendation_source.dart';
import '../entities/financial_runtime_shadow_diagnostics_snapshot.dart';

final class FinancialRuntimeShadowDiagnosticsService {
  const FinancialRuntimeShadowDiagnosticsService();

  FinancialRuntimeShadowDiagnosticsSnapshot build({
    required FinancialRecommendation? legacyRecommendation,
    required FinancialRuntimeRecommendationSelection runtimeSelection,
    required FinancialIntelligenceRuntimeRecommendationCandidate? candidate,
    required FinancialRuntimeRecommendationMode runtimeMode,
    required DateTime generatedAt,
  }) {
    return FinancialRuntimeShadowDiagnosticsSnapshot(
      legacyRecommendationId: legacyRecommendation?.recommendationId,
      intelligenceRecommendationId:
          candidate?.adaptedRecommendation?.recommendationId,
      runtimeMode: runtimeMode,
      selectedSource: runtimeSelection.source,
      adapterCandidateAvailable: candidate != null,
      adapterEligible: candidate?.isEligibleForRuntime ?? false,
      adapterUsed:
          runtimeSelection.source ==
          FinancialRuntimeRecommendationSource.intelligenceAllowlist,
      fallbackUsed:
          runtimeSelection.source ==
              FinancialRuntimeRecommendationSource.legacy &&
          candidate != null,
      fallbackReasons: candidate?.blockReasons ?? const [],
      generatedAt: generatedAt,
    );
  }
}
