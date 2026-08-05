import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/profile/controller/profile_controller.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/data/services/profile_avatar_upload_service.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';

void main() {
  group('ProfileController', () {
    test('updateAvatar uploads image and saves avatar URL', () async {
      final repository = _FakeProfileRepository();
      final uploadService = _FakeProfileAvatarUploadService(
        result: const Success('https://example.com/avatar.jpg'),
      );
      final container = _container(repository, uploadService);
      addTearDown(container.dispose);
      await container.read(profileControllerProvider.future);

      final result = await container
          .read(profileControllerProvider.notifier)
          .updateAvatar(repository.profile, ImageSource.gallery);

      expect(uploadService.sources, [ImageSource.gallery]);
      expect(repository.updatedProfiles, hasLength(1));
      expect(
        repository.updatedProfiles.single.avatarUrl,
        'https://example.com/avatar.jpg',
      );
      expect(result, isA<Success<Profile>>());
    });

    test(
      'updateAvatar does not update profile when picker is canceled',
      () async {
        final repository = _FakeProfileRepository();
        final uploadService = _FakeProfileAvatarUploadService(
          result: const Success(null),
        );
        final container = _container(repository, uploadService);
        addTearDown(container.dispose);
        await container.read(profileControllerProvider.future);

        final result = await container
            .read(profileControllerProvider.notifier)
            .updateAvatar(repository.profile, ImageSource.camera);

        expect(uploadService.sources, [ImageSource.camera]);
        expect(repository.updatedProfiles, isEmpty);
        expect(result, isNull);
      },
    );
  });
}

ProviderContainer _container(
  ProfileRepository repository,
  ProfileAvatarUploadService uploadService,
) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
      profileAvatarUploadServiceProvider.overrideWithValue(uploadService),
    ],
  );
}

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository();

  Profile profile = Profile(
    id: 'user-1',
    email: 'user@example.com',
    locale: 'en',
    currencyCode: 'USD',
    timezone: 'UTC',
    onboardingCompleted: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final updatedProfiles = <Profile>[];

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    return Success(profile);
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    updatedProfiles.add(profile);
    this.profile = profile;

    return Success(profile);
  }

  @override
  Stream<Result<Profile>> watchCurrentProfile() {
    return Stream.value(Success(profile));
  }
}

final class _FakeProfileAvatarUploadService
    implements ProfileAvatarUploadService {
  _FakeProfileAvatarUploadService({required this.result});

  final Result<String?> result;
  final sources = <ImageSource>[];

  @override
  Future<Result<String?>> uploadAvatar(ImageSource source) async {
    sources.add(source);

    return result;
  }
}
