import 'email_validation_error.dart';

class EmailValidationResult {
  const EmailValidationResult({
    required this.isValid,
    required this.normalizedEmail,
    required this.error,
    required this.suggestion,
    this.dropdownSuggestions = const [],
    required this.detectedDomain,
    required this.domainLooksSuspicious,
  });

  final bool isValid;
  final String normalizedEmail;
  final EmailValidationError? error;
  final String? suggestion;
  final List<String> dropdownSuggestions;
  final String? detectedDomain;
  final bool domainLooksSuspicious;

  bool get hasSuggestion => suggestion != null && suggestion!.isNotEmpty;

  factory EmailValidationResult.invalid({
    required String normalizedEmail,
    required EmailValidationError error,
    String? suggestion,
    List<String> dropdownSuggestions = const [],
    String? detectedDomain,
    bool domainLooksSuspicious = false,
  }) {
    return EmailValidationResult(
      isValid: false,
      normalizedEmail: normalizedEmail,
      error: error,
      suggestion: suggestion,
      dropdownSuggestions: dropdownSuggestions,
      detectedDomain: detectedDomain,
      domainLooksSuspicious: domainLooksSuspicious,
    );
  }

  factory EmailValidationResult.valid({
    required String normalizedEmail,
    String? suggestion,
    List<String> dropdownSuggestions = const [],
    String? detectedDomain,
    bool domainLooksSuspicious = false,
  }) {
    return EmailValidationResult(
      isValid: true,
      normalizedEmail: normalizedEmail,
      error: null,
      suggestion: suggestion,
      dropdownSuggestions: dropdownSuggestions,
      detectedDomain: detectedDomain,
      domainLooksSuspicious: domainLooksSuspicious,
    );
  }
}