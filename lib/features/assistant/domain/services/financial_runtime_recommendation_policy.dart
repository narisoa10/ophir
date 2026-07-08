import '../entities/financial_decision_option_type.dart';
import '../entities/financial_intelligence_recommendation_type.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_comparison_flag.dart';
import '../entities/financial_recommendation_comparison_read_model.dart';
import '../entities/financial_recommendation_conflict_level.dart';
import '../entities/financial_runtime_recommendation_mode.dart';
import '../entities/financial_runtime_recommendation_selection.dart';
import '../entities/financial_runtime_recommendation_source.dart';

final class FinancialRuntimeRecommendationPolicy {
  const FinancialRuntimeRecommendationPolicy();

  static const _allowlistedLegacyTypes = {
    FinancialDecisionOptionType.reduceDiscretionarySpending,
    FinancialDecisionOptionType.deferOptionalSpending,
    FinancialDecisionOptionType.reviewExpenseStructure,
    FinancialDecisionOptionType.improveCategorization,
    FinancialDecisionOptionType.collectMoreData,
  };

  static const _allowlistedShadowTypes = {
    FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
    FinancialIntelligenceRecommendationType.reduceReducibleSpending,
    FinancialIntelligenceRecommendationType.deferOrReduceDiscretionarySpending,
    FinancialIntelligenceRecommendationType.improveCategoryCoverage,
  };

  FinancialRuntimeRecommendationSelection select({
    required FinancialRuntimeRecommendationMode mode,
    required FinancialRecommendation? legacyRecommendation,
    required FinancialRecommendationComparisonReadModel? comparison,
  }) {
    if (mode != FinancialRuntimeRecommendationMode.intelligenceAllowlist) {
      return _legacy(mode: mode, recommendation: legacyRecommendation);
    }

    if (!_canUseIntelligenceRuntime(
      legacyRecommendation: legacyRecommendation,
      comparison: comparison,
    )) {
      return _legacy(mode: mode, recommendation: legacyRecommendation);
    }

    return FinancialRuntimeRecommendationSelection(
      mode: mode,
      source: FinancialRuntimeRecommendationSource.intelligenceAllowlist,
      recommendation: legacyRecommendation,
      comparison: comparison,
    );
  }

  bool _canUseIntelligenceRuntime({
    required FinancialRecommendation? legacyRecommendation,
    required FinancialRecommendationComparisonReadModel? comparison,
  }) {
    if (legacyRecommendation == null || comparison == null) {
      return false;
    }
    if (comparison.conflictLevel !=
        FinancialRecommendationConflictLevel.aligned) {
      return false;
    }
    if (comparison.hasPositiveSignals ||
        comparison.hasContextWarnings ||
        comparison.hasCoverageWarnings) {
      return false;
    }
    if (comparison.flags.any(_isBlockingFlag)) {
      return false;
    }

    final legacyType = comparison.legacyRecommendationType;
    if (legacyType == null ||
        legacyType != legacyRecommendation.selectedOptionType ||
        !_allowlistedLegacyTypes.contains(legacyType)) {
      return false;
    }

    final shadowTypes = comparison.shadowRecommendationTypes;
    if (shadowTypes.isEmpty) {
      return false;
    }
    return shadowTypes.every(_allowlistedShadowTypes.contains);
  }

  bool _isBlockingFlag(FinancialRecommendationComparisonFlag flag) {
    return switch (flag) {
      FinancialRecommendationComparisonFlag.positiveSignalPresent ||
      FinancialRecommendationComparisonFlag.contextWarningPresent ||
      FinancialRecommendationComparisonFlag.coverageWarningPresent => true,
      _ => false,
    };
  }

  FinancialRuntimeRecommendationSelection _legacy({
    required FinancialRuntimeRecommendationMode mode,
    required FinancialRecommendation? recommendation,
  }) {
    return FinancialRuntimeRecommendationSelection(
      mode: mode,
      source: FinancialRuntimeRecommendationSource.legacy,
      recommendation: recommendation,
      comparison: null,
    );
  }
}
