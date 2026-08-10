import 'package:flutter/foundation.dart';

import '../enums/account_type.dart';

@immutable
final class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.isIncludedInFinances = true,
    this.type,
    this.currencyCode,
    this.unofficialCurrencyCode,
    this.initialBalance,
    this.iconKey,
    this.colorKey,
    this.plaidItemId,
    this.institutionId,
    this.plaidAccountId,
    this.officialName,
    this.mask,
    this.plaidType,
    this.plaidSubtype,
    this.currentBalance,
    this.availableBalance,
    this.balanceFetchedAt,
  });

  final String id;
  final String userId;
  final String name;

  final AccountType? type;

  final String? currencyCode;
  final String? unofficialCurrencyCode;
  final double? initialBalance;

  final String? iconKey;
  final String? colorKey;

  final int sortOrder;
  final bool isArchived;
  final bool isIncludedInFinances;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String? plaidItemId;
  final String? institutionId;
  final String? plaidAccountId;
  final String? officialName;
  final String? mask;
  final String? plaidType;
  final String? plaidSubtype;
  final double? currentBalance;
  final double? availableBalance;
  final DateTime? balanceFetchedAt;
}
