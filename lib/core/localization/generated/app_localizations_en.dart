// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authWelcome => 'Welcome to Ophir';

  @override
  String get authSubtitle => 'Smart finance.\nAll your finances in one app.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOr => 'or';

  @override
  String get authEmailHint => 'Enter your email';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authContinue => 'Continue';

  @override
  String get authNoAccount => 'Don’t have an account?';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authTermsPrefix => 'By continuing, you agree to our';

  @override
  String get authTermsOfUse => 'Terms of Use';

  @override
  String get authAnd => 'and';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authComingSoon => 'Coming soon';

  @override
  String get authCheckEmail => 'Check your email inbox.';

  @override
  String get authUserNotFound => 'No account found for this email.';

  @override
  String get authPasswordRequired => 'Password is required.';

  @override
  String get authUnknownError => 'Something went wrong. Please try again.';

  @override
  String get authGoogleFailed => 'Google sign-in failed.';

  @override
  String get authServerError => 'Authentication failed. Please try again.';

  @override
  String get authEmailSuggestion => 'Did you mean';

  @override
  String get authRateLimited =>
      'Too many email requests. Please wait a few minutes and try again.';

  @override
  String get emailValidationEmpty => 'Email is required.';

  @override
  String get emailValidationContainsSpaces => 'Email must not contain spaces.';

  @override
  String get emailValidationMissingAt => 'Email must contain \'@\'.';

  @override
  String get emailValidationMultipleAt => 'Email must contain only one \'@\'.';

  @override
  String get emailValidationMissingLocalPart => 'Enter the part before \'@\'.';

  @override
  String get emailValidationMissingDomain => 'Enter the email domain.';

  @override
  String get emailValidationLocalStartsWithDot =>
      'The local part must not start with \'.\'.';

  @override
  String get emailValidationLocalEndsWithDot =>
      'The local part must not end with \'.\'.';

  @override
  String get emailValidationLocalHasConsecutiveDots =>
      'The local part must not contain consecutive dots.';

  @override
  String get emailValidationDomainStartsWithDot =>
      'The domain must not start with \'.\'.';

  @override
  String get emailValidationDomainEndsWithDot =>
      'The domain must not end with \'.\'.';

  @override
  String get emailValidationDomainHasConsecutiveDots =>
      'The domain must not contain consecutive dots.';

  @override
  String get emailValidationDomainMissingDot =>
      'The domain must contain a \'.\'.';

  @override
  String get emailValidationInvalidTopLevelDomain =>
      'Invalid top-level domain.';

  @override
  String get emailValidationTopLevelDomainTooShort =>
      'Top-level domain is too short.';

  @override
  String get emailValidationInvalidLocalCharacters =>
      'Invalid characters in the local part.';

  @override
  String get emailValidationInvalidDomainCharacters =>
      'Invalid characters in the domain.';

  @override
  String get emailValidationDomainLabelStartsWithHyphen =>
      'A domain label must not start with \'-\'.';

  @override
  String get emailValidationDomainLabelEndsWithHyphen =>
      'A domain label must not end with \'-\'.';

  @override
  String get emailValidationLocalPartTooLong => 'The local part is too long.';

  @override
  String get emailValidationDomainTooLong => 'The domain is too long.';

  @override
  String get emailValidationEmailTooLong => 'The email address is too long.';

  @override
  String get emailValidationInvalidFormat => 'Invalid email format.';

  @override
  String get passwordValidationEmpty => 'Password is required.';

  @override
  String get passwordValidationContainsSpaces =>
      'Password must not contain spaces.';

  @override
  String get passwordValidationTooShort =>
      'Password must be at least 8 characters.';

  @override
  String get passwordValidationTooLong =>
      'Password must be no more than 128 characters.';

  @override
  String get passwordValidationMissingLetter =>
      'Password must contain at least one letter.';

  @override
  String get passwordValidationMissingNumber =>
      'Password must contain at least one number.';

  @override
  String get passwordValidationMissingSpecialCharacter =>
      'Password must contain at least one special character.';

  @override
  String get passwordValidationMissingLowercaseLetter =>
      'Password must contain at least one lowercase letter.';

  @override
  String get passwordValidationMissingUppercaseLetter =>
      'Password must contain at least one uppercase letter.';

  @override
  String get passwordRequirementMinLength => 'At least 8 characters';

  @override
  String get passwordRequirementMaxLength => 'No more than 128 characters';

  @override
  String get passwordRequirementNoSpaces => 'No spaces';

  @override
  String get passwordRequirementLowercase => 'One lowercase letter';

  @override
  String get passwordRequirementUppercase => 'One uppercase letter';

  @override
  String get passwordRequirementNumber => 'One number';

  @override
  String get passwordRequirementSpecial => 'One special character';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthMedium => 'Medium';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get failureUnauthorized => 'Please sign in to continue.';

  @override
  String get failureNotFound => 'The requested data was not found.';

  @override
  String get failureValidation => 'Please check the entered data.';

  @override
  String get failureDatabase => 'A database error occurred.';

  @override
  String get failureNetwork => 'Network error. Please check your connection.';

  @override
  String get failureUnknown => 'Something went wrong.';

  @override
  String get navigationHome => 'Home';

  @override
  String get navigationAccounts => 'Accounts';

  @override
  String get navigationTransactions => 'Transactions';

  @override
  String get navigationStatistics => 'Stats';

  @override
  String get navigationSettings => 'Settings';

  @override
  String get dashboardGreeting => 'Today';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'GENERAL';

  @override
  String get settingsSectionData => 'DATA';

  @override
  String get settingsSectionSecurity => 'SECURITY';

  @override
  String get settingsSectionAbout => 'ABOUT';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Theme and display preferences';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Manage notification preferences';

  @override
  String get settingsAccountsSubtitle => 'Manage accounts and balances';

  @override
  String get settingsCategoriesTitle => 'Categories';

  @override
  String get settingsCategoriesSubtitle =>
      'Organize income and expense categories';

  @override
  String get settingsSecurityTitle => 'Security';

  @override
  String get settingsSecuritySubtitle => 'Password and account security';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'App information and support';

  @override
  String get settingsPrivacyPolicySubtitle => 'How your data is handled';

  @override
  String get settingsTermsSubtitle => 'Rules for using Ophir';

  @override
  String get settingsOpenSourceLicensesTitle => 'Open Source Licenses';

  @override
  String get settingsOpenSourceLicensesSubtitle => 'Third-party notices';

  @override
  String get settingsAppVersionTitle => 'App Version';

  @override
  String get settingsAppVersionSubtitle => 'Version details';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get navigationProfile => 'Profile';

  @override
  String get profileCurrency => 'Currency';

  @override
  String get profileTimezone => 'Timezone';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get dashboardGoodMorning => 'Good morning';

  @override
  String get navigationOperations => 'Operations';

  @override
  String get operationsTitle => 'Operations';

  @override
  String get dashboardGreetingMorning => 'Good morning';

  @override
  String get dashboardGreetingAfternoon => 'Good afternoon';

  @override
  String get dashboardGreetingEvening => 'Good evening';

  @override
  String get dashboardGreetingNight => 'Good night';

  @override
  String get profileNameMissing => 'Add your name';

  @override
  String get profileEditTitle => 'Profile';

  @override
  String get profileEditSubtitle => 'Manage your name, photo and information';

  @override
  String get profileSecurityTitle => 'Security';

  @override
  String get profileSecuritySubtitle => 'Password and account security';

  @override
  String get profileNotificationsTitle => 'Notifications';

  @override
  String get profileNotificationsSubtitle => 'Manage notification preferences';

  @override
  String get profileAppearanceTitle => 'Appearance';

  @override
  String get profileAppearanceSubtitle => 'Theme and display preferences';

  @override
  String get commonSave => 'Save';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileFullNameHint => 'Enter your name';

  @override
  String get profileFullNameRequired => 'Name is required.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get categoryRent => 'Rent';

  @override
  String get categoryMortgage => 'Mortgage';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categoryGroceries => 'Groceries';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryCoffee => 'Coffee';

  @override
  String get categoryFuel => 'Fuel';

  @override
  String get categoryPublicTransit => 'Public transit';

  @override
  String get categoryCar => 'Car';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryPharmacy => 'Pharmacy';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categorySubscriptions => 'Subscriptions';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryDebtPayment => 'Debt payment';

  @override
  String get categoryBankFees => 'Bank fees';

  @override
  String get categorySavings => 'Savings';

  @override
  String get categoryInvestments => 'Investments';

  @override
  String get categoryOtherExpense => 'Other expense';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryBusiness => 'Business';

  @override
  String get categoryBenefits => 'Benefits';

  @override
  String get categoryDividends => 'Dividends';

  @override
  String get categoryOtherIncome => 'Other income';

  @override
  String get categoryGroupHousing => 'Housing';

  @override
  String get categoryGroupFood => 'Food';

  @override
  String get categoryGroupTransport => 'Transport';

  @override
  String get categoryGroupHealth => 'Health';

  @override
  String get categoryGroupLifestyle => 'Lifestyle';

  @override
  String get categoryGroupFinance => 'Finance';

  @override
  String get categoryGroupSalary => 'Salary';

  @override
  String get categoryGroupBusiness => 'Business';

  @override
  String get categoryGroupBenefits => 'Benefits';

  @override
  String get categoryGroupInvestments => 'Investments';

  @override
  String get categoryGroupOther => 'Other';

  @override
  String get categoryExampleDefault => 'Ex. Operation detail';

  @override
  String get categoryExampleRent => 'Ex. July rent';

  @override
  String get categoryExampleMortgage => 'Ex. Mortgage payment';

  @override
  String get categoryExampleUtilities => 'Ex. Electricity bill';

  @override
  String get categoryExampleInsurance => 'Ex. Home insurance';

  @override
  String get categoryExampleGroceries => 'Ex. Costco';

  @override
  String get categoryExampleRestaurants => 'Ex. Restaurant';

  @override
  String get categoryExampleCoffee => 'Ex. Starbucks';

  @override
  String get categoryExampleFuel => 'Ex. Gas';

  @override
  String get categoryExamplePublicTransit => 'Ex. Bus pass';

  @override
  String get categoryExampleCar => 'Ex. Car maintenance';

  @override
  String get categoryExampleHealth => 'Ex. Doctor visit';

  @override
  String get categoryExamplePharmacy => 'Ex. Pharmacy';

  @override
  String get categoryExampleShopping => 'Ex. Amazon';

  @override
  String get categoryExampleEntertainment => 'Ex. Movie ticket';

  @override
  String get categoryExampleSubscriptions => 'Ex. Netflix';

  @override
  String get categoryExampleTravel => 'Ex. Flight ticket';

  @override
  String get categoryExampleEducation => 'Ex. Course';

  @override
  String get categoryExampleDebtPayment => 'Ex. Credit card payment';

  @override
  String get categoryExampleBankFees => 'Ex. Bank fee';

  @override
  String get categoryExampleSavings => 'Ex. Monthly savings';

  @override
  String get categoryExampleInvestments => 'Ex. Wealthsimple';

  @override
  String get categoryExampleOtherExpense => 'Ex. Other expense';

  @override
  String get categoryExampleSalary => 'Ex. June salary';

  @override
  String get categoryExampleBusiness => 'Ex. Client payment';

  @override
  String get categoryExampleBenefits => 'Ex. Benefit payment';

  @override
  String get categoryExampleDividends => 'Ex. Dividends';

  @override
  String get categoryExampleOtherIncome => 'Ex. Other income';

  @override
  String get categoryGroupExpenseHousing => 'Housing';

  @override
  String get categoryGroupExpenseFood => 'Food';

  @override
  String get categoryGroupExpenseTransportation => 'Transportation';

  @override
  String get categoryGroupExpenseHealth => 'Health';

  @override
  String get categoryGroupExpenseFamily => 'Family';

  @override
  String get categoryGroupExpensePersonalCare => 'Personal Care';

  @override
  String get categoryGroupExpenseEntertainmentLifestyle =>
      'Entertainment & Lifestyle';

  @override
  String get categoryGroupExpenseEducation => 'Education';

  @override
  String get categoryGroupExpenseFinance => 'Finance';

  @override
  String get categoryGroupExpenseGovernment => 'Government';

  @override
  String get categoryGroupExpensePets => 'Pets';

  @override
  String get categoryGroupExpenseGiving => 'Giving';

  @override
  String get categoryGroupExpenseWork => 'Work';

  @override
  String get categoryGroupExpenseOther => 'Other';

  @override
  String get categoryGroupIncomeEmployment => 'Employment';

  @override
  String get categoryGroupIncomeBusiness => 'Business';

  @override
  String get categoryGroupIncomeInvestments => 'Investments';

  @override
  String get categoryGroupIncomeGovernment => 'Government';

  @override
  String get categoryGroupIncomeGifts => 'Gifts';

  @override
  String get categoryGroupIncomeOtherIncome => 'Other Income';

  @override
  String get categoryTaxonomyExpenseHousingRentName => 'Rent';

  @override
  String get categoryTaxonomyExpenseHousingMortgageName => 'Mortgage';

  @override
  String get categoryTaxonomyExpenseHousingPropertyTaxName => 'Property Tax';

  @override
  String get categoryTaxonomyExpenseHousingCondoFeesName => 'Condo Fees';

  @override
  String get categoryTaxonomyExpenseHousingElectricityName => 'Electricity';

  @override
  String get categoryTaxonomyExpenseHousingNaturalGasName => 'Natural Gas';

  @override
  String get categoryTaxonomyExpenseHousingWaterName => 'Water';

  @override
  String get categoryTaxonomyExpenseHousingSewerName => 'Sewer';

  @override
  String get categoryTaxonomyExpenseHousingGarbageCollectionName =>
      'Garbage Collection';

  @override
  String get categoryTaxonomyExpenseHousingInternetName => 'Internet';

  @override
  String get categoryTaxonomyExpenseHousingMobilePhoneName => 'Mobile Phone';

  @override
  String get categoryTaxonomyExpenseHousingHomePhoneName => 'Home Phone';

  @override
  String get categoryTaxonomyExpenseHousingHomeInsuranceName =>
      'Home Insurance';

  @override
  String get categoryTaxonomyExpenseHousingHomeMaintenanceName =>
      'Home Maintenance';

  @override
  String get categoryTaxonomyExpenseHousingFurnitureName => 'Furniture';

  @override
  String get categoryTaxonomyExpenseHousingAppliancesName => 'Appliances';

  @override
  String get categoryTaxonomyExpenseHousingHomeSuppliesName => 'Home Supplies';

  @override
  String get categoryTaxonomyExpenseHousingHomeSecurityName => 'Home Security';

  @override
  String get categoryTaxonomyExpenseFoodGroceriesName => 'Groceries';

  @override
  String get categoryTaxonomyExpenseFoodFarmersMarketName => 'Farmers Market';

  @override
  String get categoryTaxonomyExpenseFoodRestaurantName => 'Restaurant';

  @override
  String get categoryTaxonomyExpenseFoodCafeCoffeeName => 'Café & Coffee';

  @override
  String get categoryTaxonomyExpenseFoodFastFoodName => 'Fast Food';

  @override
  String get categoryTaxonomyExpenseFoodFoodDeliveryName => 'Food Delivery';

  @override
  String get categoryTaxonomyExpenseFoodSnacksName => 'Snacks';

  @override
  String get categoryTaxonomyExpenseFoodAlcoholName => 'Alcohol';

  @override
  String get categoryTaxonomyExpenseTransportationFuelName => 'Fuel';

  @override
  String get categoryTaxonomyExpenseTransportationEvChargingName =>
      'EV Charging';

  @override
  String get categoryTaxonomyExpenseTransportationPublicTransitName =>
      'Public Transit';

  @override
  String get categoryTaxonomyExpenseTransportationTaxiRideSharingName =>
      'Taxi & Ride Sharing';

  @override
  String get categoryTaxonomyExpenseTransportationParkingName => 'Parking';

  @override
  String get categoryTaxonomyExpenseTransportationTollRoadsName => 'Toll Roads';

  @override
  String get categoryTaxonomyExpenseTransportationAutoInsuranceName =>
      'Auto Insurance';

  @override
  String get categoryTaxonomyExpenseTransportationAutoLoanName => 'Auto Loan';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleMaintenanceName =>
      'Vehicle Maintenance';

  @override
  String get categoryTaxonomyExpenseTransportationTireServiceName =>
      'Tire Service';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleRegistrationName =>
      'Vehicle Registration';

  @override
  String get categoryTaxonomyExpenseTransportationCarWashName => 'Car Wash';

  @override
  String get categoryTaxonomyExpenseHealthPharmacyName => 'Pharmacy';

  @override
  String get categoryTaxonomyExpenseHealthMedicineName => 'Medicine';

  @override
  String get categoryTaxonomyExpenseHealthDoctorName => 'Doctor';

  @override
  String get categoryTaxonomyExpenseHealthDentistName => 'Dentist';

  @override
  String get categoryTaxonomyExpenseHealthVisionCareName => 'Vision Care';

  @override
  String get categoryTaxonomyExpenseHealthMedicalTestsName => 'Medical Tests';

  @override
  String get categoryTaxonomyExpenseHealthMedicalProceduresName =>
      'Medical Procedures';

  @override
  String get categoryTaxonomyExpenseHealthHealthInsuranceName =>
      'Health Insurance';

  @override
  String get categoryTaxonomyExpenseHealthMentalHealthName => 'Mental Health';

  @override
  String get categoryTaxonomyExpenseHealthPhysiotherapyName => 'Physiotherapy';

  @override
  String get categoryTaxonomyExpenseHealthGymFitnessName => 'Gym & Fitness';

  @override
  String get categoryTaxonomyExpenseHealthVitaminsName => 'Vitamins';

  @override
  String get categoryTaxonomyExpenseFamilyChildcareName => 'Childcare';

  @override
  String get categoryTaxonomyExpenseFamilyDaycareName => 'Daycare';

  @override
  String get categoryTaxonomyExpenseFamilySchoolName => 'School';

  @override
  String get categoryTaxonomyExpenseFamilyUniversityName => 'University';

  @override
  String get categoryTaxonomyExpenseFamilyTutoringName => 'Tutoring';

  @override
  String get categoryTaxonomyExpenseFamilyChildrensClothingName =>
      'Children\'s Clothing';

  @override
  String get categoryTaxonomyExpenseFamilyBabySuppliesName => 'Baby Supplies';

  @override
  String get categoryTaxonomyExpenseFamilyToysName => 'Toys';

  @override
  String get categoryTaxonomyExpenseFamilyChildSupportName => 'Child Support';

  @override
  String get categoryTaxonomyExpensePersonalCareClothingName => 'Clothing';

  @override
  String get categoryTaxonomyExpensePersonalCareShoesName => 'Shoes';

  @override
  String get categoryTaxonomyExpensePersonalCareCosmeticsName => 'Cosmetics';

  @override
  String get categoryTaxonomyExpensePersonalCareJewelryName => 'Jewelry';

  @override
  String get categoryTaxonomyExpensePersonalCareHaircareName => 'Haircare';

  @override
  String get categoryTaxonomyExpensePersonalCareNailCareName => 'Nail Care';

  @override
  String get categoryTaxonomyExpensePersonalCarePersonalHygieneName =>
      'Personal Hygiene';

  @override
  String get categoryTaxonomyExpensePersonalCareContactLensesName =>
      'Contact Lenses';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMoviesName =>
      'Movies';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTheatreName =>
      'Theatre';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleConcertsName =>
      'Concerts';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleGamingName =>
      'Gaming';

  @override
  String
  get categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName =>
      'Streaming Subscriptions';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMusicName => 'Music';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleBooksName => 'Books';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName =>
      'Hobbies';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTravelName =>
      'Travel';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHotelsName =>
      'Hotels';

  @override
  String get categoryTaxonomyExpenseEducationCoursesName => 'Courses';

  @override
  String get categoryTaxonomyExpenseEducationOnlineLearningName =>
      'Online Learning';

  @override
  String get categoryTaxonomyExpenseEducationUniversityTuitionName =>
      'University Tuition';

  @override
  String get categoryTaxonomyExpenseEducationCertificationsName =>
      'Certifications';

  @override
  String get categoryTaxonomyExpenseEducationConferencesName => 'Conferences';

  @override
  String get categoryTaxonomyExpenseEducationLanguageCoursesName =>
      'Language Courses';

  @override
  String get categoryTaxonomyExpenseEducationEducationalMaterialsName =>
      'Educational Materials';

  @override
  String get categoryTaxonomyExpenseFinanceBankFeesName => 'Bank Fees';

  @override
  String get categoryTaxonomyExpenseFinanceAtmFeesName => 'ATM Fees';

  @override
  String get categoryTaxonomyExpenseFinanceCreditCardPaymentName =>
      'Credit Card Payment';

  @override
  String get categoryTaxonomyExpenseFinanceLoanPaymentName => 'Loan Payment';

  @override
  String get categoryTaxonomyExpenseFinanceDebtRepaymentName =>
      'Debt Repayment';

  @override
  String get categoryTaxonomyExpenseFinanceSavingsName => 'Savings';

  @override
  String get categoryTaxonomyExpenseFinanceEmergencyFundName =>
      'Emergency Fund';

  @override
  String get categoryTaxonomyExpenseFinanceTfsaContributionName =>
      'TFSA Contribution';

  @override
  String get categoryTaxonomyExpenseFinanceRrspContributionName =>
      'RRSP Contribution';

  @override
  String get categoryTaxonomyExpenseFinanceRespContributionName =>
      'RESP Contribution';

  @override
  String get categoryTaxonomyExpenseFinanceInvestmentsName => 'Investments';

  @override
  String get categoryTaxonomyExpenseFinanceCurrencyExchangeName =>
      'Currency Exchange';

  @override
  String get categoryTaxonomyExpenseGovernmentIncomeTaxName => 'Income Tax';

  @override
  String get categoryTaxonomyExpenseGovernmentDriverLicenceName =>
      'Driver Licence';

  @override
  String get categoryTaxonomyExpenseGovernmentPassportName => 'Passport';

  @override
  String get categoryTaxonomyExpenseGovernmentImmigrationFeesName =>
      'Immigration Fees';

  @override
  String get categoryTaxonomyExpenseGovernmentPermitsName => 'Permits';

  @override
  String get categoryTaxonomyExpenseGovernmentGovernmentServicesName =>
      'Government Services';

  @override
  String get categoryTaxonomyExpensePetsPetFoodName => 'Pet Food';

  @override
  String get categoryTaxonomyExpensePetsVeterinaryName => 'Veterinary';

  @override
  String get categoryTaxonomyExpensePetsPetMedicineName => 'Pet Medicine';

  @override
  String get categoryTaxonomyExpensePetsPetInsuranceName => 'Pet Insurance';

  @override
  String get categoryTaxonomyExpensePetsGroomingName => 'Grooming';

  @override
  String get categoryTaxonomyExpensePetsPetSuppliesName => 'Pet Supplies';

  @override
  String get categoryTaxonomyExpenseGivingGiftsName => 'Gifts';

  @override
  String get categoryTaxonomyExpenseGivingCharityName => 'Charity';

  @override
  String get categoryTaxonomyExpenseGivingDonationsName => 'Donations';

  @override
  String get categoryTaxonomyExpenseGivingHolidayExpensesName =>
      'Holiday Expenses';

  @override
  String get categoryTaxonomyExpenseWorkOfficeSuppliesName => 'Office Supplies';

  @override
  String get categoryTaxonomyExpenseWorkSoftwareName => 'Software';

  @override
  String get categoryTaxonomyExpenseWorkEquipmentName => 'Equipment';

  @override
  String get categoryTaxonomyExpenseWorkBusinessTravelName => 'Business Travel';

  @override
  String get categoryTaxonomyExpenseWorkProfessionalMembershipsName =>
      'Professional Memberships';

  @override
  String get categoryTaxonomyExpenseWorkLicencesName => 'Licences';

  @override
  String get categoryTaxonomyExpenseOtherCashWithdrawalName =>
      'Cash Withdrawal';

  @override
  String get categoryTaxonomyExpenseOtherAdjustmentName => 'Adjustment';

  @override
  String get categoryTaxonomyExpenseOtherUncategorizedName => 'Uncategorized';

  @override
  String get categoryTaxonomyIncomeEmploymentSalaryName => 'Salary';

  @override
  String get categoryTaxonomyIncomeEmploymentBonusName => 'Bonus';

  @override
  String get categoryTaxonomyIncomeEmploymentOvertimeName => 'Overtime';

  @override
  String get categoryTaxonomyIncomeEmploymentCommissionName => 'Commission';

  @override
  String get categoryTaxonomyIncomeEmploymentTipsName => 'Tips';

  @override
  String get categoryTaxonomyIncomeBusinessBusinessIncomeName =>
      'Business Income';

  @override
  String get categoryTaxonomyIncomeBusinessFreelanceName => 'Freelance';

  @override
  String get categoryTaxonomyIncomeBusinessConsultingName => 'Consulting';

  @override
  String get categoryTaxonomyIncomeBusinessRentalIncomeName => 'Rental Income';

  @override
  String get categoryTaxonomyIncomeInvestmentsInterestIncomeName =>
      'Interest Income';

  @override
  String get categoryTaxonomyIncomeInvestmentsDividendIncomeName =>
      'Dividend Income';

  @override
  String get categoryTaxonomyIncomeInvestmentsCapitalGainsName =>
      'Capital Gains';

  @override
  String get categoryTaxonomyIncomeInvestmentsInvestmentDistributionName =>
      'Investment Distribution';

  @override
  String get categoryTaxonomyIncomeGovernmentTaxRefundName => 'Tax Refund';

  @override
  String get categoryTaxonomyIncomeGovernmentGovernmentBenefitsName =>
      'Government Benefits';

  @override
  String get categoryTaxonomyIncomeGovernmentPensionName => 'Pension';

  @override
  String get categoryTaxonomyIncomeGovernmentChildBenefitName =>
      'Child Benefit';

  @override
  String get categoryTaxonomyIncomeGovernmentEmploymentInsuranceName =>
      'Employment Insurance';

  @override
  String get categoryTaxonomyIncomeGiftsGiftReceivedName => 'Gift Received';

  @override
  String get categoryTaxonomyIncomeGiftsFamilySupportName => 'Family Support';

  @override
  String get categoryTaxonomyIncomeGiftsCashbackName => 'Cashback';

  @override
  String get categoryTaxonomyIncomeGiftsRewardsName => 'Rewards';

  @override
  String get categoryTaxonomyIncomeOtherIncomeRefundName => 'Refund';

  @override
  String get categoryTaxonomyIncomeOtherIncomeReimbursementName =>
      'Reimbursement';

  @override
  String get categoryTaxonomyIncomeOtherIncomeSaleOfItemName => 'Sale of Item';

  @override
  String get categoryTaxonomyIncomeOtherIncomeOtherIncomeName => 'Other Income';

  @override
  String get operationExpense => 'Expense';

  @override
  String get operationIncome => 'Income';

  @override
  String get operationTransfer => 'Transfer';

  @override
  String get operationCreateTitle => 'Operation';

  @override
  String get operationEditTitle => 'Edit operation';

  @override
  String get operationExpenseNameHint => 'Expense name';

  @override
  String get operationIncomeNameHint => 'Income name';

  @override
  String get operationAmountHint => 'Amount';

  @override
  String get operationChooseCategory => 'Choose category';

  @override
  String get operationCategoryPickerEmpty => 'No categories available.';

  @override
  String get dashboardPercentLessThanOne => '<1%';

  @override
  String get commonApply => 'Apply';

  @override
  String get operationArchiveTitle => 'Delete operation?';

  @override
  String get operationArchiveMessage =>
      'This operation will be archived and hidden from your list.';

  @override
  String get operationArchiveConfirm => 'Delete';

  @override
  String get operationsInteractionHint => 'Tap to edit · Swipe left to delete';

  @override
  String get operationsEmptyMessage =>
      'You don’t have any income or expenses yet.\nTap + to add your first operation.';

  @override
  String get operationRecurrenceNone => 'No recurrence';

  @override
  String get operationRecurrenceDaily => 'Daily';

  @override
  String get operationRecurrenceWeekly => 'Weekly';

  @override
  String get operationRecurrenceBiweekly => 'Every 2 weeks';

  @override
  String get operationRecurrenceMonthly => 'Monthly';

  @override
  String get operationRecurrenceYearly => 'Yearly';

  @override
  String get operationRecurrenceTitle => 'Recurrence';

  @override
  String get operationDescriptionHint => 'Description';

  @override
  String get commonSaving => 'Saving...';

  @override
  String get operationAmountRequired => 'Enter a valid amount.';

  @override
  String get operationCategoryRequired => 'Choose a category.';

  @override
  String get accountsEmptyMessage =>
      'You don\'t have any accounts yet.\nTap + to create your first account.';

  @override
  String get accountCreateTitle => 'Create account';

  @override
  String get accountNameHint => 'Account name';

  @override
  String get accountNameRequired => 'Account name is required.';

  @override
  String get accountTypeHint => 'Account type';

  @override
  String get accountCurrencyHint => 'Currency';

  @override
  String get accountInitialBalanceHint => 'Initial balance';

  @override
  String get accountInitialBalanceRequired => 'Initial balance is required.';

  @override
  String get accountInitialBalanceInvalid => 'Enter a valid amount.';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeCard => 'Card';

  @override
  String get accountTypeCreditCard => 'Credit card';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeLoan => 'Loan';

  @override
  String get accountTypeWallet => 'Wallet';

  @override
  String get accountTypeOther => 'Other';
}
