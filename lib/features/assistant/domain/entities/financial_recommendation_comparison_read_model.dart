import 'financial_decision_option_type.dart';
import 'financial_intelligence_recommendation_type.dart';
import 'financial_recommendation_comparison_flag.dart';
import 'financial_recommendation_conflict_level.dart';

final class FinancialRecommendationComparisonReadModel {
  FinancialRecommendationComparisonReadModel({
    required this.legacyRecommendationType,
    required List<FinancialIntelligenceRecommendationType>
    shadowRecommendationTypes,
    required this.hasShadowDiagnostics,
    required this.hasPositiveSignals,
    required this.hasContextWarnings,
    required this.hasCoverageWarnings,
    required this.conflictLevel,
    required List<FinancialRecommendationComparisonFlag> flags,
  }) : shadowRecommendationTypes = List.unmodifiable(
         shadowRecommendationTypes,
       ),
       flags = List.unmodifiable(flags);

  final FinancialDecisionOptionType? legacyRecommendationType;
  final List<FinancialIntelligenceRecommendationType> shadowRecommendationTypes;
  final bool hasShadowDiagnostics;
  final bool hasPositiveSignals;
  final bool hasContextWarnings;
  final bool hasCoverageWarnings;
  final FinancialRecommendationConflictLevel conflictLevel;
  final List<FinancialRecommendationComparisonFlag> flags;
}
