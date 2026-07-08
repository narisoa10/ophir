import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_diagnostics_read_model.dart';
import '../domain/entities/financial_model_result.dart';
import '../domain/entities/financial_model_status.dart';
import '../domain/entities/financial_model_type.dart';
import '../domain/services/financial_intelligence_models_service.dart';
import 'assistant_dashboard_briefing_provider.dart';
import 'financial_behavior_compatibility_output_provider.dart';

final financialIntelligenceDiagnosticsProvider =
    FutureProvider<Result<FinancialIntelligenceDiagnosticsReadModel>>((
      ref,
    ) async {
      final briefingResult = await ref.watch(
        assistantDashboardBriefingProvider.future,
      );
      final outputResult = await ref.watch(
        financialBehaviorCompatibilityOutputProvider.future,
      );
      final briefing = _value(briefingResult);
      final output = _value(outputResult);

      if (briefing == null || output == null) {
        return Failure(_failureOrUnknown(briefingResult, outputResult));
      }

      final incomeDenominator = _incomeTotal(briefing.modelResults);
      final period = briefing.financialState.period;
      final modelsSnapshot = const FinancialIntelligenceModelsService().build(
        output: output,
        period: period,
        incomeTotal: incomeDenominator,
      );

      return Success(
        FinancialIntelligenceDiagnosticsReadModel(
          period: period,
          incomeDenominator: incomeDenominator,
          behaviorOutput: output,
          modelsSnapshot: modelsSnapshot,
        ),
      );
    });

double _incomeTotal(List<FinancialModelResult> models) {
  for (final model in models) {
    if (model.modelType == FinancialModelType.incomeTotal &&
        model.status == FinancialModelStatus.calculated) {
      return model.value ?? 0;
    }
  }

  return 0;
}

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(
  Result<Object?> first, [
  Result<Object?>? second,
]) {
  for (final result in [first, second].whereType<Result<Object?>>()) {
    if (result case Failure<Object?>(:final failure)) {
      return failure;
    }
  }

  return const UnknownFailure();
}
