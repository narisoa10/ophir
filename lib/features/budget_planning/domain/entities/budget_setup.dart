import 'package:flutter/foundation.dart';

import '../../../../core/currency/product_currency.dart';
import 'budget_household.dart';
import 'budget_income_source.dart';
import 'budget_obligation.dart';

@immutable
final class BudgetSetup {
  const BudgetSetup({
    required this.id,
    required this.userId,
    required this.status,
    required this.version,
    required this.currentStep,
    required this.household,
    required this.incomeSources,
    required this.obligations,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String status;
  final int version;
  final int currentStep;
  final BudgetHousehold household;
  final List<BudgetIncomeSource> incomeSources;
  final List<BudgetObligation> obligations;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The single currency of every amount in this budget: the currency its
  /// items already carry, or the product currency when it has none. A budget
  /// never mixes currencies and an item is never relabeled, so items that
  /// disagree are an error rather than something to pick a winner from.
  String get currencyCode {
    final currencyCodes = {
      for (final incomeSource in incomeSources) incomeSource.currencyCode,
      for (final obligation in obligations) obligation.currencyCode,
    };

    return switch (currencyCodes.length) {
      0 => productCurrencyCode,
      1 => currencyCodes.single,
      _ => throw StateError('Budget setup mixes currencies: $currencyCodes.'),
    };
  }
}
