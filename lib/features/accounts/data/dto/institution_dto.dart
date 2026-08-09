final class InstitutionDto {
  const InstitutionDto({
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

  factory InstitutionDto.fromJson(Map<String, dynamic> json) {
    return InstitutionDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plaidItemId: json['plaid_item_id'] as String,
      plaidInstitutionId: json['plaid_institution_id'] as String?,
      name: json['name'] as String?,
      logoBase64: json['logo_base64'] as String?,
      primaryColor: json['primary_color'] as String?,
      url: json['url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
