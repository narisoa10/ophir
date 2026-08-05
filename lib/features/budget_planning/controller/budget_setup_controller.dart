import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/errors/result.dart';
import '../../profile/controller/profile_providers.dart';
import '../../profile/domain/entities/profile.dart';
import '../data/repositories/local_budget_planning_repository.dart';
import '../domain/entities/budget_household.dart';
import '../domain/entities/budget_income_source.dart';
import '../domain/entities/budget_obligation.dart';
import '../domain/entities/budget_setup.dart';
import '../domain/entities/budget_setup_draft.dart';
import '../domain/enums/budget_setup_mode.dart';
import 'budget_planning_providers.dart';

final budgetSetupControllerProvider =
    AsyncNotifierProvider.family<
      BudgetSetupController,
      BudgetSetup?,
      BudgetSetupMode
    >(BudgetSetupController.new);

@visibleForTesting
final budgetSetupUserIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    throw StateError('Current user is required.');
  }

  return user.id;
});

final class BudgetSetupController extends AsyncNotifier<BudgetSetup?> {
  BudgetSetupController(this.mode);

  final BudgetSetupMode mode;

  String? _currencyCode;

  String? get currencyCode => _currencyCode;

  @override
  Future<BudgetSetup?> build() async {
    final userId = _currentUserId();
    final profileCurrencyCode = await _loadProfileCurrencyCode();
    _currencyCode = profileCurrencyCode;

    final localRepository = _localRepository(userId);
    final localSetup = await localRepository.getCurrentSetup();

    if (localSetup != null) {
      if (mode == BudgetSetupMode.edit) {
        return _copySetup(localSetup, currentStep: 0);
      }
      return localSetup;
    }

    final migratedDraft = await _migrateLegacyDraft(
      userId: userId,
      fallbackCurrencyCode: profileCurrencyCode,
    );

    if (migratedDraft != null) {
      return migratedDraft;
    }

    final persistedSetup = await ref
        .read(supabaseBudgetPlanningRepositoryProvider)
        .getCurrentSetup();

    if (persistedSetup != null) {
      await localRepository.saveSetupWithCurrency(
        persistedSetup,
        profileCurrencyCode,
      );

      return await localRepository.getCurrentSetup() ?? persistedSetup;
    }

    final initialSetup = _initialSetup(userId);
    await localRepository.saveSetupWithCurrency(
      initialSetup,
      profileCurrencyCode,
    );

    return await localRepository.getCurrentSetup() ?? initialSetup;
  }

  Future<void> saveHouseholdDraftAndGoNext(BudgetHousehold household) async {
    final setup = _currentSetup();
    final updatedSetup = _copySetup(
      setup,
      household: household,
      currentStep: 1,
    );

    await _saveLocalSetup(updatedSetup);
    state = AsyncData(updatedSetup);
  }

  Future<void> saveIncomeSourcesDraftAndGoNext(
    List<BudgetIncomeSource> incomeSources,
  ) async {
    final setup = _currentSetup();
    final updatedSetup = _copySetup(
      setup,
      incomeSources: incomeSources,
      currentStep: 2,
    );

    await _saveLocalSetup(updatedSetup);
    state = AsyncData(updatedSetup);
  }

  Future<void> saveObligationsDraftAndGoNext(
    List<BudgetObligation> obligations,
  ) async {
    final setup = _currentSetup();
    final updatedSetup = _copySetup(
      setup,
      obligations: obligations,
      currentStep: 3,
    );

    await _saveLocalSetup(updatedSetup);
    state = AsyncData(updatedSetup);
  }

  Future<void> goToPreviousStep() async {
    final setup = _currentSetup();
    final updatedSetup = _copySetup(
      setup,
      currentStep: _clampStep(setup.currentStep - 1),
    );

    await _saveLocalSetup(updatedSetup);
    state = AsyncData(updatedSetup);
  }

