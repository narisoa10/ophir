final class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.type,
    required this.groupKey,
    required this.nameKey,
    required this.iconKey,
    required this.colorKey,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.exampleKey,
    this.stableKey,
  });

  final String id;
  final String type;
  final String groupKey;
  final String nameKey;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String exampleKey;
  final String? stableKey;

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as String,
      type: json['type'] as String,
      groupKey: json['group_key'] as String,
      nameKey: json['name_key'] as String,
      iconKey: json['icon_key'] as String,
      colorKey: json['color_key'] as String,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      exampleKey: json['example_key'] as String,
      stableKey: json.containsKey('stable_key')
          ? json['stable_key'] as String?
          : null,
    );
  }
}
