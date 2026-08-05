import '../icons/app_category_icons.dart';
import '../localization/generated/app_localizations.dart';

enum AppCategoryId {
  expenseHousingRent,
  expenseHousingMortgage,
  expenseHousingPropertyTax,
  expenseHousingCondoFees,
  expenseHousingElectricity,
  expenseHousingNaturalGas,
  expenseHousingWater,
  expenseHousingSewer,
  expenseHousingGarbageCollection,
  expenseHousingInternet,
  expenseHousingMobilePhone,
  expenseHousingHomePhone,
  expenseHousingHomeInsurance,
  expenseHousingHomeMaintenance,
  expenseHousingFurniture,
  expenseHousingAppliances,
  expenseHousingHomeSupplies,
  expenseHousingHomeSecurity,
  expenseFoodGroceries,
  expenseFoodFarmersMarket,
  expenseFoodRestaurant,
  expenseFoodCafeCoffee,
  expenseFoodFastFood,
  expenseFoodFoodDelivery,
  expenseFoodSnacks,
  expenseFoodAlcohol,
  expenseTransportationFuel,
  expenseTransportationEvCharging,
  expenseTransportationPublicTransit,
  expenseTransportationTaxiRideSharing,
  expenseTransportationParking,
  expenseTransportationTollRoads,
  expenseTransportationAutoInsurance,
  expenseTransportationAutoLoan,
  expenseTransportationVehicleMaintenance,
  expenseTransportationTireService,
  expenseTransportationVehicleRegistration,
  expenseTransportationCarWash,
  expenseHealthPharmacy,
  expenseHealthMedicine,
  expenseHealthDoctor,
  expenseHealthDentist,
  expenseHealthVisionCare,
  expenseHealthMedicalTests,
  expenseHealthMedicalProcedures,
  expenseHealthHealthInsurance,
  expenseHealthMentalHealth,
  expenseHealthPhysiotherapy,
  expenseHealthGymFitness,
  expenseHealthVitamins,
  expenseFamilyChildcare,
  expenseFamilyDaycare,
  expenseFamilySchool,
  expenseFamilyUniversity,
  expenseFamilyTutoring,
  expenseFamilyChildrensClothing,
  expenseFamilyBabySupplies,
  expenseFamilyToys,
  expenseFamilyChildSupport,
  expensePersonalCareClothing,
  expensePersonalCareShoes,
  expensePersonalCareCosmetics,
  expensePersonalCareJewelry,
  expensePersonalCareHaircare,
  expensePersonalCareNailCare,
  expensePersonalCarePersonalHygiene,
  expensePersonalCareContactLenses,
  expenseEntertainmentLifestyleMovies,
  expenseEntertainmentLifestyleTheatre,
  expenseEntertainmentLifestyleConcerts,
  expenseEntertainmentLifestyleGaming,
  expenseEntertainmentLifestyleStreamingSubscriptions,
  expenseEntertainmentLifestyleMusic,
  expenseEntertainmentLifestyleBooks,
  expenseEntertainmentLifestyleHobbies,
  expenseEntertainmentLifestyleTravel,
  expenseEntertainmentLifestyleHotels,
  expenseEducationCourses,
  expenseEducationOnlineLearning,
  expenseEducationUniversityTuition,
  expenseEducationCertifications,
  expenseEducationConferences,
  expenseEducationLanguageCourses,
  expenseEducationEducationalMaterials,
  expenseFinanceBankFees,
  expenseFinanceAtmFees,
  expenseFinanceCreditCardPayment,
  expenseFinanceLoanPayment,
  expenseFinanceDebtRepayment,
  expenseFinanceSavings,
  expenseFinanceEmergencyFund,
  expenseFinanceTfsaContribution,
  expenseFinanceRrspContribution,
  expenseFinanceRespContribution,
  expenseFinanceInvestments,
  expenseFinanceCurrencyExchange,
  expenseGovernmentIncomeTax,
  expenseGovernmentDriverLicence,
  expenseGovernmentPassport,
  expenseGovernmentImmigrationFees,
  expenseGovernmentPermits,
  expenseGovernmentGovernmentServices,
  expensePetsPetFood,
  expensePetsVeterinary,
  expensePetsPetMedicine,
  expensePetsPetInsurance,
  expensePetsGrooming,
  expensePetsPetSupplies,
  expenseGivingTithe,
  expenseGivingGifts,
  expenseGivingCharity,
  expenseGivingDonations,
  expenseGivingHolidayExpenses,
  expenseWorkOfficeSupplies,
  expenseWorkSoftware,
  expenseWorkEquipment,
  expenseWorkBusinessTravel,
  expenseWorkProfessionalMemberships,
  expenseWorkLicences,
  expenseOtherCashWithdrawal,
  expenseOtherAdjustment,
  expenseOtherUncategorized,
  incomeEmploymentSalary,
  incomeEmploymentBonus,
  incomeEmploymentOvertime,
  incomeEmploymentCommission,
  incomeEmploymentTips,
  incomeBusinessBusinessIncome,
  incomeBusinessFreelance,
  incomeBusinessConsulting,
  incomeBusinessRentalIncome,
  incomeInvestmentsInterestIncome,
  incomeInvestmentsDividendIncome,
  incomeInvestmentsCapitalGains,
  incomeInvestmentsInvestmentDistribution,
  incomeGovernmentTaxRefund,
  incomeGovernmentGovernmentBenefits,
  incomeGovernmentPension,
  incomeGovernmentChildBenefit,
  incomeGovernmentEmploymentInsurance,
  incomeGiftsGiftReceived,
  incomeGiftsFamilySupport,
  incomeGiftsCashback,
  incomeGiftsRewards,
  incomeOtherIncomeRefund,
  incomeOtherIncomeReimbursement,
  incomeOtherIncomeSaleOfItem,
  incomeOtherIncomeOtherIncome,
}

enum AppCategoryType { expense, income }

enum AppCategoryGroup {
  housing,
  food,
  transportation,
  health,
  family,
  personalCare,
  entertainmentLifestyle,
  education,
  finance,
  governmentExpense,
  pets,
  giving,
  work,
  otherExpense,
  employmentIncome,
  businessIncome,
  investmentIncome,
  governmentIncome,
  giftsIncome,
  otherIncome,
}

enum AppCategoryRole {
  mandatory,
  flexible,
  want,
  debtPayment,
  saving,
  investment,
  transfer,
  income,
  other,
}

final class AppCategory {
  const AppCategory({
    required this.id,
    required this.type,
    required this.group,
    required this.role,
    required this.iconKey,
    required this.colorKey,
  });

  final AppCategoryId id;
  final AppCategoryType type;
  final AppCategoryGroup group;
  final AppCategoryRole role;
  final String iconKey;
  final String colorKey;
}

