import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/create_account_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/budget_planning/controller/budget_setup_gate_provider.dart';
import '../../features/budget_planning/presentation/screens/budget_setup_screen.dart';
import '../../features/budget_planning/domain/enums/budget_setup_mode.dart';
import '../../features/category_rules/presentation/screens/category_rules_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/operations/presentation/screens/operation_recurrence_picker_screen.dart';
import '../../features/operations/presentation/screens/operations_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/settings_appearance_screen.dart';
import '../../features/settings/presentation/screens/settings_about_screen.dart';
import '../../features/settings/presentation/screens/settings_data_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../core/theme_v1/app_theme_colors.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'app_startup_gate_provider.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier();

  ref.listen(appStartupGateProvider, (previous, next) {
    refreshNotifier.notify();
  });

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: AppRoutes.failure,
        builder: (context, state) {
          final colors = context.appThemeColors;

          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 48),
                  const SizedBox(height: 16),
                  const Text('Failed to verify budget setup status'),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      return ElevatedButton(
                        onPressed: () {
                          ref.invalidate(budgetSetupGateProvider);
                        },
                        child: const Text('Retry'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.operations,
            builder: (context, state) => const OperationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.statistics,
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createAccount,
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAppearance,
        builder: (context, state) => const SettingsAppearanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsData,
        builder: (context, state) => const SettingsDataScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAbout,
        builder: (context, state) => const SettingsAboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.budgetEdit,
        builder: (context, state) =>
            const BudgetSetupScreen(mode: BudgetSetupMode.edit),
      ),
      GoRoute(
        path: AppRoutes.categoryRules,
        builder: (context, state) => const CategoryRulesScreen(),
      ),
      GoRoute(
        path: AppRoutes.operationRecurrencePicker,
        builder: (context, state) => const OperationRecurrencePickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.budgetSetup,
        builder: (context, state) =>
            const BudgetSetupScreen(mode: BudgetSetupMode.onboarding),
      ),
    ],
    redirect: (context, state) {
      final startupGate = ref.read(appStartupGateProvider);

      switch (startupGate) {
        case AppStartupGateStatus.authLoading:
        case AppStartupGateStatus.budgetLoading:
          if (state.matchedLocation == AppRoutes.splash) {
            return null;
          }
          return AppRoutes.splash;

        case AppStartupGateStatus.authFailure:
        case AppStartupGateStatus.budgetFailure:
          if (state.matchedLocation == AppRoutes.failure) {
            return null;
          }
          return AppRoutes.failure;

        case AppStartupGateStatus.unauthenticated:
          if (state.matchedLocation == AppRoutes.auth) {
            return null;
          }
          return AppRoutes.auth;

        case AppStartupGateStatus.budgetRequired:
          if (state.matchedLocation == AppRoutes.budgetSetup) {
            return null;
          }
          return AppRoutes.budgetSetup;

        case AppStartupGateStatus.completed:
          final isSplashRoute = state.matchedLocation == AppRoutes.splash;
          final isSetupRoute = state.matchedLocation == AppRoutes.budgetSetup;
          final isAuthRoute = state.matchedLocation == AppRoutes.auth;

          if (isSplashRoute || isSetupRoute || isAuthRoute) {
            return AppRoutes.dashboard;
          }
          return null;
      }
    },
  );
});
