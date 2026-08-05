import 'package:flutter/foundation.dart';

@immutable
final class BudgetHousehold {
  const BudgetHousehold({
    required this.adultsCount,
    required this.childrenCount,
    this.declaredCurrentBalance,
    this.reserveAmount,
    this.overdueAmount,
    this.upcomingLargeMandatoryAmount,
    this.upcomingLargeMandatoryDate,
  });

  final int adultsCount;
  final int childrenCount;
  final double? declaredCurrentBalance;
  final double? reserveAmount;
  final double? overdueAmount;
  final double? upcomingLargeMandatoryAmount;
  final DateTime? upcomingLargeMandatoryDate;
}
