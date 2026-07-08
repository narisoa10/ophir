import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authSessionProvider = StreamProvider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);

  return repository.authStateChanges.map((event) => event.session);
});

final currentSessionProvider = Provider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.currentSession;
});

final currentUserProvider = Provider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.currentUser;
});