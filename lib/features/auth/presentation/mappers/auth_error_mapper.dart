import '../../../../core/localization/generated/app_localizations.dart';
import '../../controller/auth_state.dart';

extension AuthErrorCodeMapper on AuthErrorCode {
  String localized(AppLocalizations l10n) {
    switch (this) {
      case AuthErrorCode.userNotFound:
        return l10n.authUserNotFound;
      case AuthErrorCode.passwordRequired:
        return l10n.authPasswordRequired;
      case AuthErrorCode.googleFailed:
        return l10n.authGoogleFailed;
      case AuthErrorCode.server:
        return l10n.authServerError;
      case AuthErrorCode.unknown:
        return l10n.authUnknownError;
      case AuthErrorCode.rateLimited:
        return l10n.authRateLimited;
    }
  }
}