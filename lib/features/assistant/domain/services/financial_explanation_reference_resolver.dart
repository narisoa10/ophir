import '../entities/financial_decision_option.dart';
import '../entities/financial_deviation.dart';
import '../entities/financial_explanation_fact_reference.dart';
import '../entities/financial_explanation_reference_index.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_problem.dart';

final class FinancialExplanationReferenceResolver {
  const FinancialExplanationReferenceResolver();

  FinancialDecisionOption? option(
    FinancialExplanationReferenceIndex index,
    String optionId,
  ) {
    return index.optionsById[optionId];
  }

  FinancialProblem? problem(
    FinancialExplanationReferenceIndex index,
    String problemId,
  ) {
    return index.problemsById[problemId];
  }

  FinancialDeviation? deviation(
    FinancialExplanationReferenceIndex index,
    String deviationId,
  ) {
    return index.deviationsById[deviationId];
  }

  FinancialModelResult? modelResult(
    FinancialExplanationReferenceIndex index,
    String modelId,
  ) {
    return index.modelResultsById[modelId];
  }

  FinancialExplanationFactReference? fact(
    FinancialExplanationReferenceIndex index,
    String factId,
  ) {
    return index.factsById[factId];
  }
}
