import '../../localization/generated/app_localizations.dart';
import 'password_validation_error.dart';

extension PasswordValidationErrorMapper on PasswordValidationError {
  String localized(AppLocalizations l10n) {
    switch (this) {
      case PasswordValidationError.empty:
        return l10n.passwordValidationEmpty;
      case PasswordValidationError.containsSpaces:
        return l10n.passwordValidationContainsSpaces;
      case PasswordValidationError.tooShort:
        return l10n.passwordValidationTooShort;
      case PasswordValidationError.tooLong:
        return l10n.passwordValidationTooLong;
      case PasswordValidationError.missingLowercaseLetter:
        return l10n.passwordValidationMissingLowercaseLetter;
      case PasswordValidationError.missingUppercaseLetter:
        return l10n.passwordValidationMissingUppercaseLetter;
      case PasswordValidationError.missingNumber:
        return l10n.passwordValidationMissingNumber;
      case PasswordValidationError.missingSpecialCharacter:
        return l10n.passwordValidationMissingSpecialCharacter;
    }
  }
}