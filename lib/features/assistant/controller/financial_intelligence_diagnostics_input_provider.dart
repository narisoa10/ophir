import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/evaluation/financial_evaluation_context_provider.dart';
import '../../accounts/controller/account_providers.dart';
import '../../accounts/domain/entities/account.dart';
import '../../categories/domain/entities/category.dart';
import '../../operations/controller/operation_display_categories_provider.dart';
import '../../operations/controller/operation_providers.dart';
import '../../operations/domain/entities/operation.dart';
import '../domain/entities/financial_facts_snapshot.dart';
import '../domain/entities/financial_intelligence_diagnostics_input.dart';
import '../domain/entities/financial_model_period.dart';
import '../domain/entities/financial_model_status.dart';
import '../domain/entities/financial_model_type.dart';
import '../domain/services/financial_facts_service.dart';
import '../domain/services/financial_models_service.dart';

final financialIntelligenceDiagnosticsInputProvider =
    FutureProvider<Result<FinancialIntelligenceDiagnosticsInput>>((ref) async {
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

      final period = FinancialModelPeriod(
        start: evaluationContext.currentMonth.start,
        end: evaluationContext.currentMonth.end,
      );
      final snapshot = const FinancialFactsService().buildSnapshot(
        accounts: accounts,
        operations: operations,
        categories: categories,
      );

      return Success(
        FinancialIntelligenceDiagnosticsInput(
          period: period,
          incomeDenominator: _incomeDenominator(
            snapshot: snapshot,
            period: period,
            calculatedAt: evaluationContext.now,
          ),
          operations: operations,
          categories: categories,
        ),
      );
    });

double _incomeDenominator({
  required FinancialFactsSnapshot snapshot,
  required FinancialModelPeriod period,
  required DateTime calculatedAt,
}) {
  final income = const FinancialModelsService().calculate(
    type: FinancialModelType.incomeTotal,
    snapshot: snapshot,
    period: period,
    calculatedAt: calculatedAt,
  );
  if (income.status != FinancialModelStatus.calculated) {
    return 0;
  }
  return income.value ?? 0;
}

List<T>? _listValue<T>(Result<List<T>> result) {
  return switch (result) {
    Success<List<T>>(:final value) => value,
    Failure<List<T>>() => null,
  };
}

AppFailure _failureOrUnknown(
  Result<List<Account>> accountsResult,
  Result<List<Operation>> operationsResult,
  Result<List<Category>> categoriesResult,
) {
  return switch (accountsResult) {
    Failure<List<Account>>(:final failure) => failure,
    _ => switch (operationsResult) {
      Failure<List<Operation>>(:final failure) => failure,
      _ => switch (categoriesResult) {
        Failure<List<Category>>(:final failure) => failure,
        _ => const UnknownFailure(),
      },
    },
  };
}
