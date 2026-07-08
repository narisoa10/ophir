import 'financial_explanation_reference.dart';

final class FinancialExplanationEvidence {
  const FinancialExplanationEvidence({
    required this.evidenceId,
    required this.sourceEntityId,
    required this.references,
  });

  final String evidenceId;
  final String sourceEntityId;
  final List<FinancialExplanationReference> references;
}
