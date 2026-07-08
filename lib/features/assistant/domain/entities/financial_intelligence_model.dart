import 'financial_intelligence_model_type.dart';

final class FinancialIntelligenceModel {
  const FinancialIntelligenceModel({
    required this.type,
    required this.value,
    required this.isRatio,
  });

  final FinancialIntelligenceModelType type;
  final double value;
  final bool isRatio;
}
