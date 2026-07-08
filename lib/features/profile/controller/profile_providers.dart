import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../domain/repositories/profile_repository.dart';
import '../data/repositories/supabase_profile_repository.dart';
import '../domain/entities/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

final currentProfileProvider = FutureProvider<Result<Profile>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getCurrentProfile();
});

final currentProfileStreamProvider = StreamProvider<Result<Profile>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.watchCurrentProfile();
});