extension AppCategoryLocalization on AppCategory {
  String name(AppLocalizations l10n) {
    return switch (id) {
      AppCategoryId.expenseHousingRent =>
        l10n.categoryTaxonomyExpenseHousingRentName,
      AppCategoryId.expenseHousingMortgage =>
        l10n.categoryTaxonomyExpenseHousingMortgageName,
      AppCategoryId.expenseHousingPropertyTax =>
        l10n.categoryTaxonomyExpenseHousingPropertyTaxName,
      AppCategoryId.expenseHousingCondoFees =>
        l10n.categoryTaxonomyExpenseHousingCondoFeesName,
      AppCategoryId.expenseHousingElectricity =>
        l10n.categoryTaxonomyExpenseHousingElectricityName,
      AppCategoryId.expenseHousingNaturalGas =>
        l10n.categoryTaxonomyExpenseHousingNaturalGasName,
      AppCategoryId.expenseHousingWater =>
        l10n.categoryTaxonomyExpenseHousingWaterName,
      AppCategoryId.expenseHousingSewer =>
        l10n.categoryTaxonomyExpenseHousingSewerName,
      AppCategoryId.expenseHousingGarbageCollection =>
        l10n.categoryTaxonomyExpenseHousingGarbageCollectionName,
      AppCategoryId.expenseHousingInternet =>
        l10n.categoryTaxonomyExpenseHousingInternetName,
      AppCategoryId.expenseHousingMobilePhone =>
        l10n.categoryTaxonomyExpenseHousingMobilePhoneName,
      AppCategoryId.expenseHousingHomePhone =>
        l10n.categoryTaxonomyExpenseHousingHomePhoneName,
      AppCategoryId.expenseHousingHomeInsurance =>
        l10n.categoryTaxonomyExpenseHousingHomeInsuranceName,
      AppCategoryId.expenseHousingHomeMaintenance =>
        l10n.categoryTaxonomyExpenseHousingHomeMaintenanceName,
      AppCategoryId.expenseHousingFurniture =>
        l10n.categoryTaxonomyExpenseHousingFurnitureName,
      AppCategoryId.expenseHousingAppliances =>
        l10n.categoryTaxonomyExpenseHousingAppliancesName,
      AppCategoryId.expenseHousingHomeSupplies =>
        l10n.categoryTaxonomyExpenseHousingHomeSuppliesName,
      AppCategoryId.expenseHousingHomeSecurity =>
        l10n.categoryTaxonomyExpenseHousingHomeSecurityName,
      AppCategoryId.expenseFoodGroceries =>
        l10n.categoryTaxonomyExpenseFoodGroceriesName,
      AppCategoryId.expenseFoodFarmersMarket =>
        l10n.categoryTaxonomyExpenseFoodFarmersMarketName,
      AppCategoryId.expenseFoodRestaurant =>
        l10n.categoryTaxonomyExpenseFoodRestaurantName,
      AppCategoryId.expenseFoodCafeCoffee =>
        l10n.categoryTaxonomyExpenseFoodCafeCoffeeName,
      AppCategoryId.expenseFoodFastFood =>
        l10n.categoryTaxonomyExpenseFoodFastFoodName,
      AppCategoryId.expenseFoodFoodDelivery =>
        l10n.categoryTaxonomyExpenseFoodFoodDeliveryName,
      AppCategoryId.expenseFoodSnacks =>
        l10n.categoryTaxonomyExpenseFoodSnacksName,
      AppCategoryId.expenseFoodAlcohol =>
        l10n.categoryTaxonomyExpenseFoodAlcoholName,
      AppCategoryId.expenseTransportationFuel =>
        l10n.categoryTaxonomyExpenseTransportationFuelName,
      AppCategoryId.expenseTransportationEvCharging =>
        l10n.categoryTaxonomyExpenseTransportationEvChargingName,
      AppCategoryId.expenseTransportationPublicTransit =>
        l10n.categoryTaxonomyExpenseTransportationPublicTransitName,
      AppCategoryId.expenseTransportationTaxiRideSharing =>
        l10n.categoryTaxonomyExpenseTransportationTaxiRideSharingName,
      AppCategoryId.expenseTransportationParking =>
        l10n.categoryTaxonomyExpenseTransportationParkingName,
      AppCategoryId.expenseTransportationTollRoads =>
        l10n.categoryTaxonomyExpenseTransportationTollRoadsName,
      AppCategoryId.expenseTransportationAutoInsurance =>
        l10n.categoryTaxonomyExpenseTransportationAutoInsuranceName,
      AppCategoryId.expenseTransportationAutoLoan =>
        l10n.categoryTaxonomyExpenseTransportationAutoLoanName,
      AppCategoryId.expenseTransportationVehicleMaintenance =>
        l10n.categoryTaxonomyExpenseTransportationVehicleMaintenanceName,
      AppCategoryId.expenseTransportationTireService =>
        l10n.categoryTaxonomyExpenseTransportationTireServiceName,
      AppCategoryId.expenseTransportationVehicleRegistration =>
        l10n.categoryTaxonomyExpenseTransportationVehicleRegistrationName,
      AppCategoryId.expenseTransportationCarWash =>
        l10n.categoryTaxonomyExpenseTransportationCarWashName,
      AppCategoryId.expenseHealthPharmacy =>
        l10n.categoryTaxonomyExpenseHealthPharmacyName,
      AppCategoryId.expenseHealthMedicine =>
        l10n.categoryTaxonomyExpenseHealthMedicineName,
      AppCategoryId.expenseHealthDoctor =>
        l10n.categoryTaxonomyExpenseHealthDoctorName,
      AppCategoryId.expenseHealthDentist =>
        l10n.categoryTaxonomyExpenseHealthDentistName,
      AppCategoryId.expenseHealthVisionCare =>
        l10n.categoryTaxonomyExpenseHealthVisionCareName,
      AppCategoryId.expenseHealthMedicalTests =>
        l10n.categoryTaxonomyExpenseHealthMedicalTestsName,
      AppCategoryId.expenseHealthMedicalProcedures =>
        l10n.categoryTaxonomyExpenseHealthMedicalProceduresName,
      AppCategoryId.expenseHealthHealthInsurance =>
        l10n.categoryTaxonomyExpenseHealthHealthInsuranceName,
      AppCategoryId.expenseHealthMentalHealth =>
        l10n.categoryTaxonomyExpenseHealthMentalHealthName,
      AppCategoryId.expenseHealthPhysiotherapy =>
        l10n.categoryTaxonomyExpenseHealthPhysiotherapyName,
      AppCategoryId.expenseHealthGymFitness =>
        l10n.categoryTaxonomyExpenseHealthGymFitnessName,
      AppCategoryId.expenseHealthVitamins =>
        l10n.categoryTaxonomyExpenseHealthVitaminsName,
      AppCategoryId.expenseFamilyChildcare =>
        l10n.categoryTaxonomyExpenseFamilyChildcareName,
      AppCategoryId.expenseFamilyDaycare =>
        l10n.categoryTaxonomyExpenseFamilyDaycareName,
      AppCategoryId.expenseFamilySchool =>
        l10n.categoryTaxonomyExpenseFamilySchoolName,
      AppCategoryId.expenseFamilyUniversity =>
        l10n.categoryTaxonomyExpenseFamilyUniversityName,
      AppCategoryId.expenseFamilyTutoring =>
        l10n.categoryTaxonomyExpenseFamilyTutoringName,
      AppCategoryId.expenseFamilyChildrensClothing =>
        l10n.categoryTaxonomyExpenseFamilyChildrensClothingName,
      AppCategoryId.expenseFamilyBabySupplies =>
        l10n.categoryTaxonomyExpenseFamilyBabySuppliesName,
      AppCategoryId.expenseFamilyToys =>
        l10n.categoryTaxonomyExpenseFamilyToysName,
      AppCategoryId.expenseFamilyChildSupport =>
        l10n.categoryTaxonomyExpenseFamilyChildSupportName,
      AppCategoryId.expensePersonalCareClothing =>
        l10n.categoryTaxonomyExpensePersonalCareClothingName,
      AppCategoryId.expensePersonalCareShoes =>
        l10n.categoryTaxonomyExpensePersonalCareShoesName,
      AppCategoryId.expensePersonalCareCosmetics =>
        l10n.categoryTaxonomyExpensePersonalCareCosmeticsName,
      AppCategoryId.expensePersonalCareJewelry =>
        l10n.categoryTaxonomyExpensePersonalCareJewelryName,
      AppCategoryId.expensePersonalCareHaircare =>
        l10n.categoryTaxonomyExpensePersonalCareHaircareName,
      AppCategoryId.expensePersonalCareNailCare =>
        l10n.categoryTaxonomyExpensePersonalCareNailCareName,
      AppCategoryId.expensePersonalCarePersonalHygiene =>
        l10n.categoryTaxonomyExpensePersonalCarePersonalHygieneName,
      AppCategoryId.expensePersonalCareContactLenses =>
        l10n.categoryTaxonomyExpensePersonalCareContactLensesName,
      AppCategoryId.expenseEntertainmentLifestyleMovies =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleMoviesName,
      AppCategoryId.expenseEntertainmentLifestyleTheatre =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleTheatreName,
      AppCategoryId.expenseEntertainmentLifestyleConcerts =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleConcertsName,
      AppCategoryId.expenseEntertainmentLifestyleGaming =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleGamingName,
      AppCategoryId.expenseEntertainmentLifestyleStreamingSubscriptions =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName,
      AppCategoryId.expenseEntertainmentLifestyleMusic =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleMusicName,
      AppCategoryId.expenseEntertainmentLifestyleBooks =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleBooksName,
      AppCategoryId.expenseEntertainmentLifestyleHobbies =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName,
      AppCategoryId.expenseEntertainmentLifestyleTravel =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleTravelName,
      AppCategoryId.expenseEntertainmentLifestyleHotels =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleHotelsName,
      AppCategoryId.expenseEducationCourses =>
        l10n.categoryTaxonomyExpenseEducationCoursesName,
      AppCategoryId.expenseEducationOnlineLearning =>
        l10n.categoryTaxonomyExpenseEducationOnlineLearningName,
      AppCategoryId.expenseEducationUniversityTuition =>
        l10n.categoryTaxonomyExpenseEducationUniversityTuitionName,
      AppCategoryId.expenseEducationCertifications =>
        l10n.categoryTaxonomyExpenseEducationCertificationsName,
      AppCategoryId.expenseEducationConferences =>
        l10n.categoryTaxonomyExpenseEducationConferencesName,
      AppCategoryId.expenseEducationLanguageCourses =>
        l10n.categoryTaxonomyExpenseEducationLanguageCoursesName,
      AppCategoryId.expenseEducationEducationalMaterials =>
        l10n.categoryTaxonomyExpenseEducationEducationalMaterialsName,
      AppCategoryId.expenseFinanceBankFees =>
        l10n.categoryTaxonomyExpenseFinanceBankFeesName,
      AppCategoryId.expenseFinanceAtmFees =>
        l10n.categoryTaxonomyExpenseFinanceAtmFeesName,
      AppCategoryId.expenseFinanceCreditCardPayment =>
        l10n.categoryTaxonomyExpenseFinanceCreditCardPaymentName,
      AppCategoryId.expenseFinanceLoanPayment =>
        l10n.categoryTaxonomyExpenseFinanceLoanPaymentName,
      AppCategoryId.expenseFinanceDebtRepayment =>
        l10n.categoryTaxonomyExpenseFinanceDebtRepaymentName,
      AppCategoryId.expenseFinanceSavings =>
        l10n.categoryTaxonomyExpenseFinanceSavingsName,
      AppCategoryId.expenseFinanceEmergencyFund =>
        l10n.categoryTaxonomyExpenseFinanceEmergencyFundName,
      AppCategoryId.expenseFinanceTfsaContribution =>
        l10n.categoryTaxonomyExpenseFinanceTfsaContributionName,
      AppCategoryId.expenseFinanceRrspContribution =>
        l10n.categoryTaxonomyExpenseFinanceRrspContributionName,
      AppCategoryId.expenseFinanceRespContribution =>
        l10n.categoryTaxonomyExpenseFinanceRespContributionName,
      AppCategoryId.expenseFinanceInvestments =>
        l10n.categoryTaxonomyExpenseFinanceInvestmentsName,
      AppCategoryId.expenseFinanceCurrencyExchange =>
        l10n.categoryTaxonomyExpenseFinanceCurrencyExchangeName,
      AppCategoryId.expenseGovernmentIncomeTax =>
        l10n.categoryTaxonomyExpenseGovernmentIncomeTaxName,
      AppCategoryId.expenseGovernmentDriverLicence =>
        l10n.categoryTaxonomyExpenseGovernmentDriverLicenceName,
      AppCategoryId.expenseGovernmentPassport =>
        l10n.categoryTaxonomyExpenseGovernmentPassportName,
      AppCategoryId.expenseGovernmentImmigrationFees =>
        l10n.categoryTaxonomyExpenseGovernmentImmigrationFeesName,
      AppCategoryId.expenseGovernmentPermits =>
        l10n.categoryTaxonomyExpenseGovernmentPermitsName,
      AppCategoryId.expenseGovernmentGovernmentServices =>
        l10n.categoryTaxonomyExpenseGovernmentGovernmentServicesName,
      AppCategoryId.expensePetsPetFood =>
        l10n.categoryTaxonomyExpensePetsPetFoodName,
      AppCategoryId.expensePetsVeterinary =>
        l10n.categoryTaxonomyExpensePetsVeterinaryName,
      AppCategoryId.expensePetsPetMedicine =>
        l10n.categoryTaxonomyExpensePetsPetMedicineName,
      AppCategoryId.expensePetsPetInsurance =>
        l10n.categoryTaxonomyExpensePetsPetInsuranceName,
      AppCategoryId.expensePetsGrooming =>
        l10n.categoryTaxonomyExpensePetsGroomingName,
      AppCategoryId.expensePetsPetSupplies =>
        l10n.categoryTaxonomyExpensePetsPetSuppliesName,
      AppCategoryId.expenseGivingTithe =>
        l10n.categoryTaxonomyExpenseGivingTitheName,
      AppCategoryId.expenseGivingGifts =>
        l10n.categoryTaxonomyExpenseGivingGiftsName,
      AppCategoryId.expenseGivingCharity =>
        l10n.categoryTaxonomyExpenseGivingCharityName,
      AppCategoryId.expenseGivingDonations =>
        l10n.categoryTaxonomyExpenseGivingDonationsName,
      AppCategoryId.expenseGivingHolidayExpenses =>
        l10n.categoryTaxonomyExpenseGivingHolidayExpensesName,
      AppCategoryId.expenseWorkOfficeSupplies =>
        l10n.categoryTaxonomyExpenseWorkOfficeSuppliesName,
      AppCategoryId.expenseWorkSoftware =>
        l10n.categoryTaxonomyExpenseWorkSoftwareName,
      AppCategoryId.expenseWorkEquipment =>
        l10n.categoryTaxonomyExpenseWorkEquipmentName,
      AppCategoryId.expenseWorkBusinessTravel =>
        l10n.categoryTaxonomyExpenseWorkBusinessTravelName,
      AppCategoryId.expenseWorkProfessionalMemberships =>
        l10n.categoryTaxonomyExpenseWorkProfessionalMembershipsName,
      AppCategoryId.expenseWorkLicences =>
        l10n.categoryTaxonomyExpenseWorkLicencesName,
      AppCategoryId.expenseOtherCashWithdrawal =>
        l10n.categoryTaxonomyExpenseOtherCashWithdrawalName,
      AppCategoryId.expenseOtherAdjustment =>
        l10n.categoryTaxonomyExpenseOtherAdjustmentName,
      AppCategoryId.expenseOtherUncategorized =>
        l10n.categoryTaxonomyExpenseOtherUncategorizedName,
      AppCategoryId.incomeEmploymentSalary =>
        l10n.categoryTaxonomyIncomeEmploymentSalaryName,
      AppCategoryId.incomeEmploymentBonus =>
        l10n.categoryTaxonomyIncomeEmploymentBonusName,
      AppCategoryId.incomeEmploymentOvertime =>
        l10n.categoryTaxonomyIncomeEmploymentOvertimeName,
      AppCategoryId.incomeEmploymentCommission =>
        l10n.categoryTaxonomyIncomeEmploymentCommissionName,
      AppCategoryId.incomeEmploymentTips =>
        l10n.categoryTaxonomyIncomeEmploymentTipsName,
      AppCategoryId.incomeBusinessBusinessIncome =>
        l10n.categoryTaxonomyIncomeBusinessBusinessIncomeName,
      AppCategoryId.incomeBusinessFreelance =>
        l10n.categoryTaxonomyIncomeBusinessFreelanceName,
      AppCategoryId.incomeBusinessConsulting =>
        l10n.categoryTaxonomyIncomeBusinessConsultingName,
      AppCategoryId.incomeBusinessRentalIncome =>
        l10n.categoryTaxonomyIncomeBusinessRentalIncomeName,
      AppCategoryId.incomeInvestmentsInterestIncome =>
        l10n.categoryTaxonomyIncomeInvestmentsInterestIncomeName,
      AppCategoryId.incomeInvestmentsDividendIncome =>
        l10n.categoryTaxonomyIncomeInvestmentsDividendIncomeName,
      AppCategoryId.incomeInvestmentsCapitalGains =>
        l10n.categoryTaxonomyIncomeInvestmentsCapitalGainsName,
      AppCategoryId.incomeInvestmentsInvestmentDistribution =>
        l10n.categoryTaxonomyIncomeInvestmentsInvestmentDistributionName,
      AppCategoryId.incomeGovernmentTaxRefund =>
        l10n.categoryTaxonomyIncomeGovernmentTaxRefundName,
      AppCategoryId.incomeGovernmentGovernmentBenefits =>
        l10n.categoryTaxonomyIncomeGovernmentGovernmentBenefitsName,
      AppCategoryId.incomeGovernmentPension =>
        l10n.categoryTaxonomyIncomeGovernmentPensionName,
      AppCategoryId.incomeGovernmentChildBenefit =>
        l10n.categoryTaxonomyIncomeGovernmentChildBenefitName,
      AppCategoryId.incomeGovernmentEmploymentInsurance =>
        l10n.categoryTaxonomyIncomeGovernmentEmploymentInsuranceName,
      AppCategoryId.incomeGiftsGiftReceived =>
        l10n.categoryTaxonomyIncomeGiftsGiftReceivedName,
      AppCategoryId.incomeGiftsFamilySupport =>
        l10n.categoryTaxonomyIncomeGiftsFamilySupportName,
      AppCategoryId.incomeGiftsCashback =>
        l10n.categoryTaxonomyIncomeGiftsCashbackName,
      AppCategoryId.incomeGiftsRewards =>
        l10n.categoryTaxonomyIncomeGiftsRewardsName,
      AppCategoryId.incomeOtherIncomeRefund =>
        l10n.categoryTaxonomyIncomeOtherIncomeRefundName,
      AppCategoryId.incomeOtherIncomeReimbursement =>
        l10n.categoryTaxonomyIncomeOtherIncomeReimbursementName,
      AppCategoryId.incomeOtherIncomeSaleOfItem =>
        l10n.categoryTaxonomyIncomeOtherIncomeSaleOfItemName,
      AppCategoryId.incomeOtherIncomeOtherIncome =>
        l10n.categoryTaxonomyIncomeOtherIncomeOtherIncomeName,
    };
  }

