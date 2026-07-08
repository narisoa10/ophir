import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/evaluation/evaluation_clock.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context_provider.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/assistant/controller/financial_behavior_compatibility_output_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';
import 'package:ophir/features/dashboard/controller/dashboard_compatibility_read_model_provider.dart';
import 'package:ophir/features/dashboard/domain/entities/dashboard_financial_summary.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('dashboardCompatibilityReadModelProvider', () {
    test('builds dashboard compatibility read model', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.legacySummary.cashFlow.income, 1000);
      expect(readModel.legacySummary.cashFlow.expenses, 100);
      expect(readModel.intelligenceOutput, isNotNull);
      expect(readModel.intelligenceOrdinarySpendingTotal, 100);
    });

    test('supports unavailable intelligence output', () async {
      final container = _container(
        overrides: [
          financialBehaviorCompatibilityOutputProvider.overrideWith(
            (ref) async => const Failure(UnknownFailure()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.legacySummary.cashFlow.expenses, 100);
      expect(readModel.hasIntelligenceComparison, isFalse);
      expect(readModel.intelligenceOutput, isNull);
    });

    test('supports failed intelligence output', () async {
      final container = _container(
        overrides: [
          financialBehaviorCompatibilityOutputProvider.overrideWith(
            (ref) async => const Failure(UnknownFailure()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.legacySummary.cashFlow.expenses, 100);
      expect(readModel.hasIntelligenceComparison, isFalse);
      expect(readModel.intelligenceOutput, isNull);
    });

    test('builds read model directly from compatibility output', () async {
      final container = _container();
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.intelligenceOutput, isNotNull);
      expect(readModel.intelligenceOutput!.totals.legacyExpenseTotal, 100);
      expect(readModel.intelligenceOrdinarySpendingTotal, 100);
      expect(readModel.legacyVsIntelligenceDifference, 0);
      expect(readModel.specialActionTotals!.contextRequiredTotal, 0);
    });

    test('keeps legacy summary unchanged', () async {
      final legacySummary = _legacySummary();
      final container = ProviderContainer(
        overrides: [
          dashboardLegacyFinancialSummaryProvider.overrideWith(
            (ref) async => Success(legacySummary),
          ),
          financialBehaviorCompatibilityOutputProvider.overrideWith(
            (ref) async => const Failure(UnknownFailure()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.legacySummary, same(legacySummary));
      expect(readModel.legacyExpenseTotal, 1500);
    });

    test('keeps intelligence output unchanged', () async {
      final output = _output();
      final container = _container(
        overrides: [
          financialBehaviorCompatibilityOutputProvider.overrideWith(
            (ref) async => Success(output),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.intelligenceOutput, same(output));
      expect(readModel.legacyVsIntelligenceDifference, 500);
      expect(readModel.specialActionTotals!.assetBuildingTotal, 300);
    });

    test('uses evaluation context now for legacy summary path', () async {
      final fixedNow = DateTime(2030, 12, 15, 10, 30);
      final container = _container(
        now: fixedNow,
        overrides: [
          evaluationClockProvider.overrideWithValue(
            EvaluationClock(fixedNow: fixedNow),
          ),
          financialBehaviorCompatibilityOutputProvider.overrideWith(
            (ref) async => const Failure(UnknownFailure()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardCompatibilityReadModelProvider.future,
      );

      final readModel = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected dashboard compatibility read model'),
      };

      expect(readModel.legacySummary.cashFlow.income, 1000);
      expect(readModel.legacySummary.cashFlow.expenses, 100);
      expect(readModel.legacySummary.today.operationCount, 2);
    });

    test('does not connect compatibility provider to dashboard presentation', () {
      final builderSource = File(
        'lib/features/dashboard/presentation/widgets/dashboard_presentation_builder.dart',
      ).readAsStringSync();
      final adapterSource = File(
        'lib/features/dashboard/presentation/adapters/dashboard_presentation_adapter.dart',
      ).readAsStringSync();

      expect(
        builderSource,
        isNot(contains('dashboardCompatibilityReadModelProvider')),
      );
      expect(
        adapterSource,
        isNot(contains('dashboardCompatibilityReadModelProvider')),
      );
      expect(adapterSource, isNot(contains('DashboardCompatibilityReadModel')));
    });

    test('read model provider uses compatibility output directly', () {
      final providerSource = File(
        'lib/features/dashboard/controller/dashboard_compatibility_read_model_provider.dart',
      ).readAsStringSync();

      expect(
        providerSource,
        contains('financialBehaviorCompatibilityOutputProvider'),
      );
    });

    test('dashboard compatibility read model does not read snapshot facts', () {
      final readModelSource = File(
        'lib/features/dashboard/domain/entities/dashboard_compatibility_read_model.dart',
      ).readAsStringSync();

      expect(readModelSource, isNot(contains('.snapshot')));
      expect(readModelSource, isNot(contains('snapshot.facts')));
    });
  });
}

ProviderContainer _container({
  DateTime? now,
  List<Override> overrides = const [],
}) {
  final occurredAt = now ?? DateTime.now();
  final account = _account();
  final category = _category();

  return ProviderContainer(
    overrides: [
      accountRepositoryProvider.overrideWithValue(
        _FakeAccountRepository(accounts: [account]),
      ),
      operationRepositoryProvider.overrideWithValue(
        _FakeOperationRepository(
          operations: [
            _operation(
              id: 'income',
              type: OperationType.income,
              amount: 1000,
              occurredAt: occurredAt,
              toAccountId: account.id,
            ),
            _operation(
              id: 'rent',
              type: OperationType.expense,
              amount: 100,
              occurredAt: occurredAt,
              fromAccountId: account.id,
              categoryId: category.id,
            ),
          ],
        ),
      ),
      categoryRepositoryProvider.overrideWithValue(
        _FakeCategoryRepository(categories: [category]),
      ),
      ...overrides,
    ],
  );
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

Category _category() {
  final now = DateTime.utc(2026);

  return Category(
    id: 'rent',
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.housing,
    analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
    nameKey: 'categoryTaxonomyExpenseHousingRentName',
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: 'expense.housing.rent',
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

DashboardFinancialSummary _legacySummary() {
  return const DashboardFinancialSummary(
    currencyCode: 'CAD',
    today: DashboardTodaySummary(
      income: 100,
      expenses: 50,
      net: 50,
      operationCount: 2,
    ),
    recordedBalance: 10000,
    cashFlow: DashboardCashFlowSummary(income: 4000, expenses: 1500, net: 2500),
    expenseGroups: [],
    insights: [],
    upcomingRecurring: [],
    actions: [],
  );
}

FinancialBehaviorCompatibilityOutput _output() {
  return FinancialBehaviorCompatibilityOutput(
    snapshot: FinancialBehaviorFactsSnapshot(facts: []),
    totals: const FinancialBehaviorTotals(
      legacyExpenseTotal: 1500,
      ordinarySpendingTotal: 1000,
      assetBuildingTotal: 300,
      debtReductionTotal: 200,
      cashMovementTotal: 80,
      dataAdjustmentTotal: 40,
      contextRequiredTotal: 320,
      behavioralSavingsTotal: 300,
      legacyVsIntelligenceDifference: 500,
      unresolvedCount: 0,
    ),
  );
}
