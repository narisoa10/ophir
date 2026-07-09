import '../entities/financial_decision_option_type.dart';
import '../entities/financial_intelligence_recommendation_type.dart';
import '../entities/financial_intelligence_runtime_recommendation_candidate.dart';
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
    FinancialIntelligenceRuntimeRecommendationCandidate? candidate,
  }) {
    if (mode != FinancialRuntimeRecommendationMode.intelligenceAllowlist) {
      return _legacy(mode: mode, recommendation: legacyRecommendation);
    }

    if (!_canUseIntelligenceRuntime(
      legacyRecommendation: legacyRecommendation,
      comparison: comparison,
      candidate: candidate,
    )) {
      return _legacy(mode: mode, recommendation: legacyRecommendation);
    }

    final adaptedRecommendation = candidate!.adaptedRecommendation;

    return FinancialRuntimeRecommendationSelection(
      mode: mode,
      source: FinancialRuntimeRecommendationSource.intelligenceAllowlist,
      recommendation: adaptedRecommendation,
      comparison: comparison,
      explanation: candidate.adaptedExplanation,
    );
  }

  bool _canUseIntelligenceRuntime({
    required FinancialRecommendation? legacyRecommendation,
    required FinancialRecommendationComparisonReadModel? comparison,
    required FinancialIntelligenceRuntimeRecommendationCandidate? candidate,
  }) {
    final adaptedRecommendation = candidate?.adaptedRecommendation;
    final adaptedExplanation = candidate?.adaptedExplanation;
    if (legacyRecommendation == null ||
        comparison == null ||
        candidate == null ||
        !candidate.isEligibleForRuntime ||
        adaptedRecommendation == null ||
        adaptedExplanation == null) {
      return false;
    }
    if (comparison.conflictLevel !=
        FinancialRecommendationConflictLevel.aligned) {
      return false;
    }
    final allowsCoverageWarning = _allowsCoverageWarning(
      comparison: comparison,
      adaptedRecommendation: adaptedRecommendation,
    );
    if (comparison.hasPositiveSignals || comparison.hasContextWarnings) {
      return false;
    }
    if (comparison.hasCoverageWarnings && !allowsCoverageWarning) {
      return false;
    }
    if (comparison.flags.any(
      (flag) =>
          _isBlockingFlag(flag, allowsCoverageWarning: allowsCoverageWarning),
    )) {
      return false;
    }

    final legacyType = comparison.legacyRecommendationType;
    if (legacyType == null ||
        legacyType != legacyRecommendation.selectedOptionType ||
        legacyType != adaptedRecommendation.selectedOptionType ||
        !_allowlistedLegacyTypes.contains(legacyType)) {
      return false;
    }

    final shadowTypes = comparison.shadowRecommendationTypes;
    if (shadowTypes.isEmpty) {
      return false;
    }
    return shadowTypes.every(_allowlistedShadowTypes.contains);
  }

  bool _allowsCoverageWarning({
    required FinancialRecommendationComparisonReadModel comparison,
    required FinancialRecommendation adaptedRecommendation,
  }) {
    return adaptedRecommendation.selectedOptionType ==
            FinancialDecisionOptionType.improveCategorization &&
        comparison.shadowRecommendationTypes.length == 1 &&
        comparison.shadowRecommendationTypes.single ==
            FinancialIntelligenceRecommendationType.improveCategoryCoverage;
  }

  bool _isBlockingFlag(
    FinancialRecommendationComparisonFlag flag, {
    required bool allowsCoverageWarning,
  }) {
    return switch (flag) {
      FinancialRecommendationComparisonFlag.positiveSignalPresent ||
      FinancialRecommendationComparisonFlag.contextWarningPresent => true,
      FinancialRecommendationComparisonFlag.coverageWarningPresent =>
        !allowsCoverageWarning,
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