  String example(AppLocalizations l10n) {
    return l10n.categoryExampleDefault;
  }

  String groupName(AppLocalizations l10n) {
    return switch (group) {
      AppCategoryGroup.housing => l10n.categoryGroupExpenseHousing,
      AppCategoryGroup.food => l10n.categoryGroupExpenseFood,
      AppCategoryGroup.transportation =>
        l10n.categoryGroupExpenseTransportation,
      AppCategoryGroup.health => l10n.categoryGroupExpenseHealth,
      AppCategoryGroup.family => l10n.categoryGroupExpenseFamily,
      AppCategoryGroup.personalCare => l10n.categoryGroupExpensePersonalCare,
      AppCategoryGroup.entertainmentLifestyle =>
        l10n.categoryGroupExpenseEntertainmentLifestyle,
      AppCategoryGroup.education => l10n.categoryGroupExpenseEducation,
      AppCategoryGroup.finance => l10n.categoryGroupExpenseFinance,
      AppCategoryGroup.governmentExpense => l10n.categoryGroupExpenseGovernment,
      AppCategoryGroup.pets => l10n.categoryGroupExpensePets,
      AppCategoryGroup.giving => l10n.categoryGroupExpenseGiving,
      AppCategoryGroup.work => l10n.categoryGroupExpenseWork,
      AppCategoryGroup.otherExpense => l10n.categoryGroupExpenseOther,
      AppCategoryGroup.employmentIncome => l10n.categoryGroupIncomeEmployment,
      AppCategoryGroup.businessIncome => l10n.categoryGroupIncomeBusiness,
      AppCategoryGroup.investmentIncome => l10n.categoryGroupIncomeInvestments,
      AppCategoryGroup.governmentIncome => l10n.categoryGroupIncomeGovernment,
      AppCategoryGroup.giftsIncome => l10n.categoryGroupIncomeGifts,
      AppCategoryGroup.otherIncome => l10n.categoryGroupIncomeOtherIncome,
    };
  }
}

