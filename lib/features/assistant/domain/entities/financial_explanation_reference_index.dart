import 'financial_decision_option.dart';
import 'financial_deviation.dart';
import 'financial_explanation_fact_reference.dart';
import 'financial_model_result.dart';
import 'financial_problem.dart';

final class FinancialExplanationReferenceIndex {
  FinancialExplanationReferenceIndex({
    required Iterable<FinancialDecisionOption> options,
    required Iterable<FinancialProblem> problems,
    required Iterable<FinancialDeviation> deviations,
    required Iterable<FinancialModelResult> modelResults,
    required Iterable<FinancialExplanationFactReference> facts,
  }) : optionsById = Map.unmodifiable({
         for (final option in options) option.optionId: option,
       }),
       problemsById = Map.unmodifiable({
         for (final problem in problems) problem.problemId: problem,
       }),
       deviationsById = Map.unmodifiable({
         for (final deviation in deviations) deviation.deviationId: deviation,
       }),
       modelResultsById = Map.unmodifiable({
         for (final result in modelResults) result.modelId: result,
       }),
       factsById = Map.unmodifiable({
         for (final fact in facts) fact.factId: fact,
       });

  final Map<String, FinancialDecisionOption> optionsById;
  final Map<String, FinancialProblem> problemsById;
  final Map<String, FinancialDeviation> deviationsById;
  final Map<String, FinancialModelResult> modelResultsById;
  final Map<String, FinancialExplanationFactReference> factsById;
}
