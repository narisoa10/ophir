import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/assistant_dashboard_briefing.dart';
import '../domain/entities/financial_behavior_compatibility_output.dart';
import '../domain/entities/financial_state_category_contributors_snapshot.dart';
import '../domain/services/financial_state_category_contributors_service.dart';
import 'financial_behavior_compatibility_output_provider.dart';
import 'legacy_assistant_dashboard_briefing_provider.dart';

final financialStateCategoryContributorsProvider =
    FutureProvider<Result<FinancialStateCategoryContributorsSnapshot>>((
      ref,
    ) async {
      final briefingResult = await ref.watch(
        legacyAssistantDashboardBriefingProvider.future,
      );
      final compatibilityOutputResult = await ref.watch(
        financialBehaviorCompatibilityOutputProvider.future,
      );

      if (briefingResult case Failure<AssistantDashboardBriefing>(
        :final failure,
      )) {
        return Failure(failure);
      }
      if (compatibilityOutputResult
          case Failure<FinancialBehaviorCompatibilityOutput>(:final failure)) {
        return Failure(failure);
      }

      final briefing =
          (briefingResult as Success<AssistantDashboardBriefing>).value;
      final output =
          (compatibilityOutputResult
                  as Success<FinancialBehaviorCompatibilityOutput>)
              .value;

      return Success(
        const FinancialStateCategoryContributorsService().build(
          financialState: briefing.financialState,
          behaviorFacts: output.snapshot,
          primaryProblem: briefing.primaryProblem,
          deviations: briefing.deviations,
          financialFacts: briefing.factsSnapshot,
        ),
      );
    });
