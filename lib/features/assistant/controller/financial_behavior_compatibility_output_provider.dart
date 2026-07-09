import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_behavior_compatibility_output.dart';
import '../domain/entities/financial_intelligence_diagnostics_input.dart';
import '../domain/services/financial_behavior_compatibility_orchestrator.dart';
import 'financial_intelligence_diagnostics_input_provider.dart';

final financialBehaviorCompatibilityOutputProvider =
    FutureProvider<Result<FinancialBehaviorCompatibilityOutput>>((ref) async {
      final inputResult = await ref.watch(
        financialIntelligenceDiagnosticsInputProvider.future,
      );
      final input = _value(inputResult);

      if (input == null) {
        return Failure(_failureOrUnknown(inputResult));
      }

      return Success(
        const FinancialBehaviorCompatibilityOrchestrator().build(
          operations: input.operations,
          categories: input.categories,
          period: input.period,
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
  Result<FinancialIntelligenceDiagnosticsInput> result,
) {
  return switch (result) {
    Failure<FinancialIntelligenceDiagnosticsInput>(:final failure) => failure,
    Success<FinancialIntelligenceDiagnosticsInput>() => const UnknownFailure(),
  };
}