abstract final class AppCategories {
  AppCategories._();

  static const expenseHousingRent = AppCategory(
    id: AppCategoryId.expenseHousingRent,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.rent,
    colorKey: 'blue',
  );

  static const expenseHousingMortgage = AppCategory(
    id: AppCategoryId.expenseHousingMortgage,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.mortgage,
    colorKey: 'blue',
  );

  static const expenseHousingPropertyTax = AppCategory(
    id: AppCategoryId.expenseHousingPropertyTax,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.propertyTax,
    colorKey: 'blue',
  );

  static const expenseHousingCondoFees = AppCategory(
    id: AppCategoryId.expenseHousingCondoFees,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.condoFees,
    colorKey: 'blue',
  );

  static const expenseHousingElectricity = AppCategory(
    id: AppCategoryId.expenseHousingElectricity,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.electricity,
    colorKey: 'blue',
  );

  static const expenseHousingNaturalGas = AppCategory(
    id: AppCategoryId.expenseHousingNaturalGas,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.naturalGas,
    colorKey: 'blue',
  );

  static const expenseHousingWater = AppCategory(
    id: AppCategoryId.expenseHousingWater,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.water,
    colorKey: 'blue',
  );

  static const expenseHousingSewer = AppCategory(
    id: AppCategoryId.expenseHousingSewer,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.sewer,
    colorKey: 'blue',
  );

  static const expenseHousingGarbageCollection = AppCategory(
    id: AppCategoryId.expenseHousingGarbageCollection,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.garbageCollection,
    colorKey: 'blue',
  );

  static const expenseHousingInternet = AppCategory(
    id: AppCategoryId.expenseHousingInternet,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.internet,
    colorKey: 'blue',
  );

  static const expenseHousingMobilePhone = AppCategory(
    id: AppCategoryId.expenseHousingMobilePhone,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.mobilePhone,
    colorKey: 'blue',
  );

  static const expenseHousingHomePhone = AppCategory(
    id: AppCategoryId.expenseHousingHomePhone,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.homePhone,
    colorKey: 'blue',
  );

  static const expenseHousingHomeInsurance = AppCategory(
    id: AppCategoryId.expenseHousingHomeInsurance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.homeInsurance,
    colorKey: 'blue',
  );

  static const expenseHousingHomeMaintenance = AppCategory(
    id: AppCategoryId.expenseHousingHomeMaintenance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.homeMaintenance,
    colorKey: 'blue',
  );

  static const expenseHousingFurniture = AppCategory(
    id: AppCategoryId.expenseHousingFurniture,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.furniture,
    colorKey: 'blue',
  );

  static const expenseHousingAppliances = AppCategory(
    id: AppCategoryId.expenseHousingAppliances,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.appliances,
    colorKey: 'blue',
  );

  static const expenseHousingHomeSupplies = AppCategory(
    id: AppCategoryId.expenseHousingHomeSupplies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.homeSupplies,
    colorKey: 'blue',
  );

  static const expenseHousingHomeSecurity = AppCategory(
    id: AppCategoryId.expenseHousingHomeSecurity,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.housing,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.homeSecurity,
    colorKey: 'blue',
  );

  static const expenseFoodGroceries = AppCategory(
    id: AppCategoryId.expenseFoodGroceries,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.groceries,
    colorKey: 'green',
  );

  static const expenseFoodFarmersMarket = AppCategory(
    id: AppCategoryId.expenseFoodFarmersMarket,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.farmersMarket,
    colorKey: 'green',
  );

