import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/budget_planning/data/dto/budget_income_source_dto.dart';
import 'package:ophir/features/budget_planning/data/dto/budget_obligation_dto.dart';

void main() {
  group('Budget Planning Supabase category_id', () {
    test('BudgetIncomeSourceDto writes AppCategoryId.name', () {
      final dto = _incomeSourceDto(
        categoryId: AppCategoryId.incomeEmploymentSalary.name,
      );

      expect(
        dto.toJson()['category_id'],
        AppCategoryId.incomeEmploymentSalary.name,
      );
    });

    test('BudgetIncomeSourceDto reads AppCategoryId.name', () {
      final dto = BudgetIncomeSourceDto.fromJson(
        _incomeSourceJson(
          categoryId: AppCategoryId.incomeEmploymentSalary.name,
        ),
      );

      expect(dto.categoryId, AppCategoryId.incomeEmploymentSalary.name);
    });

    test('BudgetIncomeSourceDto writes and reads income name', () {
      final dto = _incomeSourceDto(
        categoryId: AppCategoryId.incomeEmploymentSalary.name,
      );

      expect(dto.toJson()['name'], 'Main salary');
      expect(
        BudgetIncomeSourceDto.fromJson(
          _incomeSourceJson(
            categoryId: AppCategoryId.incomeEmploymentSalary.name,
          ),
        ).name,
        'Main salary',
      );
    });

    test('BudgetIncomeSourceDto reads old rows without name', () {
      final json = _incomeSourceJson(
        categoryId: AppCategoryId.incomeEmploymentSalary.name,
      )..remove('name');

      final dto = BudgetIncomeSourceDto.fromJson(json);

      expect(dto.name, '');
    });

    test('BudgetIncomeSourceDto rejects UUID and dot stable_key', () {
      expect(
        () => _incomeSourceDto(
          categoryId: '00000000-0000-0000-0000-000000000000',
        ).toJson(),
        throwsArgumentError,
      );
      expect(
        () => BudgetIncomeSourceDto.fromJson(
          _incomeSourceJson(categoryId: 'income.employment.salary'),
        ),
        throwsArgumentError,
      );
    });

    test('BudgetObligationDto writes AppCategoryId.name', () {
      final dto = _obligationDto(
        categoryId: AppCategoryId.expenseHousingRent.name,
      );

      expect(
        dto.toJson()['category_id'],
        AppCategoryId.expenseHousingRent.name,
      );
    });

    test('BudgetObligationDto writes tithe with valid uuid id', () {
      const titheId = '4f1ce8f8-1a50-4d11-9a2a-9d92c4ec7db4';
      final dto = _obligationDto(
        id: titheId,
        categoryId: AppCategoryId.expenseGivingTithe.name,
      );
      final json = dto.toJson();

      expect(_isUuidV4(json['id'] as String), isTrue);
      expect(
        json['id'],
        isNot(contains(AppCategoryId.expenseGivingTithe.name)),
      );
      expect(json['category_id'], AppCategoryId.expenseGivingTithe.name);
    });

    test('BudgetObligationDto reads AppCategoryId.name', () {
      final dto = BudgetObligationDto.fromJson(
        _obligationJson(categoryId: AppCategoryId.expenseHousingRent.name),
      );

      expect(dto.categoryId, AppCategoryId.expenseHousingRent.name);
    });

    test('BudgetObligationDto writes and reads debt name', () {
      final dto = _obligationDto(
        categoryId: AppCategoryId.expenseFinanceCreditCardPayment.name,
        name: 'RBC Visa',
      );

      expect(dto.toJson()['name'], 'RBC Visa');
      expect(
        BudgetObligationDto.fromJson(
          _obligationJson(
            categoryId: AppCategoryId.expenseFinanceCreditCardPayment.name,
            name: 'RBC Visa',
          ),
        ).name,
        'RBC Visa',
      );
    });

    test('BudgetObligationDto reads old rows without name', () {
      final json = _obligationJson(
        categoryId: AppCategoryId.expenseHousingRent.name,
      )..remove('name');

      final dto = BudgetObligationDto.fromJson(json);

      expect(dto.name, isNull);
    });

    test('BudgetObligationDto rejects UUID and dot stable_key', () {
      expect(
        () => _obligationDto(
          categoryId: '00000000-0000-0000-0000-000000000000',
        ).toJson(),
        throwsArgumentError,
      );
      expect(
        () => BudgetObligationDto.fromJson(
          _obligationJson(categoryId: 'expense.housing.rent'),
        ),
        throwsArgumentError,
      );
    });
  });
}

BudgetIncomeSourceDto _incomeSourceDto({String? categoryId}) {
  final now = DateTime.utc(2026);

  return BudgetIncomeSourceDto(
    id: 'income-1',
    setupId: 'setup-1',
    userId: 'user-1',
    name: 'Main salary',
    categoryId: categoryId,
    amount: 1000,
    currencyCode: 'CAD',
    frequency: 'monthly',
    source: 'declared',
    confidence: 'estimated',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _incomeSourceJson({String? categoryId}) {
  return {
    'id': 'income-1',
    'setup_id': 'setup-1',
    'user_id': 'user-1',
    'name': 'Main salary',
    'category_id': categoryId,
    'amount': 1000,
    'currency_code': 'CAD',
    'frequency': 'monthly',
    'frequency_interval': null,
    'times_per_year': null,
    'next_date': null,
    'source': 'declared',
    'confidence': 'estimated',
    'is_active': true,
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
  };
}

BudgetObligationDto _obligationDto({
  String id = 'obligation-1',
  String? categoryId,
  String? name,
}) {
  final now = DateTime.utc(2026);

  return BudgetObligationDto(
    id: id,
    setupId: 'setup-1',
    userId: 'user-1',
    categoryId: categoryId,
    obligationType: 'living_expense',
    amount: 1000,
    currencyCode: 'CAD',
    frequency: 'monthly',
    name: name,
    isOverdue: false,
    source: 'declared',
    confidence: 'estimated',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _obligationJson({String? categoryId, String? name}) {
  return {
    'id': 'obligation-1',
    'setup_id': 'setup-1',
    'user_id': 'user-1',
    'category_id': categoryId,
    'obligation_type': 'living_expense',
    'amount': 1000,
    'currency_code': 'CAD',
    'frequency': 'monthly',
    'frequency_interval': null,
    'times_per_year': null,
    'next_due_date': null,
    'minimum_debt_payment': null,
    'name': name,
    'is_overdue': false,
    'source': 'declared',
    'confidence': 'estimated',
    'is_active': true,
    'note': null,
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
  };
}

bool _isUuidV4(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}
