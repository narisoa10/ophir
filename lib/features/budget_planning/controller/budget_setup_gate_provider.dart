import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../auth/controller/auth_providers.dart';
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

  final localRepository = LocalBudgetPlanningRepository(
    database: ref.read(appDatabaseProvider),
    userId: user.id,
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
      await localRepository.saveSetup(remoteSetup);

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

  await localRepository.saveSetup(remoteSetup);

  if (remoteSetup.status == 'completed') {
    return BudgetSetupGateStatus.completed;
  }

  return BudgetSetupGateStatus.required;
});