  static const expenseFoodRestaurant = AppCategory(
    id: AppCategoryId.expenseFoodRestaurant,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.restaurant,
    colorKey: 'green',
  );

  static const expenseFoodCafeCoffee = AppCategory(
    id: AppCategoryId.expenseFoodCafeCoffee,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.cafe,
    colorKey: 'green',
  );

  static const expenseFoodFastFood = AppCategory(
    id: AppCategoryId.expenseFoodFastFood,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.fastFood,
    colorKey: 'green',
  );

  static const expenseFoodFoodDelivery = AppCategory(
    id: AppCategoryId.expenseFoodFoodDelivery,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.foodDelivery,
    colorKey: 'green',
  );

  static const expenseFoodSnacks = AppCategory(
    id: AppCategoryId.expenseFoodSnacks,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.snacks,
    colorKey: 'green',
  );

  static const expenseFoodAlcohol = AppCategory(
    id: AppCategoryId.expenseFoodAlcohol,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.food,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.alcohol,
    colorKey: 'green',
  );

  static const expenseTransportationFuel = AppCategory(
    id: AppCategoryId.expenseTransportationFuel,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.fuel,
    colorKey: 'blue',
  );

  static const expenseTransportationEvCharging = AppCategory(
    id: AppCategoryId.expenseTransportationEvCharging,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.evCharging,
    colorKey: 'blue',
  );

  static const expenseTransportationPublicTransit = AppCategory(
    id: AppCategoryId.expenseTransportationPublicTransit,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.publicTransit,
    colorKey: 'blue',
  );

  static const expenseTransportationTaxiRideSharing = AppCategory(
    id: AppCategoryId.expenseTransportationTaxiRideSharing,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.taxi,
    colorKey: 'blue',
  );

  static const expenseTransportationParking = AppCategory(
    id: AppCategoryId.expenseTransportationParking,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.parking,
    colorKey: 'blue',
  );

  static const expenseTransportationTollRoads = AppCategory(
    id: AppCategoryId.expenseTransportationTollRoads,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.tollRoads,
    colorKey: 'blue',
  );

  static const expenseTransportationAutoInsurance = AppCategory(
    id: AppCategoryId.expenseTransportationAutoInsurance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.autoInsurance,
    colorKey: 'blue',
  );

  static const expenseTransportationAutoLoan = AppCategory(
    id: AppCategoryId.expenseTransportationAutoLoan,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.debtPayment,
    iconKey: AppCategoryIcons.autoLoan,
    colorKey: 'blue',
  );

  static const expenseTransportationVehicleMaintenance = AppCategory(
    id: AppCategoryId.expenseTransportationVehicleMaintenance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.vehicleMaintenance,
    colorKey: 'blue',
  );

  static const expenseTransportationTireService = AppCategory(
    id: AppCategoryId.expenseTransportationTireService,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.tireService,
    colorKey: 'blue',
  );

  static const expenseTransportationVehicleRegistration = AppCategory(
    id: AppCategoryId.expenseTransportationVehicleRegistration,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.vehicleRegistration,
    colorKey: 'blue',
  );

  static const expenseTransportationCarWash = AppCategory(
    id: AppCategoryId.expenseTransportationCarWash,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.transportation,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.carWash,
    colorKey: 'blue',
  );

  static const expenseHealthPharmacy = AppCategory(
    id: AppCategoryId.expenseHealthPharmacy,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.pharmacy,
    colorKey: 'red',
  );

  static const expenseHealthMedicine = AppCategory(
    id: AppCategoryId.expenseHealthMedicine,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.medicine,
    colorKey: 'red',
  );

  static const expenseHealthDoctor = AppCategory(
    id: AppCategoryId.expenseHealthDoctor,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.doctor,
    colorKey: 'red',
  );

  static const expenseHealthDentist = AppCategory(
    id: AppCategoryId.expenseHealthDentist,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.dentist,
    colorKey: 'red',
  );

  static const expenseHealthVisionCare = AppCategory(
    id: AppCategoryId.expenseHealthVisionCare,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.visionCare,
    colorKey: 'red',
  );

  static const expenseHealthMedicalTests = AppCategory(
    id: AppCategoryId.expenseHealthMedicalTests,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.medicalTests,
    colorKey: 'red',
  );

  static const expenseHealthMedicalProcedures = AppCategory(
    id: AppCategoryId.expenseHealthMedicalProcedures,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.medicalProcedures,
    colorKey: 'red',
  );

  static const expenseHealthHealthInsurance = AppCategory(
    id: AppCategoryId.expenseHealthHealthInsurance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.healthInsurance,
    colorKey: 'red',
  );

  static const expenseHealthMentalHealth = AppCategory(
    id: AppCategoryId.expenseHealthMentalHealth,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.mentalHealth,
    colorKey: 'red',
  );

  static const expenseHealthPhysiotherapy = AppCategory(
    id: AppCategoryId.expenseHealthPhysiotherapy,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.physiotherapy,
    colorKey: 'red',
  );

  static const expenseHealthGymFitness = AppCategory(
    id: AppCategoryId.expenseHealthGymFitness,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.gymFitness,
    colorKey: 'red',
  );

  static const expenseHealthVitamins = AppCategory(
    id: AppCategoryId.expenseHealthVitamins,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.health,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.vitamins,
    colorKey: 'red',
  );

  static const expenseFamilyChildcare = AppCategory(
    id: AppCategoryId.expenseFamilyChildcare,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.childcare,
    colorKey: 'blue',
  );

  static const expenseFamilyDaycare = AppCategory(
    id: AppCategoryId.expenseFamilyDaycare,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.daycare,
    colorKey: 'blue',
  );

  static const expenseFamilySchool = AppCategory(
    id: AppCategoryId.expenseFamilySchool,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.education,
    colorKey: 'blue',
  );

  static const expenseFamilyUniversity = AppCategory(
    id: AppCategoryId.expenseFamilyUniversity,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.university,
    colorKey: 'blue',
  );

  static const expenseFamilyTutoring = AppCategory(
    id: AppCategoryId.expenseFamilyTutoring,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.tutoring,
    colorKey: 'blue',
  );

  static const expenseFamilyChildrensClothing = AppCategory(
    id: AppCategoryId.expenseFamilyChildrensClothing,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.clothing,
    colorKey: 'blue',
  );

  static const expenseFamilyBabySupplies = AppCategory(
    id: AppCategoryId.expenseFamilyBabySupplies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.babySupplies,
    colorKey: 'blue',
  );

  static const expenseFamilyToys = AppCategory(
    id: AppCategoryId.expenseFamilyToys,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.toys,
    colorKey: 'blue',
  );

  static const expenseFamilyChildSupport = AppCategory(
    id: AppCategoryId.expenseFamilyChildSupport,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.family,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.childSupport,
    colorKey: 'blue',
  );

  static const expensePersonalCareClothing = AppCategory(
    id: AppCategoryId.expensePersonalCareClothing,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.clothing,
    colorKey: 'blue',
  );

  static const expensePersonalCareShoes = AppCategory(
    id: AppCategoryId.expensePersonalCareShoes,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.shoes,
    colorKey: 'blue',
  );

  static const expensePersonalCareCosmetics = AppCategory(
    id: AppCategoryId.expensePersonalCareCosmetics,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.cosmetics,
    colorKey: 'blue',
  );

  static const expensePersonalCareJewelry = AppCategory(
    id: AppCategoryId.expensePersonalCareJewelry,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.jewelry,
    colorKey: 'blue',
  );

  static const expensePersonalCareHaircare = AppCategory(
    id: AppCategoryId.expensePersonalCareHaircare,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.haircare,
    colorKey: 'blue',
  );

  static const expensePersonalCareNailCare = AppCategory(
    id: AppCategoryId.expensePersonalCareNailCare,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.nailCare,
    colorKey: 'blue',
  );

  static const expensePersonalCarePersonalHygiene = AppCategory(
    id: AppCategoryId.expensePersonalCarePersonalHygiene,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.personalHygiene,
    colorKey: 'blue',
  );

