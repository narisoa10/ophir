import 'financial_model_limitation.dart';
import 'financial_state_category_contributor.dart';
import 'financial_state_confidence.dart';
import 'financial_state_contributor_strategy.dart';
import 'financial_state_type.dart';

final class FinancialStateCategoryContributorsSnapshot {
  /// Explanatory category factors for the current financial state.
  FinancialStateCategoryContributorsSnapshot({
    required this.stateType,
    required this.strategy,
    required this.requiredAmount,
    required this.coveredAmount,
    required this.isCoverageComplete,
    required this.currencyCode,
    required this.confidence,
    required List<FinancialStateCategoryContributor> contributors,
    required List<FinancialModelLimitation> limitations,
  }) : contributors = List.unmodifiable(contributors),
       limitations = List.unmodifiable(limitations);

  final FinancialStateType stateType;
  final FinancialStateContributorStrategy strategy;
  final double requiredAmount;
  final double coveredAmount;
  final bool isCoverageComplete;
  final String? currencyCode;
  final FinancialStateConfidence confidence;
  final List<FinancialStateCategoryContributor> contributors;
  final List<FinancialModelLimitation> limitations;
}
