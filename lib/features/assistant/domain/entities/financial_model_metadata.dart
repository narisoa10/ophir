final class FinancialModelMetadata {
  const FinancialModelMetadata({
    required this.calculatedAt,
    required this.engineVersion,
    required this.snapshotVersion,
  });

  final DateTime calculatedAt;
  final String engineVersion;
  final String snapshotVersion;
}
