import '../../localization/generated/app_localizations.dart';
import 'email_validation_error.dart';

extension EmailValidationErrorMapper on EmailValidationError {
  String localized(AppLocalizations l10n) {
    switch (this) {
      case EmailValidationError.empty:
        return l10n.emailValidationEmpty;
      case EmailValidationError.containsSpaces:
        return l10n.emailValidationContainsSpaces;
      case EmailValidationError.missingAt:
        return l10n.emailValidationMissingAt;
      case EmailValidationError.multipleAt:
        return l10n.emailValidationMultipleAt;
      case EmailValidationError.missingLocalPart:
        return l10n.emailValidationMissingLocalPart;
      case EmailValidationError.missingDomain:
        return l10n.emailValidationMissingDomain;
      case EmailValidationError.localStartsWithDot:
        return l10n.emailValidationLocalStartsWithDot;
      case EmailValidationError.localEndsWithDot:
        return l10n.emailValidationLocalEndsWithDot;
      case EmailValidationError.localHasConsecutiveDots:
        return l10n.emailValidationLocalHasConsecutiveDots;
      case EmailValidationError.domainStartsWithDot:
        return l10n.emailValidationDomainStartsWithDot;
      case EmailValidationError.domainEndsWithDot:
        return l10n.emailValidationDomainEndsWithDot;
      case EmailValidationError.domainHasConsecutiveDots:
        return l10n.emailValidationDomainHasConsecutiveDots;
      case EmailValidationError.domainMissingDot:
        return l10n.emailValidationDomainMissingDot;
      case EmailValidationError.invalidTopLevelDomain:
        return l10n.emailValidationInvalidTopLevelDomain;
      case EmailValidationError.topLevelDomainTooShort:
        return l10n.emailValidationTopLevelDomainTooShort;
      case EmailValidationError.invalidLocalCharacters:
        return l10n.emailValidationInvalidLocalCharacters;
      case EmailValidationError.invalidDomainCharacters:
        return l10n.emailValidationInvalidDomainCharacters;
      case EmailValidationError.domainLabelStartsWithHyphen:
        return l10n.emailValidationDomainLabelStartsWithHyphen;
      case EmailValidationError.domainLabelEndsWithHyphen:
        return l10n.emailValidationDomainLabelEndsWithHyphen;
      case EmailValidationError.localPartTooLong:
        return l10n.emailValidationLocalPartTooLong;
      case EmailValidationError.domainTooLong:
        return l10n.emailValidationDomainTooLong;
      case EmailValidationError.emailTooLong:
        return l10n.emailValidationEmailTooLong;
      case EmailValidationError.invalidFormat:
        return l10n.emailValidationInvalidFormat;
    }
  }
}