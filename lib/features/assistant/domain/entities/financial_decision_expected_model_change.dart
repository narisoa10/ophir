import 'financial_model_unit.dart';
import 'financial_model_type.dart';
import 'financial_problem_confidence.dart';
import 'financial_decision_target_direction.dart';

final class FinancialDecisionExpectedModelChange {
  const FinancialDecisionExpectedModelChange({
    required this.modelType,
    required this.direction,
    required this.expectedChange,
    required this.unit,
    required this.confidence,
  });

  final FinancialModelType modelType;
  final FinancialDecisionTargetDirection direction;
  final double? expectedChange;
  final FinancialModelUnit unit;
  final FinancialProblemConfidence confidence;
}
