final class AccountDto {
  const AccountDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
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
  final String? type;
  final String? currencyCode;
  final String? unofficialCurrencyCode;
  final double? initialBalance;
  final String? iconKey;
  final String? colorKey;
  final int sortOrder;
  final bool isArchived;
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

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final initialBalance = json['initial_balance'];
    final currentBalance = json['current_balance'];
    final availableBalance = json['available_balance'];
    final balanceFetchedAt = json['balance_fetched_at'];

    return AccountDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: type as String?,
      currencyCode: json['currency_code'] as String?,
      unofficialCurrencyCode: json['unofficial_currency_code'] as String?,
      initialBalance: initialBalance == null
          ? null
          : (initialBalance as num).toDouble(),
      iconKey: json['icon_key'] as String?,
      colorKey: json['color_key'] as String?,
      sortOrder: json['sort_order'] as int,
      isArchived: json['is_archived'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      plaidItemId: json['plaid_item_id'] as String?,
      institutionId: json['institution_id'] as String?,
      plaidAccountId: json['plaid_account_id'] as String?,
      officialName: json['official_name'] as String?,
      mask: json['mask'] as String?,
      plaidType: json['plaid_type'] as String?,
      plaidSubtype: json['plaid_subtype'] as String?,
      currentBalance: currentBalance == null
          ? null
          : (currentBalance as num).toDouble(),
      availableBalance: availableBalance == null
          ? null
          : (availableBalance as num).toDouble(),
      balanceFetchedAt: balanceFetchedAt == null
          ? null
          : DateTime.parse(balanceFetchedAt as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      if (type != null) 'type': type,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (unofficialCurrencyCode != null)
        'unofficial_currency_code': unofficialCurrencyCode,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorKey != null) 'color_key': colorKey,
      'sort_order': sortOrder,
      'is_archived': isArchived,
      if (plaidItemId != null) 'plaid_item_id': plaidItemId,
      if (institutionId != null) 'institution_id': institutionId,
      if (plaidAccountId != null) 'plaid_account_id': plaidAccountId,
      if (officialName != null) 'official_name': officialName,
      if (mask != null) 'mask': mask,
      if (plaidType != null) 'plaid_type': plaidType,
      if (plaidSubtype != null) 'plaid_subtype': plaidSubtype,
      if (currentBalance != null) 'current_balance': currentBalance,
      if (availableBalance != null) 'available_balance': availableBalance,
      if (balanceFetchedAt != null)
        'balance_fetched_at': balanceFetchedAt!.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': type,
      'currency_code': currencyCode,
      'unofficial_currency_code': unofficialCurrencyCode,
      'initial_balance': initialBalance,
      'icon_key': iconKey,
      'color_key': colorKey,
      'sort_order': sortOrder,
      'is_archived': isArchived,
      'plaid_item_id': plaidItemId,
      'institution_id': institutionId,
      'plaid_account_id': plaidAccountId,
      'official_name': officialName,
      'mask': mask,
      'plaid_type': plaidType,
      'plaid_subtype': plaidSubtype,
      'current_balance': currentBalance,
      'available_balance': availableBalance,
      'balance_fetched_at': balanceFetchedAt?.toUtc().toIso8601String(),
    };
  }
}