  Future<void> goToNextStep() async {
    final setup = _currentSetup();
    final updatedSetup = _copySetup(
      setup,
      currentStep: _clampStep(setup.currentStep + 1),
    );

    await _saveLocalSetup(updatedSetup);
    state = AsyncData(updatedSetup);
  }

  Future<bool> completeBudgetSetup() async {
    final draft = _currentSetup();
    final now = DateTime.now().toUtc();
    final completedDraft = BudgetSetup(
      id: draft.id,
      userId: draft.userId,
      status: 'completed',
      version: draft.version,
      currentStep: 3,
      household: draft.household,
      incomeSources: draft.incomeSources,
      obligations: draft.obligations,
      completedAt: now,
      createdAt: draft.createdAt,
      updatedAt: now,
    );
    final localRepository = _localRepository(draft.userId);

    await localRepository.saveSetupWithCurrency(
      completedDraft,
      _requiredCurrencyCode(),
    );
    state = AsyncData(
      await localRepository.getCurrentSetup() ?? completedDraft,
    );

    try {
      final repository = ref.read(supabaseBudgetPlanningRepositoryProvider);
      final existingSetup = await repository.getCurrentSetup();
      final setupToSave =
          existingSetup ??
          await repository.createSetup(household: completedDraft.household);
      final savedSetup = await repository.saveSetup(
        _completedSetupForPersistence(setupToSave, completedDraft),
      );
      await repository.completeSetup(savedSetup.id);
      await localRepository.markBudgetSynced();
      state = AsyncData(
        await localRepository.getCurrentSetup() ?? completedDraft,
      );
      return true;
    } catch (error) {
      await localRepository.markBudgetSyncFailed();
      state = AsyncData(
        await localRepository.getCurrentSetup() ?? completedDraft,
      );
      return true;
    }
  }

  BudgetSetup _copySetup(
    BudgetSetup setup, {
    BudgetHousehold? household,
    int? currentStep,
    List<BudgetIncomeSource>? incomeSources,
    List<BudgetObligation>? obligations,
  }) {
    return BudgetSetup(
      id: setup.id,
      userId: setup.userId,
      status: setup.status,
      version: setup.version,
      currentStep: _clampStep(currentStep ?? setup.currentStep),
      household: household ?? setup.household,
      incomeSources: incomeSources ?? setup.incomeSources,
      obligations: obligations ?? setup.obligations,
      completedAt: setup.completedAt,
      createdAt: setup.createdAt,
      updatedAt: setup.updatedAt,
    );
  }

  BudgetSetup _completedSetupForPersistence(
    BudgetSetup persistedSetup,
    BudgetSetup draft,
  ) {
    final now = DateTime.now().toUtc();

    return BudgetSetup(
      id: persistedSetup.id,
      userId: persistedSetup.userId,
      status: 'completed',
      version: persistedSetup.version,
      currentStep: 3,
      household: draft.household,
      incomeSources: _incomeSourcesForSetup(draft, persistedSetup),
      obligations: _obligationsForSetup(draft, persistedSetup),
      completedAt: now,
      createdAt: persistedSetup.createdAt,
      updatedAt: persistedSetup.updatedAt,
    );
  }

  List<BudgetIncomeSource> _incomeSourcesForSetup(
    BudgetSetup draft,
    BudgetSetup persistedSetup,
  ) {
    return draft.incomeSources
        .map(
          (incomeSource) => BudgetIncomeSource(
            id: incomeSource.id,
            setupId: persistedSetup.id,
            userId: persistedSetup.userId,
            name: incomeSource.name,
            categoryId: incomeSource.categoryId,
            amount: incomeSource.amount,
            currencyCode: incomeSource.currencyCode,
            frequency: incomeSource.frequency,
            frequencyInterval: incomeSource.frequencyInterval,
            timesPerYear: incomeSource.timesPerYear,
            nextDate: incomeSource.nextDate,
            source: incomeSource.source,
            confidence: incomeSource.confidence,
            isActive: incomeSource.isActive,
          ),
        )
        .toList(growable: false);
  }

