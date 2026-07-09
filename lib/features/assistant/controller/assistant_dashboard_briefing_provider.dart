import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/assistant_dashboard_briefing.dart';
import '../domain/entities/financial_explanation.dart';
import '../domain/entities/financial_recommendation.dart';
import 'current_assistant_recommendation_explanation_provider.dart';
import 'current_assistant_recommendation_provider.dart';
import 'legacy_assistant_dashboard_briefing_provider.dart';

final assistantDashboardBriefingProvider =
    FutureProvider<Result<AssistantDashboardBriefing>>((ref) async {
      final legacyResult = await ref.watch(
        legacyAssistantDashboardBriefingProvider.future,
      );
      if (legacyResult case Failure<AssistantDashboardBriefing>(
        :final failure,
      )) {
        return Failure(failure);
      }

      final recommendationResult = await ref.watch(
        currentAssistantRecommendationProvider.future,
      );
      if (recommendationResult case Failure<FinancialRecommendation?>(
        :final failure,
      )) {
        return Failure(failure);
      }
      final explanationResult = await ref.watch(
        currentAssistantRecommendationExplanationProvider.future,
      );
      if (explanationResult case Failure<FinancialExplanation?>(
        :final failure,
      )) {
        return Failure(failure);
      }

      final legacyBriefing =
          (legacyResult as Success<AssistantDashboardBriefing>).value;
      final recommendation =
          (recommendationResult as Success<FinancialRecommendation?>).value;
      final runtimeExplanation =
          (explanationResult as Success<FinancialExplanation?>).value;

      return Success(
        _withRuntimeRecommendation(
          legacyBriefing,
          recommendation,
          runtimeExplanation,
        ),
      );
    });

AssistantDashboardBriefing _withRuntimeRecommendation(
  AssistantDashboardBriefing briefing,
  FinancialRecommendation? recommendation,
  FinancialExplanation? runtimeExplanation,
) {
  final preservesExplanation =
      recommendation?.recommendationId ==
      briefing.recommendation?.recommendationId;
  final explanation =
      runtimeExplanation ??
      (preservesExplanation ? briefing.explanation : null);

  return AssistantDashboardBriefing(
    factsSnapshot: briefing.factsSnapshot,
    modelResults: briefing.modelResults,
    deviations: briefing.deviations,
    problems: briefing.problems,
    decisionOptions: briefing.decisionOptions,
    recommendation: recommendation,
    explanation: explanation,
    radar: briefing.radar,
    primaryProblem: briefing.primaryProblem,
    financialState: briefing.financialState,
    periodDistribution: briefing.periodDistribution,
  );
}
