import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../operations/controller/operation_display_categories_provider.dart';
import '../../operations/controller/operation_providers.dart';
import '../domain/entities/financial_behavior_compatibility_output.dart';
import '../domain/services/financial_behavior_compatibility_orchestrator.dart';
import 'legacy_assistant_dashboard_briefing_provider.dart';

final financialBehaviorCompatibilityOutputProvider =
    FutureProvider<Result<FinancialBehaviorCompatibilityOutput>>((ref) async {
      final briefingResult = await ref.watch(
        legacyAssistantDashboardBriefingProvider.future,
      );
      final operationsResult = await ref.watch(operationsProvider.future);
      final categoriesResult = await ref.watch(
        operationDisplayCategoriesProvider.future,
      );
      final briefing = _value(briefingResult);
      final operations = _listValue(operationsResult);
      final categories = _listValue(categoriesResult);

      if (briefing == null || operations == null || categories == null) {
        return Failure(
          _failureOrUnknown(briefingResult, operationsResult, categoriesResult),
        );
      }

      return Success(
        const FinancialBehaviorCompatibilityOrchestrator().build(
          operations: operations,
          categories: categories,
          period: briefing.financialState.period,
        ),
      );
    });

List<T>? _listValue<T>(Result<List<T>> result) {
  return switch (result) {
    Success<List<T>>(:final value) => value,
    Failure<List<T>>() => null,
  };
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
  Result<Object?>? third,
]) {
  for (final result in [first, second, third].whereType<Result<Object?>>()) {
    if (result case Failure<Object?>(:final failure)) {
      return failure;
    }
  }

  return const UnknownFailure();
}
