final class AccountDto {
  const AccountDto({
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
  final String? type;
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
      isIncludedInFinances: json['is_included_in_finances'] as bool? ?? true,
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
}
