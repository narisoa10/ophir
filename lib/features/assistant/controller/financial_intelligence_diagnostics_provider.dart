import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_behavior_compatibility_output.dart';
import '../domain/entities/financial_intelligence_diagnostics_read_model.dart';
import '../domain/entities/financial_intelligence_diagnostics_input.dart';
import '../domain/services/financial_intelligence_models_service.dart';
import 'financial_behavior_compatibility_output_provider.dart';
import 'financial_intelligence_diagnostics_input_provider.dart';

final financialIntelligenceDiagnosticsProvider =
    FutureProvider<Result<FinancialIntelligenceDiagnosticsReadModel>>((
      ref,
    ) async {
      final inputResult = await ref.watch(
        financialIntelligenceDiagnosticsInputProvider.future,
      );
      final outputResult = await ref.watch(
        financialBehaviorCompatibilityOutputProvider.future,
      );
      final input = _value(inputResult);
      final output = _value(outputResult);

      if (input == null || output == null) {
        return Failure(_failureOrUnknown(inputResult, outputResult));
      }

      final modelsSnapshot = const FinancialIntelligenceModelsService().build(
        output: output,
        period: input.period,
        incomeTotal: input.incomeDenominator,
      );

      return Success(
        FinancialIntelligenceDiagnosticsReadModel(
          period: input.period,
          incomeDenominator: input.incomeDenominator,
          behaviorOutput: output,
          modelsSnapshot: modelsSnapshot,
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
  Result<FinancialIntelligenceDiagnosticsInput> inputResult,
  Result<FinancialBehaviorCompatibilityOutput> outputResult,
) {
  return switch (inputResult) {
    Failure<FinancialIntelligenceDiagnosticsInput>(:final failure) => failure,
    _ => switch (outputResult) {
      Failure<FinancialBehaviorCompatibilityOutput>(:final failure) => failure,
      _ => const UnknownFailure(),
    },
  };
}
