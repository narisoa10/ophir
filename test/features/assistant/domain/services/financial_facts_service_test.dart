import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_data_gap_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_facts_service.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  const service = FinancialFactsService();

  group('FinancialFactsService', () {
    test('extracts income expense and transfer facts', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(id: 'income', type: OperationType.income),
          _operation(id: 'expense', type: OperationType.expense),
          _operation(id: 'transfer', type: OperationType.transfer),
        ],
        categories: const [],
      );

      expect(
        snapshot.facts.map((fact) => fact.type),
        containsAll([
          FinancialFactType.incomeOperation,
          FinancialFactType.expenseOperation,
          FinancialFactType.transferOperation,
        ]),
      );
      expect(
        snapshot.facts
            .where(
              (fact) =>
                  fact.type == FinancialFactType.incomeOperation ||
                  fact.type == FinancialFactType.expenseOperation ||
                  fact.type == FinancialFactType.transferOperation,
            )
            .every(
              (fact) =>
                  fact.source == FinancialFactSource.manualRecorded &&
                  fact.confidence == FinancialFactConfidence.high,
            ),
        isTrue,
      );
    });

    test('extracts recurring facts', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'rent',
            type: OperationType.expense,
            recurrence: OperationRecurrence.monthly,
            isRecurring: true,
          ),
        ],
        categories: const [],
      );

      final recurringFact = snapshot.facts.singleWhere(
        (fact) => fact.type == FinancialFactType.recurringOperation,
      );

      expect(recurringFact.operationId, 'rent');
      expect(recurringFact.recurrence, OperationRecurrence.monthly);
      expect(recurringFact.source, FinancialFactSource.manualRecorded);
    });

    test('extracts categorized and uncategorized facts', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'categorized',
            type: OperationType.expense,
            categoryId: 'groceries',
          ),
          _operation(id: 'uncategorized', type: OperationType.expense),
        ],
        categories: [_category(id: 'groceries')],
      );

      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.categorizedOperation &&
              fact.operationId == 'categorized' &&
              fact.categoryId == 'groceries',
        ),
        isTrue,
      );
      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.uncategorizedOperation &&
              fact.operationId == 'uncategorized',
        ),
        isTrue,
      );
      expect(
        snapshot.dataGaps.any(
          (gap) =>
              gap.type == FinancialFactDataGapType.missingCategory &&
              gap.sourceId == 'uncategorized',
        ),
        isTrue,
      );
    });

    test('extracts analyticsGroup facts from categories', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'food',
            type: OperationType.expense,
            categoryId: 'groceries',
          ),
        ],
        categories: [
          _category(
            id: 'groceries',
            uiGroup: CategoryUiGroup.dailyLife,
            analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
          ),
        ],
      );

      final analyticsFact = snapshot.facts.singleWhere(
        (fact) => fact.type == FinancialFactType.analyticsGroup,
      );

      expect(analyticsFact.operationId, 'food');
      expect(analyticsFact.categoryId, 'groceries');
      expect(
        analyticsFact.analyticsGroup,
        CategoryAnalyticsGroup.essentialExpenses,
      );
      expect(analyticsFact.source, FinancialFactSource.category);
    });

    test(
      'extracts every analytics group enum value from active categories',
      () {
        final operations = [
          for (final group in CategoryAnalyticsGroup.values)
            _operation(
              id: group.name,
              type: OperationType.expense,
              categoryId: group.name,
            ),
        ];
        final categories = [
          for (final group in CategoryAnalyticsGroup.values)
            _category(id: group.name, analyticsGroup: group),
        ];

        final snapshot = service.buildSnapshot(
          operations: operations,
          categories: categories,
        );
        final analyticsGroups = snapshot.facts
            .where((fact) => fact.type == FinancialFactType.analyticsGroup)
            .map((fact) => fact.analyticsGroup)
            .toSet();

        expect(analyticsGroups, CategoryAnalyticsGroup.values.toSet());
      },
    );

    test('inactive category does not create active analytics group fact', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'inactive-category',
            type: OperationType.expense,
            categoryId: 'archived',
          ),
        ],
        categories: [_category(id: 'archived', isActive: false)],
      );

      expect(
        snapshot.facts.any(
          (fact) => fact.type == FinancialFactType.analyticsGroup,
        ),
        isFalse,
      );
      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.uncategorizedOperation &&
              fact.operationId == 'inactive-category',
        ),
        isTrue,
      );
      expect(
        snapshot.dataGaps.any(
          (gap) =>
              gap.type == FinancialFactDataGapType.missingCategory &&
              gap.sourceId == 'inactive-category',
        ),
        isTrue,
      );
    });

    test('inactive taxonomy category with stableKey is usable', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'taxonomy-category',
            type: OperationType.expense,
            categoryId: 'internet',
          ),
        ],
        categories: [
          _category(
            id: 'internet',
            isActive: false,
            stableKey: 'expense.housing.internet',
          ),
        ],
      );

      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.categorizedOperation &&
              fact.operationId == 'taxonomy-category' &&
              fact.categoryId == 'internet',
        ),
        isTrue,
      );
      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.uncategorizedOperation &&
              fact.operationId == 'taxonomy-category',
        ),
        isFalse,
      );
      expect(
        snapshot.dataGaps.any(
          (gap) =>
              gap.type == FinancialFactDataGapType.missingCategory &&
              gap.sourceId == 'taxonomy-category',
        ),
        isFalse,
      );
    });

    test('extracts account-linked and unlinked facts', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'linked',
            type: OperationType.expense,
            fromAccountId: 'cash',
          ),
          _operation(id: 'unlinked', type: OperationType.expense),
        ],
        categories: const [],
        accounts: [_account(id: 'cash')],
      );

      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.accountLinked &&
              fact.operationId == 'linked' &&
              fact.accountId == 'cash',
        ),
        isTrue,
      );
      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.unlinked &&
              fact.operationId == 'unlinked',
        ),
        isTrue,
      );
      expect(
        snapshot.dataGaps.any(
          (gap) =>
              gap.type == FinancialFactDataGapType.missingAccountLink &&
              gap.sourceId == 'unlinked',
        ),
        isTrue,
      );
    });

    test('extracts account balance seed facts for active accounts only', () {
      final snapshot = service.buildSnapshot(
        operations: const [],
        categories: const [],
        accounts: [
          _account(id: 'active', initialBalance: 100),
          _account(id: 'archived', initialBalance: 200, isArchived: true),
        ],
      );

      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.accountBalanceSeed &&
              fact.accountId == 'active' &&
              fact.amount == 100,
        ),
        isTrue,
      );
      expect(
        snapshot.facts.any((fact) => fact.accountId == 'archived'),
        isFalse,
      );
    });

    test('returns empty snapshot for empty input', () {
      final snapshot = service.buildSnapshot(
        operations: const [],
        categories: const [],
      );

      expect(snapshot.facts, isEmpty);
      expect(snapshot.dataGaps, isEmpty);
    });

    test('marks unavailable referenced account as data gap', () {
      final snapshot = service.buildSnapshot(
        operations: [
          _operation(
            id: 'missing-account',
            type: OperationType.income,
            toAccountId: 'unknown',
          ),
        ],
        categories: const [],
        accounts: const [],
      );

      expect(
        snapshot.facts.any(
          (fact) =>
              fact.type == FinancialFactType.accountLinked &&
              fact.accountId == 'unknown',
        ),
        isTrue,
      );
      expect(
        snapshot.dataGaps.any(
          (gap) =>
              gap.type == FinancialFactDataGapType.missingAccountData &&
              gap.sourceId == 'missing-account',
        ),
        isTrue,
      );
    });
  });
}

