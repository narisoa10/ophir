import '../entities/financial_intelligence_decision_option.dart';
import '../entities/financial_intelligence_model_parity_metric_result.dart';
import '../entities/financial_intelligence_model_parity_snapshot.dart';
import '../entities/financial_intelligence_problem.dart';
import '../entities/financial_intelligence_problems_snapshot.dart';
import '../entities/financial_intelligence_recommendation_evidence.dart';
import '../entities/financial_intelligence_recommendation_explanation.dart';
import '../entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import '../entities/financial_intelligence_recommendation_selection_snapshot.dart';

final class FinancialIntelligenceRecommendationExplanationService {
  const FinancialIntelligenceRecommendationExplanationService();

  FinancialIntelligenceRecommendationExplanationSnapshot build({
    required FinancialIntelligenceRecommendationSelectionSnapshot selection,
    required FinancialIntelligenceProblemsSnapshot problems,
    required FinancialIntelligenceModelParitySnapshot parity,
  }) {
    final selected = selection.selectedOption;
    if (selected == null) {
      return FinancialIntelligenceRecommendationExplanationSnapshot(
        explanation: FinancialIntelligenceRecommendationExplanation(
          selectedRecommendation: null,
          selectionReason: selection.selectionReason,
          supportingProblems: const [],
          supportingParityMetrics: const [],
          evidence: const [],
          isDiagnosticsOnly: true,
        ),
      );
    }

    final supportingProblems = _supportingProblems(selected, problems);
    final supportingParityMetrics = _supportingParityMetrics(selected, parity);

    return FinancialIntelligenceRecommendationExplanationSnapshot(
      explanation: FinancialIntelligenceRecommendationExplanation(
        selectedRecommendation: selected,
        selectionReason: selection.selectionReason,
        supportingProblems: supportingProblems,
        supportingParityMetrics: supportingParityMetrics,
        evidence: [
          _evidenceFor(
            selected: selected,
            supportingProblems: supportingProblems,
            supportingParityMetrics: supportingParityMetrics,
          ),
        ],
        isDiagnosticsOnly: true,
      ),
    );
  }

  List<FinancialIntelligenceProblem> _supportingProblems(
    FinancialIntelligenceDecisionOption selected,
    FinancialIntelligenceProblemsSnapshot problems,
  ) {
    final sourceIds = {...selected.sourceProblemIds};

    return problems.problems
        .where((problem) => sourceIds.contains(problem.problemId))
        .toList(growable: false);
  }

  List<FinancialIntelligenceModelParityMetricResult> _supportingParityMetrics(
    FinancialIntelligenceDecisionOption selected,
    FinancialIntelligenceModelParitySnapshot parity,
  ) {
    final metric = selected.parityMetric;
    if (metric == null) {
      return const [];
    }

    return parity.metricResults
        .where((result) => result.metric == metric)
        .toList(growable: false);
  }

  FinancialIntelligenceRecommendationEvidence _evidenceFor({
    required FinancialIntelligenceDecisionOption selected,
    required List<FinancialIntelligenceProblem> supportingProblems,
    required List<FinancialIntelligenceModelParityMetricResult>
    supportingParityMetrics,
  }) {
    return FinancialIntelligenceRecommendationEvidence(
      evidenceId:
          'financial.intelligence.recommendation.evidence.'
          '${selected.optionId}',
      sourceOptionId: selected.optionId,
      sourceProblemIds: [
        for (final problem in supportingProblems) problem.problemId,
      ],
      sourceProblemTypes: [
        for (final problem in supportingProblems) problem.type,
      ],
      sourceDeviationIds: _unique([
        for (final problem in supportingProblems) ...problem.sourceDeviationIds,
      ]),
      sourceDeviationTypes: [
        ...{
          for (final problem in supportingProblems)
            ...problem.sourceDeviationTypes,
        },
      ],
      parityMetrics: [
        for (final result in supportingParityMetrics) result.metric,
      ],
      isDiagnosticsOnly: true,
    );
  }

  List<String> _unique(List<String> values) {
    return {...values}.toList(growable: false);
  }
}
