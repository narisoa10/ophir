import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/adapters/operation_adapter.dart';

void main() {
  group('OperationAdapter', () {
    test('resolves inactive taxonomy category for operation display', () {
      final presentation = const OperationAdapter()
          .toPresentation(_operation(categoryId: 'internet'), [
            _category(
              id: 'internet',
              stableKey: 'expense.housing.internet',
              isActive: false,
            ),
          ], AppLocalizationsEn());

      expect(presentation.title, 'Housing');
      expect(presentation.subtitle, 'Internet');
    });
  });
}

Category _category({
  required String id,
  String? stableKey,
  bool isActive = true,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: 'categoryTaxonomyExpenseHousingInternetName',
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

Operation _operation({String? categoryId}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: 'operation',
    userId: 'user',
    type: OperationType.expense,
    amount: 42,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
  );
}
