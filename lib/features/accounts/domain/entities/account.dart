import 'package:flutter/foundation.dart';

import '../enums/account_source.dart';
import '../enums/account_type.dart';

@immutable
final class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.source = AccountSource.manual,
    required this.currencyCode,
    required this.initialBalance,
    required this.iconKey,
    required this.colorKey,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;

  final AccountType type;
  final AccountSource source;

  final String currencyCode;
  final double initialBalance;

  final String iconKey;
  final String colorKey;

  final int sortOrder;
  final bool isArchived;

  final DateTime createdAt;
  final DateTime updatedAt;
}
