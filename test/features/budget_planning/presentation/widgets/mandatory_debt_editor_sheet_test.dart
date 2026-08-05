import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_editor_bottom_sheet.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_debt_editor_sheet.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('MandatoryDebtEditorSheet', () {
    testWidgets('create editor uses shared shell and debt fields', (
      tester,
    ) async {
      await tester.pumpWidget(_editorApp());

      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
      expect(find.text(_l10n.budgetDebtTitle), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, _l10n.budgetDebtName),
        findsOneWidget,
      );
      expect(find.text(_l10n.budgetDebtType), findsOneWidget);
      expect(
        find.widgetWithText(
          TextFormField,
          '${_l10n.budgetDebtPaymentAmount} (CAD)',
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.commonSave), findsOneWidget);
      expect(find.text(_l10n.commonDelete), findsNothing);
    });

    testWidgets('debt type picker shows groups before debt categories', (
      tester,
    ) async {
      await tester.pumpWidget(_editorApp());

      await _openDebtCategoryPicker(tester);

      final groupedDebtCategories = AppCategories.groupByGroup(
        AppCategories.debtPaymentCategories,
      );
      final targetGroupEntry = _groupWithMostDebtCategories(
        groupedDebtCategories,
      );
      final targetGroup = targetGroupEntry.key;
      final targetCategories = targetGroupEntry.value;
      final firstTargetCategory = targetCategories.first;

      expect(
        find.byKey(
          ValueKey<String>('app-category-picker-group-${targetGroup.name}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'app-category-picker-category-${firstTargetCategory.id.name}',
          ),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          ValueKey<String>('app-category-picker-group-${targetGroup.name}'),
        ),
      );
      await tester.pumpAndSettle();

      for (final category in targetCategories) {
        expect(find.text(category.name(_l10n)), findsOneWidget);
      }

      final nonDebtCategory = _firstNonDebtCategory();
      expect(find.text(nonDebtCategory.name(_l10n)), findsNothing);
    });

    testWidgets('save returns selected debt category', (tester) async {
      MandatoryDebtEditorResult? result;
      final selectedCategory = _categoryToSelect();

      await tester.pumpWidget(
        _modalEditorApp(
          onResult: (value) {
            result = value;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-editor')));
      await tester.pumpAndSettle();
      await _selectDebtCategory(tester, selectedCategory);
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.budgetDebtName),
        'RBC Visa',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          '${_l10n.budgetDebtPaymentAmount} (CAD)',
        ),
        '250',
      );
      await tester.tap(find.text(_l10n.commonSave));
      await tester.pumpAndSettle();

      expect(result?.isDeleted, isFalse);
      expect(result?.obligation?.name, 'RBC Visa');
      expect(result?.obligation?.amount, 250);
      expect(result?.obligation?.categoryId, selectedCategory.id.name);
    });

    testWidgets('edit editor shows delete action', (tester) async {
      await tester.pumpWidget(
        _editorApp(existingObligation: _existingObligation()),
      );

      expect(find.text(_l10n.commonDelete), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, _l10n.budgetDebtName),
            )
            .controller
            ?.text,
        'RBC Visa',
      );
    });
  });
}

MapEntry<AppCategoryGroup, List<AppCategory>> _groupWithMostDebtCategories(
  Map<AppCategoryGroup, List<AppCategory>> groupedCategories,
) {
  return groupedCategories.entries.reduce(
    (best, entry) => entry.value.length > best.value.length ? entry : best,
  );
}

AppCategory _categoryToSelect() {
  final preferredCategory = AppCategories.byId(
    AppCategoryId.expenseFinanceCreditCardPayment,
  );

  if (preferredCategory != null &&
      AppCategories.debtPaymentCategories.any(
        (category) => category.id == preferredCategory.id,
      )) {
    return preferredCategory;
  }

  return AppCategories.debtPaymentCategories.first;
}

AppCategory _firstNonDebtCategory() {
  final debtCategoryIds = {
    for (final category in AppCategories.debtPaymentCategories) category.id,
  };

  return AppCategories.expenseCategories.firstWhere(
    (category) => !debtCategoryIds.contains(category.id),
  );
}

Future<void> _openDebtCategoryPicker(WidgetTester tester) async {
  final defaultCategory = AppCategories.debtPaymentCategories.first;
  final field = find
      .ancestor(
        of: find.text(defaultCategory.name(_l10n)),
        matching: find.byType(InkWell),
      )
      .first;

  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> _selectDebtCategory(
  WidgetTester tester,
  AppCategory category,
) async {
  await _openDebtCategoryPicker(tester);

  await tester.tap(
    find.byKey(
      ValueKey<String>('app-category-picker-group-${category.group.name}'),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(
      ValueKey<String>('app-category-picker-category-${category.id.name}'),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _editorApp({BudgetObligation? existingObligation}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MandatoryDebtEditorSheet(
        existingObligation: existingObligation,
        currencyCode: 'CAD',
        setupId: 'setup-id',
        userId: 'user-id',
      ),
    ),
  );
}

Widget _modalEditorApp({
  required ValueChanged<MandatoryDebtEditorResult?> onResult,
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
              final result =
                  await showModalBottomSheet<MandatoryDebtEditorResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) {
                      return const MandatoryDebtEditorSheet(
                        existingObligation: null,
                        currencyCode: 'CAD',
                        setupId: 'setup-id',
                        userId: 'user-id',
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

BudgetObligation _existingObligation() {
  return BudgetObligation(
    id: 'debt-id',
    setupId: 'setup-id',
    userId: 'user-id',
    categoryId: AppCategories.debtPaymentCategories.first.id.name,
    obligationType: 'debt_minimum',
    amount: 250,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    nextDueDate: DateTime.utc(2026, 8),
    minimumDebtPayment: 250,
    name: 'RBC Visa',
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}
