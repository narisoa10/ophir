import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_decision_options_snapshot.dart';
import '../domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import '../domain/services/financial_intelligence_recommendation_selection_service.dart';
import 'financial_intelligence_decision_options_provider.dart';

final financialIntelligenceRecommendationSelectionProvider =
    FutureProvider<
      Result<FinancialIntelligenceRecommendationSelectionSnapshot>
    >((ref) async {
      final optionsResult = await ref.watch(
        financialIntelligenceDecisionOptionsProvider.future,
      );
      final options = _value(optionsResult);

      if (options == null) {
        return Failure(_failureOrUnknown(optionsResult));
      }

      return Success(
        const FinancialIntelligenceRecommendationSelectionService().select(
          options,
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
  Result<FinancialIntelligenceDecisionOptionsSnapshot> result,
) {
  return switch (result) {
    Failure<FinancialIntelligenceDecisionOptionsSnapshot>(:final failure) =>
      failure,
    Success<FinancialIntelligenceDecisionOptionsSnapshot>() =>
      const UnknownFailure(),
  };
}
