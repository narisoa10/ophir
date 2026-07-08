final class FinancialDecisionOptionMetadata {
  const FinancialDecisionOptionMetadata({
    required this.generatedAt,
    required this.engineVersion,
    required this.ruleId,
  });

  final DateTime generatedAt;
  final String engineVersion;
  final String ruleId;
}
