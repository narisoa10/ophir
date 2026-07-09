import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import '../domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import '../domain/entities/financial_intelligence_runtime_recommendation_candidate.dart';
import '../domain/entities/financial_recommendation_comparison_read_model.dart';
import '../domain/services/financial_intelligence_runtime_recommendation_adapter.dart';
import 'financial_intelligence_recommendation_explanation_provider.dart';
import 'financial_intelligence_recommendation_selection_provider.dart';
import 'financial_recommendation_comparison_provider.dart';

final financialIntelligenceRuntimeRecommendationCandidateProvider =
    FutureProvider<Result<FinancialIntelligenceRuntimeRecommendationCandidate>>(
      (ref) async {
        final selectionResult = await ref.watch(
          financialIntelligenceRecommendationSelectionProvider.future,
        );
        final explanationResult = await ref.watch(
          financialIntelligenceRecommendationExplanationProvider.future,
        );
        final comparisonResult = await ref.watch(
          financialRecommendationComparisonProvider.future,
        );
        final selection = _value(selectionResult);
        final explanation = _value(explanationResult);
        final comparison = _value(comparisonResult);

        if (selection == null || explanation == null || comparison == null) {
          return Failure(
            _failureOrUnknown(
              selectionResult,
              explanationResult,
              comparisonResult,
            ),
          );
        }

        return Success(
          const FinancialIntelligenceRuntimeRecommendationAdapter().build(
            selection: selection,
            explanation: explanation,
            comparison: comparison,
          ),
        );
      },
    );

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(
  Result<FinancialIntelligenceRecommendationSelectionSnapshot> selectionResult,
  Result<FinancialIntelligenceRecommendationExplanationSnapshot>
  explanationResult,
  Result<FinancialRecommendationComparisonReadModel> comparisonResult,
) {
  return switch (selectionResult) {
    Failure<FinancialIntelligenceRecommendationSelectionSnapshot>(
      :final failure,
    ) =>
      failure,
    _ => switch (explanationResult) {
      Failure<FinancialIntelligenceRecommendationExplanationSnapshot>(
        :final failure,
      ) =>
        failure,
      _ => switch (comparisonResult) {
        Failure<FinancialRecommendationComparisonReadModel>(:final failure) =>
          failure,
        _ => const UnknownFailure(),
      },
    },
  };
}
