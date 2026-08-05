import 'package:flutter/foundation.dart';

@immutable
final class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.userId,
    required this.merchantKey,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String merchantKey;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
}
