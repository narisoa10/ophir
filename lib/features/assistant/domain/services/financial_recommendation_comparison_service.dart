import '../entities/financial_decision_option_type.dart';
import '../entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import '../entities/financial_intelligence_recommendation_type.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_comparison_flag.dart';
import '../entities/financial_recommendation_comparison_read_model.dart';
import '../entities/financial_recommendation_conflict_level.dart';

final class FinancialRecommendationComparisonService {
  const FinancialRecommendationComparisonService();

  static const _directMatches =
      <FinancialDecisionOptionType, List<FinancialIntelligenceRecommendationType>>{
        FinancialDecisionOptionType.reduceDiscretionarySpending: [
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          FinancialIntelligenceRecommendationType
              .deferOrReduceDiscretionarySpending,
        ],
        FinancialDecisionOptionType.deferOptionalSpending: [
          FinancialIntelligenceRecommendationType
              .deferOrReduceDiscretionarySpending,
        ],
        FinancialDecisionOptionType.optimizeEssentialExpenses: [
          FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
        ],
        FinancialDecisionOptionType.reviewExpenseStructure: [
          FinancialIntelligenceRecommendationType
              .reviewOrdinarySpendingStructure,
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
        ],
        FinancialDecisionOptionType.improveCategorization: [
          FinancialIntelligenceRecommendationType.improveCategoryCoverage,
        ],
        FinancialDecisionOptionType.collectMoreData: [
          FinancialIntelligenceRecommendationType.improveCategoryCoverage,
        ],
      };

  static const _partialMatches =
      <FinancialDecisionOptionType, List<FinancialIntelligenceRecommendationType>>{
        FinancialDecisionOptionType.buildSavingsCapacity: [
          FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
        ],
        FinancialDecisionOptionType.confirmRecurringOperations: [
          FinancialIntelligenceRecommendationType.reviewTransactionContext,
        ],
        FinancialDecisionOptionType.reviewLargeExpense: [
          FinancialIntelligenceRecommendationType.reviewTransactionContext,
        ],
      };

  static const _notComparableTypes = <FinancialDecisionOptionType>{
    FinancialDecisionOptionType.increaseIncome,
    FinancialDecisionOptionType.useExistingReserves,
    FinancialDecisionOptionType.restructureObligations,
    FinancialDecisionOptionType.reviseFinancialStrategy,
    FinancialDecisionOptionType.adjustBudgetUnavailable,
    FinancialDecisionOptionType.doNothingAndMonitor,
  };

  FinancialRecommendationComparisonReadModel build({
    required FinancialRecommendation? legacyRecommendation,
    required FinancialIntelligenceRecommendationDiagnosticsSnapshot
    shadowDiagnostics,
  }) {
    final legacyType = legacyRecommendation?.selectedOptionType;
    final shadowTypes = shadowDiagnostics.recommendations
        .map((recommendation) => recommendation.type)
        .toList(growable: false);
    final hasShadowDiagnostics = shadowTypes.isNotEmpty;
    final hasPositiveSignals = shadowDiagnostics.recommendations.any(
      (recommendation) => recommendation.isPositiveSignal,
    );
    final hasContextWarnings = shadowDiagnostics.hasRecommendation(
      FinancialIntelligenceRecommendationType.reviewTransactionContext,
    );
    final hasCoverageWarnings = shadowDiagnostics.hasRecommendation(
      FinancialIntelligenceRecommendationType.improveCategoryCoverage,
    );
    final conflictLevel = _conflictLevelFor(
      legacyType: legacyType,
      shadowTypes: shadowTypes,
    );

    return FinancialRecommendationComparisonReadModel(
      legacyRecommendationType: legacyType,
      shadowRecommendationTypes: shadowTypes,
      hasShadowDiagnostics: hasShadowDiagnostics,
      hasPositiveSignals: hasPositiveSignals,
      hasContextWarnings: hasContextWarnings,
      hasCoverageWarnings: hasCoverageWarnings,
      conflictLevel: conflictLevel,
      flags: _flagsFor(
        legacyType: legacyType,
        hasShadowDiagnostics: hasShadowDiagnostics,
        hasPositiveSignals: hasPositiveSignals,
        hasContextWarnings: hasContextWarnings,
        hasCoverageWarnings: hasCoverageWarnings,
        conflictLevel: conflictLevel,
      ),
    );
  }

  FinancialRecommendationConflictLevel _conflictLevelFor({
    required FinancialDecisionOptionType? legacyType,
    required List<FinancialIntelligenceRecommendationType> shadowTypes,
  }) {
    if (legacyType == null && shadowTypes.isEmpty) {
      return FinancialRecommendationConflictLevel.none;
    }
    if (legacyType != null && shadowTypes.isEmpty) {
      return FinancialRecommendationConflictLevel.legacyOnly;
    }
    if (legacyType == null && shadowTypes.isNotEmpty) {
      return FinancialRecommendationConflictLevel.shadowOnly;
    }
    if (_notComparableTypes.contains(legacyType)) {
      return FinancialRecommendationConflictLevel.notComparable;
    }
    if (_hasAnyMatch(_directMatches[legacyType], shadowTypes)) {
      return FinancialRecommendationConflictLevel.aligned;
    }
    if (_hasAnyMatch(_partialMatches[legacyType], shadowTypes)) {
      return FinancialRecommendationConflictLevel.partialOverlap;
    }
    return FinancialRecommendationConflictLevel.divergent;
  }

  bool _hasAnyMatch(
    List<FinancialIntelligenceRecommendationType>? expected,
    List<FinancialIntelligenceRecommendationType> actual,
  ) {
    if (expected == null || expected.isEmpty) {
      return false;
    }
    return actual.any(expected.contains);
  }

  List<FinancialRecommendationComparisonFlag> _flagsFor({
    required FinancialDecisionOptionType? legacyType,
    required bool hasShadowDiagnostics,
    required bool hasPositiveSignals,
    required bool hasContextWarnings,
    required bool hasCoverageWarnings,
    required FinancialRecommendationConflictLevel conflictLevel,
  }) {
    return [
      if (legacyType != null)
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
      if (hasShadowDiagnostics)
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
      if (hasPositiveSignals)
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
      if (hasContextWarnings)
        FinancialRecommendationComparisonFlag.contextWarningPresent,
      if (hasCoverageWarnings)
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
      switch (conflictLevel) {
        FinancialRecommendationConflictLevel.aligned =>
          FinancialRecommendationComparisonFlag.directMatch,
        FinancialRecommendationConflictLevel.partialOverlap =>
          FinancialRecommendationComparisonFlag.partialMatch,
        FinancialRecommendationConflictLevel.divergent =>
          FinancialRecommendationComparisonFlag.divergentMatch,
        FinancialRecommendationConflictLevel.notComparable =>
          FinancialRecommendationComparisonFlag.notComparable,
        _ => null,
      },
    ].whereType<FinancialRecommendationComparisonFlag>().toList();
  }
}
