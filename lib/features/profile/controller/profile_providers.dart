import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/repositories/supabase_profile_repository.dart';
import '../data/services/profile_avatar_upload_service.dart';
import '../domain/entities/profile.dart';
import '../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

final profileAvatarUploadServiceProvider = Provider<ProfileAvatarUploadService>(
  (ref) {
    return SupabaseProfileAvatarUploadService(
      Supabase.instance.client,
      ImagePicker(),
    );
  },
);

final currentProfileProvider = FutureProvider<Result<Profile>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getCurrentProfile();
});

final currentProfileStreamProvider = StreamProvider<Result<Profile>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.watchCurrentProfile();
});
