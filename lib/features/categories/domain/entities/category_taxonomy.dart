import '../enums/category_stable_key.dart';
import '../enums/category_type.dart';
import '../enums/expense_category_group.dart';
import '../enums/income_category_group.dart';
import 'category_definition.dart';

abstract final class CategoryTaxonomy {
  CategoryTaxonomy._();

  static final List<CategoryDefinition> definitions = List.unmodifiable([
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingRent,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1000,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingMortgage,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1010,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingPropertyTax,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1020,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingCondoFees,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1030,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingElectricity,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1040,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingNaturalGas,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1050,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingWater,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1060,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingSewer,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1070,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingGarbageCollection,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1080,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingInternet,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1090,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingMobilePhone,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1100,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingHomePhone,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1110,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingHomeInsurance,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1120,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingHomeMaintenance,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1130,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingFurniture,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1140,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingAppliances,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1150,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingHomeSupplies,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1160,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseHousingHomeSecurity,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.housing,
      sortOrder: 1170,
      iconKey: 'housing',
      colorKey: 'blue',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodGroceries,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2000,
      iconKey: 'groceries',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodFarmersMarket,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2010,
      iconKey: 'groceries',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodRestaurant,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2020,
      iconKey: 'restaurant',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodCafeCoffee,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2030,
      iconKey: 'restaurant',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodFastFood,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2040,
      iconKey: 'restaurant',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodFoodDelivery,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2050,
      iconKey: 'restaurant',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodSnacks,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2060,
      iconKey: 'groceries',
      colorKey: 'green',
    ),
    const CategoryDefinition(
      key: CategoryStableKey.expenseFoodAlcohol,
      type: CategoryType.expense,
      expenseGroup: ExpenseCategoryGroup.food,
      sortOrder: 2070,
      iconKey: 'restaurant',
      colorKey: 'green',
    ),
    ..._expense(
      ExpenseCategoryGroup.transportation,
      3000,
      'transport',
      'blue',
      [
        CategoryStableKey.expenseTransportationFuel,
        CategoryStableKey.expenseTransportationEvCharging,
        CategoryStableKey.expenseTransportationPublicTransit,
        CategoryStableKey.expenseTransportationTaxiRideSharing,
        CategoryStableKey.expenseTransportationParking,
        CategoryStableKey.expenseTransportationTollRoads,
        CategoryStableKey.expenseTransportationAutoInsurance,
        CategoryStableKey.expenseTransportationAutoLoan,
        CategoryStableKey.expenseTransportationVehicleMaintenance,
        CategoryStableKey.expenseTransportationTireService,
        CategoryStableKey.expenseTransportationVehicleRegistration,
        CategoryStableKey.expenseTransportationCarWash,
      ],
    ),
    ..._expense(ExpenseCategoryGroup.health, 4000, 'health', 'red', [
      CategoryStableKey.expenseHealthPharmacy,
      CategoryStableKey.expenseHealthMedicine,
      CategoryStableKey.expenseHealthDoctor,
      CategoryStableKey.expenseHealthDentist,
      CategoryStableKey.expenseHealthVisionCare,
      CategoryStableKey.expenseHealthMedicalTests,
      CategoryStableKey.expenseHealthMedicalProcedures,
      CategoryStableKey.expenseHealthHealthInsurance,
      CategoryStableKey.expenseHealthMentalHealth,
      CategoryStableKey.expenseHealthPhysiotherapy,
      CategoryStableKey.expenseHealthGymFitness,
      CategoryStableKey.expenseHealthVitamins,
    ]),
    ..._expense(ExpenseCategoryGroup.family, 5000, 'other', 'blue', [
      CategoryStableKey.expenseFamilyChildcare,
      CategoryStableKey.expenseFamilyDaycare,
      CategoryStableKey.expenseFamilySchool,
      CategoryStableKey.expenseFamilyUniversity,
      CategoryStableKey.expenseFamilyTutoring,
      CategoryStableKey.expenseFamilyChildrensClothing,
      CategoryStableKey.expenseFamilyBabySupplies,
      CategoryStableKey.expenseFamilyToys,
      CategoryStableKey.expenseFamilyChildSupport,
    ]),
    ..._expense(ExpenseCategoryGroup.personalCare, 6000, 'shopping', 'blue', [
      CategoryStableKey.expensePersonalCareClothing,
      CategoryStableKey.expensePersonalCareShoes,
      CategoryStableKey.expensePersonalCareCosmetics,
      CategoryStableKey.expensePersonalCareJewelry,
      CategoryStableKey.expensePersonalCareHaircare,
      CategoryStableKey.expensePersonalCareNailCare,
      CategoryStableKey.expensePersonalCarePersonalHygiene,
      CategoryStableKey.expensePersonalCareContactLenses,
    ]),
    ..._expense(
      ExpenseCategoryGroup.entertainmentLifestyle,
      7000,
      'entertainment',
      'blue',
      [
        CategoryStableKey.expenseEntertainmentLifestyleMovies,
        CategoryStableKey.expenseEntertainmentLifestyleTheatre,
        CategoryStableKey.expenseEntertainmentLifestyleConcerts,
        CategoryStableKey.expenseEntertainmentLifestyleGaming,
        CategoryStableKey.expenseEntertainmentLifestyleStreamingSubscriptions,
        CategoryStableKey.expenseEntertainmentLifestyleMusic,
        CategoryStableKey.expenseEntertainmentLifestyleBooks,
        CategoryStableKey.expenseEntertainmentLifestyleHobbies,
        CategoryStableKey.expenseEntertainmentLifestyleTravel,
        CategoryStableKey.expenseEntertainmentLifestyleHotels,
      ],
    ),
    ..._expense(ExpenseCategoryGroup.education, 8000, 'education', 'blue', [
      CategoryStableKey.expenseEducationCourses,
      CategoryStableKey.expenseEducationOnlineLearning,
      CategoryStableKey.expenseEducationUniversityTuition,
      CategoryStableKey.expenseEducationCertifications,
      CategoryStableKey.expenseEducationConferences,
      CategoryStableKey.expenseEducationLanguageCourses,
      CategoryStableKey.expenseEducationEducationalMaterials,
    ]),
    ..._expense(ExpenseCategoryGroup.finance, 9000, 'savings', 'green', [
      CategoryStableKey.expenseFinanceBankFees,
      CategoryStableKey.expenseFinanceAtmFees,
      CategoryStableKey.expenseFinanceCreditCardPayment,
      CategoryStableKey.expenseFinanceLoanPayment,
      CategoryStableKey.expenseFinanceDebtRepayment,
      CategoryStableKey.expenseFinanceSavings,
      CategoryStableKey.expenseFinanceEmergencyFund,
      CategoryStableKey.expenseFinanceTfsaContribution,
      CategoryStableKey.expenseFinanceRrspContribution,
      CategoryStableKey.expenseFinanceRespContribution,
      CategoryStableKey.expenseFinanceInvestments,
      CategoryStableKey.expenseFinanceCurrencyExchange,
    ]),
    ..._expense(ExpenseCategoryGroup.government, 10000, 'other', 'red', [
      CategoryStableKey.expenseGovernmentIncomeTax,
      CategoryStableKey.expenseGovernmentDriverLicence,
      CategoryStableKey.expenseGovernmentPassport,
      CategoryStableKey.expenseGovernmentImmigrationFees,
      CategoryStableKey.expenseGovernmentPermits,
      CategoryStableKey.expenseGovernmentGovernmentServices,
    ]),
    ..._expense(ExpenseCategoryGroup.pets, 11000, 'health', 'green', [
      CategoryStableKey.expensePetsPetFood,
      CategoryStableKey.expensePetsVeterinary,
      CategoryStableKey.expensePetsPetMedicine,
      CategoryStableKey.expensePetsPetInsurance,
      CategoryStableKey.expensePetsGrooming,
      CategoryStableKey.expensePetsPetSupplies,
    ]),
    ..._expense(ExpenseCategoryGroup.giving, 12000, 'other', 'green', [
      CategoryStableKey.expenseGivingGifts,
      CategoryStableKey.expenseGivingCharity,
      CategoryStableKey.expenseGivingDonations,
      CategoryStableKey.expenseGivingHolidayExpenses,
    ]),
    ..._expense(ExpenseCategoryGroup.work, 13000, 'freelance', 'blue', [
      CategoryStableKey.expenseWorkOfficeSupplies,
      CategoryStableKey.expenseWorkSoftware,
      CategoryStableKey.expenseWorkEquipment,
      CategoryStableKey.expenseWorkBusinessTravel,
      CategoryStableKey.expenseWorkProfessionalMemberships,
      CategoryStableKey.expenseWorkLicences,
    ]),
    ..._expense(ExpenseCategoryGroup.other, 14000, 'other', 'blue', [
      CategoryStableKey.expenseOtherCashWithdrawal,
      CategoryStableKey.expenseOtherAdjustment,
      CategoryStableKey.expenseOtherUncategorized,
    ]),
    ..._income(IncomeCategoryGroup.employment, 15000, [
      CategoryStableKey.incomeEmploymentSalary,
      CategoryStableKey.incomeEmploymentBonus,
      CategoryStableKey.incomeEmploymentOvertime,
      CategoryStableKey.incomeEmploymentCommission,
      CategoryStableKey.incomeEmploymentTips,
    ]),
    ..._income(IncomeCategoryGroup.business, 16000, [
      CategoryStableKey.incomeBusinessBusinessIncome,
      CategoryStableKey.incomeBusinessFreelance,
      CategoryStableKey.incomeBusinessConsulting,
      CategoryStableKey.incomeBusinessRentalIncome,
    ]),
    ..._income(IncomeCategoryGroup.investments, 17000, [
      CategoryStableKey.incomeInvestmentsInterestIncome,
      CategoryStableKey.incomeInvestmentsDividendIncome,
      CategoryStableKey.incomeInvestmentsCapitalGains,
      CategoryStableKey.incomeInvestmentsInvestmentDistribution,
    ]),
    ..._income(IncomeCategoryGroup.government, 18000, [
      CategoryStableKey.incomeGovernmentTaxRefund,
      CategoryStableKey.incomeGovernmentGovernmentBenefits,
      CategoryStableKey.incomeGovernmentPension,
      CategoryStableKey.incomeGovernmentChildBenefit,
      CategoryStableKey.incomeGovernmentEmploymentInsurance,
    ]),
    ..._income(IncomeCategoryGroup.gifts, 19000, [
      CategoryStableKey.incomeGiftsGiftReceived,
      CategoryStableKey.incomeGiftsFamilySupport,
      CategoryStableKey.incomeGiftsCashback,
      CategoryStableKey.incomeGiftsRewards,
    ]),
    ..._income(IncomeCategoryGroup.otherIncome, 20000, [
      CategoryStableKey.incomeOtherIncomeRefund,
      CategoryStableKey.incomeOtherIncomeReimbursement,
      CategoryStableKey.incomeOtherIncomeSaleOfItem,
      CategoryStableKey.incomeOtherIncomeOtherIncome,
    ]),
  ]);

  static List<CategoryDefinition> byType(CategoryType type) {
    return definitions
        .where((definition) => definition.type == type)
        .toList(growable: false);
  }

  static CategoryDefinition? definitionFor(CategoryStableKey key) {
    for (final definition in definitions) {
      if (definition.key == key) {
        return definition;
      }
    }

    return null;
  }

  static CategoryDefinition? definitionForStableKey(String stableKey) {
    for (final definition in definitions) {
      if (definition.stableKey == stableKey) {
        return definition;
      }
    }

    return null;
  }
}

List<CategoryDefinition> _expense(
  ExpenseCategoryGroup group,
  int baseSortOrder,
  String iconKey,
  String colorKey,
  List<CategoryStableKey> keys,
) {
  return [
    for (var index = 0; index < keys.length; index += 1)
      CategoryDefinition(
        key: keys[index],
        type: CategoryType.expense,
        expenseGroup: group,
        sortOrder: baseSortOrder + index * 10,
        iconKey: iconKey,
        colorKey: colorKey,
      ),
  ];
}

List<CategoryDefinition> _income(
  IncomeCategoryGroup group,
  int baseSortOrder,
  List<CategoryStableKey> keys,
) {
  return [
    for (var index = 0; index < keys.length; index += 1)
      CategoryDefinition(
        key: keys[index],
        type: CategoryType.income,
        incomeGroup: group,
        sortOrder: baseSortOrder + index * 10,
        iconKey: 'salary',
        colorKey: 'green',
      ),
  ];
}
