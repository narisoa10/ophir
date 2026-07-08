import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/dashboard/domain/entities/dashboard_financial_summary.dart';
import 'package:ophir/features/dashboard/domain/services/dashboard_compatibility_assembler.dart';

void main() {
  group('DashboardCompatibilityAssembler', () {
    const assembler = DashboardCompatibilityAssembler();

    test('returns dashboard compatibility read model', () {
      final readModel = assembler.assemble(
        legacySummary: _legacySummary(),
        intelligenceOutput: _output(),
      );

      expect(readModel.legacySummary.cashFlow.expenses, 1500);
      expect(readModel.intelligenceOrdinarySpendingTotal, 1000);
    });

    test('keeps legacy summary unchanged', () {
      final legacySummary = _legacySummary();

      final readModel = assembler.assemble(
        legacySummary: legacySummary,
        intelligenceOutput: _output(),
      );

      expect(readModel.legacySummary, same(legacySummary));
      expect(readModel.legacySummary.cashFlow.income, 4000);
      expect(readModel.legacySummary.cashFlow.expenses, 1500);
      expect(readModel.legacySummary.cashFlow.net, 2500);
    });

    test('supports null intelligence output', () {
      final readModel = assembler.assemble(
        legacySummary: _legacySummary(),
        intelligenceOutput: null,
      );

      expect(readModel.hasIntelligenceComparison, isFalse);
      expect(readModel.intelligenceOutput, isNull);
      expect(readModel.specialActionTotals, isNull);
    });

    test('keeps intelligence output unchanged', () {
      final output = _output();

      final readModel = assembler.assemble(
        legacySummary: _legacySummary(),
        intelligenceOutput: output,
      );

      expect(readModel.intelligenceOutput, same(output));
      expect(readModel.legacyVsIntelligenceDifference, 500);
      expect(readModel.specialActionTotals!.assetBuildingTotal, 300);
    });

    test('does not recalculate output totals', () {
      final output = _output(
        legacyExpenseTotal: 42,
        ordinarySpendingTotal: 7,
        assetBuildingTotal: 3,
        debtReductionTotal: 5,
        cashMovementTotal: 8,
        dataAdjustmentTotal: 13,
        contextRequiredTotal: 21,
        legacyVsIntelligenceDifference: 35,
      );

      final readModel = assembler.assemble(
        legacySummary: _legacySummary(),
        intelligenceOutput: output,
      );

      expect(readModel.legacyExpenseTotal, 1500);
      expect(readModel.intelligenceOutput!.totals.legacyExpenseTotal, 42);
      expect(readModel.intelligenceOrdinarySpendingTotal, 7);
      expect(readModel.legacyVsIntelligenceDifference, 35);
      expect(readModel.specialActionTotals!.contextRequiredTotal, 21);
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
  double assetBuildingTotal = 300,
  double debtReductionTotal = 200,
  double cashMovementTotal = 80,
  double dataAdjustmentTotal = 40,
  double contextRequiredTotal = 320,
  double legacyVsIntelligenceDifference = 500,
}) {
  return FinancialBehaviorCompatibilityOutput(
    snapshot: FinancialBehaviorFactsSnapshot(facts: []),
    totals: FinancialBehaviorTotals(
      legacyExpenseTotal: legacyExpenseTotal,
      ordinarySpendingTotal: ordinarySpendingTotal,
      assetBuildingTotal: assetBuildingTotal,
      debtReductionTotal: debtReductionTotal,
      cashMovementTotal: cashMovementTotal,
      dataAdjustmentTotal: dataAdjustmentTotal,
      contextRequiredTotal: contextRequiredTotal,
      behavioralSavingsTotal: assetBuildingTotal,
      legacyVsIntelligenceDifference: legacyVsIntelligenceDifference,
      unresolvedCount: 0,
    ),
  );
}
