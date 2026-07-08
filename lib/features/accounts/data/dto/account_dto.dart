final class AccountDto {
  const AccountDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
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
  final String type;
  final String currencyCode;
  final double initialBalance;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    return AccountDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      currencyCode: json['currency_code'] as String,
      initialBalance: (json['initial_balance'] as num).toDouble(),
      iconKey: json['icon_key'] as String,
      colorKey: json['color_key'] as String,
      sortOrder: json['sort_order'] as int,
      isArchived: json['is_archived'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'type': type,
      'currency_code': currencyCode,
      'initial_balance': initialBalance,
      'icon_key': iconKey,
      'color_key': colorKey,
      'sort_order': sortOrder,
      'is_archived': isArchived,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': type,
      'currency_code': currencyCode,
      'initial_balance': initialBalance,
      'icon_key': iconKey,
      'color_key': colorKey,
      'sort_order': sortOrder,
      'is_archived': isArchived,
    };
  }
}