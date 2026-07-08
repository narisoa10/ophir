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
import 'package:ophir/features/assistant/controller/current_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/controller/operation_controller.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('assistantDashboardBriefingProvider', () {
    test('uses shared financial evaluation context now', () async {
      final fixedNow = DateTime(2035, 6, 18, 9, 45);
      final container = _container(fixedNow: fixedNow);
      addTearDown(container.dispose);

      final result = await container.read(
        assistantDashboardBriefingProvider.future,
      );

      final briefing = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };

      expect(briefing.financialState.period.start, DateTime(2035, 6));
      expect(briefing.financialState.period.end, DateTime(2035, 7));
      expect(briefing.periodDistribution.period.start, DateTime(2035, 6));
      expect(briefing.periodDistribution.period.end, DateTime(2035, 7));
    });

    test('receives fresh totals after operation mutation', () async {
      final fixedNow = DateTime(2035, 6, 18, 9, 45);
      final account = _account();
      final category = _category();
      final operationRepository = _FakeOperationRepository(
        operations: [
          _operation(
            id: 'income',
            type: OperationType.income,
            amount: 5000,
            occurredAt: fixedNow,
            toAccountId: account.id,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          evaluationClockProvider.overrideWithValue(
            EvaluationClock(fixedNow: fixedNow),
          ),
          accountRepositoryProvider.overrideWithValue(
            _FakeAccountRepository(accounts: [account]),
          ),
          operationRepositoryProvider.overrideWithValue(operationRepository),
          categoryRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(categories: [category]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = switch (await container.read(
        assistantDashboardBriefingProvider.future,
      )) {
        Success(:final value) => value,
        Failure() => fail('Expected initial assistant dashboard briefing'),
      };

      expect(initial.financialState.income, 5000);
      expect(initial.financialState.expenses, 0);

      await container
          .read(operationControllerProvider.notifier)
          .createOperation(
            _operation(
              id: 'expense',
              type: OperationType.expense,
              amount: 100,
              occurredAt: fixedNow,
              fromAccountId: account.id,
              categoryId: category.id,
            ),
          );

      final updated = switch (await container.read(
        assistantDashboardBriefingProvider.future,
      )) {
        Success(:final value) => value,
        Failure() => fail('Expected updated assistant dashboard briefing'),
      };

      expect(updated.financialState.income, 5000);
      expect(updated.financialState.expenses, 100);
      expect(updated.periodDistribution.expenseTotal, 100);
    });

    test('uses runtime recommendation from current provider', () async {
      final fixedNow = DateTime(2035, 6, 18, 9, 45);
      final runtimeRecommendation = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.deferOptionalSpending,
      );
      final container = _container(
        fixedNow: fixedNow,
        overrides: [
          currentAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(runtimeRecommendation),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        assistantDashboardBriefingProvider.future,
      );
      final briefing = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };

      expect(briefing.recommendation, same(runtimeRecommendation));
      expect(
        briefing.recommendation?.selectedOptionType,
        FinancialDecisionOptionType.deferOptionalSpending,
      );
    });

    test('explanation follows selected runtime recommendation', () async {
      final fixedNow = DateTime(2035, 6, 18, 9, 45);
      final account = _account();
      final categories = [
        _category(
          id: 'salary',
          type: CategoryType.income,
          uiGroup: CategoryUiGroup.income,
          analyticsGroup: CategoryAnalyticsGroup.income,
          stableKey: CategoryStableKey.incomeEmploymentSalary,
        ),
        _category(
          id: 'rent',
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
          stableKey: CategoryStableKey.expenseHousingRent,
        ),
        _category(
          id: 'haircare',
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
          stableKey: CategoryStableKey.expensePersonalCareHaircare,
        ),
      ];
      final container = _container(
        fixedNow: fixedNow,
        categories: categories,
        operations: [
          _operation(
            id: 'income',
            type: OperationType.income,
            amount: 1000,
            occurredAt: fixedNow,
            toAccountId: account.id,
            categoryId: 'salary',
          ),
          _operation(
            id: 'rent',
            type: OperationType.expense,
            amount: 350,
            occurredAt: fixedNow,
            fromAccountId: account.id,
            categoryId: 'rent',
          ),
          _operation(
            id: 'haircare',
            type: OperationType.expense,
            amount: 450,
            occurredAt: fixedNow,
            fromAccountId: account.id,
            categoryId: 'haircare',
          ),
        ],
      );
      addTearDown(container.dispose);

      final briefing = switch (await container.read(
        assistantDashboardBriefingProvider.future,
      )) {
        Success(:final value) => value,
        Failure() => fail('Expected assistant dashboard briefing'),
      };
      final runtimeRecommendation = switch (await container.read(
        currentAssistantRecommendationProvider.future,
      )) {
        Success(:final value) => value,
        Failure() => fail('Expected runtime recommendation'),
      };

      expect(runtimeRecommendation, isNotNull);
      expect(
        briefing.recommendation?.recommendationId,
        runtimeRecommendation?.recommendationId,
      );
      expect(
        briefing.explanation?.explanationId,
        'explanation.${runtimeRecommendation!.recommendationId}',
      );
    });
  });
}

ProviderContainer _container({
  required DateTime fixedNow,
  List<Category>? categories,
  List<Operation>? operations,
  List<Override> overrides = const [],
}) {
  final account = _account();
  final categoryList = categories ?? [_category()];

  return ProviderContainer(
    overrides: [
      evaluationClockProvider.overrideWithValue(
        EvaluationClock(fixedNow: fixedNow),
      ),
      accountRepositoryProvider.overrideWithValue(
        _FakeAccountRepository(accounts: [account]),
      ),
      operationRepositoryProvider.overrideWithValue(
        _FakeOperationRepository(
          operations:
              operations ??
              [
                _operation(
                  id: 'income',
                  type: OperationType.income,
                  amount: 1000,
                  occurredAt: fixedNow,
                  toAccountId: account.id,
                ),
                _operation(
                  id: 'rent',
                  type: OperationType.expense,
                  amount: 100,
                  occurredAt: fixedNow,
                  fromAccountId: account.id,
                  categoryId: categoryList.first.id,
                ),
              ],
        ),
      ),
      categoryRepositoryProvider.overrideWithValue(
        _FakeCategoryRepository(categories: categoryList),
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
  _FakeOperationRepository({required List<Operation> operations})
    : _operations = [...operations];

  final List<Operation> _operations;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    return Success(List.unmodifiable(_operations));
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    _operations.add(operation);
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    final index = _operations.indexWhere((item) => item.id == operation.id);
    if (index >= 0) {
      _operations[index] = operation;
    } else {
      _operations.add(operation);
    }
    return Success(operation);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    _operations.removeWhere((operation) => operation.id == operationId);
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
  String id = 'rent',
  CategoryType type = CategoryType.expense,
  CategoryUiGroup uiGroup = CategoryUiGroup.housing,
  CategoryAnalyticsGroup analyticsGroup =
      CategoryAnalyticsGroup.essentialExpenses,
  CategoryStableKey stableKey = CategoryStableKey.expenseHousingRent,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: type,
    uiGroup: uiGroup,
    analyticsGroup: analyticsGroup,
    nameKey: 'categoryTaxonomyExpenseHousingRentName',
    iconKey: 'housing',
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
