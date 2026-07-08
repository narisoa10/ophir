final class FinancialDeviationMetadata {
  const FinancialDeviationMetadata({
    required this.calculatedAt,
    required this.engineVersion,
    required this.thresholdId,
  });

  final DateTime calculatedAt;
  final String engineVersion;
  final String thresholdId;
}
