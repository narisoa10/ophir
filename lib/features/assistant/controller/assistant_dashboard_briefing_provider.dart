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
import '../domain/entities/assistant_dashboard_briefing.dart';
import '../domain/services/assistant_dashboard_briefing_service.dart';

final assistantDashboardBriefingProvider =
    FutureProvider<Result<AssistantDashboardBriefing>>((ref) async {
      final evaluationContext = ref.watch(financialEvaluationContextProvider);
      final accountsResult = await ref.watch(accountsProvider.future);
      final operationsResult = await ref.watch(operationsProvider.future);
      final categoriesResult = await ref.watch(
        operationDisplayCategoriesProvider.future,
      );
      final accounts = _value(accountsResult);
      final operations = _value(operationsResult);
      final categories = _value(categoriesResult);

      if (accounts == null || operations == null || categories == null) {
        return Failure(switch (accountsResult) {
          Failure<List<Account>>(:final failure) => failure,
          _ => switch (operationsResult) {
            Failure<List<Operation>>(:final failure) => failure,
            _ => switch (categoriesResult) {
              Failure<List<Category>>(:final failure) => failure,
              _ => const UnknownFailure(),
            },
          },
        });
      }

      return Success(
        const AssistantDashboardBriefingService().build(
          accounts: accounts,
          operations: operations,
          categories: categories,
          now: evaluationContext.now,
        ),
      );
    });

List<T>? _value<T>(Result<List<T>> result) {
  return switch (result) {
    Success<List<T>>(:final value) => value,
    Failure<List<T>>() => null,
  };
}
