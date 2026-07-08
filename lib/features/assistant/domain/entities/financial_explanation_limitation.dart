import 'financial_explanation_source_layer.dart';

final class FinancialExplanationLimitation {
  const FinancialExplanationLimitation({
    required this.limitationId,
    required this.sourceLayer,
    required this.sourceEntityId,
  });

  final String limitationId;
  final FinancialExplanationSourceLayer sourceLayer;
  final String sourceEntityId;
}
