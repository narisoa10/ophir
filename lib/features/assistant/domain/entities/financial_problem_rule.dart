import 'financial_deviation_type.dart';
import 'financial_problem_impact.dart';
import 'financial_problem_type.dart';

final class FinancialProblemRule {
  const FinancialProblemRule({
    required this.id,
    required this.problemType,
    required this.requiredDeviationTypes,
    required this.supportingDeviationTypes,
    required this.impact,
    required this.minimumSupportingSignals,
    required this.allowsIsolatedMediumOrHighSignal,
  });

  final String id;
  final FinancialProblemType problemType;
  final List<FinancialDeviationType> requiredDeviationTypes;
  final List<FinancialDeviationType> supportingDeviationTypes;
  final FinancialProblemImpact impact;
  final int minimumSupportingSignals;
  final bool allowsIsolatedMediumOrHighSignal;
}
