import '../../domain/entities/profile.dart';
import '../dto/profile_dto.dart';

extension ProfileDtoMapper on ProfileDto {
  Profile toEntity() {
    return Profile(
      id: id,
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      locale: locale,
      currencyCode: currencyCode,
      timezone: timezone,
      onboardingCompleted: onboardingCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension ProfileEntityMapper on Profile {
  ProfileDto toDto() {
    return ProfileDto(
      id: id,
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      locale: locale,
      currencyCode: currencyCode,
      timezone: timezone,
      onboardingCompleted: onboardingCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}