import 'password_requirement.dart';
import 'password_validation_error.dart';
import 'password_validation_result.dart';

class PasswordValidator {
  PasswordValidator._();

  static const int minLength = 8;
  static const int maxLength = 128;

  static final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp _numberRegExp = RegExp(r'[0-9]');
  static final RegExp _specialCharacterRegExp = RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`;]',
  );

  static PasswordValidationResult validate({
    required String input,
  }) {
    final password = input.trim();

    final passed = <PasswordRequirement>{};
    final failed = <PasswordRequirement>{};

    void check(bool condition, PasswordRequirement requirement) {
      if (condition) {
        passed.add(requirement);
      } else {
        failed.add(requirement);
      }
    }

    check(password.length >= minLength, PasswordRequirement.minLength);
    check(password.length <= maxLength, PasswordRequirement.maxLength);
    check(!input.contains(' '), PasswordRequirement.noSpaces);
    check(_lowercaseRegExp.hasMatch(password), PasswordRequirement.lowercaseLetter);
    check(_uppercaseRegExp.hasMatch(password), PasswordRequirement.uppercaseLetter);
    check(_numberRegExp.hasMatch(password), PasswordRequirement.number);
    check(
      _specialCharacterRegExp.hasMatch(password),
      PasswordRequirement.specialCharacter,
    );

    final error = _firstError(password, input, failed);
    final strength = _calculateStrength(password, passed, failed);

    return PasswordValidationResult(
      isValid: error == null,
      error: error,
      passedRequirements: passed,
      failedRequirements: failed,
      strength: strength,
    );
  }

  static PasswordValidationError? _firstError(
      String password,
      String input,
      Set<PasswordRequirement> failed,
      ) {
    if (password.isEmpty) {
      return PasswordValidationError.empty;
    }

    if (failed.contains(PasswordRequirement.noSpaces)) {
      return PasswordValidationError.containsSpaces;
    }

    if (failed.contains(PasswordRequirement.minLength)) {
      return PasswordValidationError.tooShort;
    }

    if (failed.contains(PasswordRequirement.maxLength)) {
      return PasswordValidationError.tooLong;
    }

    if (failed.contains(PasswordRequirement.lowercaseLetter)) {
      return PasswordValidationError.missingLowercaseLetter;
    }

    if (failed.contains(PasswordRequirement.uppercaseLetter)) {
      return PasswordValidationError.missingUppercaseLetter;
    }

    if (failed.contains(PasswordRequirement.number)) {
      return PasswordValidationError.missingNumber;
    }

    if (failed.contains(PasswordRequirement.specialCharacter)) {
      return PasswordValidationError.missingSpecialCharacter;
    }

    return null;
  }

  static PasswordStrength _calculateStrength(
      String password,
      Set<PasswordRequirement> passed,
      Set<PasswordRequirement> failed,
      ) {
    if (password.isEmpty) {
      return PasswordStrength.empty;
    }

    if (failed.isEmpty && password.length >= 12) {
      return PasswordStrength.strong;
    }

    if (passed.length >= 5 && password.length >= 8) {
      return PasswordStrength.medium;
    }

    return PasswordStrength.weak;
  }
}