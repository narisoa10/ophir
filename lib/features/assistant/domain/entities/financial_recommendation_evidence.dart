final class FinancialRecommendationEvidence {
  const FinancialRecommendationEvidence({
    required this.sourceOptionId,
    required this.sourceProblemIds,
    required this.sourceProblemTypes,
    required this.sourceDeviationIds,
    required this.sourceModelIds,
  });

  final String sourceOptionId;
  final List<String> sourceProblemIds;
  final List<String> sourceProblemTypes;
  final List<String> sourceDeviationIds;
  final List<String> sourceModelIds;
}
