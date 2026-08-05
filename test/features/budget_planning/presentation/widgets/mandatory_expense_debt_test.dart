import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_financial_list_tile.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_debt.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('MandatoryExpenseDebt', () {
    testWidgets('renders debts and calls callbacks', (tester) async {
      var toggleCalls = 0;
      var addCalls = 0;
      BudgetObligation? tappedDebt;

      await _pumpDebtSection(
        tester,
        obligations: [
          _debtObligation(id: 'debt-1', name: 'RBC Visa'),
          _debtObligation(id: 'debt-2', name: 'Toyota Loan'),
        ],
        onToggle: () {
          toggleCalls += 1;
        },
        onAddDebt: () {
          addCalls += 1;
        },
        onDebtTap: (obligation) {
          tappedDebt = obligation;
        },
      );

      expect(find.text(_l10n.budgetDebtTitle), findsOneWidget);
      expect(find.text('0.00 CAD'), findsOneWidget);
      expect(find.byType(AppFinancialListTile), findsNWidgets(3));
      expect(find.text('RBC Visa'), findsOneWidget);
      expect(find.text('Toyota Loan'), findsOneWidget);
      expect(find.text(_l10n.budgetDebtAdd), findsOneWidget);

      await tester.tap(find.text(_l10n.budgetDebtTitle));
      await tester.tap(find.text(_l10n.budgetDebtAdd));
      await tester.tap(find.text('RBC Visa'));

      expect(toggleCalls, 1);
      expect(addCalls, 1);
      expect(tappedDebt?.id, 'debt-1');
    });

    testWidgets('renders collapsed state', (tester) async {
      await _pumpDebtSection(
        tester,
        isExpanded: false,
        obligations: [_debtObligation(id: 'debt-1', name: 'RBC Visa')],
      );

      expect(find.text(_l10n.budgetDebtTitle), findsOneWidget);
      expect(find.text('0.00 CAD'), findsOneWidget);
      expect(find.byType(AppFinancialListTile), findsOneWidget);
      expect(find.text('RBC Visa'), findsNothing);
      expect(find.text(_l10n.budgetDebtAdd), findsNothing);
    });
  });
}

Future<void> _pumpDebtSection(
  WidgetTester tester, {
  required List<BudgetObligation> obligations,
  bool isExpanded = true,
  VoidCallback? onToggle,
  VoidCallback? onAddDebt,
  ValueChanged<BudgetObligation>? onDebtTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MandatoryExpenseDebt(
          obligations: obligations,
          isExpanded: isExpanded,
          onToggle: onToggle ?? () {},
          currencyCode: 'CAD',
          onAddDebt: onAddDebt ?? () {},
          onDebtTap: onDebtTap ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BudgetObligation _debtObligation({required String id, required String name}) {
  return BudgetObligation(
    id: id,
    setupId: 'setup-id',
    userId: 'user-id',
    categoryId: AppCategoryId.expenseFinanceCreditCardPayment.name,
    obligationType: 'debt_minimum',
    amount: 250,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    minimumDebtPayment: 250,
    name: name,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}
