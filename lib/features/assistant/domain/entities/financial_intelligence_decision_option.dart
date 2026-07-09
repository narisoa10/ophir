import 'financial_intelligence_decision_option_type.dart';
import 'financial_intelligence_model_parity_metric.dart';
import 'financial_intelligence_model_parity_status.dart';
import 'financial_intelligence_problem_type.dart';
import 'financial_model_period.dart';

final class FinancialIntelligenceDecisionOption {
  FinancialIntelligenceDecisionOption({
    required this.optionId,
    required this.type,
    required this.period,
    required List<String> sourceProblemIds,
    required List<FinancialIntelligenceProblemType> sourceProblemTypes,
    required this.parityMetric,
    required this.parityStatus,
    required this.legacyModelValue,
    required this.intelligenceModelValue,
    required this.isPositiveSignal,
    required this.isWarning,
    required this.isDiagnosticsOnly,
  }) : sourceProblemIds = List.unmodifiable(sourceProblemIds),
       sourceProblemTypes = List.unmodifiable(sourceProblemTypes);

  final String optionId;
  final FinancialIntelligenceDecisionOptionType type;
  final FinancialModelPeriod period;
  final List<String> sourceProblemIds;
  final List<FinancialIntelligenceProblemType> sourceProblemTypes;
  final FinancialIntelligenceModelParityMetric? parityMetric;
  final FinancialIntelligenceModelParityStatus? parityStatus;
  final double? legacyModelValue;
  final double? intelligenceModelValue;
  final bool isPositiveSignal;
  final bool isWarning;
  final bool isDiagnosticsOnly;
}
