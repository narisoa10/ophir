import 'financial_explanation.dart';
import 'financial_recommendation.dart';
import 'financial_recommendation_confidence.dart';
import 'financial_recommendation_priority.dart';

final class FinancialIntelligenceRuntimeRecommendationCandidate {
  FinancialIntelligenceRuntimeRecommendationCandidate({
    required this.adaptedRecommendation,
    required this.adaptedExplanation,
    required List<String> sourceIntelligenceOptionIds,
    required List<String> rejectedIntelligenceOptionIds,
    required this.isEligibleForRuntime,
    required List<String> blockReasons,
    required this.confidence,
    required this.priority,
    required this.isDiagnosticsOnlySource,
  }) : sourceIntelligenceOptionIds = List.unmodifiable(
         sourceIntelligenceOptionIds,
       ),
       rejectedIntelligenceOptionIds = List.unmodifiable(
         rejectedIntelligenceOptionIds,
       ),
       blockReasons = List.unmodifiable(blockReasons);

  final FinancialRecommendation? adaptedRecommendation;
  final FinancialExplanation? adaptedExplanation;
  final List<String> sourceIntelligenceOptionIds;
  final List<String> rejectedIntelligenceOptionIds;
  final bool isEligibleForRuntime;
  final List<String> blockReasons;
  final FinancialRecommendationConfidence confidence;
  final FinancialRecommendationPriority priority;
  final bool isDiagnosticsOnlySource;
}
