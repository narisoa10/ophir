import 'financial_explanation_source_layer.dart';

final class FinancialExplanationAssumption {
  const FinancialExplanationAssumption({
    required this.assumptionId,
    required this.sourceLayer,
    required this.sourceEntityId,
  });

  final String assumptionId;
  final FinancialExplanationSourceLayer sourceLayer;
  final String sourceEntityId;
}
