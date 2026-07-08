import 'financial_explanation_validation_issue_type.dart';

final class FinancialExplanationValidationIssue {
  const FinancialExplanationValidationIssue({
    required this.issueType,
    required this.sourceNodeId,
    required this.referenceId,
  });

  final FinancialExplanationValidationIssueType issueType;
  final String sourceNodeId;
  final String referenceId;
}
