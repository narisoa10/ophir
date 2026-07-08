import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/email/email_validator.dart';
import '../../../core/validation/password/password_validator.dart';
import '../data/auth_failure.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

final authControllerProvider =
NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    return const AuthState();
  }

  void updateEmailInput(String email) {
    final emailResult = EmailValidator.validate(input: email);

    state = state.copyWith(
      status: AuthStatus.idle,
      emailError: emailResult.isValid ? null : emailResult.error,
      emailSuggestion: emailResult.suggestion,
      emailSuggestions: emailResult.dropdownSuggestions,
      showSignUpSuggestion: false,
      clearErrorCode: true,
      clearEmailError: emailResult.isValid,
      clearEmailSuggestion: emailResult.suggestion == null,
      clearEmailSuggestions: emailResult.dropdownSuggestions.isEmpty,
    );
  }

  void updatePasswordInput(String password) {
    final passwordResult = PasswordValidator.validate(input: password);

    state = state.copyWith(
      status: AuthStatus.idle,
      passwordError: passwordResult.isValid ? null : passwordResult.error,
      passwordPassedRequirements: passwordResult.passedRequirements,
      passwordFailedRequirements: passwordResult.failedRequirements,
      passwordStrength: passwordResult.strength,
      showSignUpSuggestion: false,
      clearErrorCode: true,
      clearPasswordError: passwordResult.isValid,
    );
  }

  Future<void> signInWithEmail(String email) async {
    final emailResult = EmailValidator.validate(input: email);

    if (!emailResult.isValid) {
      state = state.copyWith(
        status: AuthStatus.idle,
        emailError: emailResult.error,
        emailSuggestion: emailResult.suggestion,
        emailSuggestions: emailResult.dropdownSuggestions,
        showSignUpSuggestion: false,
        clearErrorCode: true,
        clearEmailSuggestion: emailResult.suggestion == null,
        clearEmailSuggestions: emailResult.dropdownSuggestions.isEmpty,
      );
      return;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      emailSuggestion: emailResult.suggestion,
      emailSuggestions: emailResult.dropdownSuggestions,
      showSignUpSuggestion: false,
      clearEmailError: true,
      clearPasswordError: true,
      clearPasswordRequirements: true,
      clearErrorCode: true,
      clearEmailSuggestion: emailResult.suggestion == null,
      clearEmailSuggestions: emailResult.dropdownSuggestions.isEmpty,
    );

    try {
      await _repository.signInWithEmailOtp(emailResult.normalizedEmail);

      state = state.copyWith(
        status: AuthStatus.emailSent,
        showSignUpSuggestion: false,
        clearEmailError: true,
        clearPasswordError: true,
        clearPasswordRequirements: true,
        clearErrorCode: true,
        clearEmailSuggestion: true,
        clearEmailSuggestions: true,
      );
    } on AuthFailure catch (failure) {
      _handleAuthFailure(failure);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final emailResult = EmailValidator.validate(input: email);

    if (!emailResult.isValid) {
      state = state.copyWith(
        status: AuthStatus.idle,
        emailError: emailResult.error,
        emailSuggestion: emailResult.suggestion,
        emailSuggestions: emailResult.dropdownSuggestions,
        showSignUpSuggestion: false,
        clearErrorCode: true,
        clearEmailSuggestion: emailResult.suggestion == null,
        clearEmailSuggestions: emailResult.dropdownSuggestions.isEmpty,
      );
      return;
    }

    final passwordResult = PasswordValidator.validate(input: password);

    if (!passwordResult.isValid) {
      state = state.copyWith(
        status: AuthStatus.idle,
        passwordError: passwordResult.error,
        passwordPassedRequirements: passwordResult.passedRequirements,
        passwordFailedRequirements: passwordResult.failedRequirements,
        passwordStrength: passwordResult.strength,
        showSignUpSuggestion: false,
        clearEmailError: true,
        clearErrorCode: true,
      );
      return;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      showSignUpSuggestion: false,
      clearEmailError: true,
      clearPasswordError: true,
      clearPasswordRequirements: true,
      clearErrorCode: true,
      clearEmailSuggestion: true,
      clearEmailSuggestions: true,
    );

    try {
      await _repository.signUpWithEmailPassword(
        email: emailResult.normalizedEmail,
        password: password,
      );

      state = state.copyWith(
        status: AuthStatus.emailSent,
        showSignUpSuggestion: false,
        clearEmailError: true,
        clearPasswordError: true,
        clearPasswordRequirements: true,
        clearErrorCode: true,
        clearEmailSuggestion: true,
        clearEmailSuggestions: true,
      );
    } on AuthFailure catch (failure) {
      _handleAuthFailure(failure);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      showSignUpSuggestion: false,
      clearEmailError: true,
      clearPasswordError: true,
      clearPasswordRequirements: true,
      clearErrorCode: true,
      clearEmailSuggestion: true,
      clearEmailSuggestions: true,
    );

    try {
      await _repository.signInWithGoogle();

      state = state.copyWith(
        status: AuthStatus.idle,
        showSignUpSuggestion: false,
        clearEmailError: true,
        clearPasswordError: true,
        clearPasswordRequirements: true,
        clearErrorCode: true,
      );
    } on AuthFailure catch (failure) {
      _handleAuthFailure(failure);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  void _handleAuthFailure(AuthFailure failure) {
    state = state.copyWith(
      status: AuthStatus.error,
      showSignUpSuggestion: failure is UserNotFoundAuthFailure,
      clearEmailError: true,
      clearPasswordError: true,
      clearPasswordRequirements: true,
      clearEmailSuggestion: true,
      clearEmailSuggestions: true,
      errorCode: _mapFailureToErrorCode(failure),
    );
  }

  AuthErrorCode _mapFailureToErrorCode(AuthFailure failure) {
    return switch (failure) {
      UserNotFoundAuthFailure() => AuthErrorCode.userNotFound,
      PasswordRequiredAuthFailure() => AuthErrorCode.passwordRequired,
      GoogleAuthFailure() => AuthErrorCode.googleFailed,
      RateLimitedAuthFailure() => AuthErrorCode.rateLimited,
      ServerAuthFailure() => AuthErrorCode.server,
      UnknownAuthFailure() => AuthErrorCode.unknown,
    };
  }
}