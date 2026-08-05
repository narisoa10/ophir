import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/budget_planning/controller/budget_planning_providers.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_controller.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_household.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_income_source.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_obligation.dart';
import 'package:ophir/features/budget_planning/domain/entities/budget_setup.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_confidence.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_data_source.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_frequency.dart';
import 'package:ophir/features/budget_planning/domain/repositories/budget_planning_repository.dart';
import 'package:ophir/features/budget_planning/domain/enums/budget_setup_mode.dart';
import 'package:ophir/features/budget_planning/presentation/screens/budget_setup_screen.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BudgetSetupScreen shell', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows localized budget planning title in Russian', (
      tester,
    ) async {
      const locale = Locale('ru');
      final l10n = lookupAppLocalizations(locale);

      await _pumpScreen(tester, locale: locale);

      expect(find.text(l10n.budgetSetupTitle), findsOneWidget);
    });

    testWidgets('first step shows first progress and only next action', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await _pumpScreen(tester);

      expect(find.text(l10n.budgetSetupTitle), findsOneWidget);
      expect(find.text(l10n.budgetSetupStepProgress(1, 4)), findsOneWidget);
      expect(find.byKey(_backButtonKey), findsNothing);
      expect(find.byKey(_nextButtonKey), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(_nextButtonKey)).tooltip,
        l10n.budgetContinue,
      );
      expect(find.byKey(_finishButtonKey), findsNothing);
    });

    testWidgets('next and back update shell progress within range', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await _pumpScreen(tester);

      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.budgetSetupStepProgress(2, 4)), findsOneWidget);
      expect(find.byKey(_backButtonKey), findsOneWidget);
      expect(find.byKey(_nextButtonKey), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(_backButtonKey)).tooltip,
        l10n.budgetBack,
      );
      expect(
        tester.widget<IconButton>(find.byKey(_nextButtonKey)).tooltip,
        l10n.budgetContinue,
      );

      await tester.tap(find.byKey(_backButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.budgetSetupStepProgress(1, 4)), findsOneWidget);
      expect(find.byKey(_backButtonKey), findsNothing);
      expect(find.byKey(_nextButtonKey), findsOneWidget);
    });

    testWidgets('last step shows final progress and finish action', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await _pumpScreen(tester, currentStep: _finishStepIndex);

      expect(find.text(l10n.budgetSetupStepProgress(4, 4)), findsOneWidget);
      expect(find.byKey(_backButtonKey), findsOneWidget);
      expect(find.byKey(_nextButtonKey), findsNothing);
      expect(find.byKey(_finishButtonKey), findsOneWidget);
      expect(find.text(l10n.budgetSetupFinish), findsOneWidget);
    });

    testWidgets('stored step below range is clamped to first step', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await _pumpScreen(tester, currentStep: _beforeFirstStepIndex);

      expect(find.text(l10n.budgetSetupStepProgress(1, 4)), findsOneWidget);
      expect(find.byKey(_backButtonKey), findsNothing);
      expect(find.byKey(_nextButtonKey), findsOneWidget);
    });

    testWidgets('stored step above range is clamped to last step', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await _pumpScreen(tester, currentStep: _afterLastStepIndex);

      expect(find.text(l10n.budgetSetupStepProgress(4, 4)), findsOneWidget);
      expect(find.byKey(_nextButtonKey), findsNothing);
      expect(find.byKey(_finishButtonKey), findsOneWidget);
    });

    testWidgets(
      'edit screen pop discards in-memory draft on same ProviderContainer/ProviderScope',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final initialSetup = _setup(currentStep: 3);
        await database.saveBudgetSetupWithCurrency(initialSetup, 'CAD');

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            budgetSetupUserIdProvider.overrideWithValue('user-1'),
            supabaseBudgetPlanningRepositoryProvider.overrideWithValue(
              _FakeBudgetPlanningRepository(),
            ),
            profileRepositoryProvider.overrideWithValue(
              const _FakeProfileRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final key = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: key,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BudgetSetupScreen(
                            mode: BudgetSetupMode.edit,
                          ),
                        ),
                      );
                    },
                    child: const Text('Go'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.byType(BudgetSetupScreen), findsOneWidget);
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.budgetSetupStepProgress(1, 4)), findsOneWidget);

        await tester.tap(find.byKey(_nextButtonKey));
        await tester.pumpAndSettle();
        expect(find.text(l10n.budgetSetupStepProgress(2, 4)), findsOneWidget);

        var setupInMem = container
            .read(budgetSetupControllerProvider(BudgetSetupMode.edit))
            .value;
        expect(setupInMem?.currentStep, 1);

        key.currentState?.pop();
        await tester.pumpAndSettle();

        expect(find.byType(BudgetSetupScreen), findsNothing);

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.byType(BudgetSetupScreen), findsOneWidget);
        expect(find.text(l10n.budgetSetupStepProgress(1, 4)), findsOneWidget);

        final setupReopened = container
            .read(budgetSetupControllerProvider(BudgetSetupMode.edit))
            .value;
        expect(setupReopened?.currentStep, 0);

        key.currentState?.pop();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('onboarding screen pop does NOT discard in-memory draft', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final initialSetup = _setup(currentStep: 0);
      await database.saveBudgetSetupWithCurrency(initialSetup, 'CAD');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          budgetSetupUserIdProvider.overrideWithValue('user-1'),
          supabaseBudgetPlanningRepositoryProvider.overrideWithValue(
            _FakeBudgetPlanningRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(
            const _FakeProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: key,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BudgetSetupScreen(
                          mode: BudgetSetupMode.onboarding,
                        ),
                      ),
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.budgetSetupStepProgress(2, 4)), findsOneWidget);

      var setupInMem = container
          .read(budgetSetupControllerProvider(BudgetSetupMode.onboarding))
          .value;
      expect(setupInMem?.currentStep, 1);

      key.currentState?.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetSetupScreen), findsOneWidget);
      expect(find.text(l10n.budgetSetupStepProgress(2, 4)), findsOneWidget);

      final setupReopened = container
          .read(budgetSetupControllerProvider(BudgetSetupMode.onboarding))
          .value;
      expect(setupReopened?.currentStep, 1);
    });
  });
}

