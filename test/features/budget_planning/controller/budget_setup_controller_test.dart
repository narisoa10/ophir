import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/budget_planning/controller/budget_planning_providers.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_controller.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_setup_mode.dart';
import 'package:ophir/features/budget_planning/data/local/budget_setup_draft_storage.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup_draft.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/domain/repositories/budget_planning_repository.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BudgetSetupController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns Drift setup without calling Supabase', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository(
        getCurrentSetupError: StateError('Supabase should not be called'),
      );
      await database.saveBudgetSetupWithCurrency(
        _setup(id: 'local-setup', currentStep: 2),
        'CAD',
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final setup = await container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );

      expect(repository.getCurrentSetupCalls, 0);
      expect(setup?.id, 'user-1');
      expect(setup?.currentStep, 2);
    });

    test('migrates legacy SharedPreferences draft into Drift', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final draft = _draft(
        currentStep: 2,
        currencyCode: 'EUR',
        household: const BudgetHousehold(adultsCount: 2, childrenCount: 1),
        incomeSources: [_incomeSource(id: 'income-draft', amount: 1000)],
      );
      await const BudgetSetupDraftStorage().saveDraft(draft);
      final repository = _FakeBudgetPlanningRepository(
        getCurrentSetupError: StateError('Supabase should not be called'),
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final setup = await container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );
      final localSetup = await database.getBudgetSetup('user-1');

      expect(repository.getCurrentSetupCalls, 0);
      expect(setup?.currentStep, 2);
      expect(
        localSetup?.incomeSources.single.categoryId,
        'incomeEmploymentSalary',
      );
      expect(localSetup?.incomeSources.single.name, 'Main salary');
      expect(await const BudgetSetupDraftStorage().loadDraft('user-1'), isNull);
      expect(
        container
            .read(
              budgetSetupControllerProvider(
                BudgetSetupMode.onboarding,
              ).notifier,
            )
            .currencyCode,
        'EUR',
      );
    });

    test('uses Supabase fallback and stores result in Drift', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final persistedSetup = _setup(
        id: 'persisted-setup',
        status: 'completed',
        currentStep: 3,
        incomeSources: [_incomeSource(id: 'income-persisted', amount: 2000)],
      );
      final repository = _FakeBudgetPlanningRepository(
        currentSetup: persistedSetup,
      );
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final setup = await container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );
      final localSetup = await database.getBudgetSetup('user-1');

      expect(repository.getCurrentSetupCalls, 1);
      expect(setup?.id, 'user-1');
      expect(localSetup?.incomeSources.single.id, 'income-persisted');
    });

    test('creates initial setup in Drift when no data exists', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository();
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);

      final setup = await container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );
      final localSetup = await database.getBudgetSetup('user-1');

      expect(repository.getCurrentSetupCalls, 1);
      expect(setup?.id, 'user-1');
      expect(localSetup?.status, 'draft');
      expect(localSetup?.currentStep, 0);
    });

    test('saves confirmed step changes to Drift', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository();
      final container = _container(database: database, repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).notifier,
      );

      await container.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );
      await controller.saveHouseholdDraftAndGoNext(
        const BudgetHousehold(adultsCount: 2, childrenCount: 0),
      );
      var setup = await database.getBudgetSetup('user-1');
      expect(setup?.currentStep, 1);
      expect(setup?.household.adultsCount, 2);

      await controller.saveIncomeSourcesDraftAndGoNext([
        _incomeSource(id: 'income-step', amount: 1200),
      ]);
      setup = await database.getBudgetSetup('user-1');
      expect(setup?.currentStep, 2);
      expect(setup?.incomeSources.single.categoryId, 'incomeEmploymentSalary');
      expect(setup?.incomeSources.single.name, 'Main salary');

      await controller.saveObligationsDraftAndGoNext([
        _obligation(id: 'obligation-step', amount: 300),
      ]);
      setup = await database.getBudgetSetup('user-1');
      expect(setup?.currentStep, 3);
      expect(setup?.obligations.single.categoryId, 'expenseHousingRent');

      await controller.goToPreviousStep();
      setup = await database.getBudgetSetup('user-1');
      expect(setup?.currentStep, 2);
    });

    test(
      'complete keeps completed setup locally when Supabase fails',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _FakeBudgetPlanningRepository(
          saveSetupError: StateError('offline'),
        );
        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        await container.read(
          budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
        );
        final completed = await container
            .read(
              budgetSetupControllerProvider(
                BudgetSetupMode.onboarding,
              ).notifier,
            )
            .completeBudgetSetup();
        final localSetup = await database.getBudgetSetup('user-1');

        expect(completed, isTrue);
        expect(localSetup?.status, 'completed');
        expect(localSetup?.completedAt, isNotNull);
      },
    );

    test('new build keeps using Drift after completion', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _FakeBudgetPlanningRepository();
      final firstContainer = _container(
        database: database,
        repository: repository,
      );
      addTearDown(firstContainer.dispose);

      await firstContainer.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );
      await firstContainer
          .read(
            budgetSetupControllerProvider(BudgetSetupMode.onboarding).notifier,
          )
          .saveIncomeSourcesDraftAndGoNext([
            _incomeSource(id: 'income-completed', amount: 2500),
          ]);
      expect(
        await firstContainer
            .read(
              budgetSetupControllerProvider(
                BudgetSetupMode.onboarding,
              ).notifier,
            )
            .completeBudgetSetup(),
        isTrue,
      );

      final secondContainer = _container(
        database: database,
        repository: repository,
      );
      addTearDown(secondContainer.dispose);
      final callsAfterCompletion = repository.getCurrentSetupCalls;

      final setup = await secondContainer.read(
        budgetSetupControllerProvider(BudgetSetupMode.onboarding).future,
      );

      expect(repository.getCurrentSetupCalls, callsAfterCompletion);
      expect(setup?.status, 'completed');
      expect(setup?.incomeSources.single.id, 'income-completed');
    });
  });

  group('BudgetSetupController - edit mode', () {
    test(
      'edit-transition does not write to local DB and keeps status completed',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final initialSetup = _setup(
          id: 'persisted-setup',
          status: 'completed',
          currentStep: 3,
          incomeSources: [_incomeSource(id: 'inc-1', amount: 1000)],
        );

        await database.saveBudgetSetupWithCurrency(initialSetup, 'CAD');

        final repository = _FakeBudgetPlanningRepository(
          currentSetup: initialSetup,
        );
        final container = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container.dispose);

        final setup = await container.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).future,
        );
        expect(setup?.status, 'completed');
        expect(setup?.currentStep, 0);

        final controller = container.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).notifier,
        );
        await controller.saveHouseholdDraftAndGoNext(
          const BudgetHousehold(adultsCount: 3, childrenCount: 2),
        );

        final modifiedSetup = await container.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).future,
        );
        expect(modifiedSetup?.household.adultsCount, 3);
        expect(modifiedSetup?.currentStep, 1);
        expect(modifiedSetup?.status, 'completed');

        final dbSetup = await database.getBudgetSetup('user-1');
        expect(dbSetup?.household.adultsCount, 1);
        expect(dbSetup?.currentStep, 3);
        expect(dbSetup?.status, 'completed');
      },
    );

    test(
      'reopening edit mode after disposal discards cancelled draft and reloads from DB',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final initialSetup = _setup(
          id: 'persisted-setup',
          status: 'completed',
          currentStep: 3,
          incomeSources: [_incomeSource(id: 'inc-1', amount: 1000)],
        );
        await database.saveBudgetSetupWithCurrency(initialSetup, 'CAD');

        final repository = _FakeBudgetPlanningRepository(
          currentSetup: initialSetup,
        );

        final container1 = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container1.dispose);

        await container1.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).future,
        );
        final controller1 = container1.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).notifier,
        );

        await controller1.saveHouseholdDraftAndGoNext(
          const BudgetHousehold(adultsCount: 5, childrenCount: 5),
        );

        final mod1 = await container1.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).future,
        );
        expect(mod1?.household.adultsCount, 5);

        container1.dispose();

        final container2 = _container(
          database: database,
          repository: repository,
        );
        addTearDown(container2.dispose);

        final reloaded = await container2.read(
          budgetSetupControllerProvider(BudgetSetupMode.edit).future,
        );
        expect(reloaded?.household.adultsCount, 1);
        expect(reloaded?.currentStep, 0);
      },
    );
  });
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeBudgetPlanningRepository repository,
  String userId = 'user-1',
  String currencyCode = 'CAD',
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      budgetSetupUserIdProvider.overrideWithValue(userId),
      supabaseBudgetPlanningRepositoryProvider.overrideWithValue(repository),
      profileRepositoryProvider.overrideWithValue(
        _FakeProfileRepository(currencyCode: currencyCode),
      ),
    ],
  );
}

