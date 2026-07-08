final class FinancialProblemMetadata {
  const FinancialProblemMetadata({
    required this.calculatedAt,
    required this.engineVersion,
    required this.ruleId,
  });

  final DateTime calculatedAt;
  final String engineVersion;
  final String ruleId;
}
