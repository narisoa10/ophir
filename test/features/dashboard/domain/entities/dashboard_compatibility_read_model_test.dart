import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/dashboard/domain/entities/dashboard_compatibility_read_model.dart';
import 'package:ophir/features/dashboard/domain/entities/dashboard_financial_summary.dart';

void main() {
  group('DashboardCompatibilityReadModel', () {
    test('keeps legacy dashboard summary unchanged', () {
      final legacySummary = _legacySummary();
      final readModel = DashboardCompatibilityReadModel(
        legacySummary: legacySummary,
        intelligenceOutput: _output(),
      );

      expect(readModel.legacySummary, same(legacySummary));
      expect(readModel.legacySummary.cashFlow.expenses, 1500);
      expect(readModel.legacyExpenseTotal, 1500);
      expect(readModel.legacySummary.cashFlow.net, 2500);
    });

    test('can hold financial behavior output next to legacy values', () {
      final output = _output();
      final readModel = DashboardCompatibilityReadModel(
        legacySummary: _legacySummary(),
        intelligenceOutput: output,
      );

      expect(readModel.hasIntelligenceComparison, isTrue);
      expect(readModel.intelligenceOutput, same(output));
      expect(readModel.intelligenceOrdinarySpendingTotal, 1000);
      expect(readModel.legacyVsIntelligenceDifference, 500);
    });

    test('exposes dashboard-safe special action totals from output totals', () {
      final readModel = DashboardCompatibilityReadModel(
        legacySummary: _legacySummary(),
        intelligenceOutput: _output(),
      );

      final totals = readModel.specialActionTotals;

      expect(totals, isNotNull);
      expect(totals!.assetBuildingTotal, 300);
      expect(totals.debtReductionTotal, 200);
      expect(totals.cashMovementTotal, 80);
      expect(totals.dataAdjustmentTotal, 40);
      expect(totals.contextRequiredTotal, 320);
    });

    test('supports legacy-only dashboard state', () {
      final readModel = DashboardCompatibilityReadModel(
        legacySummary: _legacySummary(),
        intelligenceOutput: null,
      );

      expect(readModel.hasIntelligenceComparison, isFalse);
      expect(readModel.intelligenceOrdinarySpendingTotal, isNull);
      expect(readModel.legacyVsIntelligenceDifference, isNull);
      expect(readModel.specialActionTotals, isNull);
      expect(readModel.legacyExpenseTotal, 1500);
    });

    test('does not read financial behavior snapshot facts', () {
      final output = _output();
      final readModel = DashboardCompatibilityReadModel(
        legacySummary: _legacySummary(),
        intelligenceOutput: output,
      );

      expect(readModel.intelligenceOutput, same(output));
      expect(readModel.specialActionTotals!.contextRequiredTotal, 320);
    });
  });
}

DashboardFinancialSummary _legacySummary() {
  return const DashboardFinancialSummary(
    currencyCode: 'CAD',
    today: DashboardTodaySummary(
      income: 100,
      expenses: 50,
      net: 50,
      operationCount: 2,
    ),
    recordedBalance: 10000,
    cashFlow: DashboardCashFlowSummary(income: 4000, expenses: 1500, net: 2500),
    expenseGroups: [],
    insights: [],
    upcomingRecurring: [],
    actions: [],
  );
}

FinancialBehaviorCompatibilityOutput _output({
  double legacyExpenseTotal = 1500,
  double ordinarySpendingTotal = 1000,
  double legacyVsIntelligenceDifference = 500,
}) {
  return FinancialBehaviorCompatibilityOutput(
    snapshot: FinancialBehaviorFactsSnapshot(facts: []),
    totals: FinancialBehaviorTotals(
      legacyExpenseTotal: legacyExpenseTotal,
      ordinarySpendingTotal: ordinarySpendingTotal,
      assetBuildingTotal: 300,
      debtReductionTotal: 200,
      cashMovementTotal: 80,
      dataAdjustmentTotal: 40,
      contextRequiredTotal: 320,
      behavioralSavingsTotal: 300,
      legacyVsIntelligenceDifference: legacyVsIntelligenceDifference,
      unresolvedCount: 0,
    ),
  );
}
