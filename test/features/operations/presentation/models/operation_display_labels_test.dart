import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/models/operation_display_labels.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  group('OperationDisplayLabels', () {
    test('shows note and full category path', () {
      final labels = OperationDisplayLabels.forOperation(
        _operation(
          note: 'Costco',
          categoryId: AppCategoryId.expenseFoodGroceries.name,
        ),
        l10n,
      );

      expect(labels.title, 'Costco');
      expect(labels.subtitle, 'Alimentation · Épicerie');
    });

    test('shows leaf category and group when merchant is missing', () {
      final labels = OperationDisplayLabels.forOperation(
        _operation(categoryId: AppCategoryId.expenseFoodGroceries.name),
        l10n,
      );

      expect(labels.title, 'Épicerie');
      expect(labels.subtitle, 'Alimentation');
    });
  });
}

Operation _operation({String? note, String? categoryId}) {
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
    note: note,
    categoryId: categoryId,
  );
}
