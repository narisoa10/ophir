import '../../../../core/database/app_database.dart';
import '../../domain/entities/budget_household.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/entities/budget_setup.dart';
import '../../domain/repositories/budget_planning_repository.dart';

final class LocalBudgetPlanningRepository implements BudgetPlanningRepository {
  const LocalBudgetPlanningRepository({
    required AppDatabase database,
    required String userId,
    required String Function() currencyCode,
  }) : _database = database,
       _userId = userId,
       _currencyCode = currencyCode;

  final AppDatabase _database;
  final String _userId;
  final String Function() _currencyCode;

  @override
  Future<BudgetSetup?> getCurrentSetup() {
    return _database.getBudgetSetup(_userId);
  }

  @override
  Stream<BudgetSetup?> watchCurrentSetup() {
    return _database.watchBudgetSetup(_userId);
  }

  @override
  Future<BudgetSetup> createSetup({required BudgetHousehold household}) async {
    final now = DateTime.now().toUtc();
    final setup = BudgetSetup(
      id: _userId,
      userId: _userId,
      status: 'draft',
      version: 1,
      currentStep: 0,
      household: household,
      incomeSources: const [],
      obligations: const [],
      createdAt: now,
      updatedAt: now,
    );

    await saveSetup(setup);

    return setup;
  }

  @override
  Future<BudgetSetup> saveSetup(BudgetSetup setup) async {
    await saveSetupWithCurrency(setup, _currencyCode());

    return await getCurrentSetup() ?? setup;
  }

  Future<void> saveSetupWithCurrency(BudgetSetup setup, String currencyCode) {
    return _database.saveBudgetSetupWithCurrency(setup, currencyCode);
  }

  @override
  Future<void> replaceIncomeSources({
    required String setupId,
    required List<BudgetIncomeSource> incomeSources,
  }) {
    return _database.replaceBudgetIncomeSources(_userId, incomeSources);
  }

  @override
  Future<void> replaceObligations({
    required String setupId,
    required List<BudgetObligation> obligations,
  }) {
    return _database.replaceBudgetObligations(_userId, obligations);
  }

  @override
  Future<BudgetSetup> completeSetup(String setupId) async {
    final setup = await getCurrentSetup();

    if (setup == null) {
      throw StateError('Budget setup was not found.');
    }

    final now = DateTime.now().toUtc();
    final completedSetup = BudgetSetup(
      id: setup.id,
      userId: setup.userId,
      status: 'completed',
      version: setup.version,
      currentStep: 3,
      household: setup.household,
      incomeSources: setup.incomeSources,
      obligations: setup.obligations,
      completedAt: now,
      createdAt: setup.createdAt,
      updatedAt: now,
    );

    await saveSetupWithCurrency(completedSetup, _currencyCode());

    return await getCurrentSetup() ?? completedSetup;
  }

  Future<void> markBudgetSynced() {
    return _database.markBudgetSynced(_userId);
  }

  Future<void> markBudgetSyncFailed() {
    return _database.markBudgetSyncFailed(_userId);
  }

  @override
  Future<void> deleteSetup(String setupId) {
    return _database.deleteBudgetSetup(_userId);
  }
}
