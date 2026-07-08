import 'financial_explanation_reference_type.dart';
import 'financial_explanation_source_layer.dart';

final class FinancialExplanationReference {
  const FinancialExplanationReference({
    required this.referenceId,
    required this.referenceType,
    required this.sourceLayer,
  });

  final String referenceId;
  final FinancialExplanationReferenceType referenceType;
  final FinancialExplanationSourceLayer sourceLayer;
}
