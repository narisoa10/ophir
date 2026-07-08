import 'financial_deviation_type.dart';

final class FinancialProblemEvidence {
  const FinancialProblemEvidence({
    required this.sourceDeviationIds,
    required this.sourceDeviationTypes,
    required this.sourceModelIds,
  });

  final List<String> sourceDeviationIds;
  final List<FinancialDeviationType> sourceDeviationTypes;
  final List<String> sourceModelIds;
}
