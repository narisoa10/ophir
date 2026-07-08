enum CategoryStableKey {
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
  incomeOtherIncomeOtherIncome;

  String toJson() {
    return switch (this) {
      CategoryStableKey.expenseHousingRent => 'expense.housing.rent',
      CategoryStableKey.expenseHousingMortgage => 'expense.housing.mortgage',
      CategoryStableKey.expenseHousingPropertyTax =>
        'expense.housing.property_tax',
      CategoryStableKey.expenseHousingCondoFees =>
        'expense.housing.condo_fees',
      CategoryStableKey.expenseHousingElectricity =>
        'expense.housing.electricity',
      CategoryStableKey.expenseHousingNaturalGas =>
        'expense.housing.natural_gas',
      CategoryStableKey.expenseHousingWater => 'expense.housing.water',
      CategoryStableKey.expenseHousingSewer => 'expense.housing.sewer',
      CategoryStableKey.expenseHousingGarbageCollection =>
        'expense.housing.garbage_collection',
      CategoryStableKey.expenseHousingInternet => 'expense.housing.internet',
      CategoryStableKey.expenseHousingMobilePhone =>
        'expense.housing.mobile_phone',
      CategoryStableKey.expenseHousingHomePhone =>
        'expense.housing.home_phone',
      CategoryStableKey.expenseHousingHomeInsurance =>
        'expense.housing.home_insurance',
      CategoryStableKey.expenseHousingHomeMaintenance =>
        'expense.housing.home_maintenance',
      CategoryStableKey.expenseHousingFurniture =>
        'expense.housing.furniture',
      CategoryStableKey.expenseHousingAppliances =>
        'expense.housing.appliances',
      CategoryStableKey.expenseHousingHomeSupplies =>
        'expense.housing.home_supplies',
      CategoryStableKey.expenseHousingHomeSecurity =>
        'expense.housing.home_security',
      CategoryStableKey.expenseFoodGroceries => 'expense.food.groceries',
      CategoryStableKey.expenseFoodFarmersMarket =>
        'expense.food.farmers_market',
      CategoryStableKey.expenseFoodRestaurant => 'expense.food.restaurant',
      CategoryStableKey.expenseFoodCafeCoffee => 'expense.food.cafe_coffee',
      CategoryStableKey.expenseFoodFastFood => 'expense.food.fast_food',
      CategoryStableKey.expenseFoodFoodDelivery =>
        'expense.food.food_delivery',
      CategoryStableKey.expenseFoodSnacks => 'expense.food.snacks',
      CategoryStableKey.expenseFoodAlcohol => 'expense.food.alcohol',
      CategoryStableKey.expenseTransportationFuel =>
        'expense.transportation.fuel',
      CategoryStableKey.expenseTransportationEvCharging =>
        'expense.transportation.ev_charging',
      CategoryStableKey.expenseTransportationPublicTransit =>
        'expense.transportation.public_transit',
      CategoryStableKey.expenseTransportationTaxiRideSharing =>
        'expense.transportation.taxi_ride_sharing',
      CategoryStableKey.expenseTransportationParking =>
        'expense.transportation.parking',
      CategoryStableKey.expenseTransportationTollRoads =>
        'expense.transportation.toll_roads',
      CategoryStableKey.expenseTransportationAutoInsurance =>
        'expense.transportation.auto_insurance',
      CategoryStableKey.expenseTransportationAutoLoan =>
        'expense.transportation.auto_loan',
      CategoryStableKey.expenseTransportationVehicleMaintenance =>
        'expense.transportation.vehicle_maintenance',
      CategoryStableKey.expenseTransportationTireService =>
        'expense.transportation.tire_service',
      CategoryStableKey.expenseTransportationVehicleRegistration =>
        'expense.transportation.vehicle_registration',
      CategoryStableKey.expenseTransportationCarWash =>
        'expense.transportation.car_wash',
      CategoryStableKey.expenseHealthPharmacy => 'expense.health.pharmacy',
      CategoryStableKey.expenseHealthMedicine => 'expense.health.medicine',
      CategoryStableKey.expenseHealthDoctor => 'expense.health.doctor',
      CategoryStableKey.expenseHealthDentist => 'expense.health.dentist',
      CategoryStableKey.expenseHealthVisionCare =>
        'expense.health.vision_care',
      CategoryStableKey.expenseHealthMedicalTests =>
        'expense.health.medical_tests',
      CategoryStableKey.expenseHealthMedicalProcedures =>
        'expense.health.medical_procedures',
      CategoryStableKey.expenseHealthHealthInsurance =>
        'expense.health.health_insurance',
      CategoryStableKey.expenseHealthMentalHealth =>
        'expense.health.mental_health',
      CategoryStableKey.expenseHealthPhysiotherapy =>
        'expense.health.physiotherapy',
      CategoryStableKey.expenseHealthGymFitness =>
        'expense.health.gym_fitness',
      CategoryStableKey.expenseHealthVitamins => 'expense.health.vitamins',
      CategoryStableKey.expenseFamilyChildcare =>
        'expense.family.childcare',
      CategoryStableKey.expenseFamilyDaycare => 'expense.family.daycare',
      CategoryStableKey.expenseFamilySchool => 'expense.family.school',
      CategoryStableKey.expenseFamilyUniversity =>
        'expense.family.university',
      CategoryStableKey.expenseFamilyTutoring => 'expense.family.tutoring',
      CategoryStableKey.expenseFamilyChildrensClothing =>
        'expense.family.childrens_clothing',
      CategoryStableKey.expenseFamilyBabySupplies =>
        'expense.family.baby_supplies',
      CategoryStableKey.expenseFamilyToys => 'expense.family.toys',
      CategoryStableKey.expenseFamilyChildSupport =>
        'expense.family.child_support',
      CategoryStableKey.expensePersonalCareClothing =>
        'expense.personal_care.clothing',
      CategoryStableKey.expensePersonalCareShoes =>
        'expense.personal_care.shoes',
      CategoryStableKey.expensePersonalCareCosmetics =>
        'expense.personal_care.cosmetics',
      CategoryStableKey.expensePersonalCareJewelry =>
        'expense.personal_care.jewelry',
      CategoryStableKey.expensePersonalCareHaircare =>
        'expense.personal_care.haircare',
      CategoryStableKey.expensePersonalCareNailCare =>
        'expense.personal_care.nail_care',
      CategoryStableKey.expensePersonalCarePersonalHygiene =>
        'expense.personal_care.personal_hygiene',
      CategoryStableKey.expensePersonalCareContactLenses =>
        'expense.personal_care.contact_lenses',
      CategoryStableKey.expenseEntertainmentLifestyleMovies =>
        'expense.entertainment_lifestyle.movies',
      CategoryStableKey.expenseEntertainmentLifestyleTheatre =>
        'expense.entertainment_lifestyle.theatre',
      CategoryStableKey.expenseEntertainmentLifestyleConcerts =>
        'expense.entertainment_lifestyle.concerts',
      CategoryStableKey.expenseEntertainmentLifestyleGaming =>
        'expense.entertainment_lifestyle.gaming',
      CategoryStableKey.expenseEntertainmentLifestyleStreamingSubscriptions =>
        'expense.entertainment_lifestyle.streaming_subscriptions',
      CategoryStableKey.expenseEntertainmentLifestyleMusic =>
        'expense.entertainment_lifestyle.music',
      CategoryStableKey.expenseEntertainmentLifestyleBooks =>
        'expense.entertainment_lifestyle.books',
      CategoryStableKey.expenseEntertainmentLifestyleHobbies =>
        'expense.entertainment_lifestyle.hobbies',
      CategoryStableKey.expenseEntertainmentLifestyleTravel =>
        'expense.entertainment_lifestyle.travel',
      CategoryStableKey.expenseEntertainmentLifestyleHotels =>
        'expense.entertainment_lifestyle.hotels',
      CategoryStableKey.expenseEducationCourses =>
        'expense.education.courses',
      CategoryStableKey.expenseEducationOnlineLearning =>
        'expense.education.online_learning',
      CategoryStableKey.expenseEducationUniversityTuition =>
        'expense.education.university_tuition',
      CategoryStableKey.expenseEducationCertifications =>
        'expense.education.certifications',
      CategoryStableKey.expenseEducationConferences =>
        'expense.education.conferences',
      CategoryStableKey.expenseEducationLanguageCourses =>
        'expense.education.language_courses',
      CategoryStableKey.expenseEducationEducationalMaterials =>
        'expense.education.educational_materials',
      CategoryStableKey.expenseFinanceBankFees =>
        'expense.finance.bank_fees',
      CategoryStableKey.expenseFinanceAtmFees => 'expense.finance.atm_fees',
      CategoryStableKey.expenseFinanceCreditCardPayment =>
        'expense.finance.credit_card_payment',
      CategoryStableKey.expenseFinanceLoanPayment =>
        'expense.finance.loan_payment',
      CategoryStableKey.expenseFinanceDebtRepayment =>
        'expense.finance.debt_repayment',
      CategoryStableKey.expenseFinanceSavings => 'expense.finance.savings',
      CategoryStableKey.expenseFinanceEmergencyFund =>
        'expense.finance.emergency_fund',
      CategoryStableKey.expenseFinanceTfsaContribution =>
        'expense.finance.tfsa_contribution',
      CategoryStableKey.expenseFinanceRrspContribution =>
        'expense.finance.rrsp_contribution',
      CategoryStableKey.expenseFinanceRespContribution =>
        'expense.finance.resp_contribution',
      CategoryStableKey.expenseFinanceInvestments =>
        'expense.finance.investments',
      CategoryStableKey.expenseFinanceCurrencyExchange =>
        'expense.finance.currency_exchange',
      CategoryStableKey.expenseGovernmentIncomeTax =>
        'expense.government.income_tax',
      CategoryStableKey.expenseGovernmentDriverLicence =>
        'expense.government.driver_licence',
      CategoryStableKey.expenseGovernmentPassport =>
        'expense.government.passport',
      CategoryStableKey.expenseGovernmentImmigrationFees =>
        'expense.government.immigration_fees',
      CategoryStableKey.expenseGovernmentPermits =>
        'expense.government.permits',
      CategoryStableKey.expenseGovernmentGovernmentServices =>
        'expense.government.government_services',
      CategoryStableKey.expensePetsPetFood => 'expense.pets.pet_food',
      CategoryStableKey.expensePetsVeterinary => 'expense.pets.veterinary',
      CategoryStableKey.expensePetsPetMedicine =>
        'expense.pets.pet_medicine',
      CategoryStableKey.expensePetsPetInsurance =>
        'expense.pets.pet_insurance',
      CategoryStableKey.expensePetsGrooming => 'expense.pets.grooming',
      CategoryStableKey.expensePetsPetSupplies =>
        'expense.pets.pet_supplies',
      CategoryStableKey.expenseGivingGifts => 'expense.giving.gifts',
      CategoryStableKey.expenseGivingCharity => 'expense.giving.charity',
      CategoryStableKey.expenseGivingDonations => 'expense.giving.donations',
      CategoryStableKey.expenseGivingHolidayExpenses =>
        'expense.giving.holiday_expenses',
      CategoryStableKey.expenseWorkOfficeSupplies =>
        'expense.work.office_supplies',
      CategoryStableKey.expenseWorkSoftware => 'expense.work.software',
      CategoryStableKey.expenseWorkEquipment => 'expense.work.equipment',
      CategoryStableKey.expenseWorkBusinessTravel =>
        'expense.work.business_travel',
      CategoryStableKey.expenseWorkProfessionalMemberships =>
        'expense.work.professional_memberships',
      CategoryStableKey.expenseWorkLicences => 'expense.work.licences',
      CategoryStableKey.expenseOtherCashWithdrawal =>
        'expense.other.cash_withdrawal',
      CategoryStableKey.expenseOtherAdjustment => 'expense.other.adjustment',
      CategoryStableKey.expenseOtherUncategorized =>
        'expense.other.uncategorized',
      CategoryStableKey.incomeEmploymentSalary => 'income.employment.salary',
      CategoryStableKey.incomeEmploymentBonus => 'income.employment.bonus',
      CategoryStableKey.incomeEmploymentOvertime =>
        'income.employment.overtime',
      CategoryStableKey.incomeEmploymentCommission =>
        'income.employment.commission',
      CategoryStableKey.incomeEmploymentTips => 'income.employment.tips',
      CategoryStableKey.incomeBusinessBusinessIncome =>
        'income.business.business_income',
      CategoryStableKey.incomeBusinessFreelance => 'income.business.freelance',
      CategoryStableKey.incomeBusinessConsulting =>
        'income.business.consulting',
      CategoryStableKey.incomeBusinessRentalIncome =>
        'income.business.rental_income',
      CategoryStableKey.incomeInvestmentsInterestIncome =>
        'income.investments.interest_income',
      CategoryStableKey.incomeInvestmentsDividendIncome =>
        'income.investments.dividend_income',
      CategoryStableKey.incomeInvestmentsCapitalGains =>
        'income.investments.capital_gains',
      CategoryStableKey.incomeInvestmentsInvestmentDistribution =>
        'income.investments.investment_distribution',
      CategoryStableKey.incomeGovernmentTaxRefund =>
        'income.government.tax_refund',
      CategoryStableKey.incomeGovernmentGovernmentBenefits =>
        'income.government.government_benefits',
      CategoryStableKey.incomeGovernmentPension =>
        'income.government.pension',
      CategoryStableKey.incomeGovernmentChildBenefit =>
        'income.government.child_benefit',
      CategoryStableKey.incomeGovernmentEmploymentInsurance =>
        'income.government.employment_insurance',
      CategoryStableKey.incomeGiftsGiftReceived =>
        'income.gifts.gift_received',
      CategoryStableKey.incomeGiftsFamilySupport =>
        'income.gifts.family_support',
      CategoryStableKey.incomeGiftsCashback => 'income.gifts.cashback',
      CategoryStableKey.incomeGiftsRewards => 'income.gifts.rewards',
      CategoryStableKey.incomeOtherIncomeRefund => 'income.other.refund',
      CategoryStableKey.incomeOtherIncomeReimbursement =>
        'income.other.reimbursement',
      CategoryStableKey.incomeOtherIncomeSaleOfItem =>
        'income.other.sale_of_item',
      CategoryStableKey.incomeOtherIncomeOtherIncome =>
        'income.other.other_income',
    };
  }
}
