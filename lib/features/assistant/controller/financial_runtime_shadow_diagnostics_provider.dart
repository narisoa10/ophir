import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_runtime_recommendation_candidate.dart';
import '../domain/entities/financial_recommendation.dart';
import '../domain/entities/financial_runtime_recommendation_selection.dart';
import '../domain/entities/financial_runtime_shadow_diagnostics_snapshot.dart';
import '../domain/services/financial_runtime_shadow_diagnostics_service.dart';
import 'financial_intelligence_runtime_recommendation_candidate_provider.dart';
import 'financial_runtime_recommendation_config_provider.dart';
import 'financial_runtime_recommendation_selection_provider.dart';
import 'legacy_assistant_recommendation_provider.dart';

final financialRuntimeShadowDiagnosticsProvider =
    FutureProvider<Result<FinancialRuntimeShadowDiagnosticsSnapshot>>((
      ref,
    ) async {
      final config = ref.watch(financialRuntimeRecommendationConfigProvider);
      final legacyResult = await ref.watch(
        legacyAssistantRecommendationProvider.future,
      );
      final runtimeSelectionResult = await ref.watch(
        financialRuntimeRecommendationSelectionProvider.future,
      );
      final candidateAsync = ref.watch(
        financialIntelligenceRuntimeRecommendationCandidateProvider,
      );

      if (legacyResult case Failure<FinancialRecommendation?>(:final failure)) {
        return Failure(failure);
      }
      if (runtimeSelectionResult
          case Failure<FinancialRuntimeRecommendationSelection>(
            :final failure,
          )) {
        return Failure(failure);
      }

      final legacyRecommendation =
          (legacyResult as Success<FinancialRecommendation?>).value;
      final runtimeSelection =
          (runtimeSelectionResult
                  as Success<FinancialRuntimeRecommendationSelection>)
              .value;
      final candidate = _candidateOrNull(candidateAsync);

      return Success(
        const FinancialRuntimeShadowDiagnosticsService().build(
          legacyRecommendation: legacyRecommendation,
          runtimeSelection: runtimeSelection,
          candidate: candidate,
          runtimeMode: config.mode,
          generatedAt: DateTime.now(),
        ),
      );
    });

FinancialIntelligenceRuntimeRecommendationCandidate? _candidateOrNull(
  AsyncValue<Result<FinancialIntelligenceRuntimeRecommendationCandidate>>
  candidateAsync,
) {
  return switch (candidateAsync) {
    AsyncData(:final value) => switch (value) {
      Success<FinancialIntelligenceRuntimeRecommendationCandidate>(
        :final value,
      ) =>
        value,
      Failure<FinancialIntelligenceRuntimeRecommendationCandidate>() => null,
    },
    _ => null,
  };
}
