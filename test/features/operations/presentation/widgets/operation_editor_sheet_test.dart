import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/categories/presentation/app_category_picker.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_editor_bottom_sheet.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_sheet.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_result.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('OperationEditorSheet', () {
    testWidgets('accepts ready category and uses one editor bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_editorApp(category: _rentCategory()));

      expect(find.byType(OperationEditorSheet), findsOneWidget);
      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text(_l10n.operationAddExpenseTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-category-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-frequency-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-next-date-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-note-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-recurrence-field')),
        findsNothing,
      );
      expect(find.text(_l10n.operationDescriptionHint), findsNothing);
      expect(find.text(_l10n.operationRecurrenceTitle), findsNothing);
    });

    testWidgets('uses grouped category picker inside editor', (tester) async {
      await tester.pumpWidget(_editorApp(category: _rentCategory()));

      expect(find.byType(OperationEditorSheet), findsOneWidget);
      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.byType(AppCategoryPickerField), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppEditorBottomSheet),
          matching: find.byKey(
            const ValueKey<String>('operation-category-field'),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(_rentCategory().name(_l10n)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('app-category-picker-group-housing')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('app-category-picker-group-employmentIncome'),
        ),
        findsNothing,
      );
    });

    testWidgets('switches title and category scope without moving form shell', (
      tester,
    ) async {
      await tester.pumpWidget(_editorApp(category: _rentCategory()));

      final expenseSheetRect = tester.getRect(
        find.byType(AppEditorBottomSheet),
      );
      final rentName = _rentCategory().name(_l10n);
      final salaryName = _salaryCategory().name(_l10n);

      expect(find.text(_l10n.operationAddExpenseTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsNothing,
      );
      expect(find.text(rentName), findsOneWidget);
      expect(find.text(salaryName), findsNothing);

      await tester.tap(find.text(_l10n.operationIncome));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.operationAddIncomeTitle), findsOneWidget);
      expect(find.text(_l10n.operationAddExpenseTitle), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsOneWidget,
      );
      expect(find.text(salaryName), findsOneWidget);
      expect(find.text(rentName), findsNothing);
      final incomeSheetRect = tester.getRect(find.byType(AppEditorBottomSheet));
      expect(incomeSheetRect.left, expenseSheetRect.left);
      expect(incomeSheetRect.width, expenseSheetRect.width);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(_l10n.operationExpense));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.operationAddExpenseTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsNothing,
      );
      expect(find.text(rentName), findsOneWidget);
      final saveButton = find.widgetWithText(ElevatedButton, _l10n.commonSave);
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      expect(tester.takeException(), isNull);
    });

    testWidgets('income category picker excludes expense categories', (
      tester,
    ) async {
      await tester.pumpWidget(_editorApp(category: _rentCategory()));

      await tester.tap(find.text(_l10n.operationIncome));
      await tester.pumpAndSettle();

      expect(find.text(_salaryCategory().name(_l10n)), findsOneWidget);
      expect(find.text(_rentCategory().name(_l10n)), findsNothing);

      await tester.tap(find.text(_salaryCategory().name(_l10n)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('app-category-picker-group-employmentIncome'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('app-category-picker-group-housing')),
        findsNothing,
      );
    });

    testWidgets('create result saves category id from widget category', (
      tester,
    ) async {
      OperationEditorResult? result;

      await tester.pumpWidget(
        _modalEditorApp(
          category: _rentCategory(),
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '10',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, _l10n.commonSave));
      await tester.pumpAndSettle();

      expect(result?.isArchived, isFalse);
      expect(result?.type, OperationType.expense);
      expect(result?.amount, 10);
      expect(result?.categoryId, AppCategoryId.expenseHousingRent.name);
      expect(result?.note, isNull);
    });

    testWidgets('edit result preserves selected category contract', (
      tester,
    ) async {
      OperationEditorResult? result;

      await tester.pumpWidget(
        _modalEditorApp(
          category: _rentCategory(),
          operation: _operation(amount: 25),
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '50',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, _l10n.commonSave));
      await tester.pumpAndSettle();

      expect(result?.isArchived, isFalse);
      expect(result?.amount, 50);
      expect(result?.categoryId, AppCategoryId.expenseHousingRent.name);
      expect(result?.recurrence, OperationRecurrence.none);
      expect(result?.note, isNull);
    });

    testWidgets('income create result saves current type and category', (
      tester,
    ) async {
      OperationEditorResult? result;

      await tester.pumpWidget(
        _modalEditorApp(
          category: _rentCategory(),
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.operationIncome));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-name-field')),
        'Salary',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '10',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, _l10n.commonSave));
      await tester.pumpAndSettle();

      expect(result?.isArchived, isFalse);
      expect(result?.type, OperationType.income);
      expect(result?.amount, 10);
      expect(result?.categoryId, AppCategoryId.incomeEmploymentSalary.name);
      expect(result?.note, 'Salary');
    });

    testWidgets('archive result is returned from edit delete action', (
      tester,
    ) async {
      OperationEditorResult? result;

      await tester.pumpWidget(
        _modalEditorApp(
          category: _rentCategory(),
          operation: _operation(),
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, _l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(result?.isArchived, isTrue);
    });

    testWidgets('Plaid editor exposes only category controls', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          category: _rentCategory(),
          operation: _operation(source: OperationSource.plaid),
        ),
      );

      expect(find.byType(OperationEditorSheet), findsOneWidget);
      expect(find.byType(AppCategoryPickerField), findsOneWidget);
      expect(find.text(_l10n.operationExpense), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-frequency-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('operation-next-date-field')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, _l10n.commonDelete), findsNothing);
    });

    testWidgets('Plaid editor can save explicit uncategorized override', (
      tester,
    ) async {
      OperationEditorResult? result;

      await tester.pumpWidget(
        _modalEditorApp(
          category: _rentCategory(),
          operation: _operation(source: OperationSource.plaid),
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_l10n.categoryTaxonomyExpenseOtherUncategorizedName),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, _l10n.commonSave));
      await tester.pumpAndSettle();

      expect(result?.isArchived, isFalse);
      expect(result?.categoryId, isNull);
      expect(result?.type, OperationType.expense);
      expect(result?.amount, 100);
    });

    test('source uses appFormFieldDecoration and no old grouped contract', () {
      final source = File(
        'lib/features/operations/presentation/widgets/operation_editor_sheet.dart',
      ).readAsStringSync();

      expect(source, contains('appFormFieldDecoration'));
      expect(source, contains('AppCategoryPickerField'));
      expect(source, isNot(contains('List<Operation>')));
      expect(source, isNot(contains('AppCategoryGroupTile')));
      expect(source, isNot(contains('AppGroupedCategorySelector')));
      expect(source, isNot(contains('AppCategoryGroupSummaryBuilder')));
      expect(source, isNot(contains('operationActualCategoryAmountEntries')));
      expect(source, isNot(contains('AppCategories.groupByGroup')));
      expect(source, isNot(contains('_OperationCategorySelector')));
      expect(source, isNot(contains('_OperationCategoryGroupSection')));
      expect(source, isNot(contains('_expandedCategoryGroup')));
      expect(source, isNot(contains('_categoryFieldKey')));
      expect(source, isNot(contains('operationDescriptionHint')));
      expect(source, isNot(contains('operationRecurrenceTitle')));
      expect(source, isNot(contains('operation-recurrence-field')));
      expect(source, isNot(contains('AppRoutes.operationRecurrencePicker')));
      expect(source, isNot(contains("package:go_router/go_router.dart")));
      expect(source, isNot(contains('budget_planning/domain')));
    });

    testWidgets('does not overflow in default viewport', (tester) async {
      await tester.pumpWidget(_editorApp(category: _rentCategory()));

      expect(tester.takeException(), isNull);
    });
  });
}

AppCategory _rentCategory() {
  return AppCategories.byId(AppCategoryId.expenseHousingRent)!;
}

AppCategory _salaryCategory() {
  return AppCategories.byId(AppCategoryId.incomeEmploymentSalary)!;
}

Widget _editorApp({required AppCategory category, Operation? operation}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: OperationEditorSheet(category: category, operation: operation),
    ),
  );
}

Widget _modalEditorApp({
  required AppCategory category,
  required ValueChanged<OperationEditorResult?> onResult,
  Operation? operation,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            key: const ValueKey<String>('open-editor'),
            onPressed: () async {
              final result = await showModalBottomSheet<OperationEditorResult>(
                context: context,
                isScrollControlled: true,
                builder: (context) {
                  return OperationEditorSheet(
                    category: category,
                    operation: operation,
                  );
                },
              );

              onResult(result);
            },
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

Operation _operation({
  double amount = 100,
  OperationSource source = OperationSource.manual,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: 'operation-1',
    userId: 'user-1',
    source: source,
    fromAccountId: null,
    toAccountId: null,
    categoryId: AppCategoryId.expenseHousingRent.name,
    type: OperationType.expense,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
  );
}