  List<BudgetObligation> _obligationsForSetup(
    BudgetSetup draft,
    BudgetSetup persistedSetup,
  ) {
    return draft.obligations
        .map(
          (obligation) => BudgetObligation(
            id: obligation.id,
            setupId: persistedSetup.id,
            userId: persistedSetup.userId,
            categoryId: obligation.categoryId,
            obligationType: obligation.obligationType,
            amount: obligation.amount,
            currencyCode: obligation.currencyCode,
            frequency: obligation.frequency,
            frequencyInterval: obligation.frequencyInterval,
            timesPerYear: obligation.timesPerYear,
            nextDueDate: obligation.nextDueDate,
            minimumDebtPayment: obligation.minimumDebtPayment,
            name: obligation.name,
            isOverdue: obligation.isOverdue,
            source: obligation.source,
            confidence: obligation.confidence,
            isActive: obligation.isActive,
            note: obligation.note,
          ),
        )
        .toList(growable: false);
  }

  BudgetSetup _currentSetup() {
    return state.value ?? _initialSetup(_currentUserId());
  }

  BudgetSetup _initialSetup(String userId) {
    final now = DateTime.now().toUtc();

    return BudgetSetup(
      id: '',
      userId: userId,
      status: 'draft',
      version: 1,
      currentStep: 0,
      household: const BudgetHousehold(adultsCount: 1, childrenCount: 0),
      incomeSources: const [],
      obligations: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  BudgetSetup _setupFromDraft(BudgetSetupDraft draft) {
    final now = DateTime.now().toUtc();

    return BudgetSetup(
      id: '',
      userId: draft.userId,
      status: 'draft',
      version: draft.version,
      currentStep: _clampStep(draft.currentStep),
      household: draft.household,
      incomeSources: draft.incomeSources,
      obligations: draft.obligations,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _saveLocalSetup(BudgetSetup setup) async {
    if (mode == BudgetSetupMode.edit) {
      return;
    }
    await _localRepository(
      setup.userId,
    ).saveSetupWithCurrency(setup, _requiredCurrencyCode());
  }

  Future<BudgetSetup?> _migrateLegacyDraft({
    required String userId,
    required String fallbackCurrencyCode,
  }) async {
    final storage = ref.read(budgetSetupDraftStorageProvider);
    final draft = await storage.loadDraft(userId);

    if (draft == null) {
      return null;
    }

    _currencyCode = draft.currencyCode.isNotEmpty
        ? draft.currencyCode
        : fallbackCurrencyCode;

    final setup = _setupFromDraft(draft);
    final localRepository = _localRepository(userId);
    await localRepository.saveSetupWithCurrency(setup, _requiredCurrencyCode());
    await storage.clearDraft(userId);

    return await localRepository.getCurrentSetup() ?? setup;
  }

  LocalBudgetPlanningRepository _localRepository(String userId) {
    return LocalBudgetPlanningRepository(
      database: ref.read(appDatabaseProvider),
      userId: userId,
      currencyCode: _requiredCurrencyCode,
    );
  }

  String _currentUserId() {
    return ref.read(budgetSetupUserIdProvider);
  }

  int _clampStep(int currentStep) {
    return currentStep.clamp(0, 3).toInt();
  }

  Future<String> _loadProfileCurrencyCode() async {
    final repository = ref.read(profileRepositoryProvider);
    final profileResult = await repository.getCurrentProfile();

    if (profileResult is Success<Profile>) {
      return profileResult.value.currencyCode;
    }

    throw StateError('Unable to load current profile currency.');
  }

  String _requiredCurrencyCode() {
    final value = _currencyCode;

    if (value == null || value.isEmpty) {
      throw StateError('Budget setup currency code is required.');
    }

    return value;
  }
}
