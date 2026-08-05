import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/auth/controller/auth_providers.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';
import 'package:ophir/features/budget_planning/controller/budget_planning_providers.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_provider.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_status.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/repositories/budget_planning_repository.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';

final class _FakeUser implements User {
  _FakeUser({required this.id});

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.currencyCode, this.shouldFail = false});

  final String currencyCode;
  final bool shouldFail;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    if (shouldFail) {
      return const Failure(UnknownFailure());
    }
    final now = DateTime.utc(2026);
    return Success(
      Profile(
        id: 'user-1',
        email: 'user@example.com',
        locale: 'en',
        currencyCode: currencyCode,
        timezone: 'America/Toronto',
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    return Success(profile);
  }

  @override
  Stream<Result<Profile>> watchCurrentProfile() {
    throw UnimplementedError();
  }
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
}) {
  final now = DateTime.utc(2026);
  return BudgetSetup(
    id: id,
    userId: userId,
    status: status,
    version: 1,
    currentStep: currentStep,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: const [],
    obligations: const [],
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeBudgetPlanningRepository repository,
  User? user,
  String currencyCode = 'USD',
  bool profileFails = false,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      currentUserProvider.overrideWithValue(user ?? _FakeUser(id: 'user-1')),
      supabaseBudgetPlanningRepositoryProvider.overrideWithValue(repository),
      profileRepositoryProvider.overrideWithValue(
        _FakeProfileRepository(
          currencyCode: currencyCode,
          shouldFail: profileFails,
        ),
      ),
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
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'user-1', status: 'completed'),
        'USD',
      );
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
        await database.saveBudgetSetupWithCurrency(
          _setup(id: 'user-1', status: 'draft'),
          'USD',
        );
        final container = _container(
          database: database,
          repository: repository,
          currencyCode: 'USD',
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
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'user-1', status: 'draft'),
        'USD',
      );
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
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'user-1', status: 'draft'),
        'USD',
      );
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
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'user-1', status: 'draft'),
        'USD',
      );
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
          currencyCode: 'USD',
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
          currencyCode: 'USD',
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
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'user-1', status: 'draft', currentStep: 3),
        'USD',
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
        await database.saveBudgetSetupWithCurrency(
          _setup(id: 'user-1', status: 'completed'),
          'USD',
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

    test(
      '12. local draft + remote completed + currency load error -> AsyncError',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remoteSetup = _setup(id: 'remote-id', status: 'completed');
        final repository = _FakeBudgetPlanningRepository(
          remoteSetup: remoteSetup,
        );
        await database.saveBudgetSetupWithCurrency(
          _setup(id: 'user-1', status: 'draft'),
          'USD',
        );
        final container = _container(
          database: database,
          repository: repository,
          profileFails: true,
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(budgetSetupGateProvider.future),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      '13. no local + remote completed + currency load error -> AsyncError',
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
          profileFails: true,
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(budgetSetupGateProvider.future),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
