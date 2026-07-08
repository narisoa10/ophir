import 'password_requirement.dart';
import 'password_validation_error.dart';

enum PasswordStrength {
  empty,
  weak,
  medium,
  strong,
}

class PasswordValidationResult {
  const PasswordValidationResult({
    required this.isValid,
    required this.error,
    required this.passedRequirements,
    required this.failedRequirements,
    required this.strength,
  });

  final bool isValid;
  final PasswordValidationError? error;
  final Set<PasswordRequirement> passedRequirements;
  final Set<PasswordRequirement> failedRequirements;
  final PasswordStrength strength;
}