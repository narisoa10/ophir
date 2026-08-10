import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Ophir'**
  String get authWelcome;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smart finance.\nAll your finances in one app.'**
  String get authSubtitle;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get authTermsPrefix;

  /// No description provided for @authTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get authTermsOfUse;

  /// No description provided for @authAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get authAnd;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get authComingSoon;

  /// No description provided for @authCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email inbox.'**
  String get authCheckEmail;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email.'**
  String get authUserNotFound;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authPasswordRequired;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authUnknownError;

  /// No description provided for @authGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed.'**
  String get authGoogleFailed;

  /// No description provided for @authServerError.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authServerError;

  /// No description provided for @authEmailSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Did you mean'**
  String get authEmailSuggestion;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many email requests. Please wait a few minutes and try again.'**
  String get authRateLimited;

  /// No description provided for @emailValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get emailValidationEmpty;

  /// No description provided for @emailValidationContainsSpaces.
  ///
  /// In en, this message translates to:
  /// **'Email must not contain spaces.'**
  String get emailValidationContainsSpaces;

  /// No description provided for @emailValidationMissingAt.
  ///
  /// In en, this message translates to:
  /// **'Email must contain \'@\'.'**
  String get emailValidationMissingAt;

  /// No description provided for @emailValidationMultipleAt.
  ///
  /// In en, this message translates to:
  /// **'Email must contain only one \'@\'.'**
  String get emailValidationMultipleAt;

  /// No description provided for @emailValidationMissingLocalPart.
  ///
  /// In en, this message translates to:
  /// **'Enter the part before \'@\'.'**
  String get emailValidationMissingLocalPart;

  /// No description provided for @emailValidationMissingDomain.
  ///
  /// In en, this message translates to:
  /// **'Enter the email domain.'**
  String get emailValidationMissingDomain;

  /// No description provided for @emailValidationLocalStartsWithDot.
  ///
  /// In en, this message translates to:
  /// **'The local part must not start with \'.\'.'**
  String get emailValidationLocalStartsWithDot;

  /// No description provided for @emailValidationLocalEndsWithDot.
  ///
  /// In en, this message translates to:
  /// **'The local part must not end with \'.\'.'**
  String get emailValidationLocalEndsWithDot;

  /// No description provided for @emailValidationLocalHasConsecutiveDots.
  ///
  /// In en, this message translates to:
  /// **'The local part must not contain consecutive dots.'**
  String get emailValidationLocalHasConsecutiveDots;

  /// No description provided for @emailValidationDomainStartsWithDot.
  ///
  /// In en, this message translates to:
  /// **'The domain must not start with \'.\'.'**
  String get emailValidationDomainStartsWithDot;

  /// No description provided for @emailValidationDomainEndsWithDot.
  ///
  /// In en, this message translates to:
  /// **'The domain must not end with \'.\'.'**
  String get emailValidationDomainEndsWithDot;

  /// No description provided for @emailValidationDomainHasConsecutiveDots.
  ///
  /// In en, this message translates to:
  /// **'The domain must not contain consecutive dots.'**
  String get emailValidationDomainHasConsecutiveDots;

  /// No description provided for @emailValidationDomainMissingDot.
  ///
  /// In en, this message translates to:
  /// **'The domain must contain a \'.\'.'**
  String get emailValidationDomainMissingDot;

  /// No description provided for @emailValidationInvalidTopLevelDomain.
  ///
  /// In en, this message translates to:
  /// **'Invalid top-level domain.'**
  String get emailValidationInvalidTopLevelDomain;

  /// No description provided for @emailValidationTopLevelDomainTooShort.
  ///
  /// In en, this message translates to:
  /// **'Top-level domain is too short.'**
  String get emailValidationTopLevelDomainTooShort;

  /// No description provided for @emailValidationInvalidLocalCharacters.
  ///
  /// In en, this message translates to:
  /// **'Invalid characters in the local part.'**
  String get emailValidationInvalidLocalCharacters;

  /// No description provided for @emailValidationInvalidDomainCharacters.
  ///
  /// In en, this message translates to:
  /// **'Invalid characters in the domain.'**
  String get emailValidationInvalidDomainCharacters;

  /// No description provided for @emailValidationDomainLabelStartsWithHyphen.
  ///
  /// In en, this message translates to:
  /// **'A domain label must not start with \'-\'.'**
  String get emailValidationDomainLabelStartsWithHyphen;

  /// No description provided for @emailValidationDomainLabelEndsWithHyphen.
  ///
  /// In en, this message translates to:
  /// **'A domain label must not end with \'-\'.'**
  String get emailValidationDomainLabelEndsWithHyphen;

  /// No description provided for @emailValidationLocalPartTooLong.
  ///
  /// In en, this message translates to:
  /// **'The local part is too long.'**
  String get emailValidationLocalPartTooLong;

  /// No description provided for @emailValidationDomainTooLong.
  ///
  /// In en, this message translates to:
  /// **'The domain is too long.'**
  String get emailValidationDomainTooLong;

  /// No description provided for @emailValidationEmailTooLong.
  ///
  /// In en, this message translates to:
  /// **'The email address is too long.'**
  String get emailValidationEmailTooLong;

  /// No description provided for @emailValidationInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get emailValidationInvalidFormat;

  /// No description provided for @passwordValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get passwordValidationEmpty;

  /// No description provided for @passwordValidationContainsSpaces.
  ///
  /// In en, this message translates to:
  /// **'Password must not contain spaces.'**
  String get passwordValidationContainsSpaces;

  /// No description provided for @passwordValidationTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordValidationTooShort;

  /// No description provided for @passwordValidationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be no more than 128 characters.'**
  String get passwordValidationTooLong;

  /// No description provided for @passwordValidationMissingNumber.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one number.'**
  String get passwordValidationMissingNumber;

  /// No description provided for @passwordValidationMissingSpecialCharacter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one special character.'**
  String get passwordValidationMissingSpecialCharacter;

  /// No description provided for @passwordValidationMissingLowercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one lowercase letter.'**
  String get passwordValidationMissingLowercaseLetter;

  /// No description provided for @passwordValidationMissingUppercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one uppercase letter.'**
  String get passwordValidationMissingUppercaseLetter;

  /// No description provided for @passwordRequirementMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordRequirementMinLength;

  /// No description provided for @passwordRequirementMaxLength.
  ///
  /// In en, this message translates to:
  /// **'No more than 128 characters'**
  String get passwordRequirementMaxLength;

  /// No description provided for @passwordRequirementNoSpaces.
  ///
  /// In en, this message translates to:
  /// **'No spaces'**
  String get passwordRequirementNoSpaces;

  /// No description provided for @passwordRequirementLowercase.
  ///
  /// In en, this message translates to:
  /// **'One lowercase letter'**
  String get passwordRequirementLowercase;

  /// No description provided for @passwordRequirementUppercase.
  ///
  /// In en, this message translates to:
  /// **'One uppercase letter'**
  String get passwordRequirementUppercase;

  /// No description provided for @passwordRequirementNumber.
  ///
  /// In en, this message translates to:
  /// **'One number'**
  String get passwordRequirementNumber;

  /// No description provided for @passwordRequirementSpecial.
  ///
  /// In en, this message translates to:
  /// **'One special character'**
  String get passwordRequirementSpecial;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @failureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue.'**
  String get failureUnauthorized;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested data was not found.'**
  String get failureNotFound;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the entered data.'**
  String get failureValidation;

  /// No description provided for @failureDatabase.
  ///
  /// In en, this message translates to:
  /// **'A database error occurred.'**
  String get failureDatabase;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get failureNetwork;

  /// No description provided for @failurePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your camera or photos to continue.'**
  String get failurePermission;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get failureUnknown;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ophir'**
  String get appTitle;

  /// No description provided for @navigationHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navigationHome;

  /// No description provided for @navigationStatistics.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navigationStatistics;

  /// No description provided for @navigationSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navigationSettings;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'DATA'**
  String get settingsSectionData;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme and display preferences'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsAppearanceCurrentSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme: System'**
  String get settingsAppearanceCurrentSystem;

  /// No description provided for @settingsAppearanceCurrentLight.
  ///
  /// In en, this message translates to:
  /// **'Theme: Light'**
  String get settingsAppearanceCurrentLight;

  /// No description provided for @settingsAppearanceCurrentDark.
  ///
  /// In en, this message translates to:
  /// **'Theme: Dark'**
  String get settingsAppearanceCurrentDark;

  /// No description provided for @settingsThemeSection.
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get settingsThemeSection;

  /// No description provided for @settingsThemeSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystemTitle;

  /// No description provided for @settingsThemeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow your device appearance'**
  String get settingsThemeSystemSubtitle;

  /// No description provided for @settingsThemeLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLightTitle;

  /// No description provided for @settingsThemeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the light appearance'**
  String get settingsThemeLightSubtitle;

  /// No description provided for @settingsThemeDarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDarkTitle;

  /// No description provided for @settingsThemeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the dark appearance'**
  String get settingsThemeDarkSubtitle;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts and balances'**
  String get settingsAccountsSubtitle;

  /// No description provided for @settingsCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategoriesTitle;

  /// No description provided for @settingsCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize income and expense categories'**
  String get settingsCategoriesSubtitle;

  /// No description provided for @settingsBudgetPlanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Planning'**
  String get settingsBudgetPlanningTitle;

  /// No description provided for @settingsBudgetPlanningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage household, income, and expenses'**
  String get settingsBudgetPlanningSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App information and support'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your data is handled'**
  String get settingsPrivacyPolicySubtitle;

  /// No description provided for @settingsTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rules for using Ophir'**
  String get settingsTermsSubtitle;

  /// No description provided for @settingsSecurityPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get settingsSecurityPrivacyTitle;

  /// No description provided for @settingsSecurityPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, access and personal data'**
  String get settingsSecurityPrivacySubtitle;

  /// No description provided for @settingsDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataTitle;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archive, export, import and backup'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsAboutOphirTitle.
  ///
  /// In en, this message translates to:
  /// **'About Ophir'**
  String get settingsAboutOphirTitle;

  /// No description provided for @settingsAppVersionValue.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get settingsAppVersionValue;

  /// No description provided for @settingsTermsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfServiceTitle;

  /// No description provided for @settingsContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get settingsContactTitle;

  /// No description provided for @settingsContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support and feedback'**
  String get settingsContactSubtitle;

  /// No description provided for @settingsWhatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get settingsWhatsNewTitle;

  /// No description provided for @settingsWhatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Release notes placeholder'**
  String get settingsWhatsNewSubtitle;

  /// No description provided for @settingsArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get settingsArchiveTitle;

  /// No description provided for @settingsArchiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archived operations'**
  String get settingsArchiveSubtitle;

  /// No description provided for @settingsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExportTitle;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export your data'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImportTitle;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backups and restore'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsOpenSourceLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsOpenSourceLicensesTitle;

  /// No description provided for @settingsOpenSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party notices'**
  String get settingsOpenSourceLicensesSubtitle;

  /// No description provided for @settingsAppVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersionTitle;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @navigationOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navigationOperations;

  /// No description provided for @operationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operationsTitle;

  /// No description provided for @profileNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileNameMissing;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your name, photo and information'**
  String get profileEditSubtitle;

  /// No description provided for @profileSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurityTitle;

  /// No description provided for @profileSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password and account security'**
  String get profileSecuritySubtitle;

  /// No description provided for @profileNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotificationsTitle;

  /// No description provided for @profileNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences'**
  String get profileNotificationsSubtitle;

  /// No description provided for @profileAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearanceTitle;

  /// No description provided for @profileAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme and display preferences'**
  String get profileAppearanceSubtitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// No description provided for @profileFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileFullNameHint;

  /// No description provided for @profileFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get profileFullNameRequired;

  /// No description provided for @profileAvatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get profileAvatarChange;

  /// No description provided for @profileAvatarTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get profileAvatarTakePhoto;

  /// No description provided for @profileAvatarChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profileAvatarChooseFromGallery;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @categoryRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryRent;

  /// No description provided for @categoryMortgage.
  ///
  /// In en, this message translates to:
  /// **'Mortgage'**
  String get categoryMortgage;

  /// No description provided for @categoryUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// No description provided for @categoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryInsurance;

  /// No description provided for @categoryGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryGroceries;

  /// No description provided for @categoryRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get categoryRestaurants;

  /// No description provided for @categoryCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get categoryCoffee;

  /// No description provided for @categoryFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryFuel;

  /// No description provided for @categoryPublicTransit.
  ///
  /// In en, this message translates to:
  /// **'Public transit'**
  String get categoryPublicTransit;

  /// No description provided for @categoryCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get categoryCar;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get categoryPharmacy;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categorySubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get categorySubscriptions;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryDebtPayment.
  ///
  /// In en, this message translates to:
  /// **'Debt payment'**
  String get categoryDebtPayment;

  /// No description provided for @categoryBankFees.
  ///
  /// In en, this message translates to:
  /// **'Bank fees'**
  String get categoryBankFees;

  /// No description provided for @categorySavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get categorySavings;

  /// No description provided for @categoryInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get categoryInvestments;

  /// No description provided for @categoryOtherExpense.
  ///
  /// In en, this message translates to:
  /// **'Other expense'**
  String get categoryOtherExpense;

  /// No description provided for @categorySalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// No description provided for @categoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// No description provided for @categoryBenefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get categoryBenefits;

  /// No description provided for @categoryDividends.
  ///
  /// In en, this message translates to:
  /// **'Dividends'**
  String get categoryDividends;

  /// No description provided for @categoryOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get categoryOtherIncome;

  /// No description provided for @categoryExampleDefault.
  ///
  /// In en, this message translates to:
  /// **'Ex. Operation detail'**
  String get categoryExampleDefault;

  /// No description provided for @categoryExampleRent.
  ///
  /// In en, this message translates to:
  /// **'Ex. July rent'**
  String get categoryExampleRent;

  /// No description provided for @categoryExampleMortgage.
  ///
  /// In en, this message translates to:
  /// **'Ex. Mortgage payment'**
  String get categoryExampleMortgage;

  /// No description provided for @categoryExampleUtilities.
  ///
  /// In en, this message translates to:
  /// **'Ex. Electricity bill'**
  String get categoryExampleUtilities;

  /// No description provided for @categoryExampleInsurance.
  ///
  /// In en, this message translates to:
  /// **'Ex. Home insurance'**
  String get categoryExampleInsurance;

  /// No description provided for @categoryExampleGroceries.
  ///
  /// In en, this message translates to:
  /// **'Ex. Costco'**
  String get categoryExampleGroceries;

  /// No description provided for @categoryExampleRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Ex. Restaurant'**
  String get categoryExampleRestaurants;

  /// No description provided for @categoryExampleCoffee.
  ///
  /// In en, this message translates to:
  /// **'Ex. Starbucks'**
  String get categoryExampleCoffee;

  /// No description provided for @categoryExampleFuel.
  ///
  /// In en, this message translates to:
  /// **'Ex. Gas'**
  String get categoryExampleFuel;

  /// No description provided for @categoryExamplePublicTransit.
  ///
  /// In en, this message translates to:
  /// **'Ex. Bus pass'**
  String get categoryExamplePublicTransit;

  /// No description provided for @categoryExampleCar.
  ///
  /// In en, this message translates to:
  /// **'Ex. Car maintenance'**
  String get categoryExampleCar;

  /// No description provided for @categoryExampleHealth.
  ///
  /// In en, this message translates to:
  /// **'Ex. Doctor visit'**
  String get categoryExampleHealth;

  /// No description provided for @categoryExamplePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Ex. Pharmacy'**
  String get categoryExamplePharmacy;

  /// No description provided for @categoryExampleShopping.
  ///
  /// In en, this message translates to:
  /// **'Ex. Amazon'**
  String get categoryExampleShopping;

  /// No description provided for @categoryExampleEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Ex. Movie ticket'**
  String get categoryExampleEntertainment;

  /// No description provided for @categoryExampleSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Ex. Netflix'**
  String get categoryExampleSubscriptions;

  /// No description provided for @categoryExampleTravel.
  ///
  /// In en, this message translates to:
  /// **'Ex. Flight ticket'**
  String get categoryExampleTravel;

  /// No description provided for @categoryExampleEducation.
  ///
  /// In en, this message translates to:
  /// **'Ex. Course'**
  String get categoryExampleEducation;

  /// No description provided for @categoryExampleDebtPayment.
  ///
  /// In en, this message translates to:
  /// **'Ex. Credit card payment'**
  String get categoryExampleDebtPayment;

  /// No description provided for @categoryExampleBankFees.
  ///
  /// In en, this message translates to:
  /// **'Ex. Bank fee'**
  String get categoryExampleBankFees;

  /// No description provided for @categoryExampleSavings.
  ///
  /// In en, this message translates to:
  /// **'Ex. Monthly savings'**
  String get categoryExampleSavings;

  /// No description provided for @categoryExampleInvestments.
  ///
  /// In en, this message translates to:
  /// **'Ex. Wealthsimple'**
  String get categoryExampleInvestments;

  /// No description provided for @categoryExampleOtherExpense.
  ///
  /// In en, this message translates to:
  /// **'Ex. Other expense'**
  String get categoryExampleOtherExpense;

  /// No description provided for @categoryExampleSalary.
  ///
  /// In en, this message translates to:
  /// **'Ex. June salary'**
  String get categoryExampleSalary;

  /// No description provided for @categoryExampleBusiness.
  ///
  /// In en, this message translates to:
  /// **'Ex. Client payment'**
  String get categoryExampleBusiness;

  /// No description provided for @categoryExampleBenefits.
  ///
  /// In en, this message translates to:
  /// **'Ex. Benefit payment'**
  String get categoryExampleBenefits;

  /// No description provided for @categoryExampleDividends.
  ///
  /// In en, this message translates to:
  /// **'Ex. Dividends'**
  String get categoryExampleDividends;

  /// No description provided for @categoryExampleOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Ex. Other income'**
  String get categoryExampleOtherIncome;

  /// No description provided for @categoryGroupExpenseHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get categoryGroupExpenseHousing;

  /// No description provided for @categoryGroupExpenseFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryGroupExpenseFood;

  /// No description provided for @categoryGroupExpenseTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryGroupExpenseTransportation;

  /// No description provided for @categoryGroupExpenseHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryGroupExpenseHealth;

  /// No description provided for @categoryGroupExpenseFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryGroupExpenseFamily;

  /// No description provided for @categoryGroupExpensePersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get categoryGroupExpensePersonalCare;

  /// No description provided for @categoryGroupExpenseEntertainmentLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Entertainment & Lifestyle'**
  String get categoryGroupExpenseEntertainmentLifestyle;

  /// No description provided for @categoryGroupExpenseEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryGroupExpenseEducation;

  /// No description provided for @categoryGroupExpenseFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get categoryGroupExpenseFinance;

  /// No description provided for @categoryGroupExpenseGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get categoryGroupExpenseGovernment;

  /// No description provided for @categoryGroupExpensePets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryGroupExpensePets;

  /// No description provided for @categoryGroupExpenseGiving.
  ///
  /// In en, this message translates to:
  /// **'Giving'**
  String get categoryGroupExpenseGiving;

  /// No description provided for @categoryGroupExpenseWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryGroupExpenseWork;

  /// No description provided for @categoryGroupExpenseOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryGroupExpenseOther;

  /// No description provided for @categoryGroupIncomeEmployment.
  ///
  /// In en, this message translates to:
  /// **'Employment'**
  String get categoryGroupIncomeEmployment;

  /// No description provided for @categoryGroupIncomeBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryGroupIncomeBusiness;

  /// No description provided for @categoryGroupIncomeInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get categoryGroupIncomeInvestments;

  /// No description provided for @categoryGroupIncomeGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get categoryGroupIncomeGovernment;

  /// No description provided for @categoryGroupIncomeGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryGroupIncomeGifts;

  /// No description provided for @categoryGroupIncomeOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get categoryGroupIncomeOtherIncome;

  /// No description provided for @categoryTaxonomyExpenseHousingRentName.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryTaxonomyExpenseHousingRentName;

  /// No description provided for @categoryTaxonomyExpenseHousingMortgageName.
  ///
  /// In en, this message translates to:
  /// **'Mortgage'**
  String get categoryTaxonomyExpenseHousingMortgageName;

  /// No description provided for @categoryTaxonomyExpenseHousingPropertyTaxName.
  ///
  /// In en, this message translates to:
  /// **'Property Tax'**
  String get categoryTaxonomyExpenseHousingPropertyTaxName;

  /// No description provided for @categoryTaxonomyExpenseHousingCondoFeesName.
  ///
  /// In en, this message translates to:
  /// **'Condo Fees'**
  String get categoryTaxonomyExpenseHousingCondoFeesName;

  /// No description provided for @categoryTaxonomyExpenseHousingElectricityName.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get categoryTaxonomyExpenseHousingElectricityName;

  /// No description provided for @categoryTaxonomyExpenseHousingNaturalGasName.
  ///
  /// In en, this message translates to:
  /// **'Natural Gas'**
  String get categoryTaxonomyExpenseHousingNaturalGasName;

  /// No description provided for @categoryTaxonomyExpenseHousingWaterName.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get categoryTaxonomyExpenseHousingWaterName;

  /// No description provided for @categoryTaxonomyExpenseHousingSewerName.
  ///
  /// In en, this message translates to:
  /// **'Sewer'**
  String get categoryTaxonomyExpenseHousingSewerName;

  /// No description provided for @categoryTaxonomyExpenseHousingGarbageCollectionName.
  ///
  /// In en, this message translates to:
  /// **'Garbage Collection'**
  String get categoryTaxonomyExpenseHousingGarbageCollectionName;

  /// No description provided for @categoryTaxonomyExpenseHousingInternetName.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get categoryTaxonomyExpenseHousingInternetName;

  /// No description provided for @categoryTaxonomyExpenseHousingMobilePhoneName.
  ///
  /// In en, this message translates to:
  /// **'Mobile Phone'**
  String get categoryTaxonomyExpenseHousingMobilePhoneName;

  /// No description provided for @categoryTaxonomyExpenseHousingHomePhoneName.
  ///
  /// In en, this message translates to:
  /// **'Home Phone'**
  String get categoryTaxonomyExpenseHousingHomePhoneName;

  /// No description provided for @categoryTaxonomyExpenseHousingHomeInsuranceName.
  ///
  /// In en, this message translates to:
  /// **'Home Insurance'**
  String get categoryTaxonomyExpenseHousingHomeInsuranceName;

  /// No description provided for @categoryTaxonomyExpenseHousingHomeMaintenanceName.
  ///
  /// In en, this message translates to:
  /// **'Home Maintenance'**
  String get categoryTaxonomyExpenseHousingHomeMaintenanceName;

  /// No description provided for @categoryTaxonomyExpenseHousingFurnitureName.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get categoryTaxonomyExpenseHousingFurnitureName;

  /// No description provided for @categoryTaxonomyExpenseHousingAppliancesName.
  ///
  /// In en, this message translates to:
  /// **'Appliances'**
  String get categoryTaxonomyExpenseHousingAppliancesName;

  /// No description provided for @categoryTaxonomyExpenseHousingHomeSuppliesName.
  ///
  /// In en, this message translates to:
  /// **'Home Supplies'**
  String get categoryTaxonomyExpenseHousingHomeSuppliesName;

  /// No description provided for @categoryTaxonomyExpenseHousingHomeSecurityName.
  ///
  /// In en, this message translates to:
  /// **'Home Security'**
  String get categoryTaxonomyExpenseHousingHomeSecurityName;

  /// No description provided for @categoryTaxonomyExpenseFoodGroceriesName.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryTaxonomyExpenseFoodGroceriesName;

  /// No description provided for @categoryTaxonomyExpenseFoodFarmersMarketName.
  ///
  /// In en, this message translates to:
  /// **'Farmers Market'**
  String get categoryTaxonomyExpenseFoodFarmersMarketName;

  /// No description provided for @categoryTaxonomyExpenseFoodRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get categoryTaxonomyExpenseFoodRestaurantName;

  /// No description provided for @categoryTaxonomyExpenseFoodCafeCoffeeName.
  ///
  /// In en, this message translates to:
  /// **'Café & Coffee'**
  String get categoryTaxonomyExpenseFoodCafeCoffeeName;

  /// No description provided for @categoryTaxonomyExpenseFoodFastFoodName.
  ///
  /// In en, this message translates to:
  /// **'Fast Food'**
  String get categoryTaxonomyExpenseFoodFastFoodName;

  /// No description provided for @categoryTaxonomyExpenseFoodFoodDeliveryName.
  ///
  /// In en, this message translates to:
  /// **'Food Delivery'**
  String get categoryTaxonomyExpenseFoodFoodDeliveryName;

  /// No description provided for @categoryTaxonomyExpenseFoodSnacksName.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get categoryTaxonomyExpenseFoodSnacksName;

  /// No description provided for @categoryTaxonomyExpenseFoodAlcoholName.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get categoryTaxonomyExpenseFoodAlcoholName;

  /// No description provided for @categoryTaxonomyExpenseTransportationFuelName.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryTaxonomyExpenseTransportationFuelName;

  /// No description provided for @categoryTaxonomyExpenseTransportationEvChargingName.
  ///
  /// In en, this message translates to:
  /// **'EV Charging'**
  String get categoryTaxonomyExpenseTransportationEvChargingName;

  /// No description provided for @categoryTaxonomyExpenseTransportationPublicTransitName.
  ///
  /// In en, this message translates to:
  /// **'Public Transit'**
  String get categoryTaxonomyExpenseTransportationPublicTransitName;

  /// No description provided for @categoryTaxonomyExpenseTransportationTaxiRideSharingName.
  ///
  /// In en, this message translates to:
  /// **'Taxi & Ride Sharing'**
  String get categoryTaxonomyExpenseTransportationTaxiRideSharingName;

  /// No description provided for @categoryTaxonomyExpenseTransportationParkingName.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get categoryTaxonomyExpenseTransportationParkingName;

  /// No description provided for @categoryTaxonomyExpenseTransportationTollRoadsName.
  ///
  /// In en, this message translates to:
  /// **'Toll Roads'**
  String get categoryTaxonomyExpenseTransportationTollRoadsName;

  /// No description provided for @categoryTaxonomyExpenseTransportationAutoInsuranceName.
  ///
  /// In en, this message translates to:
  /// **'Auto Insurance'**
  String get categoryTaxonomyExpenseTransportationAutoInsuranceName;

  /// No description provided for @categoryTaxonomyExpenseTransportationAutoLoanName.
  ///
  /// In en, this message translates to:
  /// **'Auto Loan'**
  String get categoryTaxonomyExpenseTransportationAutoLoanName;

  /// No description provided for @categoryTaxonomyExpenseTransportationVehicleMaintenanceName.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Maintenance'**
  String get categoryTaxonomyExpenseTransportationVehicleMaintenanceName;

  /// No description provided for @categoryTaxonomyExpenseTransportationTireServiceName.
  ///
  /// In en, this message translates to:
  /// **'Tire Service'**
  String get categoryTaxonomyExpenseTransportationTireServiceName;

  /// No description provided for @categoryTaxonomyExpenseTransportationVehicleRegistrationName.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Registration'**
  String get categoryTaxonomyExpenseTransportationVehicleRegistrationName;

  /// No description provided for @categoryTaxonomyExpenseTransportationCarWashName.
  ///
  /// In en, this message translates to:
  /// **'Car Wash'**
  String get categoryTaxonomyExpenseTransportationCarWashName;

  /// No description provided for @categoryTaxonomyExpenseHealthPharmacyName.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get categoryTaxonomyExpenseHealthPharmacyName;

  /// No description provided for @categoryTaxonomyExpenseHealthMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get categoryTaxonomyExpenseHealthMedicineName;

  /// No description provided for @categoryTaxonomyExpenseHealthDoctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get categoryTaxonomyExpenseHealthDoctorName;

  /// No description provided for @categoryTaxonomyExpenseHealthDentistName.
  ///
  /// In en, this message translates to:
  /// **'Dentist'**
  String get categoryTaxonomyExpenseHealthDentistName;

  /// No description provided for @categoryTaxonomyExpenseHealthVisionCareName.
  ///
  /// In en, this message translates to:
  /// **'Vision Care'**
  String get categoryTaxonomyExpenseHealthVisionCareName;

  /// No description provided for @categoryTaxonomyExpenseHealthMedicalTestsName.
  ///
  /// In en, this message translates to:
  /// **'Medical Tests'**
  String get categoryTaxonomyExpenseHealthMedicalTestsName;

  /// No description provided for @categoryTaxonomyExpenseHealthMedicalProceduresName.
  ///
  /// In en, this message translates to:
  /// **'Medical Procedures'**
  String get categoryTaxonomyExpenseHealthMedicalProceduresName;

  /// No description provided for @categoryTaxonomyExpenseHealthHealthInsuranceName.
  ///
  /// In en, this message translates to:
  /// **'Health Insurance'**
  String get categoryTaxonomyExpenseHealthHealthInsuranceName;

  /// No description provided for @categoryTaxonomyExpenseHealthMentalHealthName.
  ///
  /// In en, this message translates to:
  /// **'Mental Health'**
  String get categoryTaxonomyExpenseHealthMentalHealthName;

  /// No description provided for @categoryTaxonomyExpenseHealthPhysiotherapyName.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy'**
  String get categoryTaxonomyExpenseHealthPhysiotherapyName;

  /// No description provided for @categoryTaxonomyExpenseHealthGymFitnessName.
  ///
  /// In en, this message translates to:
  /// **'Gym & Fitness'**
  String get categoryTaxonomyExpenseHealthGymFitnessName;

  /// No description provided for @categoryTaxonomyExpenseHealthVitaminsName.
  ///
  /// In en, this message translates to:
  /// **'Vitamins'**
  String get categoryTaxonomyExpenseHealthVitaminsName;

  /// No description provided for @categoryTaxonomyExpenseFamilyChildcareName.
  ///
  /// In en, this message translates to:
  /// **'Childcare'**
  String get categoryTaxonomyExpenseFamilyChildcareName;

  /// No description provided for @categoryTaxonomyExpenseFamilyDaycareName.
  ///
  /// In en, this message translates to:
  /// **'Daycare'**
  String get categoryTaxonomyExpenseFamilyDaycareName;

  /// No description provided for @categoryTaxonomyExpenseFamilySchoolName.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get categoryTaxonomyExpenseFamilySchoolName;

  /// No description provided for @categoryTaxonomyExpenseFamilyUniversityName.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get categoryTaxonomyExpenseFamilyUniversityName;

  /// No description provided for @categoryTaxonomyExpenseFamilyTutoringName.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get categoryTaxonomyExpenseFamilyTutoringName;

  /// No description provided for @categoryTaxonomyExpenseFamilyChildrensClothingName.
  ///
  /// In en, this message translates to:
  /// **'Children\'s Clothing'**
  String get categoryTaxonomyExpenseFamilyChildrensClothingName;

  /// No description provided for @categoryTaxonomyExpenseFamilyBabySuppliesName.
  ///
  /// In en, this message translates to:
  /// **'Baby Supplies'**
  String get categoryTaxonomyExpenseFamilyBabySuppliesName;

  /// No description provided for @categoryTaxonomyExpenseFamilyToysName.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get categoryTaxonomyExpenseFamilyToysName;

  /// No description provided for @categoryTaxonomyExpenseFamilyChildSupportName.
  ///
  /// In en, this message translates to:
  /// **'Child Support'**
  String get categoryTaxonomyExpenseFamilyChildSupportName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareClothingName.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryTaxonomyExpensePersonalCareClothingName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareShoesName.
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get categoryTaxonomyExpensePersonalCareShoesName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareCosmeticsName.
  ///
  /// In en, this message translates to:
  /// **'Cosmetics'**
  String get categoryTaxonomyExpensePersonalCareCosmeticsName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareJewelryName.
  ///
  /// In en, this message translates to:
  /// **'Jewelry'**
  String get categoryTaxonomyExpensePersonalCareJewelryName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareHaircareName.
  ///
  /// In en, this message translates to:
  /// **'Haircare'**
  String get categoryTaxonomyExpensePersonalCareHaircareName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareNailCareName.
  ///
  /// In en, this message translates to:
  /// **'Nail Care'**
  String get categoryTaxonomyExpensePersonalCareNailCareName;

  /// No description provided for @categoryTaxonomyExpensePersonalCarePersonalHygieneName.
  ///
  /// In en, this message translates to:
  /// **'Personal Hygiene'**
  String get categoryTaxonomyExpensePersonalCarePersonalHygieneName;

  /// No description provided for @categoryTaxonomyExpensePersonalCareContactLensesName.
  ///
  /// In en, this message translates to:
  /// **'Contact Lenses'**
  String get categoryTaxonomyExpensePersonalCareContactLensesName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleMoviesName.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleMoviesName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleTheatreName.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleTheatreName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleConcertsName.
  ///
  /// In en, this message translates to:
  /// **'Concerts'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleConcertsName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleGamingName.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleGamingName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName.
  ///
  /// In en, this message translates to:
  /// **'Streaming Subscriptions'**
  String
  get categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleMusicName.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleMusicName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleBooksName.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleBooksName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName.
  ///
  /// In en, this message translates to:
  /// **'Hobbies'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleTravelName.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleTravelName;

  /// No description provided for @categoryTaxonomyExpenseEntertainmentLifestyleHotelsName.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get categoryTaxonomyExpenseEntertainmentLifestyleHotelsName;

  /// No description provided for @categoryTaxonomyExpenseEducationCoursesName.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get categoryTaxonomyExpenseEducationCoursesName;

  /// No description provided for @categoryTaxonomyExpenseEducationOnlineLearningName.
  ///
  /// In en, this message translates to:
  /// **'Online Learning'**
  String get categoryTaxonomyExpenseEducationOnlineLearningName;

  /// No description provided for @categoryTaxonomyExpenseEducationUniversityTuitionName.
  ///
  /// In en, this message translates to:
  /// **'University Tuition'**
  String get categoryTaxonomyExpenseEducationUniversityTuitionName;

  /// No description provided for @categoryTaxonomyExpenseEducationCertificationsName.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get categoryTaxonomyExpenseEducationCertificationsName;

  /// No description provided for @categoryTaxonomyExpenseEducationConferencesName.
  ///
  /// In en, this message translates to:
  /// **'Conferences'**
  String get categoryTaxonomyExpenseEducationConferencesName;

  /// No description provided for @categoryTaxonomyExpenseEducationLanguageCoursesName.
  ///
  /// In en, this message translates to:
  /// **'Language Courses'**
  String get categoryTaxonomyExpenseEducationLanguageCoursesName;

  /// No description provided for @categoryTaxonomyExpenseEducationEducationalMaterialsName.
  ///
  /// In en, this message translates to:
  /// **'Educational Materials'**
  String get categoryTaxonomyExpenseEducationEducationalMaterialsName;

  /// No description provided for @categoryTaxonomyExpenseFinanceBankFeesName.
  ///
  /// In en, this message translates to:
  /// **'Bank Fees'**
  String get categoryTaxonomyExpenseFinanceBankFeesName;

  /// No description provided for @categoryTaxonomyExpenseFinanceAtmFeesName.
  ///
  /// In en, this message translates to:
  /// **'ATM Fees'**
  String get categoryTaxonomyExpenseFinanceAtmFeesName;

  /// No description provided for @categoryTaxonomyExpenseFinanceCreditCardPaymentName.
  ///
  /// In en, this message translates to:
  /// **'Credit Card Payment'**
  String get categoryTaxonomyExpenseFinanceCreditCardPaymentName;

  /// No description provided for @categoryTaxonomyExpenseFinanceLoanPaymentName.
  ///
  /// In en, this message translates to:
  /// **'Loan Payment'**
  String get categoryTaxonomyExpenseFinanceLoanPaymentName;

  /// No description provided for @categoryTaxonomyExpenseFinanceDebtRepaymentName.
  ///
  /// In en, this message translates to:
  /// **'Debt Repayment'**
  String get categoryTaxonomyExpenseFinanceDebtRepaymentName;

  /// No description provided for @categoryTaxonomyExpenseFinanceSavingsName.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get categoryTaxonomyExpenseFinanceSavingsName;

  /// No description provided for @categoryTaxonomyExpenseFinanceEmergencyFundName.
  ///
  /// In en, this message translates to:
  /// **'Emergency Fund'**
  String get categoryTaxonomyExpenseFinanceEmergencyFundName;

  /// No description provided for @categoryTaxonomyExpenseFinanceTfsaContributionName.
  ///
  /// In en, this message translates to:
  /// **'TFSA Contribution'**
  String get categoryTaxonomyExpenseFinanceTfsaContributionName;

  /// No description provided for @categoryTaxonomyExpenseFinanceRrspContributionName.
  ///
  /// In en, this message translates to:
  /// **'RRSP Contribution'**
  String get categoryTaxonomyExpenseFinanceRrspContributionName;

  /// No description provided for @categoryTaxonomyExpenseFinanceRespContributionName.
  ///
  /// In en, this message translates to:
  /// **'RESP Contribution'**
  String get categoryTaxonomyExpenseFinanceRespContributionName;

  /// No description provided for @categoryTaxonomyExpenseFinanceInvestmentsName.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get categoryTaxonomyExpenseFinanceInvestmentsName;

  /// No description provided for @categoryTaxonomyExpenseFinanceCurrencyExchangeName.
  ///
  /// In en, this message translates to:
  /// **'Currency Exchange'**
  String get categoryTaxonomyExpenseFinanceCurrencyExchangeName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentIncomeTaxName.
  ///
  /// In en, this message translates to:
  /// **'Income Tax'**
  String get categoryTaxonomyExpenseGovernmentIncomeTaxName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentDriverLicenceName.
  ///
  /// In en, this message translates to:
  /// **'Driver Licence'**
  String get categoryTaxonomyExpenseGovernmentDriverLicenceName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentPassportName.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get categoryTaxonomyExpenseGovernmentPassportName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentImmigrationFeesName.
  ///
  /// In en, this message translates to:
  /// **'Immigration Fees'**
  String get categoryTaxonomyExpenseGovernmentImmigrationFeesName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentPermitsName.
  ///
  /// In en, this message translates to:
  /// **'Permits'**
  String get categoryTaxonomyExpenseGovernmentPermitsName;

  /// No description provided for @categoryTaxonomyExpenseGovernmentGovernmentServicesName.
  ///
  /// In en, this message translates to:
  /// **'Government Services'**
  String get categoryTaxonomyExpenseGovernmentGovernmentServicesName;

  /// No description provided for @categoryTaxonomyExpensePetsPetFoodName.
  ///
  /// In en, this message translates to:
  /// **'Pet Food'**
  String get categoryTaxonomyExpensePetsPetFoodName;

  /// No description provided for @categoryTaxonomyExpensePetsVeterinaryName.
  ///
  /// In en, this message translates to:
  /// **'Veterinary'**
  String get categoryTaxonomyExpensePetsVeterinaryName;

  /// No description provided for @categoryTaxonomyExpensePetsPetMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Pet Medicine'**
  String get categoryTaxonomyExpensePetsPetMedicineName;

  /// No description provided for @categoryTaxonomyExpensePetsPetInsuranceName.
  ///
  /// In en, this message translates to:
  /// **'Pet Insurance'**
  String get categoryTaxonomyExpensePetsPetInsuranceName;

  /// No description provided for @categoryTaxonomyExpensePetsGroomingName.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get categoryTaxonomyExpensePetsGroomingName;

  /// No description provided for @categoryTaxonomyExpensePetsPetSuppliesName.
  ///
  /// In en, this message translates to:
  /// **'Pet Supplies'**
  String get categoryTaxonomyExpensePetsPetSuppliesName;

  /// No description provided for @categoryTaxonomyExpenseGivingGiftsName.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryTaxonomyExpenseGivingGiftsName;

  /// No description provided for @categoryTaxonomyExpenseGivingTitheName.
  ///
  /// In en, this message translates to:
  /// **'Tithe'**
  String get categoryTaxonomyExpenseGivingTitheName;

  /// No description provided for @categoryTaxonomyExpenseGivingCharityName.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get categoryTaxonomyExpenseGivingCharityName;

  /// No description provided for @categoryTaxonomyExpenseGivingDonationsName.
  ///
  /// In en, this message translates to:
  /// **'Donations'**
  String get categoryTaxonomyExpenseGivingDonationsName;

  /// No description provided for @categoryTaxonomyExpenseGivingHolidayExpensesName.
  ///
  /// In en, this message translates to:
  /// **'Holiday Expenses'**
  String get categoryTaxonomyExpenseGivingHolidayExpensesName;

  /// No description provided for @categoryTaxonomyExpenseWorkOfficeSuppliesName.
  ///
  /// In en, this message translates to:
  /// **'Office Supplies'**
  String get categoryTaxonomyExpenseWorkOfficeSuppliesName;

  /// No description provided for @categoryTaxonomyExpenseWorkSoftwareName.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get categoryTaxonomyExpenseWorkSoftwareName;

  /// No description provided for @categoryTaxonomyExpenseWorkEquipmentName.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get categoryTaxonomyExpenseWorkEquipmentName;

  /// No description provided for @categoryTaxonomyExpenseWorkBusinessTravelName.
  ///
  /// In en, this message translates to:
  /// **'Business Travel'**
  String get categoryTaxonomyExpenseWorkBusinessTravelName;

  /// No description provided for @categoryTaxonomyExpenseWorkProfessionalMembershipsName.
  ///
  /// In en, this message translates to:
  /// **'Professional Memberships'**
  String get categoryTaxonomyExpenseWorkProfessionalMembershipsName;

  /// No description provided for @categoryTaxonomyExpenseWorkLicencesName.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get categoryTaxonomyExpenseWorkLicencesName;

  /// No description provided for @categoryTaxonomyExpenseOtherCashWithdrawalName.
  ///
  /// In en, this message translates to:
  /// **'Cash Withdrawal'**
  String get categoryTaxonomyExpenseOtherCashWithdrawalName;

  /// No description provided for @categoryTaxonomyExpenseOtherAdjustmentName.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get categoryTaxonomyExpenseOtherAdjustmentName;

  /// No description provided for @categoryTaxonomyExpenseOtherUncategorizedName.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get categoryTaxonomyExpenseOtherUncategorizedName;

  /// No description provided for @categoryTaxonomyIncomeEmploymentSalaryName.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categoryTaxonomyIncomeEmploymentSalaryName;

  /// No description provided for @categoryTaxonomyIncomeEmploymentBonusName.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get categoryTaxonomyIncomeEmploymentBonusName;

  /// No description provided for @categoryTaxonomyIncomeEmploymentOvertimeName.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get categoryTaxonomyIncomeEmploymentOvertimeName;

  /// No description provided for @categoryTaxonomyIncomeEmploymentCommissionName.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get categoryTaxonomyIncomeEmploymentCommissionName;

  /// No description provided for @categoryTaxonomyIncomeEmploymentTipsName.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get categoryTaxonomyIncomeEmploymentTipsName;

  /// No description provided for @categoryTaxonomyIncomeBusinessBusinessIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Business Income'**
  String get categoryTaxonomyIncomeBusinessBusinessIncomeName;

  /// No description provided for @categoryTaxonomyIncomeBusinessFreelanceName.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get categoryTaxonomyIncomeBusinessFreelanceName;

  /// No description provided for @categoryTaxonomyIncomeBusinessConsultingName.
  ///
  /// In en, this message translates to:
  /// **'Consulting'**
  String get categoryTaxonomyIncomeBusinessConsultingName;

  /// No description provided for @categoryTaxonomyIncomeBusinessRentalIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Rental Income'**
  String get categoryTaxonomyIncomeBusinessRentalIncomeName;

  /// No description provided for @categoryTaxonomyIncomeInvestmentsInterestIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Interest Income'**
  String get categoryTaxonomyIncomeInvestmentsInterestIncomeName;

  /// No description provided for @categoryTaxonomyIncomeInvestmentsDividendIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Dividend Income'**
  String get categoryTaxonomyIncomeInvestmentsDividendIncomeName;

  /// No description provided for @categoryTaxonomyIncomeInvestmentsCapitalGainsName.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get categoryTaxonomyIncomeInvestmentsCapitalGainsName;

  /// No description provided for @categoryTaxonomyIncomeInvestmentsInvestmentDistributionName.
  ///
  /// In en, this message translates to:
  /// **'Investment Distribution'**
  String get categoryTaxonomyIncomeInvestmentsInvestmentDistributionName;

  /// No description provided for @categoryTaxonomyIncomeGovernmentTaxRefundName.
  ///
  /// In en, this message translates to:
  /// **'Tax Refund'**
  String get categoryTaxonomyIncomeGovernmentTaxRefundName;

  /// No description provided for @categoryTaxonomyIncomeGovernmentGovernmentBenefitsName.
  ///
  /// In en, this message translates to:
  /// **'Government Benefits'**
  String get categoryTaxonomyIncomeGovernmentGovernmentBenefitsName;

  /// No description provided for @categoryTaxonomyIncomeGovernmentPensionName.
  ///
  /// In en, this message translates to:
  /// **'Pension'**
  String get categoryTaxonomyIncomeGovernmentPensionName;

  /// No description provided for @categoryTaxonomyIncomeGovernmentChildBenefitName.
  ///
  /// In en, this message translates to:
  /// **'Child Benefit'**
  String get categoryTaxonomyIncomeGovernmentChildBenefitName;

  /// No description provided for @categoryTaxonomyIncomeGovernmentEmploymentInsuranceName.
  ///
  /// In en, this message translates to:
  /// **'Employment Insurance'**
  String get categoryTaxonomyIncomeGovernmentEmploymentInsuranceName;

  /// No description provided for @categoryTaxonomyIncomeGiftsGiftReceivedName.
  ///
  /// In en, this message translates to:
  /// **'Gift Received'**
  String get categoryTaxonomyIncomeGiftsGiftReceivedName;

  /// No description provided for @categoryTaxonomyIncomeGiftsFamilySupportName.
  ///
  /// In en, this message translates to:
  /// **'Family Support'**
  String get categoryTaxonomyIncomeGiftsFamilySupportName;

  /// No description provided for @categoryTaxonomyIncomeGiftsCashbackName.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get categoryTaxonomyIncomeGiftsCashbackName;

  /// No description provided for @categoryTaxonomyIncomeGiftsRewardsName.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get categoryTaxonomyIncomeGiftsRewardsName;

  /// No description provided for @categoryTaxonomyIncomeOtherIncomeRefundName.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get categoryTaxonomyIncomeOtherIncomeRefundName;

  /// No description provided for @categoryTaxonomyIncomeOtherIncomeReimbursementName.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get categoryTaxonomyIncomeOtherIncomeReimbursementName;

  /// No description provided for @categoryTaxonomyIncomeOtherIncomeSaleOfItemName.
  ///
  /// In en, this message translates to:
  /// **'Sale of Item'**
  String get categoryTaxonomyIncomeOtherIncomeSaleOfItemName;

  /// No description provided for @categoryTaxonomyIncomeOtherIncomeOtherIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get categoryTaxonomyIncomeOtherIncomeOtherIncomeName;

  /// No description provided for @operationExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get operationExpense;

  /// No description provided for @operationIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get operationIncome;

  /// No description provided for @operationTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get operationTransfer;

  /// No description provided for @operationCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operationCreateTitle;

  /// No description provided for @operationAddExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get operationAddExpenseTitle;

  /// No description provided for @operationAddIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get operationAddIncomeTitle;

  /// No description provided for @operationEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit operation'**
  String get operationEditTitle;

  /// No description provided for @operationNameHint.
  ///
  /// In en, this message translates to:
  /// **'Operation name'**
  String get operationNameHint;

  /// No description provided for @operationDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get operationDate;

  /// No description provided for @operationNextDate.
  ///
  /// In en, this message translates to:
  /// **'Next operation date'**
  String get operationNextDate;

  /// No description provided for @operationAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get operationAmountHint;

  /// No description provided for @operationChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get operationChooseCategory;

  /// No description provided for @operationCategoryPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories available.'**
  String get operationCategoryPickerEmpty;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @operationArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete operation?'**
  String get operationArchiveTitle;

  /// No description provided for @operationArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'This operation will be archived and hidden from your list.'**
  String get operationArchiveMessage;

  /// No description provided for @operationArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get operationArchiveConfirm;

  /// No description provided for @operationsInteractionHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit · Swipe left to delete'**
  String get operationsInteractionHint;

  /// No description provided for @operationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any income or expenses yet.\nTap + to add your first operation.'**
  String get operationsEmptyMessage;

  /// No description provided for @operationsEmptyMonthMessage.
  ///
  /// In en, this message translates to:
  /// **'No operations in {month}.'**
  String operationsEmptyMonthMessage(String month);

  /// No description provided for @operationsPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get operationsPreviousMonth;

  /// No description provided for @operationsNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get operationsNextMonth;

  /// No description provided for @operationsPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick month'**
  String get operationsPickMonth;

  /// No description provided for @operationsMonthNavigatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected month: {month}'**
  String operationsMonthNavigatorLabel(String month);

  /// No description provided for @operationRecurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'No recurrence'**
  String get operationRecurrenceNone;

  /// No description provided for @operationRecurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get operationRecurrenceDaily;

  /// No description provided for @operationRecurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get operationRecurrenceWeekly;

  /// No description provided for @operationRecurrenceBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get operationRecurrenceBiweekly;

  /// No description provided for @operationRecurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get operationRecurrenceMonthly;

  /// No description provided for @operationRecurrenceYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get operationRecurrenceYearly;

  /// No description provided for @operationRecurrenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get operationRecurrenceTitle;

  /// No description provided for @operationDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get operationDescriptionHint;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get commonSaving;

  /// No description provided for @operationAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get operationAmountRequired;

  /// No description provided for @operationCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get operationCategoryRequired;

  /// No description provided for @accountsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any accounts yet.\nConnect a bank to show your accounts.'**
  String get accountsEmptyMessage;

  /// No description provided for @accountsConnectBank.
  ///
  /// In en, this message translates to:
  /// **'Connect bank'**
  String get accountsConnectBank;

  /// No description provided for @accountsDuplicateConnectionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Account already connected'**
  String get accountsDuplicateConnectionDialogTitle;

  /// No description provided for @accountsDuplicateConnectionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Plaid successfully verified access to your bank, but this bank account is already connected to Ophir. To prevent duplicate transactions and inaccurate calculations, we didn\'t add it again. You can continue using the existing account or connect a different one.'**
  String get accountsDuplicateConnectionDialogBody;

  /// No description provided for @accountsDuplicateConnectionDialogAction.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get accountsDuplicateConnectionDialogAction;

  /// No description provided for @accountsInstitutionAccountCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} accounts}}'**
  String accountsInstitutionAccountCount(int count);

  /// No description provided for @accountsFinancialParticipationIncludedStatus.
  ///
  /// In en, this message translates to:
  /// **'Included in finances'**
  String get accountsFinancialParticipationIncludedStatus;

  /// No description provided for @accountsFinancialParticipationExcludedStatus.
  ///
  /// In en, this message translates to:
  /// **'Excluded from finances'**
  String get accountsFinancialParticipationExcludedStatus;

  /// No description provided for @accountsFinancialExclusionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exclude from finances?'**
  String get accountsFinancialExclusionDialogTitle;

  /// No description provided for @accountsFinancialExclusionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This account will stay connected and continue updating, but its balance and transactions won\'t be included in financial calculations, reports, and advice.'**
  String get accountsFinancialExclusionDialogBody;

  /// No description provided for @accountsFinancialExclusionDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountsFinancialExclusionDialogCancel;

  /// No description provided for @accountsFinancialExclusionDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Don\'t include'**
  String get accountsFinancialExclusionDialogConfirm;

  /// No description provided for @accountsBankMenuSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get accountsBankMenuSync;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get dashboardWelcome;

  /// No description provided for @dashboardHeaderGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboardHeaderGreetingMorning;

  /// No description provided for @dashboardHeaderGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboardHeaderGreetingAfternoon;

  /// No description provided for @dashboardHeaderGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboardHeaderGreetingEvening;

  /// No description provided for @dashboardHeaderGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get dashboardHeaderGreetingNight;

  /// No description provided for @budgetSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Planning'**
  String get budgetSetupTitle;

  /// No description provided for @budgetSetupStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {currentStep} of {totalSteps}'**
  String budgetSetupStepProgress(int currentStep, int totalSteps);

  /// No description provided for @budgetSetupFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get budgetSetupFinish;

  /// No description provided for @budgetSetupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save budget setup.'**
  String get budgetSetupSaveError;

  /// No description provided for @budgetHouseholdTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get budgetHouseholdTitle;

  /// No description provided for @budgetAdultsCount.
  ///
  /// In en, this message translates to:
  /// **'Number of adults'**
  String get budgetAdultsCount;

  /// No description provided for @budgetChildrenCount.
  ///
  /// In en, this message translates to:
  /// **'Number of children'**
  String get budgetChildrenCount;

  /// No description provided for @budgetContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get budgetContinue;

  /// No description provided for @budgetRequiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get budgetRequiredField;

  /// No description provided for @budgetInvalidNonNegativeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get budgetInvalidNonNegativeAmount;

  /// No description provided for @budgetSetupLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load budget setup.'**
  String get budgetSetupLoadError;

  /// No description provided for @budgetSetupDraftLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load budget setup draft.'**
  String get budgetSetupDraftLoadError;

  /// No description provided for @budgetRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get budgetRetry;

  /// No description provided for @budgetTitheDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get budgetTitheDisabled;

  /// No description provided for @budgetTitheSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable tithe'**
  String get budgetTitheSwitchLabel;

  /// No description provided for @budgetTitheSwitchValueEnabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get budgetTitheSwitchValueEnabled;

  /// No description provided for @budgetTitheSwitchValueDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get budgetTitheSwitchValueDisabled;

  /// No description provided for @budgetMandatoryExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Mandatory expenses'**
  String get budgetMandatoryExpensesTitle;

  /// No description provided for @budgetExpenseNotFilled.
  ///
  /// In en, this message translates to:
  /// **'Not filled'**
  String get budgetExpenseNotFilled;

  /// No description provided for @budgetExpenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get budgetExpenseAmount;

  /// No description provided for @budgetExpenseFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get budgetExpenseFrequency;

  /// No description provided for @budgetExpenseNextDueDate.
  ///
  /// In en, this message translates to:
  /// **'Next due date'**
  String get budgetExpenseNextDueDate;

  /// No description provided for @budgetDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get budgetDebtTitle;

  /// No description provided for @budgetDebtAdd.
  ///
  /// In en, this message translates to:
  /// **'Add debt'**
  String get budgetDebtAdd;

  /// No description provided for @budgetDebtName.
  ///
  /// In en, this message translates to:
  /// **'Debt name'**
  String get budgetDebtName;

  /// No description provided for @budgetDebtType.
  ///
  /// In en, this message translates to:
  /// **'Debt type'**
  String get budgetDebtType;

  /// No description provided for @budgetDebtPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment amount'**
  String get budgetDebtPaymentAmount;

  /// No description provided for @budgetDebtNextDueDate.
  ///
  /// In en, this message translates to:
  /// **'Next due date'**
  String get budgetDebtNextDueDate;

  /// No description provided for @budgetIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get budgetIncomeTitle;

  /// No description provided for @budgetIncomeEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Income source'**
  String get budgetIncomeEditorTitle;

  /// No description provided for @budgetIncomeName.
  ///
  /// In en, this message translates to:
  /// **'Income source name'**
  String get budgetIncomeName;

  /// No description provided for @budgetIncomeType.
  ///
  /// In en, this message translates to:
  /// **'Income type'**
  String get budgetIncomeType;

  /// No description provided for @budgetIncomeCategory.
  ///
  /// In en, this message translates to:
  /// **'Income category'**
  String get budgetIncomeCategory;

  /// No description provided for @budgetIncomeSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select income category'**
  String get budgetIncomeSelectCategory;

  /// No description provided for @budgetIncomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Income amount'**
  String get budgetIncomeAmount;

  /// No description provided for @budgetIncomeFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get budgetIncomeFrequency;

  /// No description provided for @budgetIncomeNextDate.
  ///
  /// In en, this message translates to:
  /// **'Next income date'**
  String get budgetIncomeNextDate;

  /// No description provided for @budgetIncomeAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add income source'**
  String get budgetIncomeAddSource;

  /// No description provided for @budgetIncomeRemoveSource.
  ///
  /// In en, this message translates to:
  /// **'Remove income source'**
  String get budgetIncomeRemoveSource;

  /// No description provided for @budgetFrequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get budgetFrequencyDaily;

  /// No description provided for @budgetFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get budgetFrequencyWeekly;

  /// No description provided for @budgetFrequencyBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get budgetFrequencyBiweekly;

  /// No description provided for @budgetFrequencySemiMonthly.
  ///
  /// In en, this message translates to:
  /// **'Twice a month'**
  String get budgetFrequencySemiMonthly;

  /// No description provided for @budgetFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get budgetFrequencyMonthly;

  /// No description provided for @budgetFrequencyEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every N months'**
  String get budgetFrequencyEveryNMonths;

  /// No description provided for @budgetFrequencyTimesPerYear.
  ///
  /// In en, this message translates to:
  /// **'Times per year'**
  String get budgetFrequencyTimesPerYear;

  /// No description provided for @budgetFrequencyYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get budgetFrequencyYearly;

  /// No description provided for @budgetFrequencyIrregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular'**
  String get budgetFrequencyIrregular;

  /// No description provided for @budgetFrequencyInterval.
  ///
  /// In en, this message translates to:
  /// **'Frequency interval'**
  String get budgetFrequencyInterval;

  /// No description provided for @budgetTimesPerYear.
  ///
  /// In en, this message translates to:
  /// **'Times per year'**
  String get budgetTimesPerYear;

  /// No description provided for @budgetBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get budgetBack;

  /// No description provided for @budgetMandatoryExpensesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Mandatory expenses will be added in the next step.'**
  String get budgetMandatoryExpensesPlaceholder;

  /// No description provided for @operationsReviewBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 to categorize} other{{count} to categorize}}'**
  String operationsReviewBanner(int count);

  /// No description provided for @operationsReviewFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No operations need categorization in this month.'**
  String get operationsReviewFilterEmpty;

  /// No description provided for @operationNeedsCategorizationBadge.
  ///
  /// In en, this message translates to:
  /// **'Needs category'**
  String get operationNeedsCategorizationBadge;

  /// No description provided for @operationPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get operationPendingBadge;

  /// No description provided for @operationCategorySuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get operationCategorySuggestions;

  /// No description provided for @categoryRuleRememberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remember this category?'**
  String get categoryRuleRememberTitle;

  /// No description provided for @categoryRuleRememberMessage.
  ///
  /// In en, this message translates to:
  /// **'Remember this category for future similar operations from this merchant?'**
  String categoryRuleRememberMessage(String merchant, String category);

  /// No description provided for @categoryRuleRememberOnlyThis.
  ///
  /// In en, this message translates to:
  /// **'Only this one'**
  String get categoryRuleRememberOnlyThis;

  /// No description provided for @categoryRuleRememberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remember'**
  String get categoryRuleRememberConfirm;

  /// No description provided for @categoryRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Category rules'**
  String get categoryRulesTitle;

  /// No description provided for @categoryRulesSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved merchant categories'**
  String get categoryRulesSettingsSubtitle;

  /// No description provided for @categoryRulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved rules yet. Categorize a bank transaction and choose Remember.'**
  String get categoryRulesEmpty;

  /// No description provided for @dashboardCategorizationActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Review transactions'**
  String get dashboardCategorizationActionTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
