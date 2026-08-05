import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/errors/result.dart';
import '../../auth/controller/auth_providers.dart';
import '../../profile/controller/profile_providers.dart';
import '../../profile/domain/entities/profile.dart';
import '../data/repositories/local_budget_planning_repository.dart';
import '../domain/entities/budget_setup.dart';
import 'budget_planning_providers.dart';
import 'budget_setup_gate_status.dart';

final budgetSetupGateProvider = FutureProvider<BudgetSetupGateStatus>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('Current user is required.');
  }
  final userId = user.id;

  String? currencyCode;

  String getRequiredCurrencyCode() {
    final code = currencyCode;
    if (code == null || code.isEmpty) {
      throw StateError('Budget setup currency code is required.');
    }
    return code;
  }

  final localRepository = LocalBudgetPlanningRepository(
    database: ref.read(appDatabaseProvider),
    userId: userId,
    currencyCode: getRequiredCurrencyCode,
  );

  final localSetup = await localRepository.getCurrentSetup();

  if (localSetup != null) {
    if (localSetup.status == 'completed') {
      return BudgetSetupGateStatus.completed;
    }

    BudgetSetup? remoteSetup;
    try {
      remoteSetup = await ref
          .read(supabaseBudgetPlanningRepositoryProvider)
          .getCurrentSetup();
    } catch (_) {
      return BudgetSetupGateStatus.required;
    }

    if (remoteSetup != null && remoteSetup.status == 'completed') {
      final profileRepository = ref.read(profileRepositoryProvider);
      final profileResult = await profileRepository.getCurrentProfile();

      if (profileResult is! Success<Profile>) {
        throw StateError('Unable to load current profile currency.');
      }

      final currency = profileResult.value.currencyCode;
      currencyCode = currency;

      await localRepository.saveSetupWithCurrency(remoteSetup, currency);

      return BudgetSetupGateStatus.completed;
    }

    return BudgetSetupGateStatus.required;
  }

  final remoteSetup = await ref
      .read(supabaseBudgetPlanningRepositoryProvider)
      .getCurrentSetup();

  if (remoteSetup == null) {
    return BudgetSetupGateStatus.required;
  }

  final profileRepository = ref.read(profileRepositoryProvider);
  final profileResult = await profileRepository.getCurrentProfile();

  if (profileResult is! Success<Profile>) {
    throw StateError('Unable to load current profile currency.');
  }

  final currency = profileResult.value.currencyCode;
  currencyCode = currency;

  await localRepository.saveSetupWithCurrency(remoteSetup, currency);

  if (remoteSetup.status == 'completed') {
    return BudgetSetupGateStatus.completed;
  }

  return BudgetSetupGateStatus.required;
});
