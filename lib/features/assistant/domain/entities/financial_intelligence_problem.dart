import 'financial_intelligence_deviation_type.dart';
import 'financial_intelligence_problem_type.dart';
import 'financial_model_period.dart';
import 'financial_problem_impact.dart';
import 'financial_problem_severity.dart';

final class FinancialIntelligenceProblem {
  FinancialIntelligenceProblem({
    required this.problemId,
    required this.type,
    required this.period,
    required this.severity,
    required this.impact,
    required List<String> sourceDeviationIds,
    required List<FinancialIntelligenceDeviationType> sourceDeviationTypes,
    required this.isPositiveSignal,
    required this.isWarning,
    required this.isDiagnosticsOnly,
  }) : sourceDeviationIds = List.unmodifiable(sourceDeviationIds),
       sourceDeviationTypes = List.unmodifiable(sourceDeviationTypes);

  final String problemId;
  final FinancialIntelligenceProblemType type;
  final FinancialModelPeriod period;
  final FinancialProblemSeverity severity;
  final FinancialProblemImpact impact;
  final List<String> sourceDeviationIds;
  final List<FinancialIntelligenceDeviationType> sourceDeviationTypes;
  final bool isPositiveSignal;
  final bool isWarning;
  final bool isDiagnosticsOnly;
}
