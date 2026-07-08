// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get authWelcome => 'Bienvenue sur Ophir';

  @override
  String get authSubtitle =>
      'Finance intelligente.\nToutes vos finances dans une seule app.';

  @override
  String get authContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authOr => 'ou';

  @override
  String get authEmailHint => 'Entrez votre e-mail';

  @override
  String get authPasswordHint => 'Entrez votre mot de passe';

  @override
  String get authContinue => 'Continuer';

  @override
  String get authNoAccount => 'Vous n’avez pas de compte ?';

  @override
  String get authSignUp => 'S’inscrire';

  @override
  String get authTermsPrefix => 'En continuant, vous acceptez nos';

  @override
  String get authTermsOfUse => 'Conditions d’utilisation';

  @override
  String get authAnd => 'et';

  @override
  String get authPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get authComingSoon => 'Bientôt disponible';

  @override
  String get authCheckEmail => 'Vérifiez votre boîte e-mail.';

  @override
  String get authUserNotFound => 'Aucun compte trouvé pour cet e-mail.';

  @override
  String get authPasswordRequired => 'Le mot de passe est requis.';

  @override
  String get authUnknownError => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get authGoogleFailed => 'Connexion Google impossible.';

  @override
  String get authServerError =>
      'Échec de l’authentification. Veuillez réessayer.';

  @override
  String get authEmailSuggestion => 'Vouliez-vous dire';

  @override
  String get authRateLimited =>
      'Trop de demandes par e-mail. Veuillez patienter quelques minutes puis réessayer.';

  @override
  String get emailValidationEmpty => 'L’e-mail est requis.';

  @override
  String get emailValidationContainsSpaces =>
      'L’e-mail ne doit pas contenir d’espaces.';

  @override
  String get emailValidationMissingAt => 'L’e-mail doit contenir \'@\'.';

  @override
  String get emailValidationMultipleAt =>
      'L’e-mail ne doit contenir qu’un seul \'@\'.';

  @override
  String get emailValidationMissingLocalPart => 'Entrez la partie avant \'@\'.';

  @override
  String get emailValidationMissingDomain => 'Entrez le domaine de l’e-mail.';

  @override
  String get emailValidationLocalStartsWithDot =>
      'La partie locale ne doit pas commencer par \'.\'.';

  @override
  String get emailValidationLocalEndsWithDot =>
      'La partie locale ne doit pas se terminer par \'.\'.';

  @override
  String get emailValidationLocalHasConsecutiveDots =>
      'La partie locale ne doit pas contenir de points consécutifs.';

  @override
  String get emailValidationDomainStartsWithDot =>
      'Le domaine ne doit pas commencer par \'.\'.';

  @override
  String get emailValidationDomainEndsWithDot =>
      'Le domaine ne doit pas se terminer par \'.\'.';

  @override
  String get emailValidationDomainHasConsecutiveDots =>
      'Le domaine ne doit pas contenir de points consécutifs.';

  @override
  String get emailValidationDomainMissingDot =>
      'Le domaine doit contenir un \'.\'.';

  @override
  String get emailValidationInvalidTopLevelDomain =>
      'Domaine de premier niveau invalide.';

  @override
  String get emailValidationTopLevelDomainTooShort =>
      'Le domaine de premier niveau est trop court.';

  @override
  String get emailValidationInvalidLocalCharacters =>
      'Caractères invalides dans la partie locale.';

  @override
  String get emailValidationInvalidDomainCharacters =>
      'Caractères invalides dans le domaine.';

  @override
  String get emailValidationDomainLabelStartsWithHyphen =>
      'Une section du domaine ne doit pas commencer par \'-\'.';

  @override
  String get emailValidationDomainLabelEndsWithHyphen =>
      'Une section du domaine ne doit pas se terminer par \'-\'.';

  @override
  String get emailValidationLocalPartTooLong =>
      'La partie locale est trop longue.';

  @override
  String get emailValidationDomainTooLong => 'Le domaine est trop long.';

  @override
  String get emailValidationEmailTooLong => 'L’adresse e-mail est trop longue.';

  @override
  String get emailValidationInvalidFormat => 'Format d’e-mail invalide.';

  @override
  String get passwordValidationEmpty => 'Le mot de passe est requis.';

  @override
  String get passwordValidationContainsSpaces =>
      'Le mot de passe ne doit pas contenir d’espaces.';

  @override
  String get passwordValidationTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get passwordValidationTooLong =>
      'Le mot de passe ne doit pas dépasser 128 caractères.';

  @override
  String get passwordValidationMissingLetter =>
      'Le mot de passe doit contenir au moins une lettre.';

  @override
  String get passwordValidationMissingNumber =>
      'Le mot de passe doit contenir au moins un chiffre.';

  @override
  String get passwordValidationMissingSpecialCharacter =>
      'Le mot de passe doit contenir au moins un caractère spécial.';

  @override
  String get passwordValidationMissingLowercaseLetter =>
      'Le mot de passe doit contenir au moins une lettre minuscule.';

  @override
  String get passwordValidationMissingUppercaseLetter =>
      'Le mot de passe doit contenir au moins une lettre majuscule.';

  @override
  String get passwordRequirementMinLength => 'Au moins 8 caractères';

  @override
  String get passwordRequirementMaxLength => 'Pas plus de 128 caractères';

  @override
  String get passwordRequirementNoSpaces => 'Sans espaces';

  @override
  String get passwordRequirementLowercase => 'Une lettre minuscule';

  @override
  String get passwordRequirementUppercase => 'Une lettre majuscule';

  @override
  String get passwordRequirementNumber => 'Un chiffre';

  @override
  String get passwordRequirementSpecial => 'Un caractère spécial';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthMedium => 'Moyen';

  @override
  String get passwordStrengthStrong => 'Fort';

  @override
  String get failureUnauthorized => 'Veuillez vous connecter pour continuer.';

  @override
  String get failureNotFound => 'Les données demandées sont introuvables.';

  @override
  String get failureValidation => 'Veuillez vérifier les données saisies.';

  @override
  String get failureDatabase => 'Une erreur de base de données est survenue.';

  @override
  String get failureNetwork =>
      'Erreur réseau. Vérifiez votre connexion Internet.';

  @override
  String get failureUnknown => 'Une erreur est survenue.';

  @override
  String get navigationHome => 'Accueil';

  @override
  String get navigationAccounts => 'Comptes';

  @override
  String get navigationTransactions => 'Transactions';

  @override
  String get navigationStatistics => 'Stats';

  @override
  String get navigationSettings => 'Réglages';

  @override
  String get dashboardGreeting => 'Aujourd’hui';

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String get statisticsTitle => 'Statistiques';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSectionGeneral => 'GÉNÉRAL';

  @override
  String get settingsSectionData => 'DONNÉES';

  @override
  String get settingsSectionSecurity => 'SÉCURITÉ';

  @override
  String get settingsSectionAbout => 'À PROPOS';

  @override
  String get settingsAppearanceTitle => 'Apparence';

  @override
  String get settingsAppearanceSubtitle => 'Thème et préférences d’affichage';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Gérer vos préférences de notifications';

  @override
  String get settingsAccountsSubtitle => 'Gérer les comptes et les soldes';

  @override
  String get settingsCategoriesTitle => 'Catégories';

  @override
  String get settingsCategoriesSubtitle =>
      'Organiser les catégories de revenus et dépenses';

  @override
  String get settingsSecurityTitle => 'Sécurité';

  @override
  String get settingsSecuritySubtitle => 'Mot de passe et sécurité du compte';

  @override
  String get settingsAboutTitle => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Informations sur l’app et assistance';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Comment vos données sont traitées';

  @override
  String get settingsTermsSubtitle => 'Règles d’utilisation d’Ophir';

  @override
  String get settingsOpenSourceLicensesTitle => 'Licences open source';

  @override
  String get settingsOpenSourceLicensesSubtitle => 'Mentions des tiers';

  @override
  String get settingsAppVersionTitle => 'Version de l’app';

  @override
  String get settingsAppVersionSubtitle => 'Détails de version';

  @override
  String get settingsComingSoon => 'Bientôt disponible';

  @override
  String get navigationProfile => 'Profil';

  @override
  String get profileCurrency => 'Devise';

  @override
  String get profileTimezone => 'Fuseau horaire';

  @override
  String get authSignOut => 'Se déconnecter';

  @override
  String get dashboardGoodMorning => 'Bonjour';

  @override
  String get navigationOperations => 'Opérations';

  @override
  String get operationsTitle => 'Opérations';

  @override
  String get dashboardGreetingMorning => 'Bonjour';

  @override
  String get dashboardGreetingAfternoon => 'Bon après-midi';

  @override
  String get dashboardGreetingEvening => 'Bonsoir';

  @override
  String get dashboardGreetingNight => 'Bonne nuit';

  @override
  String get profileNameMissing => 'Ajouter votre nom';

  @override
  String get profileEditTitle => 'Profil';

  @override
  String get profileEditSubtitle => 'Gérer votre nom, photo et informations';

  @override
  String get profileSecurityTitle => 'Sécurité';

  @override
  String get profileSecuritySubtitle => 'Mot de passe et sécurité du compte';

  @override
  String get profileNotificationsTitle => 'Notifications';

  @override
  String get profileNotificationsSubtitle =>
      'Gérer vos préférences de notifications';

  @override
  String get profileAppearanceTitle => 'Apparence';

  @override
  String get profileAppearanceSubtitle => 'Thème et préférences d’affichage';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get profileFullName => 'Nom complet';

  @override
  String get profileFullNameHint => 'Entrez votre nom';

  @override
  String get profileFullNameRequired => 'Le nom est requis.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get categoryRent => 'Loyer';

  @override
  String get categoryMortgage => 'Hypothèque';

  @override
  String get categoryUtilities => 'Services publics';

  @override
  String get categoryInsurance => 'Assurance';

  @override
  String get categoryGroceries => 'Épicerie';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryCoffee => 'Café';

  @override
  String get categoryFuel => 'Carburant';

  @override
  String get categoryPublicTransit => 'Transport en commun';

  @override
  String get categoryCar => 'Voiture';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryPharmacy => 'Pharmacie';

  @override
  String get categoryShopping => 'Achats';

  @override
  String get categoryEntertainment => 'Divertissement';

  @override
  String get categorySubscriptions => 'Abonnements';

  @override
  String get categoryTravel => 'Voyages';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryDebtPayment => 'Paiement de dette';

  @override
  String get categoryBankFees => 'Frais bancaires';

  @override
  String get categorySavings => 'Épargne';

  @override
  String get categoryInvestments => 'Investissements';

  @override
  String get categoryOtherExpense => 'Autre dépense';

  @override
  String get categorySalary => 'Salaire';

  @override
  String get categoryBusiness => 'Entreprise';

  @override
  String get categoryBenefits => 'Prestations';

  @override
  String get categoryDividends => 'Dividendes';

  @override
  String get categoryOtherIncome => 'Autre revenu';

  @override
  String get categoryGroupHousing => 'Logement';

  @override
  String get categoryGroupFood => 'Alimentation';

  @override
  String get categoryGroupTransport => 'Transport';

  @override
  String get categoryGroupHealth => 'Santé';

  @override
  String get categoryGroupLifestyle => 'Style de vie';

  @override
  String get categoryGroupFinance => 'Finances';

  @override
  String get categoryGroupSalary => 'Salaire';

  @override
  String get categoryGroupBusiness => 'Entreprise';

  @override
  String get categoryGroupBenefits => 'Prestations';

  @override
  String get categoryGroupInvestments => 'Investissements';

  @override
  String get categoryGroupOther => 'Autre';

  @override
  String get categoryExampleDefault => 'Ex. Détail de l\'opération';

  @override
  String get categoryExampleRent => 'Ex. Loyer de juillet';

  @override
  String get categoryExampleMortgage => 'Ex. Hypothèque';

  @override
  String get categoryExampleUtilities => 'Ex. Hydro-Québec';

  @override
  String get categoryExampleInsurance => 'Ex. Assurance habitation';

  @override
  String get categoryExampleGroceries => 'Ex. Costco';

  @override
  String get categoryExampleRestaurants => 'Ex. Restaurant';

  @override
  String get categoryExampleCoffee => 'Ex. Tim Hortons';

  @override
  String get categoryExampleFuel => 'Ex. Essence';

  @override
  String get categoryExamplePublicTransit => 'Ex. STM';

  @override
  String get categoryExampleCar => 'Ex. Entretien voiture';

  @override
  String get categoryExampleHealth => 'Ex. Consultation médicale';

  @override
  String get categoryExamplePharmacy => 'Ex. Pharmacie';

  @override
  String get categoryExampleShopping => 'Ex. Amazon';

  @override
  String get categoryExampleEntertainment => 'Ex. Cinéma';

  @override
  String get categoryExampleSubscriptions => 'Ex. Netflix';

  @override
  String get categoryExampleTravel => 'Ex. Billet d\'avion';

  @override
  String get categoryExampleEducation => 'Ex. Cours';

  @override
  String get categoryExampleDebtPayment => 'Ex. Paiement carte de crédit';

  @override
  String get categoryExampleBankFees => 'Ex. Frais bancaires';

  @override
  String get categoryExampleSavings => 'Ex. Épargne mensuelle';

  @override
  String get categoryExampleInvestments => 'Ex. Wealthsimple';

  @override
  String get categoryExampleOtherExpense => 'Ex. Autre dépense';

  @override
  String get categoryExampleSalary => 'Ex. Salaire de juin';

  @override
  String get categoryExampleBusiness => 'Ex. Revenu client';

  @override
  String get categoryExampleBenefits => 'Ex. Allocation';

  @override
  String get categoryExampleDividends => 'Ex. Dividendes';

  @override
  String get categoryExampleOtherIncome => 'Ex. Autre revenu';

  @override
  String get categoryGroupExpenseHousing => 'Logement';

  @override
  String get categoryGroupExpenseFood => 'Alimentation';

  @override
  String get categoryGroupExpenseTransportation => 'Transport';

  @override
  String get categoryGroupExpenseHealth => 'Santé';

  @override
  String get categoryGroupExpenseFamily => 'Famille';

  @override
  String get categoryGroupExpensePersonalCare => 'Soins personnels';

  @override
  String get categoryGroupExpenseEntertainmentLifestyle =>
      'Divertissement et style de vie';

  @override
  String get categoryGroupExpenseEducation => 'Éducation';

  @override
  String get categoryGroupExpenseFinance => 'Finances';

  @override
  String get categoryGroupExpenseGovernment => 'Gouvernement';

  @override
  String get categoryGroupExpensePets => 'Animaux';

  @override
  String get categoryGroupExpenseGiving => 'Dons';

  @override
  String get categoryGroupExpenseWork => 'Travail';

  @override
  String get categoryGroupExpenseOther => 'Autre';

  @override
  String get categoryGroupIncomeEmployment => 'Emploi';

  @override
  String get categoryGroupIncomeBusiness => 'Entreprise';

  @override
  String get categoryGroupIncomeInvestments => 'Investissements';

  @override
  String get categoryGroupIncomeGovernment => 'Gouvernement';

  @override
  String get categoryGroupIncomeGifts => 'Cadeaux';

  @override
  String get categoryGroupIncomeOtherIncome => 'Autres revenus';

  @override
  String get categoryTaxonomyExpenseHousingRentName => 'Loyer';

  @override
  String get categoryTaxonomyExpenseHousingMortgageName => 'Hypothèque';

  @override
  String get categoryTaxonomyExpenseHousingPropertyTaxName => 'Taxe foncière';

  @override
  String get categoryTaxonomyExpenseHousingCondoFeesName =>
      'Frais de copropriété';

  @override
  String get categoryTaxonomyExpenseHousingElectricityName => 'Électricité';

  @override
  String get categoryTaxonomyExpenseHousingNaturalGasName => 'Gaz naturel';

  @override
  String get categoryTaxonomyExpenseHousingWaterName => 'Eau';

  @override
  String get categoryTaxonomyExpenseHousingSewerName => 'Égouts';

  @override
  String get categoryTaxonomyExpenseHousingGarbageCollectionName =>
      'Collecte des déchets';

  @override
  String get categoryTaxonomyExpenseHousingInternetName => 'Internet';

  @override
  String get categoryTaxonomyExpenseHousingMobilePhoneName =>
      'Téléphone mobile';

  @override
  String get categoryTaxonomyExpenseHousingHomePhoneName =>
      'Téléphone résidentiel';

  @override
  String get categoryTaxonomyExpenseHousingHomeInsuranceName =>
      'Assurance habitation';

  @override
  String get categoryTaxonomyExpenseHousingHomeMaintenanceName =>
      'Entretien du logement';

  @override
  String get categoryTaxonomyExpenseHousingFurnitureName => 'Meubles';

  @override
  String get categoryTaxonomyExpenseHousingAppliancesName => 'Électroménagers';

  @override
  String get categoryTaxonomyExpenseHousingHomeSuppliesName =>
      'Articles pour la maison';

  @override
  String get categoryTaxonomyExpenseHousingHomeSecurityName =>
      'Sécurité résidentielle';

  @override
  String get categoryTaxonomyExpenseFoodGroceriesName => 'Épicerie';

  @override
  String get categoryTaxonomyExpenseFoodFarmersMarketName => 'Marché fermier';

  @override
  String get categoryTaxonomyExpenseFoodRestaurantName => 'Restaurant';

  @override
  String get categoryTaxonomyExpenseFoodCafeCoffeeName => 'Café et boissons';

  @override
  String get categoryTaxonomyExpenseFoodFastFoodName => 'Restauration rapide';

  @override
  String get categoryTaxonomyExpenseFoodFoodDeliveryName =>
      'Livraison de repas';

  @override
  String get categoryTaxonomyExpenseFoodSnacksName => 'Collations';

  @override
  String get categoryTaxonomyExpenseFoodAlcoholName => 'Alcool';

  @override
  String get categoryTaxonomyExpenseTransportationFuelName => 'Carburant';

  @override
  String get categoryTaxonomyExpenseTransportationEvChargingName =>
      'Recharge de véhicule électrique';

  @override
  String get categoryTaxonomyExpenseTransportationPublicTransitName =>
      'Transport en commun';

  @override
  String get categoryTaxonomyExpenseTransportationTaxiRideSharingName =>
      'Taxi et covoiturage';

  @override
  String get categoryTaxonomyExpenseTransportationParkingName =>
      'Stationnement';

  @override
  String get categoryTaxonomyExpenseTransportationTollRoadsName => 'Péages';

  @override
  String get categoryTaxonomyExpenseTransportationAutoInsuranceName =>
      'Assurance auto';

  @override
  String get categoryTaxonomyExpenseTransportationAutoLoanName => 'Prêt auto';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleMaintenanceName =>
      'Entretien du véhicule';

  @override
  String get categoryTaxonomyExpenseTransportationTireServiceName => 'Pneus';

  @override
  String get categoryTaxonomyExpenseTransportationVehicleRegistrationName =>
      'Immatriculation du véhicule';

  @override
  String get categoryTaxonomyExpenseTransportationCarWashName => 'Lavage auto';

  @override
  String get categoryTaxonomyExpenseHealthPharmacyName => 'Pharmacie';

  @override
  String get categoryTaxonomyExpenseHealthMedicineName => 'Médicaments';

  @override
  String get categoryTaxonomyExpenseHealthDoctorName => 'Médecin';

  @override
  String get categoryTaxonomyExpenseHealthDentistName => 'Dentiste';

  @override
  String get categoryTaxonomyExpenseHealthVisionCareName => 'Soins de la vue';

  @override
  String get categoryTaxonomyExpenseHealthMedicalTestsName =>
      'Analyses médicales';

  @override
  String get categoryTaxonomyExpenseHealthMedicalProceduresName =>
      'Procédures médicales';

  @override
  String get categoryTaxonomyExpenseHealthHealthInsuranceName =>
      'Assurance santé';

  @override
  String get categoryTaxonomyExpenseHealthMentalHealthName => 'Santé mentale';

  @override
  String get categoryTaxonomyExpenseHealthPhysiotherapyName => 'Physiothérapie';

  @override
  String get categoryTaxonomyExpenseHealthGymFitnessName =>
      'Gym et mise en forme';

  @override
  String get categoryTaxonomyExpenseHealthVitaminsName => 'Vitamines';

  @override
  String get categoryTaxonomyExpenseFamilyChildcareName => 'Garde d\'enfants';

  @override
  String get categoryTaxonomyExpenseFamilyDaycareName => 'Garderie';

  @override
  String get categoryTaxonomyExpenseFamilySchoolName => 'École';

  @override
  String get categoryTaxonomyExpenseFamilyUniversityName => 'Université';

  @override
  String get categoryTaxonomyExpenseFamilyTutoringName => 'Tutorat';

  @override
  String get categoryTaxonomyExpenseFamilyChildrensClothingName =>
      'Vêtements pour enfants';

  @override
  String get categoryTaxonomyExpenseFamilyBabySuppliesName =>
      'Articles pour bébé';

  @override
  String get categoryTaxonomyExpenseFamilyToysName => 'Jouets';

  @override
  String get categoryTaxonomyExpenseFamilyChildSupportName =>
      'Pension alimentaire pour enfant';

  @override
  String get categoryTaxonomyExpensePersonalCareClothingName => 'Vêtements';

  @override
  String get categoryTaxonomyExpensePersonalCareShoesName => 'Chaussures';

  @override
  String get categoryTaxonomyExpensePersonalCareCosmeticsName => 'Cosmétiques';

  @override
  String get categoryTaxonomyExpensePersonalCareJewelryName => 'Bijoux';

  @override
  String get categoryTaxonomyExpensePersonalCareHaircareName =>
      'Soins des cheveux';

  @override
  String get categoryTaxonomyExpensePersonalCareNailCareName =>
      'Soins des ongles';

  @override
  String get categoryTaxonomyExpensePersonalCarePersonalHygieneName =>
      'Hygiène personnelle';

  @override
  String get categoryTaxonomyExpensePersonalCareContactLensesName =>
      'Lentilles de contact';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMoviesName =>
      'Cinéma';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTheatreName =>
      'Théâtre';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleConcertsName =>
      'Concerts';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleGamingName =>
      'Jeux vidéo';

  @override
  String
  get categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName =>
      'Abonnements streaming';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleMusicName =>
      'Musique';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleBooksName => 'Livres';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName =>
      'Loisirs';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleTravelName =>
      'Voyage';

  @override
  String get categoryTaxonomyExpenseEntertainmentLifestyleHotelsName =>
      'Hôtels';

  @override
  String get categoryTaxonomyExpenseEducationCoursesName => 'Cours';

  @override
  String get categoryTaxonomyExpenseEducationOnlineLearningName =>
      'Formation en ligne';

  @override
  String get categoryTaxonomyExpenseEducationUniversityTuitionName =>
      'Frais de scolarité universitaire';

  @override
  String get categoryTaxonomyExpenseEducationCertificationsName =>
      'Certifications';

  @override
  String get categoryTaxonomyExpenseEducationConferencesName => 'Conférences';

  @override
  String get categoryTaxonomyExpenseEducationLanguageCoursesName =>
      'Cours de langue';

  @override
  String get categoryTaxonomyExpenseEducationEducationalMaterialsName =>
      'Matériel pédagogique';

  @override
  String get categoryTaxonomyExpenseFinanceBankFeesName => 'Frais bancaires';

  @override
  String get categoryTaxonomyExpenseFinanceAtmFeesName => 'Frais de guichet';

  @override
  String get categoryTaxonomyExpenseFinanceCreditCardPaymentName =>
      'Paiement de carte de crédit';

  @override
  String get categoryTaxonomyExpenseFinanceLoanPaymentName =>
      'Paiement de prêt';

  @override
  String get categoryTaxonomyExpenseFinanceDebtRepaymentName =>
      'Remboursement de dette';

  @override
  String get categoryTaxonomyExpenseFinanceSavingsName => 'Épargne';

  @override
  String get categoryTaxonomyExpenseFinanceEmergencyFundName =>
      'Fonds d\'urgence';

  @override
  String get categoryTaxonomyExpenseFinanceTfsaContributionName =>
      'Cotisation CELI';

  @override
  String get categoryTaxonomyExpenseFinanceRrspContributionName =>
      'Cotisation REER';

  @override
  String get categoryTaxonomyExpenseFinanceRespContributionName =>
      'Cotisation REEE';

  @override
  String get categoryTaxonomyExpenseFinanceInvestmentsName => 'Investissements';

  @override
  String get categoryTaxonomyExpenseFinanceCurrencyExchangeName =>
      'Change de devise';

  @override
  String get categoryTaxonomyExpenseGovernmentIncomeTaxName =>
      'Impôt sur le revenu';

  @override
  String get categoryTaxonomyExpenseGovernmentDriverLicenceName =>
      'Permis de conduire';

  @override
  String get categoryTaxonomyExpenseGovernmentPassportName => 'Passeport';

  @override
  String get categoryTaxonomyExpenseGovernmentImmigrationFeesName =>
      'Frais d\'immigration';

  @override
  String get categoryTaxonomyExpenseGovernmentPermitsName => 'Autorisations';

  @override
  String get categoryTaxonomyExpenseGovernmentGovernmentServicesName =>
      'Services gouvernementaux';

  @override
  String get categoryTaxonomyExpensePetsPetFoodName =>
      'Nourriture pour animaux';

  @override
  String get categoryTaxonomyExpensePetsVeterinaryName => 'Vétérinaire';

  @override
  String get categoryTaxonomyExpensePetsPetMedicineName =>
      'Médicaments pour animaux';

  @override
  String get categoryTaxonomyExpensePetsPetInsuranceName =>
      'Assurance pour animaux';

  @override
  String get categoryTaxonomyExpensePetsGroomingName => 'Toilettage';

  @override
  String get categoryTaxonomyExpensePetsPetSuppliesName =>
      'Fournitures pour animaux';

  @override
  String get categoryTaxonomyExpenseGivingGiftsName => 'Cadeaux';

  @override
  String get categoryTaxonomyExpenseGivingCharityName =>
      'Organismes caritatifs';

  @override
  String get categoryTaxonomyExpenseGivingDonationsName => 'Dons';

  @override
  String get categoryTaxonomyExpenseGivingHolidayExpensesName =>
      'Dépenses des fêtes';

  @override
  String get categoryTaxonomyExpenseWorkOfficeSuppliesName =>
      'Fournitures de bureau';

  @override
  String get categoryTaxonomyExpenseWorkSoftwareName => 'Logiciels';

  @override
  String get categoryTaxonomyExpenseWorkEquipmentName => 'Équipement';

  @override
  String get categoryTaxonomyExpenseWorkBusinessTravelName =>
      'Voyages d\'affaires';

  @override
  String get categoryTaxonomyExpenseWorkProfessionalMembershipsName =>
      'Adhésions professionnelles';

  @override
  String get categoryTaxonomyExpenseWorkLicencesName => 'Licences';

  @override
  String get categoryTaxonomyExpenseOtherCashWithdrawalName =>
      'Retrait d\'espèces';

  @override
  String get categoryTaxonomyExpenseOtherAdjustmentName => 'Ajustement';

  @override
  String get categoryTaxonomyExpenseOtherUncategorizedName => 'Non catégorisé';

  @override
  String get categoryTaxonomyIncomeEmploymentSalaryName => 'Salaire';

  @override
  String get categoryTaxonomyIncomeEmploymentBonusName => 'Prime';

  @override
  String get categoryTaxonomyIncomeEmploymentOvertimeName =>
      'Heures supplémentaires';

  @override
  String get categoryTaxonomyIncomeEmploymentCommissionName => 'Commission';

  @override
  String get categoryTaxonomyIncomeEmploymentTipsName => 'Pourboires';

  @override
  String get categoryTaxonomyIncomeBusinessBusinessIncomeName =>
      'Revenu d\'entreprise';

  @override
  String get categoryTaxonomyIncomeBusinessFreelanceName =>
      'Travail indépendant';

  @override
  String get categoryTaxonomyIncomeBusinessConsultingName => 'Conseil';

  @override
  String get categoryTaxonomyIncomeBusinessRentalIncomeName => 'Revenu locatif';

  @override
  String get categoryTaxonomyIncomeInvestmentsInterestIncomeName => 'Intérêts';

  @override
  String get categoryTaxonomyIncomeInvestmentsDividendIncomeName =>
      'Dividendes';

  @override
  String get categoryTaxonomyIncomeInvestmentsCapitalGainsName =>
      'Gains en capital';

  @override
  String get categoryTaxonomyIncomeInvestmentsInvestmentDistributionName =>
      'Distribution d\'investissement';

  @override
  String get categoryTaxonomyIncomeGovernmentTaxRefundName =>
      'Remboursement d\'impôt';

  @override
  String get categoryTaxonomyIncomeGovernmentGovernmentBenefitsName =>
      'Prestations gouvernementales';

  @override
  String get categoryTaxonomyIncomeGovernmentPensionName => 'Pension';

  @override
  String get categoryTaxonomyIncomeGovernmentChildBenefitName =>
      'Allocation pour enfant';

  @override
  String get categoryTaxonomyIncomeGovernmentEmploymentInsuranceName =>
      'Assurance-emploi';

  @override
  String get categoryTaxonomyIncomeGiftsGiftReceivedName => 'Cadeau reçu';

  @override
  String get categoryTaxonomyIncomeGiftsFamilySupportName => 'Soutien familial';

  @override
  String get categoryTaxonomyIncomeGiftsCashbackName => 'Remise en argent';

  @override
  String get categoryTaxonomyIncomeGiftsRewardsName => 'Récompenses';

  @override
  String get categoryTaxonomyIncomeOtherIncomeRefundName => 'Remboursement';

  @override
  String get categoryTaxonomyIncomeOtherIncomeReimbursementName =>
      'Remboursement de frais';

  @override
  String get categoryTaxonomyIncomeOtherIncomeSaleOfItemName =>
      'Vente d\'un article';

  @override
  String get categoryTaxonomyIncomeOtherIncomeOtherIncomeName => 'Autre revenu';

  @override
  String get operationExpense => 'Dépense';

  @override
  String get operationIncome => 'Revenu';

  @override
  String get operationTransfer => 'Transfert';

  @override
  String get operationCreateTitle => 'Opération';

  @override
  String get operationEditTitle => 'Modifier l’opération';

  @override
  String get operationExpenseNameHint => 'Nom de la dépense';

  @override
  String get operationIncomeNameHint => 'Nom du revenu';

  @override
  String get operationAmountHint => 'Montant';

  @override
  String get operationChooseCategory => 'Choisir une catégorie';

  @override
  String get operationCategoryPickerEmpty => 'Aucune catégorie disponible.';

  @override
  String get dashboardPercentLessThanOne => '<1 %';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get operationArchiveTitle => 'Supprimer l’opération ?';

  @override
  String get operationArchiveMessage =>
      'Cette opération sera archivée et masquée de votre liste.';

  @override
  String get operationArchiveConfirm => 'Supprimer';

  @override
  String get operationsInteractionHint =>
      'Touchez pour modifier · Balayez à gauche pour supprimer';

  @override
  String get operationsEmptyMessage =>
      'Vous n’avez encore aucun revenu ni aucune dépense.\nAppuyez sur + pour ajouter votre première opération.';

  @override
  String get operationRecurrenceNone => 'Aucune répétition';

  @override
  String get operationRecurrenceDaily => 'Quotidien';

  @override
  String get operationRecurrenceWeekly => 'Hebdomadaire';

  @override
  String get operationRecurrenceBiweekly => 'Toutes les 2 semaines';

  @override
  String get operationRecurrenceMonthly => 'Mensuel';

  @override
  String get operationRecurrenceYearly => 'Annuel';

  @override
  String get operationRecurrenceTitle => 'Répétition';

  @override
  String get operationDescriptionHint => 'Description';

  @override
  String get commonSaving => 'Enregistrement...';

  @override
  String get operationAmountRequired => 'Veuillez saisir un montant valide.';

  @override
  String get operationCategoryRequired => 'Veuillez choisir une catégorie.';

  @override
  String get accountsEmptyMessage =>
      'Vous n\'avez encore aucun compte.\nAppuyez sur + pour créer votre premier compte.';

  @override
  String get accountCreateTitle => 'Créer un compte';

  @override
  String get accountNameHint => 'Nom du compte';

  @override
  String get accountNameRequired => 'Le nom du compte est requis.';

  @override
  String get accountTypeHint => 'Type de compte';

  @override
  String get accountCurrencyHint => 'Devise';

  @override
  String get accountInitialBalanceHint => 'Solde initial';

  @override
  String get accountInitialBalanceRequired => 'Le solde initial est requis.';

  @override
  String get accountInitialBalanceInvalid => 'Entrez un montant valide.';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeBank => 'Banque';

  @override
  String get accountTypeCard => 'Carte';

  @override
  String get accountTypeCreditCard => 'Carte de crédit';

  @override
  String get accountTypeSavings => 'Épargne';

  @override
  String get accountTypeInvestment => 'Investissement';

  @override
  String get accountTypeLoan => 'Prêt';

  @override
  String get accountTypeWallet => 'Portefeuille';

  @override
  String get accountTypeOther => 'Autre';
}
