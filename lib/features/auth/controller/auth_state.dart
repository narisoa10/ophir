import '../../../core/validation/email/email_validation_error.dart';
import '../../../core/validation/password/password_requirement.dart';
import '../../../core/validation/password/password_validation_error.dart';
import '../../../core/validation/password/password_validation_result.dart';

enum AuthStatus {
  idle,
  loading,
  emailSent,
  error,
}

enum AuthErrorCode {
  userNotFound,
  passwordRequired,
  googleFailed,
  unknown,
  server,
  rateLimited,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.emailError,
    this.passwordError,
    this.errorCode,
    this.emailSuggestion,
    this.emailSuggestions = const [],
    this.passwordPassedRequirements = const {},
    this.passwordFailedRequirements = const {},
    this.passwordStrength = PasswordStrength.empty,
    this.showSignUpSuggestion = false,
  });

  final AuthStatus status;
  final EmailValidationError? emailError;
  final PasswordValidationError? passwordError;
  final AuthErrorCode? errorCode;
  final String? emailSuggestion;
  final List<String> emailSuggestions;
  final Set<PasswordRequirement> passwordPassedRequirements;
  final Set<PasswordRequirement> passwordFailedRequirements;
  final PasswordStrength passwordStrength;
  final bool showSignUpSuggestion;

  bool get isLoading => status == AuthStatus.loading;

  bool get hasEmailSuggestion =>
      emailSuggestion != null && emailSuggestion!.isNotEmpty;

  AuthState copyWith({
    AuthStatus? status,
    EmailValidationError? emailError,
    PasswordValidationError? passwordError,
    AuthErrorCode? errorCode,
    String? emailSuggestion,
    List<String>? emailSuggestions,
    Set<PasswordRequirement>? passwordPassedRequirements,
    Set<PasswordRequirement>? passwordFailedRequirements,
    PasswordStrength? passwordStrength,
    bool? showSignUpSuggestion,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearErrorCode = false,
    bool clearEmailSuggestion = false,
    bool clearEmailSuggestions = false,
    bool clearPasswordRequirements = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      emailError: clearEmailError ? null : emailError ?? this.emailError,
      passwordError:
      clearPasswordError ? null : passwordError ?? this.passwordError,
      errorCode: clearErrorCode ? null : errorCode ?? this.errorCode,
      emailSuggestion: clearEmailSuggestion
          ? null
          : emailSuggestion ?? this.emailSuggestion,
      emailSuggestions: clearEmailSuggestions
          ? const []
          : emailSuggestions ?? this.emailSuggestions,
      passwordPassedRequirements: clearPasswordRequirements
          ? const {}
          : passwordPassedRequirements ?? this.passwordPassedRequirements,
      passwordFailedRequirements: clearPasswordRequirements
          ? const {}
          : passwordFailedRequirements ?? this.passwordFailedRequirements,
      passwordStrength: clearPasswordRequirements
          ? PasswordStrength.empty
          : passwordStrength ?? this.passwordStrength,
      showSignUpSuggestion:
      showSignUpSuggestion ?? this.showSignUpSuggestion,
    );
  }
}