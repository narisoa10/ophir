import 'financial_model_unit.dart';
import 'financial_model_type.dart';
import 'financial_problem_confidence.dart';
import 'financial_decision_target_direction.dart';

final class FinancialDecisionTarget {
  const FinancialDecisionTarget({
    required this.targetModelType,
    required this.desiredDirection,
    required this.expectedImprovement,
    required this.unit,
    required this.confidence,
  });

  final FinancialModelType targetModelType;
  final FinancialDecisionTargetDirection desiredDirection;
  final double? expectedImprovement;
  final FinancialModelUnit unit;
  final FinancialProblemConfidence confidence;
}
