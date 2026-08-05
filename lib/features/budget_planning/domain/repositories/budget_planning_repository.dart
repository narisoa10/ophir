import '../entities/budget_household.dart';
import '../entities/budget_income_source.dart';
import '../entities/budget_obligation.dart';
import '../entities/budget_setup.dart';

abstract interface class BudgetPlanningRepository {
  Future<BudgetSetup?> getCurrentSetup();

  Stream<BudgetSetup?> watchCurrentSetup();

  Future<BudgetSetup> createSetup({required BudgetHousehold household});

  Future<BudgetSetup> saveSetup(BudgetSetup setup);

  Future<void> replaceIncomeSources({
    required String setupId,
    required List<BudgetIncomeSource> incomeSources,
  });

  Future<void> replaceObligations({
    required String setupId,
    required List<BudgetObligation> obligations,
  });

  Future<BudgetSetup> completeSetup(String setupId);

  Future<void> deleteSetup(String setupId);
}
