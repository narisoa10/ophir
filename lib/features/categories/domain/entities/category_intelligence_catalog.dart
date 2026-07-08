import '../enums/category_stable_key.dart';
import '../enums/category_type.dart';
import '../enums/financial_action_semantics.dart';
import '../enums/financial_impact.dart';
import '../enums/spending_pattern.dart';
import '../enums/spending_role.dart';
import 'category_intelligence_profile.dart';

abstract final class CategoryIntelligenceCatalog {
  CategoryIntelligenceCatalog._();

  static final Map<CategoryStableKey, CategoryIntelligenceProfile>
  profiles = Map.unmodifiable({
    ..._expense(
      role: SpendingRole.mandatory,
      pattern: SpendingPattern.usuallyRecurring,
      keys: const [
        CategoryStableKey.expenseHousingRent,
        CategoryStableKey.expenseHousingMortgage,
        CategoryStableKey.expenseHousingCondoFees,
        CategoryStableKey.expenseHousingElectricity,
        CategoryStableKey.expenseHousingNaturalGas,
        CategoryStableKey.expenseHousingWater,
        CategoryStableKey.expenseHousingSewer,
        CategoryStableKey.expenseHousingGarbageCollection,
        CategoryStableKey.expenseHousingInternet,
        CategoryStableKey.expenseHousingMobilePhone,
        CategoryStableKey.expenseHousingHomePhone,
        CategoryStableKey.expenseHousingHomeInsurance,
        CategoryStableKey.expenseHousingHomeSecurity,
        CategoryStableKey.expenseTransportationAutoInsurance,
        CategoryStableKey.expenseTransportationAutoLoan,
        CategoryStableKey.expenseHealthHealthInsurance,
        CategoryStableKey.expenseFamilyChildcare,
        CategoryStableKey.expenseFamilyDaycare,
        CategoryStableKey.expenseFamilyChildSupport,
      ],
    ),
    ..._expense(
      role: SpendingRole.mandatory,
      pattern: SpendingPattern.usuallyVariable,
      keys: const [
        CategoryStableKey.expenseFoodGroceries,
        CategoryStableKey.expenseFoodFarmersMarket,
        CategoryStableKey.expenseTransportationFuel,
        CategoryStableKey.expenseTransportationEvCharging,
        CategoryStableKey.expenseTransportationPublicTransit,
        CategoryStableKey.expenseHealthPharmacy,
        CategoryStableKey.expenseHealthMedicine,
        CategoryStableKey.expensePersonalCarePersonalHygiene,
        CategoryStableKey.expensePersonalCareContactLenses,
        CategoryStableKey.expensePetsPetFood,
      ],
    ),
    ..._expense(
      role: SpendingRole.mandatory,
      pattern: SpendingPattern.periodic,
      keys: const [
        CategoryStableKey.expenseHousingPropertyTax,
        CategoryStableKey.expenseTransportationVehicleRegistration,
        CategoryStableKey.expenseHealthDoctor,
        CategoryStableKey.expenseHealthDentist,
        CategoryStableKey.expenseHealthVisionCare,
        CategoryStableKey.expenseHealthMedicalTests,
        CategoryStableKey.expenseHealthMedicalProcedures,
        CategoryStableKey.expenseFamilySchool,
        CategoryStableKey.expenseFamilyUniversity,
        CategoryStableKey.expenseEducationUniversityTuition,
        CategoryStableKey.expenseGovernmentIncomeTax,
        CategoryStableKey.expenseGovernmentDriverLicence,
        CategoryStableKey.expenseGovernmentPassport,
        CategoryStableKey.expenseGovernmentImmigrationFees,
        CategoryStableKey.expenseGovernmentPermits,
        CategoryStableKey.expenseGovernmentGovernmentServices,
      ],
    ),
    ..._expense(
      role: SpendingRole.flexible,
      pattern: SpendingPattern.usuallyVariable,
      keys: const [
        CategoryStableKey.expenseHousingHomeSupplies,
        CategoryStableKey.expenseTransportationTaxiRideSharing,
        CategoryStableKey.expenseTransportationParking,
        CategoryStableKey.expenseTransportationTollRoads,
        CategoryStableKey.expenseTransportationCarWash,
        CategoryStableKey.expenseHealthVitamins,
        CategoryStableKey.expenseFamilyChildrensClothing,
        CategoryStableKey.expenseFamilyBabySupplies,
        CategoryStableKey.expensePersonalCareClothing,
        CategoryStableKey.expensePersonalCareShoes,
        CategoryStableKey.expensePersonalCareCosmetics,
        CategoryStableKey.expensePersonalCareHaircare,
        CategoryStableKey.expensePersonalCareNailCare,
        CategoryStableKey.expenseFinanceBankFees,
        CategoryStableKey.expenseFinanceAtmFees,
        CategoryStableKey.expensePetsPetMedicine,
        CategoryStableKey.expensePetsPetSupplies,
        CategoryStableKey.expenseOtherUncategorized,
      ],
    ),
    ..._expense(
      role: SpendingRole.flexible,
      pattern: SpendingPattern.periodic,
      keys: const [
        CategoryStableKey.expenseHousingHomeMaintenance,
        CategoryStableKey.expenseTransportationVehicleMaintenance,
        CategoryStableKey.expenseTransportationTireService,
        CategoryStableKey.expenseHealthMentalHealth,
        CategoryStableKey.expenseHealthPhysiotherapy,
        CategoryStableKey.expenseHealthGymFitness,
        CategoryStableKey.expenseFamilyTutoring,
        CategoryStableKey.expenseEducationCourses,
        CategoryStableKey.expenseEducationOnlineLearning,
        CategoryStableKey.expenseEducationCertifications,
        CategoryStableKey.expenseEducationConferences,
        CategoryStableKey.expenseEducationLanguageCourses,
        CategoryStableKey.expenseEducationEducationalMaterials,
        CategoryStableKey.expensePetsVeterinary,
        CategoryStableKey.expensePetsPetInsurance,
        CategoryStableKey.expensePetsGrooming,
        CategoryStableKey.expenseWorkProfessionalMemberships,
        CategoryStableKey.expenseWorkLicences,
      ],
    ),
    ..._expense(
      role: SpendingRole.flexible,
      pattern: SpendingPattern.usuallyOneOff,
      keys: const [
        CategoryStableKey.expenseHousingFurniture,
        CategoryStableKey.expenseHousingAppliances,
        CategoryStableKey.expenseFamilyToys,
        CategoryStableKey.expensePersonalCareJewelry,
        CategoryStableKey.expenseWorkOfficeSupplies,
        CategoryStableKey.expenseWorkSoftware,
        CategoryStableKey.expenseWorkEquipment,
        CategoryStableKey.expenseWorkBusinessTravel,
      ],
    ),
    ..._expense(
      role: SpendingRole.flexible,
      pattern: SpendingPattern.requiresTransactionEvidence,
      keys: const [CategoryStableKey.expenseFinanceCurrencyExchange],
    ),
    ..._expense(
      role: SpendingRole.discretionary,
      pattern: SpendingPattern.usuallyVariable,
      keys: const [
        CategoryStableKey.expenseFoodRestaurant,
        CategoryStableKey.expenseFoodCafeCoffee,
        CategoryStableKey.expenseFoodFastFood,
        CategoryStableKey.expenseFoodFoodDelivery,
        CategoryStableKey.expenseFoodSnacks,
        CategoryStableKey.expenseFoodAlcohol,
        CategoryStableKey.expenseEntertainmentLifestyleMovies,
        CategoryStableKey.expenseEntertainmentLifestyleTheatre,
        CategoryStableKey.expenseEntertainmentLifestyleConcerts,
        CategoryStableKey.expenseEntertainmentLifestyleGaming,
        CategoryStableKey.expenseEntertainmentLifestyleMusic,
        CategoryStableKey.expenseEntertainmentLifestyleBooks,
        CategoryStableKey.expenseEntertainmentLifestyleHobbies,
        CategoryStableKey.expenseGivingGifts,
        CategoryStableKey.expenseGivingCharity,
        CategoryStableKey.expenseGivingDonations,
        CategoryStableKey.expenseGivingHolidayExpenses,
      ],
    ),
    ..._expense(
      role: SpendingRole.discretionary,
      pattern: SpendingPattern.usuallyRecurring,
      keys: const [
        CategoryStableKey.expenseEntertainmentLifestyleStreamingSubscriptions,
      ],
    ),
    ..._expense(
      role: SpendingRole.discretionary,
      pattern: SpendingPattern.usuallyOneOff,
      keys: const [
        CategoryStableKey.expenseEntertainmentLifestyleTravel,
        CategoryStableKey.expenseEntertainmentLifestyleHotels,
      ],
    ),
    CategoryStableKey.expenseFinanceSavings: _profile(
      key: CategoryStableKey.expenseFinanceSavings,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.savingsContribution,
    ),
    CategoryStableKey.expenseFinanceEmergencyFund: _profile(
      key: CategoryStableKey.expenseFinanceEmergencyFund,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.emergencyFundContribution,
    ),
    CategoryStableKey.expenseFinanceInvestments: _profile(
      key: CategoryStableKey.expenseFinanceInvestments,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.investmentContribution,
    ),
    CategoryStableKey.expenseFinanceTfsaContribution: _profile(
      key: CategoryStableKey.expenseFinanceTfsaContribution,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.tfsaContribution,
    ),
    CategoryStableKey.expenseFinanceRrspContribution: _profile(
      key: CategoryStableKey.expenseFinanceRrspContribution,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.rrspContribution,
    ),
    CategoryStableKey.expenseFinanceRespContribution: _profile(
      key: CategoryStableKey.expenseFinanceRespContribution,
      type: CategoryType.expense,
      role: SpendingRole.savingOrAssetBuilding,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.assetBuilding,
      action: FinancialActionSemantics.respContribution,
    ),
    CategoryStableKey.expenseFinanceDebtRepayment: _profile(
      key: CategoryStableKey.expenseFinanceDebtRepayment,
      type: CategoryType.expense,
      role: SpendingRole.debtService,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.debtReduction,
      action: FinancialActionSemantics.debtRepayment,
    ),
    CategoryStableKey.expenseFinanceCreditCardPayment: _profile(
      key: CategoryStableKey.expenseFinanceCreditCardPayment,
      type: CategoryType.expense,
      role: SpendingRole.debtService,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.debtReduction,
      action: FinancialActionSemantics.creditCardPayment,
    ),
    CategoryStableKey.expenseFinanceLoanPayment: _profile(
      key: CategoryStableKey.expenseFinanceLoanPayment,
      type: CategoryType.expense,
      role: SpendingRole.debtService,
      pattern: SpendingPattern.usuallyRecurring,
      impact: FinancialImpact.debtReduction,
      action: FinancialActionSemantics.loanPayment,
    ),
    CategoryStableKey.expenseOtherCashWithdrawal: _profile(
      key: CategoryStableKey.expenseOtherCashWithdrawal,
      type: CategoryType.expense,
      role: SpendingRole.nonBudgetFinancialAction,
      pattern: SpendingPattern.requiresTransactionEvidence,
      impact: FinancialImpact.cashMovement,
      action: FinancialActionSemantics.cashWithdrawal,
    ),
    CategoryStableKey.expenseOtherAdjustment: _profile(
      key: CategoryStableKey.expenseOtherAdjustment,
      type: CategoryType.expense,
      role: SpendingRole.nonBudgetFinancialAction,
      pattern: SpendingPattern.requiresTransactionEvidence,
      impact: FinancialImpact.dataAdjustment,
      action: FinancialActionSemantics.adjustment,
    ),
    ..._income(
      pattern: SpendingPattern.usuallyRecurring,
      keys: const [
        CategoryStableKey.incomeEmploymentSalary,
        CategoryStableKey.incomeBusinessRentalIncome,
        CategoryStableKey.incomeGovernmentGovernmentBenefits,
        CategoryStableKey.incomeGovernmentPension,
        CategoryStableKey.incomeGovernmentChildBenefit,
        CategoryStableKey.incomeGovernmentEmploymentInsurance,
        CategoryStableKey.incomeGiftsFamilySupport,
      ],
    ),
    ..._income(
      pattern: SpendingPattern.usuallyVariable,
      keys: const [
        CategoryStableKey.incomeEmploymentBonus,
        CategoryStableKey.incomeEmploymentOvertime,
        CategoryStableKey.incomeEmploymentCommission,
        CategoryStableKey.incomeEmploymentTips,
        CategoryStableKey.incomeBusinessBusinessIncome,
        CategoryStableKey.incomeBusinessFreelance,
        CategoryStableKey.incomeBusinessConsulting,
        CategoryStableKey.incomeInvestmentsInterestIncome,
        CategoryStableKey.incomeInvestmentsDividendIncome,
        CategoryStableKey.incomeInvestmentsInvestmentDistribution,
        CategoryStableKey.incomeGiftsCashback,
        CategoryStableKey.incomeGiftsRewards,
        CategoryStableKey.incomeOtherIncomeOtherIncome,
      ],
    ),
    ..._income(
      pattern: SpendingPattern.usuallyOneOff,
      keys: const [
        CategoryStableKey.incomeInvestmentsCapitalGains,
        CategoryStableKey.incomeGovernmentTaxRefund,
        CategoryStableKey.incomeGiftsGiftReceived,
        CategoryStableKey.incomeOtherIncomeRefund,
        CategoryStableKey.incomeOtherIncomeReimbursement,
        CategoryStableKey.incomeOtherIncomeSaleOfItem,
      ],
    ),
  });

