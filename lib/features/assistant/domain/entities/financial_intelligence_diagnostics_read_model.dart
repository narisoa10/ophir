import 'financial_behavior_compatibility_output.dart';
import 'financial_intelligence_models_snapshot.dart';
import 'financial_model_period.dart';

final class FinancialIntelligenceDiagnosticsReadModel {
  const FinancialIntelligenceDiagnosticsReadModel({
    required this.period,
    required this.incomeDenominator,
    required this.behaviorOutput,
    required this.modelsSnapshot,
  });

  final FinancialModelPeriod period;
  final double incomeDenominator;
  final FinancialBehaviorCompatibilityOutput behaviorOutput;
  final FinancialIntelligenceModelsSnapshot modelsSnapshot;
}
