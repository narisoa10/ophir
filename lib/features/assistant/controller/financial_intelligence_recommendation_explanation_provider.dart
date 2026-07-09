import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_model_parity_snapshot.dart';
import '../domain/entities/financial_intelligence_problems_snapshot.dart';
import '../domain/entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import '../domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import '../domain/services/financial_intelligence_recommendation_explanation_service.dart';
import 'financial_intelligence_model_parity_provider.dart';
import 'financial_intelligence_problems_provider.dart';
import 'financial_intelligence_recommendation_selection_provider.dart';

final financialIntelligenceRecommendationExplanationProvider =
    FutureProvider<
      Result<FinancialIntelligenceRecommendationExplanationSnapshot>
    >((ref) async {
      final selectionResult = await ref.watch(
        financialIntelligenceRecommendationSelectionProvider.future,
      );
      final problemsResult = await ref.watch(
        financialIntelligenceProblemsProvider.future,
      );
      final parityResult = await ref.watch(
        financialIntelligenceModelParityProvider.future,
      );
      final selection = _value(selectionResult);
      final problems = _value(problemsResult);
      final parity = _value(parityResult);

      if (selection == null || problems == null || parity == null) {
        return Failure(
          _failureOrUnknown(selectionResult, problemsResult, parityResult),
        );
      }

      return Success(
        const FinancialIntelligenceRecommendationExplanationService().build(
          selection: selection,
          problems: problems,
          parity: parity,
        ),
      );
    });

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(
  Result<FinancialIntelligenceRecommendationSelectionSnapshot> selectionResult,
  Result<FinancialIntelligenceProblemsSnapshot> problemsResult,
  Result<FinancialIntelligenceModelParitySnapshot> parityResult,
) {
  return switch (selectionResult) {
    Failure<FinancialIntelligenceRecommendationSelectionSnapshot>(
      :final failure,
    ) =>
      failure,
    _ => switch (problemsResult) {
      Failure<FinancialIntelligenceProblemsSnapshot>(:final failure) => failure,
      _ => switch (parityResult) {
        Failure<FinancialIntelligenceModelParitySnapshot>(:final failure) =>
          failure,
        _ => const UnknownFailure(),
      },
    },
  };
}
