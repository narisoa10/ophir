import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import '../domain/services/financial_intelligence_recommendation_diagnostics_service.dart';
import 'financial_intelligence_problems_provider.dart';

final financialIntelligenceRecommendationDiagnosticsProvider =
    FutureProvider<
      Result<FinancialIntelligenceRecommendationDiagnosticsSnapshot>
    >((ref) async {
      final problemsResult = await ref.watch(
        financialIntelligenceProblemsProvider.future,
      );
      final problems = _value(problemsResult);

      if (problems == null) {
        return Failure(_failureOrUnknown(problemsResult));
      }

      return Success(
        const FinancialIntelligenceRecommendationDiagnosticsService().build(
          problems,
        ),
      );
    });

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(Result<Object?> result) {
  return switch (result) {
    Failure<Object?>(:final failure) => failure,
    Success<Object?>() => const UnknownFailure(),
  };
}
