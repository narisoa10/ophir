import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> completeOnboarding() async {
    final currentResult = state.valueOrNull;

    if (currentResult is! Success<Profile>) {
      return;
    }

    await updateProfile(
      currentResult.value.copyWith(
        onboardingCompleted: true,
      ),
    );
  }
}