final class _FakeBudgetPlanningRepository implements BudgetPlanningRepository {
  _FakeBudgetPlanningRepository({
    this.currentSetup,
    this.getCurrentSetupError,
    this.saveSetupError,
  });

  BudgetSetup? currentSetup;
  final Object? getCurrentSetupError;
  final Object? saveSetupError;
  int getCurrentSetupCalls = 0;

  @override
  Future<BudgetSetup?> getCurrentSetup() async {
    getCurrentSetupCalls += 1;

    if (getCurrentSetupError != null) {
      throw getCurrentSetupError!;
    }

    return currentSetup;
  }

  @override
  Stream<BudgetSetup?> watchCurrentSetup() {
    throw UnimplementedError();
  }

  @override
  Future<BudgetSetup> createSetup({required BudgetHousehold household}) async {
    final setup = _setup(id: 'created-setup', household: household);
    currentSetup = setup;
    return setup;
  }

  @override
  Future<BudgetSetup> saveSetup(BudgetSetup setup) async {
    if (saveSetupError != null) {
      throw saveSetupError!;
    }

    currentSetup = setup;
    return setup;
  }

  @override
  Future<void> replaceIncomeSources({
    required String setupId,
    required List<BudgetIncomeSource> incomeSources,
  }) async {}

  @override
  Future<void> replaceObligations({
    required String setupId,
    required List<BudgetObligation> obligations,
  }) async {}

