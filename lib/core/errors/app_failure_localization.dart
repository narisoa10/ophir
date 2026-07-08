import '../localization/generated/app_localizations.dart';
import 'app_failure.dart';

extension AppFailureLocalization on AppFailure {
  String localized(AppLocalizations l10n) {
    return switch (this) {
      UnauthorizedFailure() => l10n.failureUnauthorized,
      NotFoundFailure() => l10n.failureNotFound,
      ValidationFailure() => l10n.failureValidation,
      DatabaseFailure() => l10n.failureDatabase,
      NetworkFailure() => l10n.failureNetwork,
      UnknownFailure() => l10n.failureUnknown,
    };
  }
}