  static const expensePersonalCareContactLenses = AppCategory(
    id: AppCategoryId.expensePersonalCareContactLenses,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.personalCare,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.contactLenses,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleMovies = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleMovies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.movies,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleTheatre = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleTheatre,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.theatre,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleConcerts = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleConcerts,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.concerts,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleGaming = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleGaming,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.gaming,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleStreamingSubscriptions =
      AppCategory(
        id: AppCategoryId.expenseEntertainmentLifestyleStreamingSubscriptions,
        type: AppCategoryType.expense,
        group: AppCategoryGroup.entertainmentLifestyle,
        role: AppCategoryRole.want,
        iconKey: AppCategoryIcons.streaming,
        colorKey: 'blue',
      );

  static const expenseEntertainmentLifestyleMusic = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleMusic,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.music,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleBooks = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleBooks,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.books,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleHobbies = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleHobbies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.hobbies,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleTravel = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleTravel,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.travel,
    colorKey: 'blue',
  );

  static const expenseEntertainmentLifestyleHotels = AppCategory(
    id: AppCategoryId.expenseEntertainmentLifestyleHotels,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.entertainmentLifestyle,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.hotels,
    colorKey: 'blue',
  );

  static const expenseEducationCourses = AppCategory(
    id: AppCategoryId.expenseEducationCourses,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.courses,
    colorKey: 'blue',
  );

  static const expenseEducationOnlineLearning = AppCategory(
    id: AppCategoryId.expenseEducationOnlineLearning,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.onlineLearning,
    colorKey: 'blue',
  );

  static const expenseEducationUniversityTuition = AppCategory(
    id: AppCategoryId.expenseEducationUniversityTuition,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.universityTuition,
    colorKey: 'blue',
  );

  static const expenseEducationCertifications = AppCategory(
    id: AppCategoryId.expenseEducationCertifications,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.certifications,
    colorKey: 'blue',
  );

  static const expenseEducationConferences = AppCategory(
    id: AppCategoryId.expenseEducationConferences,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.conferences,
    colorKey: 'blue',
  );

  static const expenseEducationLanguageCourses = AppCategory(
    id: AppCategoryId.expenseEducationLanguageCourses,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.languageCourses,
    colorKey: 'blue',
  );

  static const expenseEducationEducationalMaterials = AppCategory(
    id: AppCategoryId.expenseEducationEducationalMaterials,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.education,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.educationalMaterials,
    colorKey: 'blue',
  );

  static const expenseFinanceBankFees = AppCategory(
    id: AppCategoryId.expenseFinanceBankFees,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.bankFees,
    colorKey: 'green',
  );

  static const expenseFinanceAtmFees = AppCategory(
    id: AppCategoryId.expenseFinanceAtmFees,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.atmFees,
    colorKey: 'green',
  );

  static const expenseFinanceCreditCardPayment = AppCategory(
    id: AppCategoryId.expenseFinanceCreditCardPayment,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.debtPayment,
    iconKey: AppCategoryIcons.creditCardPayment,
    colorKey: 'green',
  );

  static const expenseFinanceLoanPayment = AppCategory(
    id: AppCategoryId.expenseFinanceLoanPayment,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.debtPayment,
    iconKey: AppCategoryIcons.loanPayment,
    colorKey: 'green',
  );

  static const expenseFinanceDebtRepayment = AppCategory(
    id: AppCategoryId.expenseFinanceDebtRepayment,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.debtPayment,
    iconKey: AppCategoryIcons.debtRepayment,
    colorKey: 'green',
  );

  static const expenseFinanceSavings = AppCategory(
    id: AppCategoryId.expenseFinanceSavings,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.saving,
    iconKey: AppCategoryIcons.savings,
    colorKey: 'green',
  );

  static const expenseFinanceEmergencyFund = AppCategory(
    id: AppCategoryId.expenseFinanceEmergencyFund,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.saving,
    iconKey: AppCategoryIcons.emergencyFund,
    colorKey: 'green',
  );

  static const expenseFinanceTfsaContribution = AppCategory(
    id: AppCategoryId.expenseFinanceTfsaContribution,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.investments,
    colorKey: 'green',
  );

  static const expenseFinanceRrspContribution = AppCategory(
    id: AppCategoryId.expenseFinanceRrspContribution,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.investments,
    colorKey: 'green',
  );

  static const expenseFinanceRespContribution = AppCategory(
    id: AppCategoryId.expenseFinanceRespContribution,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.investments,
    colorKey: 'green',
  );

  static const expenseFinanceInvestments = AppCategory(
    id: AppCategoryId.expenseFinanceInvestments,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.investments,
    colorKey: 'green',
  );

  static const expenseFinanceCurrencyExchange = AppCategory(
    id: AppCategoryId.expenseFinanceCurrencyExchange,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.finance,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.currencyExchange,
    colorKey: 'green',
  );

  static const expenseGovernmentIncomeTax = AppCategory(
    id: AppCategoryId.expenseGovernmentIncomeTax,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.incomeTax,
    colorKey: 'red',
  );

  static const expenseGovernmentDriverLicence = AppCategory(
    id: AppCategoryId.expenseGovernmentDriverLicence,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.driverLicence,
    colorKey: 'red',
  );

  static const expenseGovernmentPassport = AppCategory(
    id: AppCategoryId.expenseGovernmentPassport,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.passport,
    colorKey: 'red',
  );

  static const expenseGovernmentImmigrationFees = AppCategory(
    id: AppCategoryId.expenseGovernmentImmigrationFees,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.immigrationFees,
    colorKey: 'red',
  );

  static const expenseGovernmentPermits = AppCategory(
    id: AppCategoryId.expenseGovernmentPermits,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.permits,
    colorKey: 'red',
  );

  static const expenseGovernmentGovernmentServices = AppCategory(
    id: AppCategoryId.expenseGovernmentGovernmentServices,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.governmentExpense,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.governmentServices,
    colorKey: 'red',
  );

  static const expensePetsPetFood = AppCategory(
    id: AppCategoryId.expensePetsPetFood,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.petFood,
    colorKey: 'green',
  );

  static const expensePetsVeterinary = AppCategory(
    id: AppCategoryId.expensePetsVeterinary,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.veterinary,
    colorKey: 'green',
  );

  static const expensePetsPetMedicine = AppCategory(
    id: AppCategoryId.expensePetsPetMedicine,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.petMedicine,
    colorKey: 'green',
  );

  static const expensePetsPetInsurance = AppCategory(
    id: AppCategoryId.expensePetsPetInsurance,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.petInsurance,
    colorKey: 'green',
  );

  static const expensePetsGrooming = AppCategory(
    id: AppCategoryId.expensePetsGrooming,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.petGrooming,
    colorKey: 'green',
  );

  static const expensePetsPetSupplies = AppCategory(
    id: AppCategoryId.expensePetsPetSupplies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.pets,
    role: AppCategoryRole.flexible,
    iconKey: AppCategoryIcons.petSupplies,
    colorKey: 'green',
  );

  static const expenseGivingTithe = AppCategory(
    id: AppCategoryId.expenseGivingTithe,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.giving,
    role: AppCategoryRole.mandatory,
    iconKey: AppCategoryIcons.donations,
    colorKey: 'green',
  );
  static const expenseGivingGifts = AppCategory(
    id: AppCategoryId.expenseGivingGifts,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.giving,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.gifts,
    colorKey: 'green',
  );

  static const expenseGivingCharity = AppCategory(
    id: AppCategoryId.expenseGivingCharity,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.giving,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.charity,
    colorKey: 'green',
  );

  static const expenseGivingDonations = AppCategory(
    id: AppCategoryId.expenseGivingDonations,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.giving,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.donations,
    colorKey: 'green',
  );

  static const expenseGivingHolidayExpenses = AppCategory(
    id: AppCategoryId.expenseGivingHolidayExpenses,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.giving,
    role: AppCategoryRole.want,
    iconKey: AppCategoryIcons.holidayExpenses,
    colorKey: 'green',
  );

