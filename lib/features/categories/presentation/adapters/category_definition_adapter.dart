import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../domain/entities/category_definition.dart';
import '../../domain/enums/category_stable_key.dart';
import '../models/category_definition_presentation.dart';

final class CategoryDefinitionAdapter {
  const CategoryDefinitionAdapter();

  CategoryDefinitionPresentation toPresentation(
    CategoryDefinition definition,
    AppLocalizations l10n,
  ) {
    return CategoryDefinitionPresentation(
      stableKey: definition.stableKey,
      name: _label(definition.key, l10n),
      icon: AppCategoryIcons.fromKey(definition.iconKey),
      color: AppCategoryColors.fromKey(definition.colorKey),
      backgroundColor: AppCategoryColors.backgroundFromKey(definition.colorKey),
      type: definition.type,
      sortOrder: definition.sortOrder,
    );
  }

  String _label(CategoryStableKey key, AppLocalizations l10n) {
    return switch (key) {
      CategoryStableKey.expenseHousingRent =>
        l10n.categoryTaxonomyExpenseHousingRentName,
      CategoryStableKey.expenseHousingMortgage =>
        l10n.categoryTaxonomyExpenseHousingMortgageName,
      CategoryStableKey.expenseHousingPropertyTax =>
        l10n.categoryTaxonomyExpenseHousingPropertyTaxName,
      CategoryStableKey.expenseHousingCondoFees =>
        l10n.categoryTaxonomyExpenseHousingCondoFeesName,
      CategoryStableKey.expenseHousingElectricity =>
        l10n.categoryTaxonomyExpenseHousingElectricityName,
      CategoryStableKey.expenseHousingNaturalGas =>
        l10n.categoryTaxonomyExpenseHousingNaturalGasName,
      CategoryStableKey.expenseHousingWater =>
        l10n.categoryTaxonomyExpenseHousingWaterName,
      CategoryStableKey.expenseHousingSewer =>
        l10n.categoryTaxonomyExpenseHousingSewerName,
      CategoryStableKey.expenseHousingGarbageCollection =>
        l10n.categoryTaxonomyExpenseHousingGarbageCollectionName,
      CategoryStableKey.expenseHousingInternet =>
        l10n.categoryTaxonomyExpenseHousingInternetName,
      CategoryStableKey.expenseHousingMobilePhone =>
        l10n.categoryTaxonomyExpenseHousingMobilePhoneName,
      CategoryStableKey.expenseHousingHomePhone =>
        l10n.categoryTaxonomyExpenseHousingHomePhoneName,
      CategoryStableKey.expenseHousingHomeInsurance =>
        l10n.categoryTaxonomyExpenseHousingHomeInsuranceName,
      CategoryStableKey.expenseHousingHomeMaintenance =>
        l10n.categoryTaxonomyExpenseHousingHomeMaintenanceName,
      CategoryStableKey.expenseHousingFurniture =>
        l10n.categoryTaxonomyExpenseHousingFurnitureName,
      CategoryStableKey.expenseHousingAppliances =>
        l10n.categoryTaxonomyExpenseHousingAppliancesName,
      CategoryStableKey.expenseHousingHomeSupplies =>
        l10n.categoryTaxonomyExpenseHousingHomeSuppliesName,
      CategoryStableKey.expenseHousingHomeSecurity =>
        l10n.categoryTaxonomyExpenseHousingHomeSecurityName,
      CategoryStableKey.expenseFoodGroceries =>
        l10n.categoryTaxonomyExpenseFoodGroceriesName,
      CategoryStableKey.expenseFoodFarmersMarket =>
        l10n.categoryTaxonomyExpenseFoodFarmersMarketName,
      CategoryStableKey.expenseFoodRestaurant =>
        l10n.categoryTaxonomyExpenseFoodRestaurantName,
      CategoryStableKey.expenseFoodCafeCoffee =>
        l10n.categoryTaxonomyExpenseFoodCafeCoffeeName,
      CategoryStableKey.expenseFoodFastFood =>
        l10n.categoryTaxonomyExpenseFoodFastFoodName,
      CategoryStableKey.expenseFoodFoodDelivery =>
        l10n.categoryTaxonomyExpenseFoodFoodDeliveryName,
      CategoryStableKey.expenseFoodSnacks =>
        l10n.categoryTaxonomyExpenseFoodSnacksName,
      CategoryStableKey.expenseFoodAlcohol =>
        l10n.categoryTaxonomyExpenseFoodAlcoholName,
      CategoryStableKey.expenseTransportationFuel =>
        l10n.categoryTaxonomyExpenseTransportationFuelName,
      CategoryStableKey.expenseTransportationEvCharging =>
        l10n.categoryTaxonomyExpenseTransportationEvChargingName,
      CategoryStableKey.expenseTransportationPublicTransit =>
        l10n.categoryTaxonomyExpenseTransportationPublicTransitName,
      CategoryStableKey.expenseTransportationTaxiRideSharing =>
        l10n.categoryTaxonomyExpenseTransportationTaxiRideSharingName,
      CategoryStableKey.expenseTransportationParking =>
        l10n.categoryTaxonomyExpenseTransportationParkingName,
      CategoryStableKey.expenseTransportationTollRoads =>
        l10n.categoryTaxonomyExpenseTransportationTollRoadsName,
      CategoryStableKey.expenseTransportationAutoInsurance =>
        l10n.categoryTaxonomyExpenseTransportationAutoInsuranceName,
      CategoryStableKey.expenseTransportationAutoLoan =>
        l10n.categoryTaxonomyExpenseTransportationAutoLoanName,
      CategoryStableKey.expenseTransportationVehicleMaintenance =>
        l10n.categoryTaxonomyExpenseTransportationVehicleMaintenanceName,
      CategoryStableKey.expenseTransportationTireService =>
        l10n.categoryTaxonomyExpenseTransportationTireServiceName,
      CategoryStableKey.expenseTransportationVehicleRegistration =>
        l10n.categoryTaxonomyExpenseTransportationVehicleRegistrationName,
      CategoryStableKey.expenseTransportationCarWash =>
        l10n.categoryTaxonomyExpenseTransportationCarWashName,
      CategoryStableKey.expenseHealthPharmacy =>
        l10n.categoryTaxonomyExpenseHealthPharmacyName,
      CategoryStableKey.expenseHealthMedicine =>
        l10n.categoryTaxonomyExpenseHealthMedicineName,
      CategoryStableKey.expenseHealthDoctor =>
        l10n.categoryTaxonomyExpenseHealthDoctorName,
      CategoryStableKey.expenseHealthDentist =>
        l10n.categoryTaxonomyExpenseHealthDentistName,
      CategoryStableKey.expenseHealthVisionCare =>
        l10n.categoryTaxonomyExpenseHealthVisionCareName,
      CategoryStableKey.expenseHealthMedicalTests =>
        l10n.categoryTaxonomyExpenseHealthMedicalTestsName,
      CategoryStableKey.expenseHealthMedicalProcedures =>
        l10n.categoryTaxonomyExpenseHealthMedicalProceduresName,
      CategoryStableKey.expenseHealthHealthInsurance =>
        l10n.categoryTaxonomyExpenseHealthHealthInsuranceName,
      CategoryStableKey.expenseHealthMentalHealth =>
        l10n.categoryTaxonomyExpenseHealthMentalHealthName,
      CategoryStableKey.expenseHealthPhysiotherapy =>
        l10n.categoryTaxonomyExpenseHealthPhysiotherapyName,
      CategoryStableKey.expenseHealthGymFitness =>
        l10n.categoryTaxonomyExpenseHealthGymFitnessName,
      CategoryStableKey.expenseHealthVitamins =>
        l10n.categoryTaxonomyExpenseHealthVitaminsName,
      CategoryStableKey.expenseFamilyChildcare =>
        l10n.categoryTaxonomyExpenseFamilyChildcareName,
      CategoryStableKey.expenseFamilyDaycare =>
        l10n.categoryTaxonomyExpenseFamilyDaycareName,
      CategoryStableKey.expenseFamilySchool =>
        l10n.categoryTaxonomyExpenseFamilySchoolName,
      CategoryStableKey.expenseFamilyUniversity =>
        l10n.categoryTaxonomyExpenseFamilyUniversityName,
      CategoryStableKey.expenseFamilyTutoring =>
        l10n.categoryTaxonomyExpenseFamilyTutoringName,
      CategoryStableKey.expenseFamilyChildrensClothing =>
        l10n.categoryTaxonomyExpenseFamilyChildrensClothingName,
      CategoryStableKey.expenseFamilyBabySupplies =>
        l10n.categoryTaxonomyExpenseFamilyBabySuppliesName,
      CategoryStableKey.expenseFamilyToys =>
        l10n.categoryTaxonomyExpenseFamilyToysName,
      CategoryStableKey.expenseFamilyChildSupport =>
        l10n.categoryTaxonomyExpenseFamilyChildSupportName,
      CategoryStableKey.expensePersonalCareClothing =>
        l10n.categoryTaxonomyExpensePersonalCareClothingName,
      CategoryStableKey.expensePersonalCareShoes =>
        l10n.categoryTaxonomyExpensePersonalCareShoesName,
      CategoryStableKey.expensePersonalCareCosmetics =>
        l10n.categoryTaxonomyExpensePersonalCareCosmeticsName,
      CategoryStableKey.expensePersonalCareJewelry =>
        l10n.categoryTaxonomyExpensePersonalCareJewelryName,
      CategoryStableKey.expensePersonalCareHaircare =>
        l10n.categoryTaxonomyExpensePersonalCareHaircareName,
      CategoryStableKey.expensePersonalCareNailCare =>
        l10n.categoryTaxonomyExpensePersonalCareNailCareName,
      CategoryStableKey.expensePersonalCarePersonalHygiene =>
        l10n.categoryTaxonomyExpensePersonalCarePersonalHygieneName,
      CategoryStableKey.expensePersonalCareContactLenses =>
        l10n.categoryTaxonomyExpensePersonalCareContactLensesName,
      CategoryStableKey.expenseEntertainmentLifestyleMovies =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleMoviesName,
      CategoryStableKey.expenseEntertainmentLifestyleTheatre =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleTheatreName,
      CategoryStableKey.expenseEntertainmentLifestyleConcerts =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleConcertsName,
      CategoryStableKey.expenseEntertainmentLifestyleGaming =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleGamingName,
      CategoryStableKey.expenseEntertainmentLifestyleStreamingSubscriptions =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleStreamingSubscriptionsName,
      CategoryStableKey.expenseEntertainmentLifestyleMusic =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleMusicName,
      CategoryStableKey.expenseEntertainmentLifestyleBooks =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleBooksName,
      CategoryStableKey.expenseEntertainmentLifestyleHobbies =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleHobbiesName,
      CategoryStableKey.expenseEntertainmentLifestyleTravel =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleTravelName,
      CategoryStableKey.expenseEntertainmentLifestyleHotels =>
        l10n.categoryTaxonomyExpenseEntertainmentLifestyleHotelsName,
      CategoryStableKey.expenseEducationCourses =>
        l10n.categoryTaxonomyExpenseEducationCoursesName,
      CategoryStableKey.expenseEducationOnlineLearning =>
        l10n.categoryTaxonomyExpenseEducationOnlineLearningName,
      CategoryStableKey.expenseEducationUniversityTuition =>
        l10n.categoryTaxonomyExpenseEducationUniversityTuitionName,
      CategoryStableKey.expenseEducationCertifications =>
        l10n.categoryTaxonomyExpenseEducationCertificationsName,
      CategoryStableKey.expenseEducationConferences =>
        l10n.categoryTaxonomyExpenseEducationConferencesName,
      CategoryStableKey.expenseEducationLanguageCourses =>
        l10n.categoryTaxonomyExpenseEducationLanguageCoursesName,
      CategoryStableKey.expenseEducationEducationalMaterials =>
        l10n.categoryTaxonomyExpenseEducationEducationalMaterialsName,
      CategoryStableKey.expenseFinanceBankFees =>
        l10n.categoryTaxonomyExpenseFinanceBankFeesName,
      CategoryStableKey.expenseFinanceAtmFees =>
        l10n.categoryTaxonomyExpenseFinanceAtmFeesName,
      CategoryStableKey.expenseFinanceCreditCardPayment =>
        l10n.categoryTaxonomyExpenseFinanceCreditCardPaymentName,
      CategoryStableKey.expenseFinanceLoanPayment =>
        l10n.categoryTaxonomyExpenseFinanceLoanPaymentName,
      CategoryStableKey.expenseFinanceDebtRepayment =>
        l10n.categoryTaxonomyExpenseFinanceDebtRepaymentName,
      CategoryStableKey.expenseFinanceSavings =>
        l10n.categoryTaxonomyExpenseFinanceSavingsName,
      CategoryStableKey.expenseFinanceEmergencyFund =>
        l10n.categoryTaxonomyExpenseFinanceEmergencyFundName,
      CategoryStableKey.expenseFinanceTfsaContribution =>
        l10n.categoryTaxonomyExpenseFinanceTfsaContributionName,
      CategoryStableKey.expenseFinanceRrspContribution =>
        l10n.categoryTaxonomyExpenseFinanceRrspContributionName,
      CategoryStableKey.expenseFinanceRespContribution =>
        l10n.categoryTaxonomyExpenseFinanceRespContributionName,
      CategoryStableKey.expenseFinanceInvestments =>
        l10n.categoryTaxonomyExpenseFinanceInvestmentsName,
      CategoryStableKey.expenseFinanceCurrencyExchange =>
        l10n.categoryTaxonomyExpenseFinanceCurrencyExchangeName,
      CategoryStableKey.expenseGovernmentIncomeTax =>
        l10n.categoryTaxonomyExpenseGovernmentIncomeTaxName,
      CategoryStableKey.expenseGovernmentDriverLicence =>
        l10n.categoryTaxonomyExpenseGovernmentDriverLicenceName,
      CategoryStableKey.expenseGovernmentPassport =>
        l10n.categoryTaxonomyExpenseGovernmentPassportName,
      CategoryStableKey.expenseGovernmentImmigrationFees =>
        l10n.categoryTaxonomyExpenseGovernmentImmigrationFeesName,
      CategoryStableKey.expenseGovernmentPermits =>
        l10n.categoryTaxonomyExpenseGovernmentPermitsName,
      CategoryStableKey.expenseGovernmentGovernmentServices =>
        l10n.categoryTaxonomyExpenseGovernmentGovernmentServicesName,
      CategoryStableKey.expensePetsPetFood =>
        l10n.categoryTaxonomyExpensePetsPetFoodName,
      CategoryStableKey.expensePetsVeterinary =>
        l10n.categoryTaxonomyExpensePetsVeterinaryName,
      CategoryStableKey.expensePetsPetMedicine =>
        l10n.categoryTaxonomyExpensePetsPetMedicineName,
      CategoryStableKey.expensePetsPetInsurance =>
        l10n.categoryTaxonomyExpensePetsPetInsuranceName,
      CategoryStableKey.expensePetsGrooming =>
        l10n.categoryTaxonomyExpensePetsGroomingName,
      CategoryStableKey.expensePetsPetSupplies =>
        l10n.categoryTaxonomyExpensePetsPetSuppliesName,
      CategoryStableKey.expenseGivingGifts =>
        l10n.categoryTaxonomyExpenseGivingGiftsName,
      CategoryStableKey.expenseGivingCharity =>
        l10n.categoryTaxonomyExpenseGivingCharityName,
      CategoryStableKey.expenseGivingDonations =>
        l10n.categoryTaxonomyExpenseGivingDonationsName,
      CategoryStableKey.expenseGivingHolidayExpenses =>
        l10n.categoryTaxonomyExpenseGivingHolidayExpensesName,
      CategoryStableKey.expenseWorkOfficeSupplies =>
        l10n.categoryTaxonomyExpenseWorkOfficeSuppliesName,
      CategoryStableKey.expenseWorkSoftware =>
        l10n.categoryTaxonomyExpenseWorkSoftwareName,
      CategoryStableKey.expenseWorkEquipment =>
        l10n.categoryTaxonomyExpenseWorkEquipmentName,
      CategoryStableKey.expenseWorkBusinessTravel =>
        l10n.categoryTaxonomyExpenseWorkBusinessTravelName,
      CategoryStableKey.expenseWorkProfessionalMemberships =>
        l10n.categoryTaxonomyExpenseWorkProfessionalMembershipsName,
      CategoryStableKey.expenseWorkLicences =>
        l10n.categoryTaxonomyExpenseWorkLicencesName,
      CategoryStableKey.expenseOtherCashWithdrawal =>
        l10n.categoryTaxonomyExpenseOtherCashWithdrawalName,
      CategoryStableKey.expenseOtherAdjustment =>
        l10n.categoryTaxonomyExpenseOtherAdjustmentName,
      CategoryStableKey.expenseOtherUncategorized =>
        l10n.categoryTaxonomyExpenseOtherUncategorizedName,
      CategoryStableKey.incomeEmploymentSalary =>
        l10n.categoryTaxonomyIncomeEmploymentSalaryName,
      CategoryStableKey.incomeEmploymentBonus =>
        l10n.categoryTaxonomyIncomeEmploymentBonusName,
      CategoryStableKey.incomeEmploymentOvertime =>
        l10n.categoryTaxonomyIncomeEmploymentOvertimeName,
      CategoryStableKey.incomeEmploymentCommission =>
        l10n.categoryTaxonomyIncomeEmploymentCommissionName,
      CategoryStableKey.incomeEmploymentTips =>
        l10n.categoryTaxonomyIncomeEmploymentTipsName,
      CategoryStableKey.incomeBusinessBusinessIncome =>
        l10n.categoryTaxonomyIncomeBusinessBusinessIncomeName,
      CategoryStableKey.incomeBusinessFreelance =>
        l10n.categoryTaxonomyIncomeBusinessFreelanceName,
      CategoryStableKey.incomeBusinessConsulting =>
        l10n.categoryTaxonomyIncomeBusinessConsultingName,
      CategoryStableKey.incomeBusinessRentalIncome =>
        l10n.categoryTaxonomyIncomeBusinessRentalIncomeName,
      CategoryStableKey.incomeInvestmentsInterestIncome =>
        l10n.categoryTaxonomyIncomeInvestmentsInterestIncomeName,
      CategoryStableKey.incomeInvestmentsDividendIncome =>
        l10n.categoryTaxonomyIncomeInvestmentsDividendIncomeName,
      CategoryStableKey.incomeInvestmentsCapitalGains =>
        l10n.categoryTaxonomyIncomeInvestmentsCapitalGainsName,
      CategoryStableKey.incomeInvestmentsInvestmentDistribution =>
        l10n.categoryTaxonomyIncomeInvestmentsInvestmentDistributionName,
      CategoryStableKey.incomeGovernmentTaxRefund =>
        l10n.categoryTaxonomyIncomeGovernmentTaxRefundName,
      CategoryStableKey.incomeGovernmentGovernmentBenefits =>
        l10n.categoryTaxonomyIncomeGovernmentGovernmentBenefitsName,
      CategoryStableKey.incomeGovernmentPension =>
        l10n.categoryTaxonomyIncomeGovernmentPensionName,
      CategoryStableKey.incomeGovernmentChildBenefit =>
        l10n.categoryTaxonomyIncomeGovernmentChildBenefitName,
      CategoryStableKey.incomeGovernmentEmploymentInsurance =>
        l10n.categoryTaxonomyIncomeGovernmentEmploymentInsuranceName,
      CategoryStableKey.incomeGiftsGiftReceived =>
        l10n.categoryTaxonomyIncomeGiftsGiftReceivedName,
      CategoryStableKey.incomeGiftsFamilySupport =>
        l10n.categoryTaxonomyIncomeGiftsFamilySupportName,
      CategoryStableKey.incomeGiftsCashback =>
        l10n.categoryTaxonomyIncomeGiftsCashbackName,
      CategoryStableKey.incomeGiftsRewards =>
        l10n.categoryTaxonomyIncomeGiftsRewardsName,
      CategoryStableKey.incomeOtherIncomeRefund =>
        l10n.categoryTaxonomyIncomeOtherIncomeRefundName,
      CategoryStableKey.incomeOtherIncomeReimbursement =>
        l10n.categoryTaxonomyIncomeOtherIncomeReimbursementName,
      CategoryStableKey.incomeOtherIncomeSaleOfItem =>
        l10n.categoryTaxonomyIncomeOtherIncomeSaleOfItemName,
      CategoryStableKey.incomeOtherIncomeOtherIncome =>
        l10n.categoryTaxonomyIncomeOtherIncomeOtherIncomeName,
    };
  }
}
