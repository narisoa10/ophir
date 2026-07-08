import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/evaluation/evaluation_clock.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context_provider.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/assistant/controller/assistant_dashboard_briefing_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_diagnostics_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('financialIntelligenceDiagnosticsProvider', () {
    test('builds diagnostics snapshot from compatibility output', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDiagnosticsProvider.future,
      );

      final diagnostics = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected financial intelligence diagnostics'),
      };

      expect(diagnostics.period.start, DateTime(2035, 6));
      expect(diagnostics.period.end, DateTime(2035, 7));
      expect(diagnostics.incomeDenominator, 5000);
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.ordinarySpendingTotal,
        ),
        100,
      );
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.ordinarySpendingRatio,
        ),
        100 / 5000,
      );
    });

    test('uses legacy briefing income total as denominator', () async {
      final container = _container();
      addTearDown(container.dispose);

      final briefingResult = await container.read(
        assistantDashboardBriefingProvider.future,
      );
      final diagnosticsResult = await container.read(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final briefing = switch (briefingResult) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };
      final diagnostics = switch (diagnosticsResult) {
        Success(:final value) => value,
        Failure() => fail('Expected financial intelligence diagnostics'),
      };
      final incomeModel = briefing.modelResults.singleWhere(
        (model) => model.modelType == FinancialModelType.incomeTotal,
      );

      expect(diagnostics.incomeDenominator, incomeModel.value);
    });

    test('does not create provider cycle with Assistant briefing', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final briefingProviderSource = File(
        'lib/features/assistant/controller/assistant_dashboard_briefing_provider.dart',
      ).readAsStringSync();

      expect(result, isA<Success>());
      expect(
        briefingProviderSource,
        isNot(contains('financialIntelligenceDiagnosticsProvider')),
      );
    });

    test('does not change existing Assistant recommendation output', () async {
      final container = _container();
      addTearDown(container.dispose);

      final beforeResult = await container.read(
        assistantDashboardBriefingProvider.future,
      );
      await container.read(financialIntelligenceDiagnosticsProvider.future);
      final afterResult = await container.read(
        assistantDashboardBriefingProvider.future,
      );
      final before = switch (beforeResult) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };
      final after = switch (afterResult) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };

      expect(
        after.recommendation?.selectedOptionId,
        before.recommendation?.selectedOptionId,
      );
      expect(after.modelResults.length, before.modelResults.length);
      expect(after.deviations.length, before.deviations.length);
    });

    test('zero income is safe', () async {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final container = _container(
        categories: [rent],
        operations: [
          _operation(
            id: 'rent',
            type: OperationType.expense,
            amount: 100,
            occurredAt: DateTime(2035, 6, 10),
            fromAccountId: 'cash',
            categoryId: rent.id,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final diagnostics = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected financial intelligence diagnostics'),
      };

      expect(diagnostics.incomeDenominator, 0);
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.ordinarySpendingRatio,
        ),
        0,
      );
    });

    test('special actions are reflected in intelligence models', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final diagnostics = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected financial intelligence diagnostics'),
      };

      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.assetBuildingTotal,
        ),
        300,
      );
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.behavioralSavingsTotal,
        ),
        300,
      );
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.debtReductionTotal,
        ),
        600,
      );
      expect(
        diagnostics.modelsSnapshot.valueFor(
          FinancialIntelligenceModelType.contextRequiredTotal,
        ),
        600,
      );
    });
  });
}

ProviderContainer _container({
  DateTime? fixedNow,
  List<Operation>? operations,
  List<Category>? categories,
}) {
  final now = fixedNow ?? DateTime(2035, 6, 18, 9, 45);
  final account = _account();
  final categoryList = categories ?? _defaultCategories();

  return ProviderContainer(
    overrides: [
      evaluationClockProvider.overrideWithValue(EvaluationClock(fixedNow: now)),
      accountRepositoryProvider.overrideWithValue(
        _FakeAccountRepository(accounts: [account]),
      ),
      operationRepositoryProvider.overrideWithValue(
        _FakeOperationRepository(
          operations: operations ?? _defaultOperations(account.id),
        ),
      ),
      categoryRepositoryProvider.overrideWithValue(
        _FakeCategoryRepository(categories: categoryList),
      ),
    ],
  );
}

