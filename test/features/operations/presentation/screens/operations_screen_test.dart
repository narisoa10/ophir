import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ophir/app/router/app_routes.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_editor_bottom_sheet.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/controller/internal_transfer_review_providers.dart';
import 'package:ophir/features/operations/data/repositories/local_operation_repository.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/entities/internal_transfer_review_item.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/internal_transfer_confirm_outcome.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';
import 'package:ophir/features/operations/domain/repositories/internal_transfer_review_repository.dart';
import 'package:ophir/features/operations/presentation/screens/operation_recurrence_picker_screen.dart';
import 'package:ophir/features/operations/presentation/screens/operations_screen.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_sheet.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('OperationsScreen modal editor', () {
    testWidgets('FAB opens editor bottom sheet directly', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(OperationEditorSheet), findsOneWidget);
      expect(find.byType(AppEditorBottomSheet), findsOneWidget);
      expect(find.text(_l10n.operationAddExpenseTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppEditorBottomSheet),
          matching: find.byKey(
            const ValueKey<String>('operation-category-field'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'starts bootstrap once and keeps local operations visible during hydration',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.saveOperation(_operation(id: 'local-1'));
        final local = _TrackingLocalOperationRepository(database: database);
        final remoteStarted = Completer<void>();
        final remote = _FakeRemoteOperationRepository(
          getCompleter: Completer<Result<List<Operation>>>(),
          getStarted: remoteStarted,
        );

        await tester.pumpWidget(
          _OperationsTestApp(
            database: database,
            localRepository: local,
            remoteRepository: remote,
          ),
        );
        await tester.pump();
        await remoteStarted.future;
        await tester.pump();

        expect(remote.getCalls, 1);
        expect(find.byKey(const ValueKey<String>('local-1')), findsOneWidget);

        remote.getCompleter!.complete(
          Success([_operation(id: 'remote-1', amount: 200)]),
        );
        await tester.pumpAndSettle();

        expect(remote.getCalls, 1);
        expect(find.byKey(const ValueKey<String>('local-1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('remote-1')), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(remote.getCalls, 1);
      },
    );

    testWidgets('pull-to-refresh uses centralized remote sync', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveSyncedOperation(_operation(id: 'op-1', amount: 4.33));
      final local = _TrackingLocalOperationRepository(database: database);
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'op-1', amount: 4.33)]),
      );

      await tester.pumpWidget(
        _OperationsTestApp(
          database: database,
          localRepository: local,
          remoteRepository: remote,
        ),
      );
      await tester.pumpAndSettle();

      expect(remote.getCalls, 1);

      remote.getResult = Success([_operation(id: 'op-1', amount: 4.34)]);

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(remote.getCalls, 2);
      expect((await database.getOperationById('op-1'))?.amount, 4.34);
    });

    testWidgets('cancel from create editor does not call persistence', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(OperationEditorSheet), findsOneWidget);

      await _dismissModal(tester);

      expect(find.byType(OperationEditorSheet), findsNothing);
      expect(local.createCalls, 0);
      expect(local.updateCalls, 0);
    });

    testWidgets('valid create result invokes createOperation once', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(OperationEditorSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '10',
      );
      await _tapEditorSave(tester);
      await tester.pumpAndSettle();

      expect(local.createCalls, 1);
      expect(local.updateCalls, 0);
      expect(local.createdOperation?.id, '');
      expect(local.createdOperation?.userId, '');
      expect(local.createdOperation?.fromAccountId, isNull);
      expect(local.createdOperation?.toAccountId, isNull);
      expect(local.createdOperation?.amount, 10);
      expect(local.createdOperation?.currencyCode, 'CAD');
      expect(
        local.createdOperation?.categoryId,
        AppCategoryId.expenseHousingRent.name,
      );
      expect(find.byType(OperationEditorSheet), findsNothing);
    });

    testWidgets('create failure shows existing error feedback', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(
        database: database,
        failCreate: true,
      );

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(OperationEditorSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '10',
      );
      await _tapEditorSave(tester);
      await tester.pumpAndSettle();

      expect(local.createCalls, 1);
      expect(find.text(_l10n.failureUnknown), findsOneWidget);
    });

    testWidgets('tap operation opens edit modal and update preserves fields', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final existing = _operation(
        id: 'operation-1',
        userId: 'user-7',
        amount: 25,
        fromAccountId: 'from-account',
        toAccountId: 'to-account',
        categoryId: AppCategoryId.expenseHousingRent.name,
        recurrence: OperationRecurrence.monthly,
      );
      await database.saveOperation(existing);
      final local = _TrackingLocalOperationRepository(
        database: database,
        userId: 'user-7',
      );

      await tester.pumpWidget(
        _OperationsTestApp(
          database: database,
          localRepository: local,
          userId: 'user-7',
        ),
      );
      await tester.pumpAndSettle();

      final operationTile = find.byKey(const ValueKey<String>('operation-1'));
      expect(operationTile, findsOneWidget);
      await tester.tap(
        find.descendant(of: operationTile, matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationEditorSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppEditorBottomSheet),
          matching: find.byKey(
            const ValueKey<String>('operation-category-field'),
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('operation-amount-field')),
        '50',
      );
      await _tapEditorSave(tester);
      await tester.pumpAndSettle();

      expect(local.createCalls, 0);
      expect(local.updateCalls, 1);
      expect(local.updatedOperation?.id, 'operation-1');
      expect(local.updatedOperation?.userId, 'user-7');
      expect(local.updatedOperation?.fromAccountId, 'from-account');
      expect(local.updatedOperation?.toAccountId, 'to-account');
      expect(
        local.updatedOperation?.createdAt.millisecondsSinceEpoch,
        existing.createdAt.millisecondsSinceEpoch,
      );
      expect(local.updatedOperation?.updatedAt, isNot(existing.updatedAt));
      expect(local.updatedOperation?.recurrence, OperationRecurrence.monthly);
      expect(
        local.updatedOperation?.occurredAt.millisecondsSinceEpoch,
        existing.occurredAt.millisecondsSinceEpoch,
      );
      expect(local.updatedOperation?.amount, 50);
    });

    testWidgets('create editor keeps category selection inside the form', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppEditorBottomSheet),
          matching: find.byKey(
            const ValueKey<String>('operation-category-field'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(_rentCategoryName()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('type switch changes title and available category scope', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final expenseSheetRect = tester.getRect(
        find.byType(AppEditorBottomSheet),
      );
      expect(find.text(_l10n.operationAddExpenseTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsNothing,
      );
      expect(find.text(_rentCategoryName()), findsOneWidget);
      expect(find.text(_salaryCategoryName()), findsNothing);

      await tester.tap(find.text(_l10n.operationIncome));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.operationAddIncomeTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('operation-name-field')),
        findsOneWidget,
      );
      expect(find.text(_salaryCategoryName()), findsOneWidget);
      expect(find.text(_rentCategoryName()), findsNothing);
      final incomeSheetRect = tester.getRect(find.byType(AppEditorBottomSheet));
      expect(incomeSheetRect.left, expenseSheetRect.left);
      expect(incomeSheetRect.width, expenseSheetRect.width);
      expect(tester.takeException(), isNull);

      final saveButton = find.widgetWithText(ElevatedButton, _l10n.commonSave);
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel from edit modal does not call update', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'operation-1'));
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      final operationTile = find.byKey(const ValueKey<String>('operation-1'));
      expect(operationTile, findsOneWidget);
      await tester.tap(
        find.descendant(of: operationTile, matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OperationEditorSheet), findsOneWidget);

      await _dismissModal(tester);

      expect(find.byType(OperationEditorSheet), findsNothing);
      expect(local.updateCalls, 0);
    });

    testWidgets('editor archive cancel does not call archive', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'operation-1'));
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await _openExistingOperationEditor(tester, 'operation-1');
      await _tapEditorDelete(tester);
      await tester.pumpAndSettle();

      expect(find.byType(OperationEditorSheet), findsNothing);
      expect(find.text(_l10n.operationArchiveTitle), findsOneWidget);

      await tester.tap(find.text(_l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(local.archiveCalls, 0);
    });

    testWidgets('editor archive confirm calls archive once', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'operation-1'));
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await _openExistingOperationEditor(tester, 'operation-1');
      await _tapEditorDelete(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.operationArchiveConfirm));
      await tester.pumpAndSettle();

      expect(local.archiveCalls, 1);
      expect(local.archivedOperationId, 'operation-1');
    });

    testWidgets('swipe archive flow remains wired to archiveOperation', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'operation-1'));
      final local = _TrackingLocalOperationRepository(database: database);

      await tester.pumpWidget(
        _OperationsTestApp(database: database, localRepository: local),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey<String>('operation-1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.operationArchiveConfirm));
      await tester.pumpAndSettle();

      expect(local.archiveCalls, 1);
      expect(local.archivedOperationId, 'operation-1');
    });

    test('main screen does not use legacy create route for create/edit', () {
      final source = File(
        'lib/features/operations/presentation/screens/operations_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('context.push(')));
      expect(source, isNot(contains('app_routes.dart')));
      expect(source, isNot(contains('_openCategoryPicker')));
    });
  });
}

