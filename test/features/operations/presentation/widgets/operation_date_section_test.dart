import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/models/operation_date_section_presentation.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_date_section.dart';

void main() {
  testWidgets('running balance is labeled CAD even when the first operation '
      'of the day is in another currency', (tester) async {
    final operations = [
      _operation(id: 'usd', amount: 500, currencyCode: 'USD'),
      _operation(id: 'cad', amount: 20, currencyCode: 'CAD'),
    ];
    final section = operationDateSectionsFor(operations).single;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OperationDateSection(
            date: 'Jan 1',
            runningBalanceAfterDate: section.runningBalanceAfterDate,
            operations: section.operations,
            onOperationTap: (_) {},
            onOperationArchive: (_) async => false,
          ),
        ),
      ),
    );

    expect(find.text('-20.00 CAD'), findsNWidgets(2));
    expect(find.text('-500.00 USD'), findsOneWidget);
    expect(find.textContaining('-520'), findsNothing);
  });
}

Operation _operation({
  required String id,
  required double amount,
  required String currencyCode,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: 'user',
    type: OperationType.expense,
    amount: amount,
    currencyCode: currencyCode,
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: AppCategoryId.expenseFoodGroceries.name,
  );
}