List<Category> _defaultCategories() {
  return [
    _category(
      id: 'salary',
      type: CategoryType.income,
      stableKey: CategoryStableKey.incomeEmploymentSalary,
    ),
    _category(id: 'rent', stableKey: CategoryStableKey.expenseHousingRent),
    _category(
      id: 'savings',
      stableKey: CategoryStableKey.expenseFinanceSavings,
    ),
    _category(
      id: 'credit-card',
      stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
    ),
  ];
}

List<Operation> _defaultOperations(String accountId) {
  final now = DateTime(2035, 6, 18, 9, 45);

  return [
    _operation(
      id: 'income',
      type: OperationType.income,
      amount: 5000,
      occurredAt: now,
      toAccountId: accountId,
      categoryId: 'salary',
    ),
    _operation(
      id: 'rent',
      type: OperationType.expense,
      amount: 100,
      occurredAt: now,
      fromAccountId: accountId,
      categoryId: 'rent',
    ),
    _operation(
      id: 'savings',
      type: OperationType.expense,
      amount: 300,
      occurredAt: now,
      fromAccountId: accountId,
      categoryId: 'savings',
    ),
    _operation(
      id: 'credit-card',
      type: OperationType.expense,
      amount: 600,
      occurredAt: now,
      fromAccountId: accountId,
      categoryId: 'credit-card',
    ),
  ];
}

final class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository({required this.accounts});

  final List<Account> accounts;

  @override
  Future<Result<List<Account>>> getAccounts() async {
    return Success(accounts);
  }

  @override
  Future<Result<Account>> createAccount(Account account) async {
    return Success(account);
  }

  @override
  Future<Result<Account>> updateAccount(Account account) async {
    return Success(account);
  }

  @override
  Future<Result<void>> archiveAccount(String accountId) async {
    return const Success(null);
  }
}

final class _FakeOperationRepository implements OperationRepository {
  const _FakeOperationRepository({required this.operations});

  final List<Operation> operations;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    return Success(operations);
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    return const Success(null);
  }
}

final class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository({required this.categories});

  final List<Category> categories;

  @override
  Future<Result<List<Category>>> getCategories() async {
    return Success(categories);
  }

  @override
  Future<Result<List<Category>>> getCategoriesByType(CategoryType type) async {
    return Success(
      categories
          .where((category) => category.type == type && category.isActive)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Category>>> getTaxonomyCategoriesByType(
    CategoryType type,
  ) async {
    return Success(
      categories
          .where(
            (category) => category.type == type && category.stableKey != null,
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids) async {
    return Success(
      categories
          .where((category) => ids.contains(category.id))
          .toList(growable: false),
    );
  }
}

Account _account() {
  final now = DateTime.utc(2026);

  return Account(
    id: 'cash',
    userId: 'user',
    name: 'Cash',
    type: AccountType.cash,
    currencyCode: 'CAD',
    initialBalance: 1000,
    iconKey: 'cash',
    colorKey: 'green',
    sortOrder: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Category _category({
  required String id,
  required CategoryStableKey stableKey,
  CategoryType type = CategoryType.expense,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: type,
    uiGroup: type == CategoryType.income
        ? CategoryUiGroup.income
        : CategoryUiGroup.dailyLife,
    analyticsGroup: type == CategoryType.income
        ? CategoryAnalyticsGroup.income
        : CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: 'categoryUnknownLegacy',
    iconKey: 'other',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey.toJson(),
  );
}

Operation _operation({
  required String id,
  required OperationType type,
  required double amount,
  required DateTime occurredAt,
  String? fromAccountId,
  String? toAccountId,
  String? categoryId,
}) {
  return Operation(
    id: id,
    userId: 'user',
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: occurredAt,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}
