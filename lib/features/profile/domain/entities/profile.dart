import 'package:flutter/foundation.dart';

@immutable
final class Profile {
  const Profile({
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

  Profile copyWith({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? locale,
    String? currencyCode,
    String? timezone,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locale: locale ?? this.locale,
      currencyCode: currencyCode ?? this.currencyCode,
      timezone: timezone ?? this.timezone,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}