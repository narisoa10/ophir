import '../../domain/entities/category_rule.dart';

final class CategoryRuleDto {
  const CategoryRuleDto({
    required this.id,
    required this.userId,
    required this.merchantKey,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryRuleDto.fromJson(Map<String, dynamic> json) {
    return CategoryRuleDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      merchantKey: json['merchant_key'] as String,
      categoryId: json['category_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String merchantKey;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'merchant_key': merchantKey,
      'category_id': categoryId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'merchant_key': merchantKey,
      'category_id': categoryId,
    };
  }

  CategoryRule toEntity() {
    return CategoryRule(
      id: id,
      userId: userId,
      merchantKey: merchantKey,
      categoryId: categoryId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension CategoryRuleDtoMapper on CategoryRule {
  CategoryRuleDto toDto() {
    return CategoryRuleDto(
      id: id,
      userId: userId,
      merchantKey: merchantKey,
      categoryId: categoryId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
