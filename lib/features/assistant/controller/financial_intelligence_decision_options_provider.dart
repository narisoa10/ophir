import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_decision_options_snapshot.dart';
import '../domain/entities/financial_intelligence_model_parity_snapshot.dart';
import '../domain/entities/financial_intelligence_problems_snapshot.dart';
import '../domain/services/financial_intelligence_decision_options_service.dart';
import 'financial_intelligence_model_parity_provider.dart';
import 'financial_intelligence_problems_provider.dart';

final financialIntelligenceDecisionOptionsProvider =
    FutureProvider<Result<FinancialIntelligenceDecisionOptionsSnapshot>>((
      ref,
    ) async {
      final problemsResult = await ref.watch(
        financialIntelligenceProblemsProvider.future,
      );
      final parityResult = await ref.watch(
        financialIntelligenceModelParityProvider.future,
      );
      final problems = _value(problemsResult);
      final parity = _value(parityResult);

      if (problems == null || parity == null) {
        return Failure(_failureOrUnknown(problemsResult, parityResult));
      }

      return Success(
        const FinancialIntelligenceDecisionOptionsService().build(
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
  Result<FinancialIntelligenceProblemsSnapshot> problemsResult,
  Result<FinancialIntelligenceModelParitySnapshot> parityResult,
) {
  return switch (problemsResult) {
    Failure<FinancialIntelligenceProblemsSnapshot>(:final failure) => failure,
    _ => switch (parityResult) {
      Failure<FinancialIntelligenceModelParitySnapshot>(:final failure) =>
        failure,
      _ => const UnknownFailure(),
    },
  };
}
