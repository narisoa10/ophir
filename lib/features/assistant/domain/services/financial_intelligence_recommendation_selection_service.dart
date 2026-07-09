import '../entities/financial_intelligence_decision_option.dart';
import '../entities/financial_intelligence_decision_option_type.dart';
import '../entities/financial_intelligence_decision_options_snapshot.dart';
import '../entities/financial_intelligence_recommendation_selection.dart';
import '../entities/financial_intelligence_recommendation_selection_reason.dart';
import '../entities/financial_intelligence_recommendation_selection_snapshot.dart';

final class FinancialIntelligenceRecommendationSelectionService {
  const FinancialIntelligenceRecommendationSelectionService();

  FinancialIntelligenceRecommendationSelectionSnapshot select(
    FinancialIntelligenceDecisionOptionsSnapshot snapshot,
  ) {
    if (snapshot.options.isEmpty) {
      return FinancialIntelligenceRecommendationSelectionSnapshot(
        selection: FinancialIntelligenceRecommendationSelection(
          selectedOption: null,
          rejectedOptions: const [],
          selectionReason: FinancialIntelligenceRecommendationSelectionReason
              .noAvailableOptions,
          isDiagnosticsOnly: true,
        ),
      );
    }

    final ordered = [...snapshot.options]..sort(_compare);

    return FinancialIntelligenceRecommendationSelectionSnapshot(
      selection: FinancialIntelligenceRecommendationSelection(
        selectedOption: ordered.first,
        rejectedOptions: ordered.skip(1).toList(growable: false),
        selectionReason:
            FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
        isDiagnosticsOnly: true,
      ),
    );
  }

  int _compare(
    FinancialIntelligenceDecisionOption left,
    FinancialIntelligenceDecisionOption right,
  ) {
    final priority = _priority(left.type).compareTo(_priority(right.type));
    if (priority != 0) {
      return priority;
    }
    final start = left.period.start.microsecondsSinceEpoch.compareTo(
      right.period.start.microsecondsSinceEpoch,
    );
    if (start != 0) {
      return start;
    }
    final end = left.period.end.microsecondsSinceEpoch.compareTo(
      right.period.end.microsecondsSinceEpoch,
    );
    if (end != 0) {
      return end;
    }
    return left.optionId.compareTo(right.optionId);
  }

  int _priority(FinancialIntelligenceDecisionOptionType type) {
    return switch (type) {
      FinancialIntelligenceDecisionOptionType.reviewTransactionContext => 0,
      FinancialIntelligenceDecisionOptionType.improveCategoryCoverage => 1,
      FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts => 2,
      FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
        3,
      FinancialIntelligenceDecisionOptionType.reduceReducibleSpending => 4,
      FinancialIntelligenceDecisionOptionType
          .deferOrReduceDiscretionarySpending =>
        5,
      FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
        6,
      FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
        7,
    };
  }
}
