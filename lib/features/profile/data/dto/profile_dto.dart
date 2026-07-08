final class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.email,
    required this.locale,
    required this.currencyCode,
    required this.timezone,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String locale;
  final String currencyCode;
  final String timezone;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    return ProfileDto(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      locale: json['locale'] as String,
      currencyCode: json['currency_code'] as String,
      timezone: json['timezone'] as String,
      onboardingCompleted: json['onboarding_completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'locale': locale,
      'currency_code': currencyCode,
      'timezone': timezone,
      'onboarding_completed': onboardingCompleted,
    };
  }
}