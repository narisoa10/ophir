import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_list_tile.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('OperationListTile', () {
    testWidgets('shows merchant and category path for bank sync operations', (
      tester,
    ) async {
      await tester.pumpWidget(
        _App(
          child: OperationListTile(
            operation: _operation(
              categoryId: AppCategoryId.expenseHousingInternet.name,
              note: 'Rogers',
            ),
          ),
        ),
      );

      expect(find.text('Rogers'), findsOneWidget);
      expect(
        find.text(
          '${AppCategories.byId(AppCategoryId.expenseHousingInternet)!.groupName(_l10n)} · ${AppCategories.byId(AppCategoryId.expenseHousingInternet)!.name(_l10n)}',
        ),
        findsOneWidget,
      );
      expect(find.text('-42.00 CAD'), findsOneWidget);
    });

    testWidgets('shows leaf category when merchant is missing', (tester) async {
      await tester.pumpWidget(
        _App(
          child: OperationListTile(
            operation: _operation(
              categoryId: AppCategoryId.expenseHousingInternet.name,
            ),
          ),
        ),
      );

      expect(
        find.text(
          AppCategories.byId(AppCategoryId.expenseHousingInternet)!.name(_l10n),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          AppCategories.byId(
            AppCategoryId.expenseHousingInternet,
          )!.groupName(_l10n),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to operation type when category is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _App(
          child: OperationListTile(
            operation: _operation(categoryId: 'legacy-supabase-category-id'),
          ),
        ),
      );

      expect(find.text(_l10n.operationExpense), findsOneWidget);
      expect(
        find.text(
          AppCategories.byId(AppCategoryId.expenseHousingInternet)!.name(_l10n),
        ),
        findsNothing,
      );
    });
  });
}

final class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

Operation _operation({String? categoryId, String? note}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: 'operation',
    userId: 'user',
    type: OperationType.expense,
    amount: 42,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
    note: note,
  );
}