  @override
  Future<BudgetSetup> completeSetup(String setupId) async {
    final setup = currentSetup!;
    final completedSetup = _setup(
      id: setup.id,
      userId: setup.userId,
      status: 'completed',
      currentStep: 3,
      household: setup.household,
      incomeSources: setup.incomeSources,
      obligations: setup.obligations,
      completedAt: DateTime.utc(2026),
    );
    currentSetup = completedSetup;
    return completedSetup;
  }

  @override
  Future<void> deleteSetup(String setupId) async {
    if (currentSetup?.id == setupId) {
      currentSetup = null;
    }
  }
}

final class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository({required this.currencyCode});

  final String currencyCode;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
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

BudgetSetupDraft _draft({
  int currentStep = 1,
  String currencyCode = 'CAD',
  BudgetHousehold household = const BudgetHousehold(
    adultsCount: 1,
    childrenCount: 0,
  ),
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
}) {
  return BudgetSetupDraft(
    userId: 'user-1',
    currencyCode: currencyCode,
    currentStep: currentStep,
    household: household,
    incomeSources: incomeSources,
    obligations: obligations,
    version: 1,
  );
}

BudgetSetup _setup({
  required String id,
  String userId = 'user-1',
  String status = 'draft',
  int currentStep = 0,
  BudgetHousehold household = const BudgetHousehold(
    adultsCount: 1,
    childrenCount: 0,
  ),
  List<BudgetIncomeSource> incomeSources = const [],
  List<BudgetObligation> obligations = const [],
  DateTime? completedAt,
}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: id,
    userId: userId,
    status: status,
    version: 1,
    currentStep: currentStep,
    household: household,
    incomeSources: incomeSources,
    obligations: obligations,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource({required String id, required double amount}) {
  return BudgetIncomeSource(
    id: id,
    setupId: '',
    userId: 'user-1',
    name: 'Main salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: amount,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.confirmed,
    confidence: BudgetDataConfidence.verified,
    isActive: true,
  );
}

BudgetObligation _obligation({required String id, required double amount}) {
  return BudgetObligation(
    id: id,
    setupId: '',
    userId: 'user-1',
    categoryId: AppCategoryId.expenseHousingRent.name,
    obligationType: 'living_expense',
    amount: amount,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    isOverdue: false,
    source: BudgetDataSource.confirmed,
    confidence: BudgetDataConfidence.verified,
    isActive: true,
  );
}