const _backButtonKey = ValueKey<String>('budget-setup-back-button');
const _nextButtonKey = ValueKey<String>('budget-setup-next-button');
const _finishButtonKey = ValueKey<String>('budget-setup-finish-button');
const _finishStepIndex = 3;
const _beforeFirstStepIndex = -1;
const _afterLastStepIndex = 99;

Future<void> _pumpScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  int currentStep = 0,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  await database.saveBudgetSetupWithCurrency(
    _setup(currentStep: currentStep),
    'CAD',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        budgetSetupUserIdProvider.overrideWithValue('user-1'),
        supabaseBudgetPlanningRepositoryProvider.overrideWithValue(
          _FakeBudgetPlanningRepository(),
        ),
        profileRepositoryProvider.overrideWithValue(
          const _FakeProfileRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BudgetSetupScreen(mode: BudgetSetupMode.onboarding),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BudgetSetup _setup({required int currentStep}) {
  final now = DateTime.utc(2026);

  return BudgetSetup(
    id: 'user-1',
    userId: 'user-1',
    status: 'draft',
    version: 1,
    currentStep: currentStep,
    household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
    incomeSources: [_incomeSource()],
    obligations: [_obligation()],
    createdAt: now,
    updatedAt: now,
  );
}

BudgetIncomeSource _incomeSource() {
  return BudgetIncomeSource(
    id: 'income-1',
    setupId: 'user-1',
    userId: 'user-1',
    name: 'Main salary',
    categoryId: AppCategoryId.incomeEmploymentSalary.name,
    amount: 1000,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

BudgetObligation _obligation() {
  return BudgetObligation(
    id: 'obligation-1',
    setupId: 'user-1',
    userId: 'user-1',
    categoryId: AppCategoryId.expenseHousingRent.name,
    obligationType: 'living_expense',
    amount: 42,
    currencyCode: 'CAD',
    frequency: BudgetFrequency.monthly,
    isOverdue: false,
    source: BudgetDataSource.declared,
    confidence: BudgetDataConfidence.estimated,
    isActive: true,
  );
}

final class _FakeBudgetPlanningRepository implements BudgetPlanningRepository {
  @override
  Future<BudgetSetup?> getCurrentSetup() async {
    return null;
  }

  @override
  Stream<BudgetSetup?> watchCurrentSetup() {
    return const Stream.empty();
  }

  @override
  Future<BudgetSetup> createSetup({required BudgetHousehold household}) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetSetup> saveSetup(BudgetSetup setup) async {
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
  Future<BudgetSetup> completeSetup(String setupId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSetup(String setupId) async {}
}

final class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository();

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    final now = DateTime.utc(2026);

    return Success(
      Profile(
        id: 'user-1',
        email: 'user@example.com',
        locale: 'en',
        currencyCode: 'CAD',
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
    return const Stream.empty();
  }
}
