import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/category_rules/controller/category_rule_providers.dart';
import 'package:ophir/features/category_rules/domain/entities/category_rule.dart';
import 'package:ophir/features/category_rules/presentation/screens/category_rules_screen.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('shows localized names and never a raw category id', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRulesProvider.overrideWith(
            (ref) => Stream.value([
              _rule(
                merchantKey: 'metro',
                categoryId: AppCategoryId.expenseFoodGroceries.name,
              ),
              _rule(merchantKey: 'legacy', categoryId: 'removedCategoryId'),
            ]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CategoryRulesScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(_l10n.categoryTaxonomyExpenseFoodGroceriesName),
      findsOneWidget,
    );
    expect(find.text(_l10n.categoryRulesUnknownCategory), findsOneWidget);
    expect(find.text('removedCategoryId'), findsNothing);
  });
}

CategoryRule _rule({required String merchantKey, required String categoryId}) {
  final timestamp = DateTime.utc(2026);
  return CategoryRule(
    id: merchantKey,
    userId: 'user-id',
    merchantKey: merchantKey,
    categoryId: categoryId,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
