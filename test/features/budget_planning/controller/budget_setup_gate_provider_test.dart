import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/features/auth/controller/auth_providers.dart';
import 'package:ophir/features/budget_planning/controller/budget_planning_providers.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_provider.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_status.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/domain/repositories/budget_planning_repository.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';

final class _FakeUser implements User {
  _FakeUser({required this.id});

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeBudgetPlanningRepository implements BudgetPlanningRepository {
  _FakeBudgetPlanningRepository({this.remoteSetup, this.getCurrentSetupError});

  BudgetSetup? remoteSetup;
  final Object? getCurrentSetupError;
  int getCurrentSetupCalls = 0;

  @override
  Future<BudgetSetup?> getCurrentSetup() async {
    getCurrentSetupCalls++;
    if (getCurrentSetupError != null) {
      throw getCurrentSetupError!;
    }
    return remoteSetup;
  }

  @override
  Stream<BudgetSetup?> watchCurrentSetup() => throw UnimplementedError();

  @override
  Future<BudgetSetup> createSetup({required BudgetHousehold household}) =>
      throw UnimplementedError();

  @override
  Future<BudgetSetup> saveSetup(BudgetSetup setup) =>
      throw UnimplementedError();

  @override
  Future<void> replaceIncomeSources({
    required String setupId,
    required List<dynamic> incomeSources,
  }) => throw UnimplementedError();

  @override
  Future<void> replaceObligations({
    required String setupId,
    required List<dynamic> obligations,
  }) => throw UnimplementedError();

  @override
  Future<BudgetSetup> completeSetup(String setupId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSetup(String setupId) => throw UnimplementedError();
}

BudgetSetup _setup({
  required String id,
  String userId = 'user-1',
  String status = 'draft',
  int currentStep = 0,
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
}) {
  final now = DateTime.utc(2026);
  return BudgetSetup(
    id: id,
    userId: userId,
    status: status,
    version: 1,
    currentStep: currentStep,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: incomeSources,
    obligations: obligations,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource({required String currencyCode}) {
  return BudgetIncomeSource(
    id: 'income-$currencyCode',
    setupId: 'remote-id',
    userId: 'user-1',
    name: 'Salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: 1000,
    currencyCode: currencyCode,
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _obligation({required String currencyCode}) {
  return BudgetObligation(
    id: 'obligation-$currencyCode',
    setupId: 'remote-id',
    userId: 'user-1',
    categoryId: AppCategoryId.expenseHousingRent.name,
    obligationType: 'living_expense',
    amount: 500,
    currencyCode: currencyCode,
    frequency: BudgetFrequency.monthly,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeBudgetPlanningRepository repository,
  User? user,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      currentUserProvider.overrideWithValue(user ?? _FakeUser(id: 'user-1')),
      supabaseBudgetPlanningRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  group('budgetSetupGateProvider Tests', () {
    test('1. local completed -> completed, remote not called', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        getCurrentSetupError: StateError('Supabase should not be called'),
      );
      await database.saveBudgetSetup(_setup(id: 'user-1', status: 'completed'));
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.completed);
      expect(repository.getCurrentSetupCalls, 0);
    });

    test(
      '2. local draft + remote completed -> completed, remote saved locally',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remoteSetup = _setup(id: 'remote-id', status: 'completed');
        final repository = _FakeBudgetPlanningRepository(
          remoteSetup: remoteSetup,
        );
        await database.saveBudgetSetup(_setup(id: 'user-1', status: 'draft'));
        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        final status = await container.read(budgetSetupGateProvider.future);

        expect(status, BudgetSetupGateStatus.completed);
        expect(repository.getCurrentSetupCalls, 1);

        final localSetup = await database.getBudgetSetup('user-1');
        expect(localSetup?.id, 'user-1');
        expect(localSetup?.status, 'completed');
      },
    );

    test('3. local draft + remote draft -> required', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remoteSetup = _setup(id: 'remote-id', status: 'draft');
      final repository = _FakeBudgetPlanningRepository(
        remoteSetup: remoteSetup,
      );
      await database.saveBudgetSetup(_setup(id: 'user-1', status: 'draft'));
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.required);
      expect(repository.getCurrentSetupCalls, 1);
    });

    test('4. local draft + remote null -> required', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(remoteSetup: null);
      await database.saveBudgetSetup(_setup(id: 'user-1', status: 'draft'));
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.required);
      expect(repository.getCurrentSetupCalls, 1);
    });

    test('5. local draft + remote error -> required', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        getCurrentSetupError: StateError('Supabase error'),
      );
      await database.saveBudgetSetup(_setup(id: 'user-1', status: 'draft'));
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.required);
      expect(repository.getCurrentSetupCalls, 1);
    });

    test(
      '6. no local + remote completed -> completed, remote saved locally',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remoteSetup = _setup(id: 'remote-id', status: 'completed');
        final repository = _FakeBudgetPlanningRepository(
          remoteSetup: remoteSetup,
        );

        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        final status = await container.read(budgetSetupGateProvider.future);

        expect(status, BudgetSetupGateStatus.completed);
        expect(repository.getCurrentSetupCalls, 1);

        final localSetup = await database.getBudgetSetup('user-1');
        expect(localSetup?.id, 'user-1');
        expect(localSetup?.status, 'completed');
      },
    );

    test(
      '7. no local + remote draft -> required, remote saved locally',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remoteSetup = _setup(id: 'remote-id', status: 'draft');
        final repository = _FakeBudgetPlanningRepository(
          remoteSetup: remoteSetup,
        );

        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        final status = await container.read(budgetSetupGateProvider.future);

        expect(status, BudgetSetupGateStatus.required);
        expect(repository.getCurrentSetupCalls, 1);

        final localSetup = await database.getBudgetSetup('user-1');
        expect(localSetup?.id, 'user-1');
        expect(localSetup?.status, 'draft');
      },
    );

    test('8. no local + remote null -> required', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(remoteSetup: null);

      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.required);
      expect(repository.getCurrentSetupCalls, 1);

      final localSetup = await database.getBudgetSetup('user-1');
      expect(localSetup, isNull);
    });

    test('9. no local + remote error -> AsyncError', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        getCurrentSetupError: StateError('Supabase error'),
      );

      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      await expectLater(
        container.read(budgetSetupGateProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(repository.getCurrentSetupCalls, 1);
    });

    test('10. currentStep == 3 and status == draft -> required', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(remoteSetup: null);
      await database.saveBudgetSetup(
        _setup(id: 'user-1', status: 'draft', currentStep: 3),
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final status = await container.read(budgetSetupGateProvider.future);

      expect(status, BudgetSetupGateStatus.required);
      expect(repository.getCurrentSetupCalls, 1);
    });

    test(
      '11. status == completed and syncStatus == failed -> completed',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _FakeBudgetPlanningRepository(
          getCurrentSetupError: StateError('Supabase should not be called'),
        );
        await database.saveBudgetSetup(
          _setup(id: 'user-1', status: 'completed'),
        );
        await database.markBudgetSyncFailed('user-1');
        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        final status = await container.read(budgetSetupGateProvider.future);

        expect(status, BudgetSetupGateStatus.completed);
        expect(repository.getCurrentSetupCalls, 0);
      },
    );

    test('12. remote budget without items is stored as CAD', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        remoteSetup: _setup(id: 'remote-id', status: 'completed'),
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      await container.read(budgetSetupGateProvider.future);

      final localSetup = await database.getBudgetSetup('user-1');
      expect(localSetup?.currencyCode, 'CAD');
    });

    test('13. remote budget items keep their own currency locally', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        remoteSetup: _setup(
          id: 'remote-id',
          status: 'completed',
          incomeSources: [_incomeSource(currencyCode: 'USD')],
          obligations: [_obligation(currencyCode: 'USD')],
        ),
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      await container.read(budgetSetupGateProvider.future);

      final localSetup = await database.getBudgetSetup('user-1');
      expect(localSetup?.incomeSources.single.currencyCode, 'USD');
      expect(localSetup?.obligations.single.currencyCode, 'USD');
    });

    test(
      '14. remote budget mixing currencies -> AsyncError, nothing relabeled',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _FakeBudgetPlanningRepository(
          remoteSetup: _setup(
            id: 'remote-id',
            status: 'completed',
            incomeSources: [_incomeSource(currencyCode: 'CAD')],
            obligations: [_obligation(currencyCode: 'USD')],
          ),
        );
        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(budgetSetupGateProvider.future),
          throwsA(isA<StateError>()),
        );
        expect(await database.getBudgetSetup('user-1'), isNull);
      },
    );
  });
}
