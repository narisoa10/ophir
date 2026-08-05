import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/budget_income_step.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('BudgetIncomeStep', () {
    testWidgets('add source opens editor with name field and type dropdown', (
      tester,
    ) async {
      await _pumpStep(tester);

      await tester.tap(find.text(_l10n.budgetIncomeAddSource));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.budgetIncomeTitle), findsWidgets);
      expect(find.text(_l10n.budgetIncomeName), findsOneWidget);
      expect(find.text(_l10n.budgetIncomeType), findsOneWidget);
      expect(find.text(_salaryName), findsWidgets);
      expect(find.text(_l10n.commonDelete), findsNothing);
    });

    testWidgets('income type is selected through grouped category picker', (
      tester,
    ) async {
      await _pumpStep(tester);

      await tester.tap(find.text(_l10n.budgetIncomeAddSource));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_salaryName).last);
      await tester.pumpAndSettle();

      final businessIncomeGroup = find.byKey(
        const ValueKey<String>('app-category-picker-group-businessIncome'),
      );
      await tester.ensureVisible(businessIncomeGroup);
      await tester.pumpAndSettle();
      await tester.tap(businessIncomeGroup);
      await tester.pumpAndSettle();

      final businessIncomeCategory = find.byKey(
        const ValueKey<String>(
          'app-category-picker-category-incomeBusinessBusinessIncome',
        ),
      );
      await tester.ensureVisible(businessIncomeCategory);
      await tester.pumpAndSettle();
      await tester.tap(businessIncomeCategory);
      await tester.pumpAndSettle();

      expect(find.text(_businessIncomeName), findsWidgets);
    });

    testWidgets('save new income stores name', (tester) async {
      final key = GlobalKey<BudgetIncomeStepState>();
      await _pumpStep(tester, key: key);

      await tester.tap(find.text(_l10n.budgetIncomeAddSource));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.budgetIncomeName),
        'Main salary',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '${_l10n.budgetIncomeAmount} (CAD)'),
        '4200',
      );
      await _selectFrequency(tester, _l10n.budgetFrequencyIrregular);
      await tester.tap(find.text(_l10n.commonSave));
      await tester.pumpAndSettle();

      final incomeSources = key.currentState!.validateAndCreateIncomeSources();

      expect(incomeSources, hasLength(1));
      expect(incomeSources!.single.name, 'Main salary');
    });

    testWidgets('edit existing income fills name and shows delete', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        incomeSources: [_incomeSource(name: 'Primary job')],
      );

      await tester.tap(find.text('Primary job'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, _l10n.budgetIncomeName),
            )
            .controller
            ?.text,
        'Primary job',
      );
      expect(find.text(_l10n.commonDelete), findsOneWidget);
    });

    testWidgets('delete removes existing income', (tester) async {
      final key = GlobalKey<BudgetIncomeStepState>();
      await _pumpStep(
        tester,
        key: key,
        incomeSources: [_incomeSource(name: 'Primary job')],
      );

      await tester.tap(find.text('Primary job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(key.currentState!.validateAndCreateIncomeSources(), isNull);
    });

    testWidgets('income list displays income name', (tester) async {
      await _pumpStep(
        tester,
        incomeSources: [_incomeSource(name: 'Primary job')],
      );

      expect(find.text('Primary job'), findsOneWidget);
      expect(
        find.text('1000.00 CAD / ${_l10n.budgetFrequencyMonthly}'),
        findsOneWidget,
      );
    });

    testWidgets('income list falls back to category name for empty name', (
      tester,
    ) async {
      await _pumpStep(tester, incomeSources: [_incomeSource(name: '')]);

      expect(find.text(_salaryName), findsOneWidget);
    });

    testWidgets('frequencyInterval remains available for every N months', (
      tester,
    ) async {
      await _pumpStep(tester);

      await tester.tap(find.text(_l10n.budgetIncomeAddSource));
      await tester.pumpAndSettle();
      await _selectFrequency(tester, _l10n.budgetFrequencyEveryNMonths);

      expect(find.text(_l10n.budgetFrequencyInterval), findsOneWidget);
    });

    testWidgets('timesPerYear remains available for times per year', (
      tester,
    ) async {
      await _pumpStep(tester);

      await tester.tap(find.text(_l10n.budgetIncomeAddSource));
      await tester.pumpAndSettle();
      await _selectFrequency(tester, _l10n.budgetFrequencyTimesPerYear);

      expect(find.text(_l10n.budgetTimesPerYear), findsWidgets);
    });
  });
}

Future<void> _pumpStep(
  WidgetTester tester, {
  GlobalKey<BudgetIncomeStepState>? key,
  List<BudgetIncomeSource> incomeSources = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BudgetIncomeStep(
          key: key,
          setup: _setup(incomeSources: incomeSources),
          currencyCode: 'CAD',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectFrequency(WidgetTester tester, String label) async {
  await tester.tap(find.text(_l10n.budgetFrequencyMonthly).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String get _salaryName =>
    AppCategories.byId(AppCategoryId.incomeEmploymentSalary)!.name(_l10n);

String get _businessIncomeName =>
    AppCategories.byId(AppCategoryId.incomeBusinessBusinessIncome)!.name(_l10n);

BudgetSetup _setup({List<BudgetIncomeSource> incomeSources = const []}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: 'setup-id',
    userId: 'user-id',
    status: 'draft',
    version: 1,
    currentStep: 1,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: incomeSources,
    obligations: const [],
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource({required String name}) {
  return BudgetIncomeSource(
    id: 'income-id',
    setupId: 'setup-id',
    userId: 'user-id',
    name: name,
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: 1000,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}
