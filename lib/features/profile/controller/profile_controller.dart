import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/profile.dart';
import 'profile_providers.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Result<Profile>?>(
      ProfileController.new,
    );

final class ProfileController extends AsyncNotifier<Result<Profile>?> {
  @override
  Future<Result<Profile>?> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    return repository.getCurrentProfile();
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      return repository.getCurrentProfile();
    });
  }

  Future<void> updateProfile(Profile profile) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      return repository.updateProfile(profile);
    });
  }

  Future<Result<Profile>?> updateAvatar(
    Profile profile,
    ImageSource source,
  ) async {
    final uploadService = ref.read(profileAvatarUploadServiceProvider);
    final uploadResult = await uploadService.uploadAvatar(source);

    switch (uploadResult) {
      case Success<String?>(:final value):
        if (value == null) {
          return null;
        }

        final repository = ref.read(profileRepositoryProvider);
        final updateResult = await repository.updateProfile(
          profile.copyWith(avatarUrl: value),
        );

        state = AsyncData(updateResult);

        return updateResult;
      case Failure<String?>(:final failure):
        return Failure(failure);
    }
  }

  Future<void> completeOnboarding() async {
    final currentResult = state.value;

    if (currentResult is! Success<Profile>) {
      return;
    }

    await updateProfile(
      currentResult.value.copyWith(onboardingCompleted: true),
    );
  }
}
