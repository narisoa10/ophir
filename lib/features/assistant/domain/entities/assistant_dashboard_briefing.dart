import 'assistant_dashboard_radar.dart';
import 'financial_decision_option.dart';
import 'financial_deviation.dart';
import 'financial_explanation.dart';
import 'financial_facts_snapshot.dart';
import 'financial_model_result.dart';
import 'financial_period_distribution.dart';
import 'financial_problem.dart';
import 'financial_recommendation.dart';
import 'financial_state.dart';

final class AssistantDashboardBriefing {
  const AssistantDashboardBriefing({
    required this.factsSnapshot,
    required this.modelResults,
    required this.deviations,
    required this.problems,
    required this.decisionOptions,
    required this.recommendation,
    required this.explanation,
    required this.radar,
    required this.primaryProblem,
    required this.financialState,
    required this.periodDistribution,
  });

  final FinancialFactsSnapshot factsSnapshot;
  final List<FinancialModelResult> modelResults;
  final List<FinancialDeviation> deviations;
  final List<FinancialProblem> problems;
  final List<FinancialDecisionOption> decisionOptions;
  final FinancialRecommendation? recommendation;
  final FinancialExplanation? explanation;
  final AssistantDashboardRadar radar;
  final FinancialProblem? primaryProblem;
  final FinancialState financialState;
  final FinancialPeriodDistribution periodDistribution;
}
