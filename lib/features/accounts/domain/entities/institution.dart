import 'package:flutter/foundation.dart';

@immutable
final class Institution {
  const Institution({
    required this.id,
    required this.userId,
    required this.plaidItemId,
    required this.createdAt,
    required this.updatedAt,
    this.plaidInstitutionId,
    this.name,
    this.logoBase64,
    this.primaryColor,
    this.url,
  });

  final String id;
  final String userId;
  final String plaidItemId;
  final String? plaidInstitutionId;
  final String? name;
  final String? logoBase64;
  final String? primaryColor;
  final String? url;
  final DateTime createdAt;
  final DateTime updatedAt;
}
