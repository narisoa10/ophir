import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/controller/auth_providers.dart';
import '../../features/budget_planning/controller/budget_setup_gate_provider.dart';
import '../../features/budget_planning/controller/budget_setup_gate_status.dart';

enum AppStartupGateStatus {
  authLoading,
  authFailure,
  unauthenticated,
  budgetLoading,
  budgetFailure,
  budgetRequired,
  completed,
}

final appStartupGateProvider = Provider<AppStartupGateStatus>((ref) {
  final authState = ref.watch(authSessionProvider);

  return authState.when(
    loading: () => AppStartupGateStatus.authLoading,
    error: (error, stackTrace) => AppStartupGateStatus.authFailure,
    data: (session) {
      if (session == null) {
        return AppStartupGateStatus.unauthenticated;
      }

      final budgetState = ref.watch(budgetSetupGateProvider);

      return budgetState.when(
        loading: () => AppStartupGateStatus.budgetLoading,
        error: (error, stackTrace) => AppStartupGateStatus.budgetFailure,
        data: (status) {
          if (status == BudgetSetupGateStatus.required) {
            return AppStartupGateStatus.budgetRequired;
          } else {
            return AppStartupGateStatus.completed;
          }
        },
      );
    },
  );
});