Operation _operation({
  required String id,
  required OperationType type,
  String? fromAccountId,
  String? toAccountId,
  String? categoryId,
  OperationRecurrence recurrence = OperationRecurrence.none,
  bool isRecurring = false,
}) {
  final now = DateTime(2026, 1, 1);

  return Operation(
    id: id,
    userId: 'user',
    type: type,
    amount: 42,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: recurrence,
    isRecurring: isRecurring,
    createdAt: now,
    updatedAt: now,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
  );
}

Category _category({
  required String id,
  CategoryUiGroup uiGroup = CategoryUiGroup.dailyLife,
  CategoryAnalyticsGroup analyticsGroup =
      CategoryAnalyticsGroup.flexibleExpenses,
  bool isActive = true,
  String? stableKey,
}) {
  final now = DateTime(2026, 1, 1);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: uiGroup,
    analyticsGroup: analyticsGroup,
    nameKey: 'category.$id.name',
    iconKey: 'category.$id.icon',
    colorKey: 'category.$id.color',
    sortOrder: 0,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'category.$id.example',
    stableKey: stableKey,
  );
}

Account _account({
  required String id,
  double initialBalance = 0,
  bool isArchived = false,
}) {
  final now = DateTime(2026, 1, 1);

  return Account(
    id: id,
    userId: 'user',
    name: id,
    type: AccountType.cash,
    currencyCode: 'CAD',
    initialBalance: initialBalance,
    iconKey: 'cash',
    colorKey: 'blue',
    sortOrder: 0,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}