  static const expenseWorkOfficeSupplies = AppCategory(
    id: AppCategoryId.expenseWorkOfficeSupplies,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.officeSupplies,
    colorKey: 'blue',
  );

  static const expenseWorkSoftware = AppCategory(
    id: AppCategoryId.expenseWorkSoftware,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.software,
    colorKey: 'blue',
  );

  static const expenseWorkEquipment = AppCategory(
    id: AppCategoryId.expenseWorkEquipment,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.equipment,
    colorKey: 'blue',
  );

  static const expenseWorkBusinessTravel = AppCategory(
    id: AppCategoryId.expenseWorkBusinessTravel,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.businessTravel,
    colorKey: 'blue',
  );

  static const expenseWorkProfessionalMemberships = AppCategory(
    id: AppCategoryId.expenseWorkProfessionalMemberships,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.professionalMemberships,
    colorKey: 'blue',
  );

  static const expenseWorkLicences = AppCategory(
    id: AppCategoryId.expenseWorkLicences,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.work,
    role: AppCategoryRole.investment,
    iconKey: AppCategoryIcons.licences,
    colorKey: 'blue',
  );

  static const expenseOtherCashWithdrawal = AppCategory(
    id: AppCategoryId.expenseOtherCashWithdrawal,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.otherExpense,
    role: AppCategoryRole.transfer,
    iconKey: AppCategoryIcons.cashWithdrawal,
    colorKey: 'blue',
  );

  static const expenseOtherAdjustment = AppCategory(
    id: AppCategoryId.expenseOtherAdjustment,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.otherExpense,
    role: AppCategoryRole.other,
    iconKey: AppCategoryIcons.adjustment,
    colorKey: 'blue',
  );

  static const expenseOtherUncategorized = AppCategory(
    id: AppCategoryId.expenseOtherUncategorized,
    type: AppCategoryType.expense,
    group: AppCategoryGroup.otherExpense,
    role: AppCategoryRole.other,
    iconKey: AppCategoryIcons.other,
    colorKey: 'blue',
  );

  static const incomeEmploymentSalary = AppCategory(
    id: AppCategoryId.incomeEmploymentSalary,
    type: AppCategoryType.income,
    group: AppCategoryGroup.employmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.salary,
    colorKey: 'green',
  );

  static const incomeEmploymentBonus = AppCategory(
    id: AppCategoryId.incomeEmploymentBonus,
    type: AppCategoryType.income,
    group: AppCategoryGroup.employmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.bonus,
    colorKey: 'green',
  );

  static const incomeEmploymentOvertime = AppCategory(
    id: AppCategoryId.incomeEmploymentOvertime,
    type: AppCategoryType.income,
    group: AppCategoryGroup.employmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.overtime,
    colorKey: 'green',
  );

  static const incomeEmploymentCommission = AppCategory(
    id: AppCategoryId.incomeEmploymentCommission,
    type: AppCategoryType.income,
    group: AppCategoryGroup.employmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.commission,
    colorKey: 'green',
  );

  static const incomeEmploymentTips = AppCategory(
    id: AppCategoryId.incomeEmploymentTips,
    type: AppCategoryType.income,
    group: AppCategoryGroup.employmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.tips,
    colorKey: 'green',
  );

  static const incomeBusinessBusinessIncome = AppCategory(
    id: AppCategoryId.incomeBusinessBusinessIncome,
    type: AppCategoryType.income,
    group: AppCategoryGroup.businessIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.businessIncome,
    colorKey: 'green',
  );

  static const incomeBusinessFreelance = AppCategory(
    id: AppCategoryId.incomeBusinessFreelance,
    type: AppCategoryType.income,
    group: AppCategoryGroup.businessIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.freelance,
    colorKey: 'green',
  );

  static const incomeBusinessConsulting = AppCategory(
    id: AppCategoryId.incomeBusinessConsulting,
    type: AppCategoryType.income,
    group: AppCategoryGroup.businessIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.consulting,
    colorKey: 'green',
  );

  static const incomeBusinessRentalIncome = AppCategory(
    id: AppCategoryId.incomeBusinessRentalIncome,
    type: AppCategoryType.income,
    group: AppCategoryGroup.businessIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.rentalIncome,
    colorKey: 'green',
  );

  static const incomeInvestmentsInterestIncome = AppCategory(
    id: AppCategoryId.incomeInvestmentsInterestIncome,
    type: AppCategoryType.income,
    group: AppCategoryGroup.investmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.interestIncome,
    colorKey: 'green',
  );

  static const incomeInvestmentsDividendIncome = AppCategory(
    id: AppCategoryId.incomeInvestmentsDividendIncome,
    type: AppCategoryType.income,
    group: AppCategoryGroup.investmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.dividendIncome,
    colorKey: 'green',
  );

  static const incomeInvestmentsCapitalGains = AppCategory(
    id: AppCategoryId.incomeInvestmentsCapitalGains,
    type: AppCategoryType.income,
    group: AppCategoryGroup.investmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.capitalGains,
    colorKey: 'green',
  );

  static const incomeInvestmentsInvestmentDistribution = AppCategory(
    id: AppCategoryId.incomeInvestmentsInvestmentDistribution,
    type: AppCategoryType.income,
    group: AppCategoryGroup.investmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.investmentDistribution,
    colorKey: 'green',
  );

  static const incomeGovernmentTaxRefund = AppCategory(
    id: AppCategoryId.incomeGovernmentTaxRefund,
    type: AppCategoryType.income,
    group: AppCategoryGroup.governmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.taxRefund,
    colorKey: 'green',
  );

  static const incomeGovernmentGovernmentBenefits = AppCategory(
    id: AppCategoryId.incomeGovernmentGovernmentBenefits,
    type: AppCategoryType.income,
    group: AppCategoryGroup.governmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.governmentBenefits,
    colorKey: 'green',
  );

  static const incomeGovernmentPension = AppCategory(
    id: AppCategoryId.incomeGovernmentPension,
    type: AppCategoryType.income,
    group: AppCategoryGroup.governmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.pension,
    colorKey: 'green',
  );

  static const incomeGovernmentChildBenefit = AppCategory(
    id: AppCategoryId.incomeGovernmentChildBenefit,
    type: AppCategoryType.income,
    group: AppCategoryGroup.governmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.childBenefit,
    colorKey: 'green',
  );

  static const incomeGovernmentEmploymentInsurance = AppCategory(
    id: AppCategoryId.incomeGovernmentEmploymentInsurance,
    type: AppCategoryType.income,
    group: AppCategoryGroup.governmentIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.employmentInsurance,
    colorKey: 'green',
  );

  static const incomeGiftsGiftReceived = AppCategory(
    id: AppCategoryId.incomeGiftsGiftReceived,
    type: AppCategoryType.income,
    group: AppCategoryGroup.giftsIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.giftReceived,
    colorKey: 'green',
  );

  static const incomeGiftsFamilySupport = AppCategory(
    id: AppCategoryId.incomeGiftsFamilySupport,
    type: AppCategoryType.income,
    group: AppCategoryGroup.giftsIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.familySupport,
    colorKey: 'green',
  );

  static const incomeGiftsCashback = AppCategory(
    id: AppCategoryId.incomeGiftsCashback,
    type: AppCategoryType.income,
    group: AppCategoryGroup.giftsIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.cashback,
    colorKey: 'green',
  );

  static const incomeGiftsRewards = AppCategory(
    id: AppCategoryId.incomeGiftsRewards,
    type: AppCategoryType.income,
    group: AppCategoryGroup.giftsIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.rewards,
    colorKey: 'green',
  );

  static const incomeOtherIncomeRefund = AppCategory(
    id: AppCategoryId.incomeOtherIncomeRefund,
    type: AppCategoryType.income,
    group: AppCategoryGroup.otherIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.refund,
    colorKey: 'green',
  );

  static const incomeOtherIncomeReimbursement = AppCategory(
    id: AppCategoryId.incomeOtherIncomeReimbursement,
    type: AppCategoryType.income,
    group: AppCategoryGroup.otherIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.reimbursement,
    colorKey: 'green',
  );

