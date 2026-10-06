import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';

void main() {
  group('BudgetSetup.currencyCode', () {
    test('a new budget without items is CAD', () {
      expect(_setup().currencyCode, 'CAD');
    });

    test('is the currency every item carries, never another one', () {
      final setup = _setup(
        incomeSources: [_incomeSource('USD')],
        obligations: [_obligation('USD')],
      );

      expect(setup.currencyCode, 'USD');
    });

    test('refuses to pick a currency when items disagree', () {
      final setup = _setup(
        incomeSources: [_incomeSource('CAD')],
        obligations: [_obligation('USD')],
      );

      expect(() => setup.currencyCode, throwsStateError);
    });
  });
}

BudgetSetup _setup({
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: 'user-1',
    userId: 'user-1',
    status: 'draft',
    version: 1,
    currentStep: 0,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: incomeSources,
    obligations: obligations,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource(String currencyCode) {
  return BudgetIncomeSource(
    id: 'income-$currencyCode',
    setupId: 'user-1',
    userId: 'user-1',
    name: 'Salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: 1000,
    currencyCode: currencyCode,
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _obligation(String currencyCode) {
  return BudgetObligation(
    id: 'obligation-$currencyCode',
    setupId: 'user-1',
    userId: 'user-1',
    categoryId: AppCategoryId.expenseHousingRent.name,
    obligationType: 'living_expense',
    amount: 500,
    currencyCode: currencyCode,
    frequency: BudgetFrequency.monthly,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}