  static CategoryIntelligenceProfile? profileFor(CategoryStableKey key) {
    return profiles[key];
  }
}

Map<CategoryStableKey, CategoryIntelligenceProfile> _expense({
  required SpendingRole role,
  required SpendingPattern pattern,
  required List<CategoryStableKey> keys,
}) {
  return {
    for (final key in keys)
      key: _profile(
        key: key,
        type: CategoryType.expense,
        role: role,
        pattern: pattern,
        impact: FinancialImpact.ordinaryExpense,
        action: FinancialActionSemantics.none,
      ),
  };
}

Map<CategoryStableKey, CategoryIntelligenceProfile> _income({
  required SpendingPattern pattern,
  required List<CategoryStableKey> keys,
}) {
  return {
    for (final key in keys)
      key: _profile(
        key: key,
        type: CategoryType.income,
        role: SpendingRole.income,
        pattern: pattern,
        impact: FinancialImpact.income,
        action: FinancialActionSemantics.none,
      ),
  };
}

CategoryIntelligenceProfile _profile({
  required CategoryStableKey key,
  required CategoryType type,
  required SpendingRole role,
  required SpendingPattern pattern,
  required FinancialImpact impact,
  required FinancialActionSemantics action,
}) {
  return CategoryIntelligenceProfile(
    stableKey: key,
    type: type,
    spendingRole: role,
    spendingPattern: pattern,
    financialImpact: impact,
    financialActionSemantics: action,
  );
}
