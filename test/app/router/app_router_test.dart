import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ophir/app/router/app_router.dart';
import 'package:ophir/app/router/app_routes.dart';
import 'package:ophir/app/router/app_startup_gate_provider.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/auth/controller/auth_providers.dart';
import 'package:ophir/features/auth/data/auth_repository.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_provider.dart';
import 'package:ophir/features/budget_planning/controller/budget_setup_gate_status.dart';
import 'package:ophir/features/operations/controller/internal_transfer_review_providers.dart';
import 'package:ophir/features/operations/domain/entities/internal_transfer_review_item.dart';
import 'package:ophir/features/operations/domain/internal_transfer_confirm_outcome.dart';
import 'package:ophir/features/operations/domain/repositories/internal_transfer_review_repository.dart';

final class _FakeUser implements User {
  _FakeUser({required this.id});
  @override
  final String id;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.session,
    this.user,
    required Stream<AuthState> authStateChanges,
  }) : _authStateChanges = authStateChanges;

  final Session? session;
  final User? user;
  final Stream<AuthState> _authStateChanges;

  @override
  Stream<AuthState> get authStateChanges => _authStateChanges;

  @override
  Session? get currentSession => session;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GoRouter Redirection and Gate Tests', () {
    late StreamController<AuthState> authStateController;

    setUp(() {
      authStateController = StreamController<AuthState>.broadcast();
    });

    tearDown(() {
      authStateController.close();
    });

    String getPath(GoRouter router) {
      try {
        return router.routerDelegate.currentConfiguration.uri.toString();
      } catch (_) {
        return router.routeInformationProvider.value.uri.toString();
      }
    }

    ProviderContainer createContainer({
      Session? session,
      User? user,
      required Future<BudgetSetupGateStatus> Function() gateFuture,
      Stream<Session?>? authSessionStream,
      int? Function()? onGateCall,
    }) {
      return ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              session: session,
              user: user,
              authStateChanges: authStateController.stream,
            ),
          ),
          currentUserProvider.overrideWithValue(user),
          authSessionProvider.overrideWith((ref) {
            return authSessionStream ?? Stream.value(session);
          }),
          budgetSetupGateProvider.overrideWith((ref) {
            if (onGateCall != null) {
              onGateCall();
            }
            return gateFuture();
          }),
          // Additive H2 on OperationsScreen; isolate router tests from Supabase.instance.
          internalTransferReviewRepositoryProvider.overrideWithValue(
            const _EmptyInternalTransferReviewRepository(),
          ),
        ],
      );
    }

    Future<void> pumpRouter(
      WidgetTester tester,
      ProviderContainer container, {
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    testWidgets('1. authenticated + completed + cold start -> Dashboard', (
      tester,
    ) async {
      final container = createContainer(
        session: _FakeSession(),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.dashboard);
    });

    testWidgets('2. authenticated + required + cold start -> Budget Setup', (
      tester,
    ) async {
      final container = createContainer(
        session: _FakeSession(),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => BudgetSetupGateStatus.required,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.budgetSetup);
    });

    testWidgets(
      '3. authenticated + required + attempt to open Dashboard -> Budget Setup',
      (tester) async {
        final container = createContainer(
          session: _FakeSession(),
          user: _FakeUser(id: 'user-1'),
          gateFuture: () async => BudgetSetupGateStatus.required,
        );
        addTearDown(container.dispose);

        await pumpRouter(tester, container);

        final router = container.read(appRouterProvider);
        router.go(AppRoutes.dashboard);
        await tester.pumpAndSettle();

        expect(getPath(router), AppRoutes.budgetSetup);
      },
    );

    testWidgets(
      '4. authenticated + completed + navigate to custom allowed route -> no redirect to Dashboard',
      (tester) async {
        final container = createContainer(
          session: _FakeSession(),
          user: _FakeUser(id: 'user-1'),
          gateFuture: () async => BudgetSetupGateStatus.completed,
        );
        addTearDown(container.dispose);

        await pumpRouter(tester, container);

        final router = container.read(appRouterProvider);
        expect(getPath(router), AppRoutes.dashboard);

        router.go(AppRoutes.operations);
        await tester.pumpAndSettle();

        expect(getPath(router), AppRoutes.operations);
      },
    );

    testWidgets('5. unauthenticated -> Auth', (tester) async {
      final container = createContainer(
        session: null,
        user: null,
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.auth);
    });

    testWidgets('6. gate loading -> Splash', (tester) async {
      final completer = Completer<BudgetSetupGateStatus>();
      final container = createContainer(
        session: _FakeSession(),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () => completer.future,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container, settle: false);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.splash);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('7. gate failure -> Failure/Retry', (tester) async {
      final container = createContainer(
        session: _FakeSession(),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => throw StateError('Failed connection'),
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.failure);
    });

    testWidgets(
      '8. complete setup -> gate updates and navigates to Dashboard',
      (tester) async {
        var currentStatus = BudgetSetupGateStatus.required;
        final container = createContainer(
          session: _FakeSession(),
          user: _FakeUser(id: 'user-1'),
          gateFuture: () async => currentStatus,
        );
        addTearDown(container.dispose);

        await pumpRouter(tester, container);

        final router = container.read(appRouterProvider);
        expect(getPath(router), AppRoutes.budgetSetup);

        currentStatus = BudgetSetupGateStatus.completed;
        container.invalidate(budgetSetupGateProvider);
        await container.read(budgetSetupGateProvider.future);
        await tester.pumpAndSettle();

        expect(getPath(router), AppRoutes.dashboard);
      },
    );

    testWidgets('9. recreating app/router after completion -> Dashboard', (
      tester,
    ) async {
      final container = createContainer(
        session: _FakeSession(),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.dashboard);
    });

    // --- ADDITIONAL STARTUP GATE TESTS ---

    testWidgets('10. auth loading -> Splash', (tester) async {
      final container = createContainer(
        authSessionStream: const Stream.empty(), // Stays in loading forever
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container, settle: false);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.splash);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('11. auth error -> failure route', (tester) async {
      final container = createContainer(
        authSessionStream: Stream.error(StateError('Auth loading failed')),
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.failure);
    });

    testWidgets('12. unauthenticated -> auth route (session is null)', (
      tester,
    ) async {
      final container = createContainer(
        authSessionStream: Stream.value(null),
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.auth);
    });

    testWidgets('13. active session + budget loading -> splash', (
      tester,
    ) async {
      final completer = Completer<BudgetSetupGateStatus>();
      final container = createContainer(
        authSessionStream: Stream.value(_FakeSession()),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () => completer.future,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container, settle: false);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.splash);
    });

    testWidgets('14. active session + budget error -> failure route', (
      tester,
    ) async {
      final container = createContainer(
        authSessionStream: Stream.value(_FakeSession()),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => throw StateError('Budget verification failed'),
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.failure);
    });

    testWidgets('15. active session + required -> budget setup', (
      tester,
    ) async {
      final container = createContainer(
        authSessionStream: Stream.value(_FakeSession()),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => BudgetSetupGateStatus.required,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.budgetSetup);
    });

    testWidgets('16. active session + completed -> dashboard', (tester) async {
      final container = createContainer(
        authSessionStream: Stream.value(_FakeSession()),
        user: _FakeUser(id: 'user-1'),
        gateFuture: () async => BudgetSetupGateStatus.completed,
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final router = container.read(appRouterProvider);
      expect(getPath(router), AppRoutes.dashboard);
    });

    testWidgets(
      '17. budgetSetupGateProvider is NOT triggered during auth loading',
      (tester) async {
        var gateCallCount = 0;
        final container = createContainer(
          authSessionStream: const Stream.empty(), // Stays in loading forever
          gateFuture: () async => BudgetSetupGateStatus.completed,
          onGateCall: () {
            gateCallCount++;
            return null;
          },
        );
        addTearDown(container.dispose);

        await pumpRouter(tester, container, settle: false);

        // Verify startup state is indeed authLoading
        final startupStatus = container.read(appStartupGateProvider);
        expect(startupStatus, AppStartupGateStatus.authLoading);

        // Assert that budgetSetupGateProvider was NEVER initialized/called
        expect(gateCallCount, equals(0));
      },
    );

    testWidgets(
      '18. budgetSetupGateProvider is NOT triggered when session is null',
      (tester) async {
        var gateCallCount = 0;
        final container = createContainer(
          authSessionStream: Stream.value(null), // Emits null
          gateFuture: () async => BudgetSetupGateStatus.completed,
          onGateCall: () {
            gateCallCount++;
            return null;
          },
        );
        addTearDown(container.dispose);

        await pumpRouter(tester, container);

        // Verify startup state is unauthenticated
        final startupStatus = container.read(appStartupGateProvider);
        expect(startupStatus, AppStartupGateStatus.unauthenticated);

        // Assert that budgetSetupGateProvider was NEVER initialized/called
        expect(gateCallCount, equals(0));
      },
    );
  });
}

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}

/// Empty H2 review dependency for router harness (no network / Supabase).
class _EmptyInternalTransferReviewRepository
    implements InternalTransferReviewRepository {
  const _EmptyInternalTransferReviewRepository();

  @override
  Future<Result<List<InternalTransferReviewItem>>> listCandidates() async {
    return const Success(<InternalTransferReviewItem>[]);
  }

  @override
  Future<InternalTransferConfirmOutcome> confirm(
    String reconciliationId,
  ) async {
    return const InternalTransferConfirmSucceeded(
      status: 'confirmed',
      reconciliationId: 'unused',
      transferOperationId: 'unused',
    );
  }
}
