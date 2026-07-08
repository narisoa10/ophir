import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/create_account_screen.dart';
import '../../features/auth/controller/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/categories/domain/enums/category_type.dart';
import '../../features/dashboard/presentation/screens/dashboard_actions_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_balance_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_cash_flow_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_financial_state_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_insights_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_today_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_upcoming_detail_screen.dart';
import '../../features/operations/domain/entities/operation.dart';
import '../../features/operations/presentation/screens/create_operation_screen.dart';
import '../../features/operations/presentation/screens/operation_category_picker_screen.dart';
import '../../features/operations/presentation/screens/operation_recurrence_picker_screen.dart';
import '../../features/operations/presentation/screens/operations_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.auth,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    routes: [
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
            path: AppRoutes.dashboardFinancialState,
            builder: (context, state) =>
                const DashboardFinancialStateDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardToday,
            builder: (context, state) => const DashboardTodayDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardBalance,
            builder: (context, state) => const DashboardBalanceDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardCashFlow,
            builder: (context, state) => const DashboardCashFlowDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardInsights,
            builder: (context, state) => const DashboardInsightsDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardUpcoming,
            builder: (context, state) => const DashboardUpcomingDetailScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardActions,
            builder: (context, state) => const DashboardActionsDetailScreen(),
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
        path: AppRoutes.createOperation,
        builder: (context, state) {
          final operation = switch (state.extra) {
            final Operation operation => operation,
            _ => null,
          };

          return CreateOperationScreen(operation: operation);
        },
      ),
      GoRoute(
        path: AppRoutes.operationRecurrencePicker,
        builder: (context, state) => const OperationRecurrencePickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.operationCategoryPicker,
        builder: (context, state) {
          final type = switch (state.extra) {
            final CategoryType type => type,
            final String value => CategoryType.fromJson(value),
            _ => CategoryType.expense,
          };

          return OperationCategoryPickerScreen(type: type);
        },
      ),
    ],
    redirect: (context, state) {
      final session = authRepository.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.auth;

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.auth;
      }

      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.initialAuthenticated;
      }

      return null;
    },
  );
});
