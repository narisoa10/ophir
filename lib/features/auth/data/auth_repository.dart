import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_failure.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signInWithEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: false,
        emailRedirectTo: 'ophir://login-callback',
      );
    } on AuthException catch (e) {
      throw _mapSupabaseAuthException(e);
    } catch (_) {
      throw const UnknownAuthFailure();
    }
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'ophir://login-callback',
      );
    } on AuthException catch (e) {
      throw _mapSupabaseAuthException(e);
    } catch (_) {
      throw const UnknownAuthFailure();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'ophir://login-callback',
      );
    } catch (_) {
      throw const GoogleAuthFailure();
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AuthFailure _mapSupabaseAuthException(AuthException exception) {
    final message = exception.message.toLowerCase();
    final statusCode = exception.statusCode;

    if (statusCode == '429' || message.contains('rate limit')) {
      return const RateLimitedAuthFailure();
    }

    if (message.contains('signups not allowed') ||
        message.contains('signup not allowed') ||
        message.contains('user not found') ||
        message.contains('not found')) {
      return const UserNotFoundAuthFailure();
    }

    return const ServerAuthFailure();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;
}