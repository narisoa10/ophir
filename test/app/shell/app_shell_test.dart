import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ophir/app/shell/app_shell.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShell operations resume refresh', () {
    testWidgets('triggers centralized sync only on resumed', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remote = _FakeRemoteOperationRepository(
        getResult: const Success(<Operation>[]),
      );

      final router = GoRouter(
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            operationUserIdProvider.overrideWithValue('user-1'),
            operationAuthUserIdReaderProvider.overrideWithValue(() => 'user-1'),
            remoteOperationRepositoryProvider.overrideWithValue(remote),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(remote.getCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(remote.getCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(remote.getCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(remote.getCalls, 1);
    });
  });
}

final class _FakeRemoteOperationRepository implements OperationRepository {
  _FakeRemoteOperationRepository({required this.getResult});

  final Result<List<Operation>> getResult;
  int getCalls = 0;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    getCalls += 1;
    return getResult;
  }

  @override
  Stream<Result<List<Operation>>> watchOperations() {
    return Stream.value(getResult);
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<void>> overridePlaidOperationCategory({
    required String operationId,
    required String? categoryId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> resetPlaidOperationCategoryOverride({
    required String operationId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    return const Success(null);
  }
}
