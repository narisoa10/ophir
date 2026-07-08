import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/assistant_dashboard_briefing.dart';
import '../domain/entities/financial_recommendation.dart';
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

      final legacyBriefing =
          (legacyResult as Success<AssistantDashboardBriefing>).value;
      final recommendation =
          (recommendationResult as Success<FinancialRecommendation?>).value;

      return Success(
        _withRuntimeRecommendation(legacyBriefing, recommendation),
      );
    });

AssistantDashboardBriefing _withRuntimeRecommendation(
  AssistantDashboardBriefing briefing,
  FinancialRecommendation? recommendation,
) {
  final preservesExplanation =
      recommendation?.recommendationId ==
      briefing.recommendation?.recommendationId;

  return AssistantDashboardBriefing(
    factsSnapshot: briefing.factsSnapshot,
    modelResults: briefing.modelResults,
    deviations: briefing.deviations,
    problems: briefing.problems,
    decisionOptions: briefing.decisionOptions,
    recommendation: recommendation,
    explanation: preservesExplanation ? briefing.explanation : null,
    radar: briefing.radar,
    primaryProblem: briefing.primaryProblem,
    financialState: briefing.financialState,
    periodDistribution: briefing.periodDistribution,
  );
}
