import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/evaluation/financial_evaluation_context_provider.dart';
import '../../accounts/controller/account_providers.dart';
import '../../assistant/controller/financial_behavior_compatibility_output_provider.dart';
import '../../assistant/domain/entities/financial_behavior_compatibility_output.dart';
import '../../operations/controller/operation_display_categories_provider.dart';
import '../../operations/controller/operation_providers.dart';
import '../domain/entities/dashboard_compatibility_read_model.dart';
import '../domain/entities/dashboard_financial_summary.dart';
import '../domain/services/dashboard_compatibility_assembler.dart';
import '../domain/services/dashboard_financial_service.dart';

final dashboardLegacyFinancialSummaryProvider =
    FutureProvider<Result<DashboardFinancialSummary>>((ref) async {
      final evaluationContext = ref.watch(financialEvaluationContextProvider);
      final accountsResult = await ref.watch(accountsProvider.future);
      final operationsResult = await ref.watch(operationsProvider.future);
      final categoriesResult = await ref.watch(
        operationDisplayCategoriesProvider.future,
      );
      final accounts = _listValue(accountsResult);
      final operations = _listValue(operationsResult);
      final categories = _listValue(categoriesResult);

      if (accounts == null || operations == null || categories == null) {
        return Failure(
          _failureOrUnknown(accountsResult, operationsResult, categoriesResult),
        );
      }

      return Success(
        const DashboardFinancialService().buildSummary(
          accounts: accounts,
          operations: operations,
          categories: categories,
          now: evaluationContext.now,
        ),
      );
    });

final dashboardCompatibilityReadModelProvider =
    FutureProvider<Result<DashboardCompatibilityReadModel>>((ref) async {
      final legacyResult = await ref.watch(
        dashboardLegacyFinancialSummaryProvider.future,
      );
      final legacySummary = _value(legacyResult);

      if (legacySummary == null) {
        return Failure(_failureOrUnknown(legacyResult));
      }

      final outputResult = await ref.watch(
        financialBehaviorCompatibilityOutputProvider.future,
      );
      final intelligenceOutput = switch (outputResult) {
        Success<FinancialBehaviorCompatibilityOutput>(:final value) => value,
        Failure<FinancialBehaviorCompatibilityOutput>() => null,
      };

      return Success(
        const DashboardCompatibilityAssembler().assemble(
          legacySummary: legacySummary,
          intelligenceOutput: intelligenceOutput,
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
