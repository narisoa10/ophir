import 'financial_runtime_recommendation_mode.dart';
import 'financial_runtime_recommendation_source.dart';

final class FinancialRuntimeShadowDiagnosticsSnapshot {
  FinancialRuntimeShadowDiagnosticsSnapshot({
    required this.legacyRecommendationId,
    required this.intelligenceRecommendationId,
    required this.runtimeMode,
    required this.selectedSource,
    required this.adapterCandidateAvailable,
    required this.adapterEligible,
    required this.adapterUsed,
    required this.fallbackUsed,
    required List<String> fallbackReasons,
    required this.generatedAt,
  }) : fallbackReasons = List.unmodifiable(fallbackReasons);

  final String? legacyRecommendationId;
  final String? intelligenceRecommendationId;
  final FinancialRuntimeRecommendationMode runtimeMode;
  final FinancialRuntimeRecommendationSource selectedSource;
  final bool adapterCandidateAvailable;
  final bool adapterEligible;
  final bool adapterUsed;
  final bool fallbackUsed;
  final List<String> fallbackReasons;
  final DateTime generatedAt;
}
