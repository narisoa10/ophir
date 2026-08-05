import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';

void main() {
  group('AppDatabase budget planning', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and reads BudgetSetup', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(userId: 'user-1'),
        'CAD',
      );

      final setup = await database.getBudgetSetup('user-1');

      expect(setup?.userId, 'user-1');
      expect(setup?.household.adultsCount, 1);
      expect(setup?.status, 'draft');
    });

    test('saves income sources with AppCategoryId.name', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(
          userId: 'user-1',
          incomeSources: [_incomeSource(id: 'income-1', userId: 'user-1')],
        ),
        'CAD',
      );

      final incomeSources = await database.getBudgetIncomeSources('user-1');

      expect(incomeSources, hasLength(1));
      expect(
        incomeSources.single.categoryId,
        AppCategoryId.incomeEmploymentSalary.name,
      );
      expect(incomeSources.single.name, 'Main salary');
    });

    test('saves obligations with AppCategoryId.name', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(
          userId: 'user-1',
          obligations: [_obligation(id: 'obligation-1', userId: 'user-1')],
        ),
        'CAD',
      );

      final obligations = await database.getBudgetObligations('user-1');

      expect(obligations, hasLength(1));
      expect(
        obligations.single.categoryId,
        AppCategoryId.expenseHousingRent.name,
      );
    });

    test(
      'saves and reads debt names with duplicate categoryId values',
      () async {
        await database.saveBudgetSetupWithCurrency(
          _setup(
            userId: 'user-1',
            obligations: [
              _debtObligation(id: 'debt-1', userId: 'user-1', name: 'RBC Visa'),
              _debtObligation(
                id: 'debt-2',
                userId: 'user-1',
                name: 'Backup Visa',
              ),
            ],
          ),
          'CAD',
        );

        final obligations = await database.getBudgetObligations('user-1');

        expect(obligations, hasLength(2));
        expect(
          obligations.map((obligation) => obligation.id),
          containsAll(['debt-1', 'debt-2']),
        );
        expect(
          obligations.map((obligation) => obligation.name),
          containsAll(['RBC Visa', 'Backup Visa']),
        );
        expect(obligations.map((obligation) => obligation.categoryId).toSet(), {
          AppCategoryId.expenseFinanceCreditCardPayment.name,
        });
      },
    );

    test('replace does not create duplicates', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(userId: 'user-1'),
        'CAD',
      );
      await database.replaceBudgetIncomeSources('user-1', [
        _incomeSource(id: 'income-1', userId: 'user-1', amount: 100),
      ]);
      await database.replaceBudgetIncomeSources('user-1', [
        _incomeSource(id: 'income-1', userId: 'user-1', amount: 200),
      ]);

      final incomeSources = await database.getBudgetIncomeSources('user-1');

      expect(incomeSources, hasLength(1));
      expect(incomeSources.single.amount, 200);
      expect(incomeSources.single.name, 'Main salary');
    });

    test('does not mix different userId values', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(
          userId: 'user-1',
          incomeSources: [_incomeSource(id: 'income-1', userId: 'user-1')],
        ),
        'CAD',
      );
      await database.saveBudgetSetupWithCurrency(
        _setup(
          userId: 'user-2',
          incomeSources: [_incomeSource(id: 'income-2', userId: 'user-2')],
        ),
        'CAD',
      );

      final firstUser = await database.getBudgetIncomeSources('user-1');
      final secondUser = await database.getBudgetIncomeSources('user-2');

      expect(firstUser.single.id, 'income-1');
      expect(secondUser.single.id, 'income-2');
    });

    test('completed setup remains local after sync status changes', () async {
      await database.saveBudgetSetupWithCurrency(
        _setup(userId: 'user-1', status: 'completed'),
        'CAD',
      );

      await database.markBudgetSyncFailed('user-1');
      var setup = await database.getBudgetSetup('user-1');
      expect(setup?.status, 'completed');

      await database.markBudgetSynced('user-1');
      setup = await database.getBudgetSetup('user-1');
      expect(setup?.status, 'completed');
    });
  });
}

BudgetSetup _setup({
  required String userId,
  String status = 'draft',
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: userId,
    userId: userId,
    status: status,
    version: 1,
    currentStep: status == 'completed' ? 3 : 0,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: incomeSources,
    obligations: obligations,
    completedAt: status == 'completed' ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource({
  required String id,
  required String userId,
  double amount = 100,
}) {
  return BudgetIncomeSource(
    id: id,
    setupId: userId,
    userId: userId,
    name: 'Main salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: amount,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _obligation({
  required String id,
  required String userId,
  double amount = 100,
}) {
  return BudgetObligation(
    id: id,
    setupId: userId,
    userId: userId,
    categoryId: AppCategoryId.expenseHousingRent.name,
    obligationType: 'living_expense',
    amount: amount,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _debtObligation({
  required String id,
  required String userId,
  required String name,
}) {
  return BudgetObligation(
    id: id,
    setupId: userId,
    userId: userId,
    categoryId: AppCategoryId.expenseFinanceCreditCardPayment.name,
    obligationType: 'debt_minimum',
    amount: 100,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    minimumDebtPayment: 100,
    name: name,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}