Future<void> _openExistingOperationEditor(
  WidgetTester tester,
  String operationId,
) async {
  final operationTile = find.byKey(ValueKey<String>(operationId));
  expect(operationTile, findsOneWidget);
  await tester.tap(
    find.descendant(of: operationTile, matching: find.byType(InkWell)),
  );
  await tester.pumpAndSettle();
  expect(find.byType(OperationEditorSheet), findsOneWidget);
}

Future<void> _tapEditorDelete(WidgetTester tester) async {
  final editorSheet = find.byType(AppEditorBottomSheet);
  expect(editorSheet, findsOneWidget);

  final deleteButton = find.descendant(
    of: editorSheet,
    matching: find.widgetWithText(TextButton, _l10n.commonDelete),
  );
  expect(deleteButton, findsOneWidget);

  await tester.ensureVisible(deleteButton);
  await tester.pump();

  await tester.tap(deleteButton);
  await tester.pump();
}

Future<void> _tapEditorSave(WidgetTester tester) async {
  final editorSheet = find.byType(AppEditorBottomSheet);
  expect(editorSheet, findsOneWidget);

  final saveButton = find.descendant(
    of: editorSheet,
    matching: find.widgetWithText(ElevatedButton, _l10n.commonSave),
  );
  expect(saveButton, findsOneWidget);

  final editorScrollView = find.descendant(
    of: editorSheet,
    matching: find.byType(SingleChildScrollView),
  );
  expect(editorScrollView, findsOneWidget);

  await tester.ensureVisible(saveButton);
  await tester.pump();

  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final saveRect = tester.getRect(saveButton);

  if (saveRect.bottom > logicalSize.height - 80) {
    await tester.drag(editorScrollView, const Offset(0, -120));
    await tester.pump();
  }

  final visibleSaveRect = tester.getRect(saveButton);

  expect(visibleSaveRect.top, greaterThanOrEqualTo(0));
  expect(visibleSaveRect.bottom, lessThan(logicalSize.height));

  await tester.tap(saveButton);
  await tester.pump();
}