  static const incomeOtherIncomeSaleOfItem = AppCategory(
    id: AppCategoryId.incomeOtherIncomeSaleOfItem,
    type: AppCategoryType.income,
    group: AppCategoryGroup.otherIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.saleOfItem,
    colorKey: 'green',
  );

  static const incomeOtherIncomeOtherIncome = AppCategory(
    id: AppCategoryId.incomeOtherIncomeOtherIncome,
    type: AppCategoryType.income,
    group: AppCategoryGroup.otherIncome,
    role: AppCategoryRole.income,
    iconKey: AppCategoryIcons.otherIncome,
    colorKey: 'green',
  );

  static AppCategory? byId(AppCategoryId id) {
    for (final category in all) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }

  static AppCategory? byIdName(String? idName) {
    if (idName == null) {
      return null;
    }

    for (final id in AppCategoryId.values) {
      if (id.name == idName) {
        return byId(id);
      }
    }

    return null;
  }

  static List<AppCategory> get expenseCategories {
    return all
        .where((category) => category.type == AppCategoryType.expense)
        .toList(growable: false);
  }

  static List<AppCategory> get incomeCategories {
    return all
        .where((category) => category.role == AppCategoryRole.income)
        .toList(growable: false);
  }

  static List<AppCategory> get debtPaymentCategories {
    return all
        .where((category) => category.role == AppCategoryRole.debtPayment)
        .toList(growable: false);
  }

  static List<AppCategory> mandatoryExpenseCategories(AppCategoryGroup group) {
    return expenseCategories
        .where(
          (category) =>
              category.group == group &&
              category.role == AppCategoryRole.mandatory,
        )
        .toList(growable: false);
  }

  static Map<AppCategoryGroup, List<AppCategory>> groupByGroup(
    Iterable<AppCategory> categories,
  ) {
    final grouped = <AppCategoryGroup, List<AppCategory>>{};

    for (final category in categories) {
      grouped.putIfAbsent(category.group, () => <AppCategory>[]).add(category);
    }

    return Map<AppCategoryGroup, List<AppCategory>>.unmodifiable(
      grouped.map(
        (group, items) =>
            MapEntry(group, List<AppCategory>.unmodifiable(items)),
      ),
    );
  }

  static const List<AppCategory> all = [
    expenseHousingRent,
    expenseHousingMortgage,
    expenseHousingPropertyTax,
    expenseHousingCondoFees,
    expenseHousingElectricity,
    expenseHousingNaturalGas,
    expenseHousingWater,
    expenseHousingSewer,
    expenseHousingGarbageCollection,
    expenseHousingInternet,
    expenseHousingMobilePhone,
    expenseHousingHomePhone,
    expenseHousingHomeInsurance,
    expenseHousingHomeMaintenance,
    expenseHousingFurniture,
    expenseHousingAppliances,
    expenseHousingHomeSupplies,
    expenseHousingHomeSecurity,
    expenseFoodGroceries,
    expenseFoodFarmersMarket,
    expenseFoodRestaurant,
    expenseFoodCafeCoffee,
    expenseFoodFastFood,
    expenseFoodFoodDelivery,
    expenseFoodSnacks,
    expenseFoodAlcohol,
    expenseTransportationFuel,
    expenseTransportationEvCharging,
    expenseTransportationPublicTransit,
    expenseTransportationTaxiRideSharing,
    expenseTransportationParking,
    expenseTransportationTollRoads,
    expenseTransportationAutoInsurance,
    expenseTransportationAutoLoan,
    expenseTransportationVehicleMaintenance,
    expenseTransportationTireService,
    expenseTransportationVehicleRegistration,
    expenseTransportationCarWash,
    expenseHealthPharmacy,
    expenseHealthMedicine,
    expenseHealthDoctor,
    expenseHealthDentist,
    expenseHealthVisionCare,
    expenseHealthMedicalTests,
    expenseHealthMedicalProcedures,
    expenseHealthHealthInsurance,
    expenseHealthMentalHealth,
    expenseHealthPhysiotherapy,
    expenseHealthGymFitness,
    expenseHealthVitamins,
    expenseFamilyChildcare,
    expenseFamilyDaycare,
    expenseFamilySchool,
    expenseFamilyUniversity,
    expenseFamilyTutoring,
    expenseFamilyChildrensClothing,
    expenseFamilyBabySupplies,
    expenseFamilyToys,
    expenseFamilyChildSupport,
    expensePersonalCareClothing,
    expensePersonalCareShoes,
    expensePersonalCareCosmetics,
    expensePersonalCareJewelry,
    expensePersonalCareHaircare,
    expensePersonalCareNailCare,
    expensePersonalCarePersonalHygiene,
    expensePersonalCareContactLenses,
    expenseEntertainmentLifestyleMovies,
    expenseEntertainmentLifestyleTheatre,
    expenseEntertainmentLifestyleConcerts,
    expenseEntertainmentLifestyleGaming,
    expenseEntertainmentLifestyleStreamingSubscriptions,
    expenseEntertainmentLifestyleMusic,
    expenseEntertainmentLifestyleBooks,
    expenseEntertainmentLifestyleHobbies,
    expenseEntertainmentLifestyleTravel,
    expenseEntertainmentLifestyleHotels,
    expenseEducationCourses,
    expenseEducationOnlineLearning,
    expenseEducationUniversityTuition,
    expenseEducationCertifications,
    expenseEducationConferences,
    expenseEducationLanguageCourses,
    expenseEducationEducationalMaterials,
    expenseFinanceBankFees,
    expenseFinanceAtmFees,
    expenseFinanceCreditCardPayment,
    expenseFinanceLoanPayment,
    expenseFinanceDebtRepayment,
    expenseFinanceSavings,
    expenseFinanceEmergencyFund,
    expenseFinanceTfsaContribution,
    expenseFinanceRrspContribution,
    expenseFinanceRespContribution,
    expenseFinanceInvestments,
    expenseFinanceCurrencyExchange,
    expenseGovernmentIncomeTax,
    expenseGovernmentDriverLicence,
    expenseGovernmentPassport,
    expenseGovernmentImmigrationFees,
    expenseGovernmentPermits,
    expenseGovernmentGovernmentServices,
    expensePetsPetFood,
    expensePetsVeterinary,
    expensePetsPetMedicine,
    expensePetsPetInsurance,
    expensePetsGrooming,
    expensePetsPetSupplies,
    expenseGivingTithe,
    expenseGivingGifts,
    expenseGivingCharity,
    expenseGivingDonations,
    expenseGivingHolidayExpenses,
    expenseWorkOfficeSupplies,
    expenseWorkSoftware,
    expenseWorkEquipment,
    expenseWorkBusinessTravel,
    expenseWorkProfessionalMemberships,
    expenseWorkLicences,
    expenseOtherCashWithdrawal,
    expenseOtherAdjustment,
    expenseOtherUncategorized,
    incomeEmploymentSalary,
    incomeEmploymentBonus,
    incomeEmploymentOvertime,
    incomeEmploymentCommission,
    incomeEmploymentTips,
    incomeBusinessBusinessIncome,
    incomeBusinessFreelance,
    incomeBusinessConsulting,
    incomeBusinessRentalIncome,
    incomeInvestmentsInterestIncome,
    incomeInvestmentsDividendIncome,
    incomeInvestmentsCapitalGains,
    incomeInvestmentsInvestmentDistribution,
    incomeGovernmentTaxRefund,
    incomeGovernmentGovernmentBenefits,
    incomeGovernmentPension,
    incomeGovernmentChildBenefit,
    incomeGovernmentEmploymentInsurance,
    incomeGiftsGiftReceived,
    incomeGiftsFamilySupport,
    incomeGiftsCashback,
    incomeGiftsRewards,
    incomeOtherIncomeRefund,
    incomeOtherIncomeReimbursement,
    incomeOtherIncomeSaleOfItem,
    incomeOtherIncomeOtherIncome,
  ];
}
