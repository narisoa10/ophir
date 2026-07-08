import 'email_domain_data.dart';
import 'email_validation_error.dart';
import 'email_validation_result.dart';

class EmailValidator {
  EmailValidator._();

  static const int _maxEmailLength = 254;
  static const int _maxLocalPartLength = 64;
  static const int _maxDomainLength = 253;
  static const int _maxDirectSuggestions = 6;
  static const int _maxFuzzySuggestions = 4;
  static const int _maxSuggestionDistance = 2;
  static const int _maxSafeAutoApplyDistance = 1;

  static final RegExp _validLocalCharsRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$",
  );

  static final RegExp _validDomainCharsRegExp = RegExp(
    r'^[a-zA-Z0-9.-]+$',
  );

  static final RegExp _topLevelDomainRegExp = RegExp(
    r'^[a-zA-Z]{2,24}$',
  );

  static String normalizeEmail(String input) {
    return input.trim().toLowerCase();
  }

  static EmailValidationResult validate({
    required String input,
  }) {
    final normalized = normalizeEmail(input);
    final dropdownSuggestions = getDropdownSuggestions(normalized);

    EmailValidationResult invalid({
      required EmailValidationError error,
      String? suggestion,
      String? detectedDomain,
      bool domainLooksSuspicious = false,
    }) {
      return EmailValidationResult.invalid(
        normalizedEmail: normalized,
        error: error,
        suggestion: suggestion,
        dropdownSuggestions: dropdownSuggestions,
        detectedDomain: detectedDomain,
        domainLooksSuspicious: domainLooksSuspicious,
      );
    }

    if (normalized.isEmpty) {
      return invalid(error: EmailValidationError.empty);
    }

    if (normalized.contains(' ')) {
      return invalid(error: EmailValidationError.containsSpaces);
    }

    final atMatches = '@'.allMatches(normalized).length;

    if (atMatches == 0) {
      return invalid(error: EmailValidationError.missingAt);
    }

    if (atMatches > 1) {
      return invalid(
        error: EmailValidationError.multipleAt,
        domainLooksSuspicious: true,
      );
    }

    if (normalized.length > _maxEmailLength) {
      return invalid(error: EmailValidationError.emailTooLong);
    }

    final parts = normalized.split('@');
    final local = parts.first;
    final domain = parts.last;

    if (local.isEmpty) {
      return invalid(
        error: EmailValidationError.missingLocalPart,
        detectedDomain: domain.isEmpty ? null : domain,
      );
    }

    if (domain.isEmpty) {
      return invalid(error: EmailValidationError.missingDomain);
    }

    if (local.length > _maxLocalPartLength) {
      return invalid(
        error: EmailValidationError.localPartTooLong,
        detectedDomain: domain,
      );
    }

    if (domain.length > _maxDomainLength) {
      return invalid(
        error: EmailValidationError.domainTooLong,
        detectedDomain: domain,
      );
    }

    if (local.startsWith('.')) {
      return invalid(
        error: EmailValidationError.localStartsWithDot,
        detectedDomain: domain,
      );
    }

    if (local.endsWith('.')) {
      return invalid(
        error: EmailValidationError.localEndsWithDot,
        detectedDomain: domain,
      );
    }

    if (local.contains('..')) {
      return invalid(
        error: EmailValidationError.localHasConsecutiveDots,
        detectedDomain: domain,
      );
    }

    if (!_validLocalCharsRegExp.hasMatch(local)) {
      return invalid(
        error: EmailValidationError.invalidLocalCharacters,
        detectedDomain: domain,
      );
    }

    if (domain.startsWith('.')) {
      return invalid(
        error: EmailValidationError.domainStartsWithDot,
        detectedDomain: domain,
      );
    }

    if (domain.endsWith('.')) {
      return invalid(
        error: EmailValidationError.domainEndsWithDot,
        detectedDomain: domain,
      );
    }

    if (domain.contains('..')) {
      return invalid(
        error: EmailValidationError.domainHasConsecutiveDots,
        detectedDomain: domain,
      );
    }

    if (!_validDomainCharsRegExp.hasMatch(domain)) {
      return invalid(
        error: EmailValidationError.invalidDomainCharacters,
        detectedDomain: domain,
      );
    }

    if (!domain.contains('.')) {
      return invalid(
        error: EmailValidationError.domainMissingDot,
        suggestion: _domainSuggestion(local, domain),
        detectedDomain: domain,
        domainLooksSuspicious: true,
      );
    }

    final labels = domain.split('.');

    for (final label in labels) {
      if (label.isEmpty) {
        return invalid(
          error: EmailValidationError.invalidFormat,
          detectedDomain: domain,
          domainLooksSuspicious: true,
        );
      }

      if (label.startsWith('-')) {
        return invalid(
          error: EmailValidationError.domainLabelStartsWithHyphen,
          detectedDomain: domain,
        );
      }

      if (label.endsWith('-')) {
        return invalid(
          error: EmailValidationError.domainLabelEndsWithHyphen,
          detectedDomain: domain,
        );
      }
    }

    final tld = labels.last;

    if (tld.length < 2) {
      return invalid(
        error: EmailValidationError.topLevelDomainTooShort,
        detectedDomain: domain,
      );
    }

    if (!_topLevelDomainRegExp.hasMatch(tld)) {
      return invalid(
        error: EmailValidationError.invalidTopLevelDomain,
        detectedDomain: domain,
      );
    }

    final suggestion = suggestCorrection(normalized);
    final domainLooksSuspicious =
        !EmailDomainData.popularDomainsSet.contains(domain) &&
            suggestion != null;

    return EmailValidationResult.valid(
      normalizedEmail: normalized,
      suggestion: suggestion == normalized ? null : suggestion,
      dropdownSuggestions: dropdownSuggestions,
      detectedDomain: domain,
      domainLooksSuspicious: domainLooksSuspicious,
    );
  }

  static List<String> getDropdownSuggestions(String input) {
    final normalized = normalizeEmail(input);

    if (!normalized.contains('@')) {
      return const [];
    }

    final parts = normalized.split('@');
    if (parts.length != 2) {
      return const [];
    }

    final local = parts.first;
    final domainPart = parts.last;

    if (local.isEmpty) {
      return const [];
    }

    final directMatches = EmailDomainData.popularDomains
        .where((domain) => domain.startsWith(domainPart))
        .take(_maxDirectSuggestions)
        .map((domain) => '$local@$domain')
        .toList();

    final fuzzyMatches = EmailDomainData.popularDomains
        .where(
          (domain) =>
      domainPart.isNotEmpty &&
          _levenshtein(domainPart, domain) <= _maxSuggestionDistance,
    )
        .take(_maxFuzzySuggestions)
        .map((domain) => '$local@$domain')
        .toList();

    final suggestions = <String>{
      ...directMatches,
      ...fuzzyMatches,
    }.toList();

    if (directMatches.isNotEmpty) {
      return suggestions.take(_maxDirectSuggestions).toList();
    }

    return suggestions.take(_maxFuzzySuggestions).toList();
  }

  static String? suggestCorrection(String input) {
    final normalized = normalizeEmail(input);

    if (!normalized.contains('@')) {
      return null;
    }

    final parts = normalized.split('@');
    if (parts.length != 2) {
      return null;
    }

    final local = parts.first;
    final domain = parts.last;

    if (local.isEmpty || domain.isEmpty) {
      return null;
    }

    final typoMatch = EmailDomainData.commonTypos[domain];
    if (typoMatch != null) {
      return '$local@$typoMatch';
    }

    final closestDomain = _findClosestDomain(domain);
    if (closestDomain == null || closestDomain == domain) {
      return null;
    }

    final distance = _levenshtein(domain, closestDomain);
    if (distance <= _maxSuggestionDistance) {
      return '$local@$closestDomain';
    }

    return null;
  }

  static String applySuggestionIfSafe(String input) {
    final normalized = normalizeEmail(input);
    final suggestion = suggestCorrection(normalized);

    if (suggestion == null || !normalized.contains('@')) {
      return normalized;
    }

    final originalDomain = normalized.split('@').last;
    final suggestedDomain = suggestion.split('@').last;
    final distance = _levenshtein(originalDomain, suggestedDomain);

    if (distance <= _maxSafeAutoApplyDistance ||
        EmailDomainData.commonTypos.containsKey(originalDomain)) {
      return suggestion;
    }

    return normalized;
  }

  static String? _domainSuggestion(String local, String domain) {
    final closestDomain = _findClosestDomain(domain);
    if (closestDomain == null) {
      return null;
    }

    return '$local@$closestDomain';
  }

  static String? _findClosestDomain(String typedDomain) {
    String? bestMatch;
    var bestDistance = 1 << 30;

    for (final domain in EmailDomainData.popularDomains) {
      final distance = _levenshtein(typedDomain, domain);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = domain;
      }
    }

    if (bestDistance <= _maxSuggestionDistance) {
      return bestMatch;
    }

    return null;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previousRow = List<int>.generate(
      b.length + 1,
          (index) => index,
    );
    final currentRow = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      currentRow[0] = i;

      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;

        currentRow[j] = _min3(
          previousRow[j] + 1,
          currentRow[j - 1] + 1,
          previousRow[j - 1] + substitutionCost,
        );
      }

      for (var j = 0; j <= b.length; j++) {
        previousRow[j] = currentRow[j];
      }
    }

    return previousRow[b.length];
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= a && b <= c) return b;
    return c;
  }
}