String _rentCategoryName() {
  return AppCategories.byId(AppCategoryId.expenseHousingRent)!.name(_l10n);
}

String _salaryCategoryName() {
  return AppCategories.byId(AppCategoryId.incomeEmploymentSalary)!.name(_l10n);
}

Future<void> _dismissModal(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

final class _OperationsTestApp extends StatelessWidget {
  const _OperationsTestApp({
    required this.database,
    required this.localRepository,
    this.remoteRepository,
    this.userId = 'user-1',
  });

  final AppDatabase database;
  final _TrackingLocalOperationRepository localRepository;
  final _FakeRemoteOperationRepository? remoteRepository;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const OperationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.operationRecurrencePicker,
          builder: (context, state) {
            return const OperationRecurrencePickerScreen();
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        operationUserIdProvider.overrideWithValue(userId),
        operationAuthUserIdReaderProvider.overrideWithValue(() => userId),
        localOperationRepositoryProvider.overrideWithValue(localRepository),
        remoteOperationRepositoryProvider.overrideWithValue(
          remoteRepository ?? _FakeRemoteOperationRepository(),
        ),
        // H2 review is additive on OperationsScreen; isolate from Supabase.instance.
        internalTransferReviewRepositoryProvider.overrideWithValue(
          const _EmptyInternalTransferReviewRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

final class _TrackingLocalOperationRepository extends LocalOperationRepository {
  _TrackingLocalOperationRepository({
    required super.database,
    super.userId = 'user-1',
    this.failCreate = false,
  });

  final bool failCreate;
  int createCalls = 0;
  int updateCalls = 0;
  int archiveCalls = 0;
  Operation? createdOperation;
  Operation? updatedOperation;
  String? archivedOperationId;

  @override
  Future<Result<Operation>> createOperation(Operation operation) {
    createCalls += 1;
    createdOperation = operation;

    if (failCreate) {
      return Future.value(const Failure(DatabaseFailure()));
    }

    return super.createOperation(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) {
    updateCalls += 1;
    updatedOperation = operation;
    return super.updateOperation(operation);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) {
    archiveCalls += 1;
    archivedOperationId = operationId;
    return super.archiveOperation(operationId);
  }
}

final class _FakeRemoteOperationRepository implements OperationRepository {
  _FakeRemoteOperationRepository({
    Result<List<Operation>>? getResult,
    this.getCompleter,
    this.getStarted,
  }) : getResult = getResult ?? const Success(<Operation>[]);

  Result<List<Operation>> getResult;
  final Completer<Result<List<Operation>>>? getCompleter;
  final Completer<void>? getStarted;
  int getCalls = 0;

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

  @override
  Future<Result<List<Operation>>> getOperations() async {
    getCalls += 1;

    if (getStarted != null && !getStarted!.isCompleted) {
      getStarted!.complete();
    }

    if (getCompleter != null) {
      return getCompleter!.future;
    }

    return getResult;
  }

  @override
  Stream<Result<List<Operation>>> watchOperations() {
    return Stream.value(getResult);
  }
}

/// Empty H2 review dependency for OperationsScreen harness (no network / Supabase).
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

Operation _operation({
  required String id,
  String userId = 'user-1',
  double amount = 100,
  String? fromAccountId,
  String? toAccountId,
  String? categoryId,
  OperationRecurrence recurrence = OperationRecurrence.none,
  DateTime? occurredAt,
}) {
  final now = DateTime.now();
  final operationDate = occurredAt ?? DateTime(now.year, now.month, 15);

  return Operation(
    id: id,
    userId: userId,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    categoryId: categoryId ?? AppCategoryId.expenseFoodGroceries.name,
    type: OperationType.expense,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: operationDate,
    recurrence: recurrence,
    isRecurring: recurrence != OperationRecurrence.none,
    createdAt: operationDate,
    updatedAt: operationDate,
  );
}
