import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/budget_planning/domain/entities/budget_household.dart';
import '../../features/budget_planning/domain/entities/budget_income_source.dart';
import '../../features/budget_planning/domain/entities/budget_obligation.dart';
import '../../features/budget_planning/domain/entities/budget_setup.dart';
import '../../features/budget_planning/domain/enums/budget_data_confidence.dart';
import '../../features/budget_planning/domain/enums/budget_data_source.dart';
import '../../features/budget_planning/domain/enums/budget_frequency.dart';
import '../../features/operations/domain/entities/operation.dart';
import '../../features/operations/domain/enums/operation_recurrence.dart';
import '../../features/operations/domain/enums/operation_source.dart';
import '../../features/operations/domain/enums/operation_type.dart';
import '../../features/operations/domain/utils/operation_calendar_date.dart';
import '../categories/app_categories.dart';
import 'tables/budget_income_sources_table.dart';
import 'tables/budget_obligations_table.dart';
import 'tables/budget_setups_table.dart';
import 'tables/operations_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    BudgetSetups,
    BudgetIncomeSources,
    BudgetObligations,
    OperationsTable,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static const syncPending = 'pending';
  static const syncSynced = 'synced';
  static const syncFailed = 'failed';

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await customStatement(
            'ALTER TABLE budget_obligations ADD COLUMN name TEXT NULL',
          );
        }

        if (from < 3) {
          await customStatement(
            'ALTER TABLE budget_income_sources ADD COLUMN name TEXT NOT NULL DEFAULT \'\'',
          );
          await customStatement(
            'UPDATE budget_income_sources SET name = category_id WHERE name = \'\'',
          );
        }

        if (from < 4) {
          await customStatement(
            "ALTER TABLE operations "
            "ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
          );
          await customStatement(
            'ALTER TABLE operations '
            'ADD COLUMN external_id TEXT NULL',
          );
          await customStatement(
            'ALTER TABLE operations '
            'ADD COLUMN is_pending INTEGER NOT NULL DEFAULT 0',
          );
        }

        if (from < 5) {
          await customStatement(
            'ALTER TABLE operations '
            'ADD COLUMN category_overridden INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'ophir');
  }

  Future<List<Operation>> getOperations(String userId) async {
    final rows =
        await (select(operationsTable)
              ..where((table) => table.userId.equals(userId))
              ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
            .get();

    return [for (final row in rows) ?_operationFromRow(row)];
  }

  Stream<List<Operation>> watchOperations(String userId) {
    return (select(operationsTable)
          ..where((table) => table.userId.equals(userId))
          ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
        .watch()
        .map((rows) => [for (final row in rows) ?_operationFromRow(row)]);
  }

  Future<Operation?> getOperationById(String id) async {
    final row = await (select(
      operationsTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _operationFromRow(row);
  }

  Future<void> saveOperation(Operation operation) {
    return _saveOperation(operation, syncStatus: syncPending);
  }

  Future<void> deleteOperation(String id) {
    return (delete(
      operationsTable,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> replaceOperations(String userId, List<Operation> operations) {
    return transaction(() async {
      final remoteIds = operations.map((operation) => operation.id).toSet();
      final localRows = await (select(
        operationsTable,
      )..where((table) => table.userId.equals(userId))).get();
      final unsyncedIds = {
        for (final row in localRows)
          if (row.syncStatus != syncSynced) row.id,
      };

      for (final operation in operations) {
        if (unsyncedIds.contains(operation.id)) {
          continue;
        }

        await _saveOperation(
          _operationForUser(operation, userId),
          syncStatus: syncSynced,
        );
      }

      for (final row in localRows) {
        final isMissingRemotely = !remoteIds.contains(row.id);

        if (isMissingRemotely && row.syncStatus == syncSynced) {
          await (delete(
            operationsTable,
          )..where((table) => table.id.equals(row.id))).go();
        }
      }
    });
  }

  Future<void> markOperationSynced(String id) {
    return _markOperationSyncStatus(id, syncSynced);
  }

  Future<void> markOperationSyncFailed(String id) {
    return _markOperationSyncStatus(id, syncFailed);
  }

  Future<BudgetSetup?> getBudgetSetup(String userId) async {
    final row = await (select(
      budgetSetups,
    )..where((table) => table.userId.equals(userId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final incomeSources = await getBudgetIncomeSources(userId);
    final obligations = await getBudgetObligations(userId);

    return _setupFromRow(
      row,
      incomeSources: incomeSources,
      obligations: obligations,
    );
  }

  Stream<BudgetSetup?> watchBudgetSetup(String userId) {
    return (select(budgetSetups)..where((table) => table.userId.equals(userId)))
        .watchSingleOrNull()
        .asyncMap((_) => getBudgetSetup(userId));
  }

  Future<List<BudgetIncomeSource>> getBudgetIncomeSources(String userId) async {
    final rows =
        await (select(budgetIncomeSources)
              ..where((table) => table.userId.equals(userId))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    final currencyCode = await _currencyCodeFor(userId);
    final values = <BudgetIncomeSource>[];

    for (final row in rows) {
      final value = _incomeSourceFromRow(row, currencyCode: currencyCode);
      if (value != null) {
        values.add(value);
      }
    }

    return values;
  }

  Stream<List<BudgetIncomeSource>> watchBudgetIncomeSources(String userId) {
    return (select(budgetIncomeSources)
          ..where((table) => table.userId.equals(userId))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .watch()
        .asyncMap((_) => getBudgetIncomeSources(userId));
  }

  Future<List<BudgetObligation>> getBudgetObligations(String userId) async {
    final rows =
        await (select(budgetObligations)
              ..where((table) => table.userId.equals(userId))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    final currencyCode = await _currencyCodeFor(userId);
    final values = <BudgetObligation>[];

    for (final row in rows) {
      final value = _obligationFromRow(row, currencyCode: currencyCode);
      if (value != null) {
        values.add(value);
      }
    }

    return values;
  }

  Stream<List<BudgetObligation>> watchBudgetObligations(String userId) {
    return (select(budgetObligations)
          ..where((table) => table.userId.equals(userId))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .watch()
        .asyncMap((_) => getBudgetObligations(userId));
  }

  Future<void> saveBudgetSetup(
    BudgetSetup setup,
    List<BudgetIncomeSource> incomeSources,
    List<BudgetObligation> obligations,
  ) {
    return _saveBudgetSetupWithCurrency(
      setup,
      incomeSources,
      obligations,
      _currencyCodeFromSetup(setup),
    );
  }

  Future<void> saveBudgetSetupWithCurrency(
    BudgetSetup setup,
    String currencyCode,
  ) {
    return _saveBudgetSetupWithCurrency(
      setup,
      setup.incomeSources,
      setup.obligations,
      currencyCode,
    );
  }

  Future<void> _saveBudgetSetupWithCurrency(
    BudgetSetup setup,
    List<BudgetIncomeSource> incomeSources,
    List<BudgetObligation> obligations,
    String currencyCode,
  ) {
    return transaction(() async {
      await into(budgetSetups).insertOnConflictUpdate(
        _setupCompanion(setup, currencyCode: currencyCode),
      );
      await _replaceBudgetIncomeSources(
        setup.userId,
        incomeSources,
        syncStatus: syncPending,
      );
      await _replaceBudgetObligations(
        setup.userId,
        obligations,
        syncStatus: syncPending,
      );
    });
  }

  Future<void> replaceBudgetIncomeSources(
    String userId,
    List<BudgetIncomeSource> incomeSources,
  ) async {
    await transaction(() async {
      await _replaceBudgetIncomeSources(
        userId,
        incomeSources,
        syncStatus: syncPending,
      );
      await _touchSetup(userId, syncStatus: syncPending);
    });
  }

  Future<void> replaceBudgetObligations(
    String userId,
    List<BudgetObligation> obligations,
  ) async {
    await transaction(() async {
      await _replaceBudgetObligations(
        userId,
        obligations,
        syncStatus: syncPending,
      );
      await _touchSetup(userId, syncStatus: syncPending);
    });
  }

  Future<void> markBudgetSynced(String userId) {
    return _markBudgetSyncStatus(userId, syncSynced);
  }

  Future<void> markBudgetSyncFailed(String userId) {
    return _markBudgetSyncStatus(userId, syncFailed);
  }

  Future<void> deleteBudgetSetup(String userId) {
    return transaction(() async {
      await (delete(
        budgetIncomeSources,
      )..where((table) => table.userId.equals(userId))).go();
      await (delete(
        budgetObligations,
      )..where((table) => table.userId.equals(userId))).go();
      await (delete(
        budgetSetups,
      )..where((table) => table.userId.equals(userId))).go();
    });
  }

  Future<void> _replaceBudgetIncomeSources(
    String userId,
    List<BudgetIncomeSource> incomeSources, {
    required String syncStatus,
  }) async {
    await (delete(
      budgetIncomeSources,
    )..where((table) => table.userId.equals(userId))).go();

    for (final incomeSource in incomeSources) {
      final categoryId = incomeSource.categoryId;
      if (!_isKnownCategoryId(categoryId)) {
        continue;
      }

      await into(budgetIncomeSources).insert(
        BudgetIncomeSourcesCompanion.insert(
          id: incomeSource.id,
          userId: userId,
          name: incomeSource.name,
          categoryId: categoryId!,
          amount: incomeSource.amount,
          frequency: _frequencyToJson(incomeSource.frequency),
          nextPaymentDate: Value(incomeSource.nextDate),
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          syncStatus: syncStatus,
        ),
      );
    }
  }

  Future<void> _replaceBudgetObligations(
    String userId,
    List<BudgetObligation> obligations, {
    required String syncStatus,
  }) async {
    await (delete(
      budgetObligations,
    )..where((table) => table.userId.equals(userId))).go();

    for (final obligation in obligations) {
      if (!_isKnownNullableCategoryId(obligation.categoryId)) {
        continue;
      }

      await into(budgetObligations).insert(
        BudgetObligationsCompanion.insert(
          id: obligation.id,
          userId: userId,
          categoryId: Value(obligation.categoryId),
          amount: obligation.amount,
          frequency: _frequencyToJson(obligation.frequency),
          nextDueDate: Value(obligation.nextDueDate),
          obligationType: obligation.obligationType,
          name: Value(obligation.name),
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          syncStatus: syncStatus,
        ),
      );
    }
  }

  BudgetSetupsCompanion _setupCompanion(
    BudgetSetup setup, {
    required String currencyCode,
  }) {
    final now = DateTime.now().toUtc();
    final isCompleted =
        setup.status == 'completed' || setup.completedAt != null;

    return BudgetSetupsCompanion.insert(
      userId: setup.userId,
      currentStep: setup.currentStep,
      adults: setup.household.adultsCount,
      children: setup.household.childrenCount,
      currencyCode: currencyCode,
      isCompleted: isCompleted,
      syncStatus: syncPending,
      createdAt: setup.createdAt,
      updatedAt: now,
    );
  }

  BudgetSetup _setupFromRow(
    BudgetSetupRow row, {
    required List<BudgetIncomeSource> incomeSources,
    required List<BudgetObligation> obligations,
  }) {
    return BudgetSetup(
      id: row.userId,
      userId: row.userId,
      status: row.isCompleted ? 'completed' : 'draft',
      version: 1,
      currentStep: row.currentStep,
      household: BudgetHousehold(
        adultsCount: row.adults,
        childrenCount: row.children,
      ),
      incomeSources: incomeSources,
      obligations: obligations,
      completedAt: row.isCompleted ? row.updatedAt : null,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  BudgetIncomeSource? _incomeSourceFromRow(
    BudgetIncomeSourceRow row, {
    required String currencyCode,
  }) {
    if (!_isKnownCategoryId(row.categoryId)) {
      return null;
    }

    return BudgetIncomeSource(
      id: row.id,
      setupId: row.userId,
      userId: row.userId,
      name: row.name,
      categoryId: row.categoryId,
      amount: row.amount,
      currencyCode: currencyCode,
      frequency: _frequencyFromJson(row.frequency),
      nextDate: row.nextPaymentDate,
      source: BudgetDataSource.declared,
      confidence: BudgetDataConfidence.estimated,
      isActive: true,
    );
  }

  BudgetObligation? _obligationFromRow(
    BudgetObligationRow row, {
    required String currencyCode,
  }) {
    if (!_isKnownNullableCategoryId(row.categoryId)) {
      return null;
    }

    return BudgetObligation(
      id: row.id,
      setupId: row.userId,
      userId: row.userId,
      categoryId: row.categoryId,
      obligationType: row.obligationType,
      amount: row.amount,
      currencyCode: currencyCode,
      frequency: _frequencyFromJson(row.frequency),
      nextDueDate: row.nextDueDate,
      minimumDebtPayment: row.obligationType == 'debt_minimum'
          ? row.amount
          : null,
      isOverdue: false,
      name: row.name,
      source: BudgetDataSource.declared,
      confidence: BudgetDataConfidence.estimated,
      isActive: true,
    );
  }

  Future<String> _currencyCodeFor(String userId) async {
    final row = await (select(
      budgetSetups,
    )..where((table) => table.userId.equals(userId))).getSingleOrNull();

    return row?.currencyCode ?? 'CAD';
  }

  String _currencyCodeFromSetup(BudgetSetup setup) {
    if (setup.incomeSources.isNotEmpty) {
      return setup.incomeSources.first.currencyCode;
    }

    if (setup.obligations.isNotEmpty) {
      return setup.obligations.first.currencyCode;
    }

    return 'CAD';
  }

  Future<void> _touchSetup(String userId, {required String syncStatus}) async {
    await (update(
      budgetSetups,
    )..where((table) => table.userId.equals(userId))).write(
      BudgetSetupsCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _markBudgetSyncStatus(String userId, String syncStatus) {
    return transaction(() async {
      await _touchSetup(userId, syncStatus: syncStatus);
      await (update(budgetIncomeSources)
            ..where((table) => table.userId.equals(userId)))
          .write(BudgetIncomeSourcesCompanion(syncStatus: Value(syncStatus)));
      await (update(budgetObligations)
            ..where((table) => table.userId.equals(userId)))
          .write(BudgetObligationsCompanion(syncStatus: Value(syncStatus)));
    });
  }

  Future<void> _saveOperation(
    Operation operation, {
    required String syncStatus,
  }) async {
    if (!_isKnownNullableCategoryId(operation.categoryId)) {
      return;
    }

    await into(operationsTable).insertOnConflictUpdate(
      OperationsTableCompanion.insert(
        id: operation.id,
        userId: operation.userId,
        source: Value(operation.source.toJson()),
        externalId: Value(operation.externalId),
        isPending: Value(operation.isPending),
        categoryOverridden: Value(operation.categoryOverridden),
        fromAccountId: Value(operation.fromAccountId),
        toAccountId: Value(operation.toAccountId),
        categoryId: Value(operation.categoryId),
        type: _operationTypeToJson(operation.type),
        amount: operation.amount,
        currencyCode: operation.currencyCode,
        occurredAt: operationCalendarDateValue(operation.occurredAt),
        recurrence: _operationRecurrenceToJson(operation.recurrence),
        isRecurring: operation.isRecurring,
        note: Value(operation.note),
        createdAt: operation.createdAt,
        updatedAt: operation.updatedAt,
        syncStatus: syncStatus,
      ),
    );
  }

  Future<void> _markOperationSyncStatus(String id, String syncStatus) {
    return (update(
      operationsTable,
    )..where((table) => table.id.equals(id))).write(
      OperationsTableCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Operation _operationForUser(Operation operation, String userId) {
    return Operation(
      id: operation.id,
      userId: userId,
      source: operation.source,
      externalId: operation.externalId,
      isPending: operation.isPending,
      categoryOverridden: operation.categoryOverridden,
      fromAccountId: operation.fromAccountId,
      toAccountId: operation.toAccountId,
      categoryId: operation.categoryId,
      type: operation.type,
      amount: operation.amount,
      currencyCode: operation.currencyCode,
      occurredAt: operationCalendarDateValue(operation.occurredAt),
      recurrence: operation.recurrence,
      isRecurring: operation.isRecurring,
      note: operation.note,
      createdAt: operation.createdAt,
      updatedAt: operation.updatedAt,
    );
  }

  Operation? _operationFromRow(OperationRow row) {
    if (!_isKnownNullableCategoryId(row.categoryId)) {
      return null;
    }

    return Operation(
      id: row.id,
      userId: row.userId,
      source: OperationSource.fromJson(row.source),
      externalId: row.externalId,
      isPending: row.isPending,
      categoryOverridden: row.categoryOverridden,
      fromAccountId: row.fromAccountId,
      toAccountId: row.toAccountId,
      categoryId: row.categoryId,
      type: _operationTypeFromJson(row.type),
      amount: row.amount,
      currencyCode: row.currencyCode,
      occurredAt: operationCalendarDateValue(row.occurredAt),
      recurrence: _operationRecurrenceFromJson(row.recurrence),
      isRecurring: row.isRecurring,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  bool _isKnownNullableCategoryId(String? value) {
    return value == null || _isKnownCategoryId(value);
  }

  bool _isKnownCategoryId(String? value) {
    if (value == null) {
      return false;
    }

    return AppCategories.byIdName(value) != null;
  }

  BudgetFrequency _frequencyFromJson(String value) {
    return switch (value) {
      'daily' => BudgetFrequency.daily,
      'weekly' => BudgetFrequency.weekly,
      'biweekly' => BudgetFrequency.biweekly,
      'semi_monthly' => BudgetFrequency.semiMonthly,
      'monthly' => BudgetFrequency.monthly,
      'every_n_months' => BudgetFrequency.everyNMonths,
      'times_per_year' => BudgetFrequency.timesPerYear,
      'yearly' => BudgetFrequency.yearly,
      'irregular' => BudgetFrequency.irregular,
      _ => throw StateError('Unknown budget frequency: $value'),
    };
  }

  String _frequencyToJson(BudgetFrequency value) {
    return switch (value) {
      BudgetFrequency.daily => 'daily',
      BudgetFrequency.weekly => 'weekly',
      BudgetFrequency.biweekly => 'biweekly',
      BudgetFrequency.semiMonthly => 'semi_monthly',
      BudgetFrequency.monthly => 'monthly',
      BudgetFrequency.everyNMonths => 'every_n_months',
      BudgetFrequency.timesPerYear => 'times_per_year',
      BudgetFrequency.yearly => 'yearly',
      BudgetFrequency.irregular => 'irregular',
    };
  }

  OperationType _operationTypeFromJson(String value) {
    return switch (value) {
      'expense' => OperationType.expense,
      'income' => OperationType.income,
      'transfer' => OperationType.transfer,
      _ => throw StateError('Unknown operation type: $value'),
    };
  }

  String _operationTypeToJson(OperationType value) {
    return switch (value) {
      OperationType.expense => 'expense',
      OperationType.income => 'income',
      OperationType.transfer => 'transfer',
    };
  }

  OperationRecurrence _operationRecurrenceFromJson(String value) {
    return switch (value) {
      'none' => OperationRecurrence.none,
      'daily' => OperationRecurrence.daily,
      'weekly' => OperationRecurrence.weekly,
      'biweekly' => OperationRecurrence.biweekly,
      'monthly' => OperationRecurrence.monthly,
      'yearly' => OperationRecurrence.yearly,
      _ => throw StateError('Unknown operation recurrence: $value'),
    };
  }

  String _operationRecurrenceToJson(OperationRecurrence value) {
    return switch (value) {
      OperationRecurrence.none => 'none',
      OperationRecurrence.daily => 'daily',
      OperationRecurrence.weekly => 'weekly',
      OperationRecurrence.biweekly => 'biweekly',
      OperationRecurrence.monthly => 'monthly',
      OperationRecurrence.yearly => 'yearly',
    };
  }
}
