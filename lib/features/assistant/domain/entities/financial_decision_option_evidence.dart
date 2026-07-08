import 'financial_problem_type.dart';

final class FinancialDecisionOptionEvidence {
  const FinancialDecisionOptionEvidence({
    required this.sourceProblemIds,
    required this.sourceProblemTypes,
    required this.sourceDeviationIds,
    required this.sourceModelIds,
  });

  final List<String> sourceProblemIds;
  final List<FinancialProblemType> sourceProblemTypes;
  final List<String> sourceDeviationIds;
  final List<String> sourceModelIds;
}
