alter table public.operations
add column category_key text;

alter table public.budget_income_sources
add column category_key text;

alter table public.budget_obligations
add column category_key text;

with category_mapping(stable_key, app_category_id) as (
  values
    ('expense.housing.rent', 'expenseHousingRent'),
    ('expense.housing.mortgage', 'expenseHousingMortgage'),
    ('expense.housing.property_tax', 'expenseHousingPropertyTax'),
    ('expense.housing.condo_fees', 'expenseHousingCondoFees'),
    ('expense.housing.electricity', 'expenseHousingElectricity'),
    ('expense.housing.natural_gas', 'expenseHousingNaturalGas'),
    ('expense.housing.water', 'expenseHousingWater'),
    ('expense.housing.sewer', 'expenseHousingSewer'),
    ('expense.housing.garbage_collection', 'expenseHousingGarbageCollection'),
    ('expense.housing.internet', 'expenseHousingInternet'),
    ('expense.housing.mobile_phone', 'expenseHousingMobilePhone'),
    ('expense.housing.home_phone', 'expenseHousingHomePhone'),
    ('expense.housing.home_insurance', 'expenseHousingHomeInsurance'),
    ('expense.housing.home_maintenance', 'expenseHousingHomeMaintenance'),
    ('expense.housing.furniture', 'expenseHousingFurniture'),
    ('expense.housing.appliances', 'expenseHousingAppliances'),
    ('expense.housing.home_supplies', 'expenseHousingHomeSupplies'),
    ('expense.housing.home_security', 'expenseHousingHomeSecurity'),
    ('expense.food.groceries', 'expenseFoodGroceries'),
    ('expense.food.farmers_market', 'expenseFoodFarmersMarket'),
    ('expense.food.restaurant', 'expenseFoodRestaurant'),
    ('expense.food.cafe_coffee', 'expenseFoodCafeCoffee'),
    ('expense.food.fast_food', 'expenseFoodFastFood'),
    ('expense.food.food_delivery', 'expenseFoodFoodDelivery'),
    ('expense.food.snacks', 'expenseFoodSnacks'),
    ('expense.food.alcohol', 'expenseFoodAlcohol'),
    ('expense.transportation.fuel', 'expenseTransportationFuel'),
    ('expense.transportation.ev_charging', 'expenseTransportationEvCharging'),
    ('expense.transportation.public_transit', 'expenseTransportationPublicTransit'),
    ('expense.transportation.taxi_ride_sharing', 'expenseTransportationTaxiRideSharing'),
    ('expense.transportation.parking', 'expenseTransportationParking'),
    ('expense.transportation.toll_roads', 'expenseTransportationTollRoads'),
    ('expense.transportation.auto_insurance', 'expenseTransportationAutoInsurance'),
    ('expense.transportation.auto_loan', 'expenseTransportationAutoLoan'),
    ('expense.transportation.vehicle_maintenance', 'expenseTransportationVehicleMaintenance'),
    ('expense.transportation.tire_service', 'expenseTransportationTireService'),
    ('expense.transportation.vehicle_registration', 'expenseTransportationVehicleRegistration'),
    ('expense.transportation.car_wash', 'expenseTransportationCarWash'),
    ('expense.health.pharmacy', 'expenseHealthPharmacy'),
    ('expense.health.medicine', 'expenseHealthMedicine'),
    ('expense.health.doctor', 'expenseHealthDoctor'),
    ('expense.health.dentist', 'expenseHealthDentist'),
    ('expense.health.vision_care', 'expenseHealthVisionCare'),
    ('expense.health.medical_tests', 'expenseHealthMedicalTests'),
    ('expense.health.medical_procedures', 'expenseHealthMedicalProcedures'),
    ('expense.health.health_insurance', 'expenseHealthHealthInsurance'),
    ('expense.health.mental_health', 'expenseHealthMentalHealth'),
    ('expense.health.physiotherapy', 'expenseHealthPhysiotherapy'),
    ('expense.health.gym_fitness', 'expenseHealthGymFitness'),
    ('expense.health.vitamins', 'expenseHealthVitamins'),
    ('expense.family.childcare', 'expenseFamilyChildcare'),
    ('expense.family.daycare', 'expenseFamilyDaycare'),
    ('expense.family.school', 'expenseFamilySchool'),
    ('expense.family.university', 'expenseFamilyUniversity'),
    ('expense.family.tutoring', 'expenseFamilyTutoring'),
    ('expense.family.childrens_clothing', 'expenseFamilyChildrensClothing'),
    ('expense.family.baby_supplies', 'expenseFamilyBabySupplies'),
    ('expense.family.toys', 'expenseFamilyToys'),
    ('expense.family.child_support', 'expenseFamilyChildSupport'),
    ('expense.personal_care.clothing', 'expensePersonalCareClothing'),
    ('expense.personal_care.shoes', 'expensePersonalCareShoes'),
    ('expense.personal_care.cosmetics', 'expensePersonalCareCosmetics'),
    ('expense.personal_care.jewelry', 'expensePersonalCareJewelry'),
    ('expense.personal_care.haircare', 'expensePersonalCareHaircare'),
    ('expense.personal_care.nail_care', 'expensePersonalCareNailCare'),
    ('expense.personal_care.personal_hygiene', 'expensePersonalCarePersonalHygiene'),
    ('expense.personal_care.contact_lenses', 'expensePersonalCareContactLenses'),
    ('expense.entertainment_lifestyle.movies', 'expenseEntertainmentLifestyleMovies'),
    ('expense.entertainment_lifestyle.theatre', 'expenseEntertainmentLifestyleTheatre'),
    ('expense.entertainment_lifestyle.concerts', 'expenseEntertainmentLifestyleConcerts'),
    ('expense.entertainment_lifestyle.gaming', 'expenseEntertainmentLifestyleGaming'),
    ('expense.entertainment_lifestyle.streaming_subscriptions', 'expenseEntertainmentLifestyleStreamingSubscriptions'),
    ('expense.entertainment_lifestyle.music', 'expenseEntertainmentLifestyleMusic'),
    ('expense.entertainment_lifestyle.books', 'expenseEntertainmentLifestyleBooks'),
    ('expense.entertainment_lifestyle.hobbies', 'expenseEntertainmentLifestyleHobbies'),
    ('expense.entertainment_lifestyle.travel', 'expenseEntertainmentLifestyleTravel'),
    ('expense.entertainment_lifestyle.hotels', 'expenseEntertainmentLifestyleHotels'),
    ('expense.education.courses', 'expenseEducationCourses'),
    ('expense.education.online_learning', 'expenseEducationOnlineLearning'),
    ('expense.education.university_tuition', 'expenseEducationUniversityTuition'),
    ('expense.education.certifications', 'expenseEducationCertifications'),
    ('expense.education.conferences', 'expenseEducationConferences'),
    ('expense.education.language_courses', 'expenseEducationLanguageCourses'),
    ('expense.education.educational_materials', 'expenseEducationEducationalMaterials'),
    ('expense.finance.bank_fees', 'expenseFinanceBankFees'),
    ('expense.finance.atm_fees', 'expenseFinanceAtmFees'),
    ('expense.finance.credit_card_payment', 'expenseFinanceCreditCardPayment'),
    ('expense.finance.loan_payment', 'expenseFinanceLoanPayment'),
    ('expense.finance.debt_repayment', 'expenseFinanceDebtRepayment'),
    ('expense.finance.savings', 'expenseFinanceSavings'),
    ('expense.finance.emergency_fund', 'expenseFinanceEmergencyFund'),
    ('expense.finance.tfsa_contribution', 'expenseFinanceTfsaContribution'),
    ('expense.finance.rrsp_contribution', 'expenseFinanceRrspContribution'),
    ('expense.finance.resp_contribution', 'expenseFinanceRespContribution'),
    ('expense.finance.investments', 'expenseFinanceInvestments'),
    ('expense.finance.currency_exchange', 'expenseFinanceCurrencyExchange'),
    ('expense.government.income_tax', 'expenseGovernmentIncomeTax'),
    ('expense.government.driver_licence', 'expenseGovernmentDriverLicence'),
    ('expense.government.passport', 'expenseGovernmentPassport'),
    ('expense.government.immigration_fees', 'expenseGovernmentImmigrationFees'),
    ('expense.government.permits', 'expenseGovernmentPermits'),
    ('expense.government.government_services', 'expenseGovernmentGovernmentServices'),
    ('expense.pets.pet_food', 'expensePetsPetFood'),
    ('expense.pets.veterinary', 'expensePetsVeterinary'),
    ('expense.pets.pet_medicine', 'expensePetsPetMedicine'),
    ('expense.pets.pet_insurance', 'expensePetsPetInsurance'),
    ('expense.pets.grooming', 'expensePetsGrooming'),
    ('expense.pets.pet_supplies', 'expensePetsPetSupplies'),
    ('expense.giving.tithe', 'expenseGivingTithe'),
    ('expense.giving.gifts', 'expenseGivingGifts'),
    ('expense.giving.charity', 'expenseGivingCharity'),
    ('expense.giving.donations', 'expenseGivingDonations'),
    ('expense.giving.holiday_expenses', 'expenseGivingHolidayExpenses'),
    ('expense.work.office_supplies', 'expenseWorkOfficeSupplies'),
    ('expense.work.software', 'expenseWorkSoftware'),
    ('expense.work.equipment', 'expenseWorkEquipment'),
    ('expense.work.business_travel', 'expenseWorkBusinessTravel'),
    ('expense.work.professional_memberships', 'expenseWorkProfessionalMemberships'),
    ('expense.work.licences', 'expenseWorkLicences'),
    ('expense.other.cash_withdrawal', 'expenseOtherCashWithdrawal'),
    ('expense.other.adjustment', 'expenseOtherAdjustment'),
    ('expense.other.uncategorized', 'expenseOtherUncategorized'),
    ('income.employment.salary', 'incomeEmploymentSalary'),
    ('income.employment.bonus', 'incomeEmploymentBonus'),
    ('income.employment.overtime', 'incomeEmploymentOvertime'),
    ('income.employment.commission', 'incomeEmploymentCommission'),
    ('income.employment.tips', 'incomeEmploymentTips'),
    ('income.business.business_income', 'incomeBusinessBusinessIncome'),
    ('income.business.freelance', 'incomeBusinessFreelance'),
    ('income.business.consulting', 'incomeBusinessConsulting'),
    ('income.business.rental_income', 'incomeBusinessRentalIncome'),
    ('income.investments.interest_income', 'incomeInvestmentsInterestIncome'),
    ('income.investments.dividend_income', 'incomeInvestmentsDividendIncome'),
    ('income.investments.capital_gains', 'incomeInvestmentsCapitalGains'),
    ('income.investments.investment_distribution', 'incomeInvestmentsInvestmentDistribution'),
    ('income.government.tax_refund', 'incomeGovernmentTaxRefund'),
    ('income.government.government_benefits', 'incomeGovernmentGovernmentBenefits'),
    ('income.government.pension', 'incomeGovernmentPension'),
    ('income.government.child_benefit', 'incomeGovernmentChildBenefit'),
    ('income.government.employment_insurance', 'incomeGovernmentEmploymentInsurance'),
    ('income.gifts.gift_received', 'incomeGiftsGiftReceived'),
    ('income.gifts.family_support', 'incomeGiftsFamilySupport'),
    ('income.gifts.cashback', 'incomeGiftsCashback'),
    ('income.gifts.rewards', 'incomeGiftsRewards'),
    ('income.other.refund', 'incomeOtherIncomeRefund'),
    ('income.other.reimbursement', 'incomeOtherIncomeReimbursement'),
    ('income.other.sale_of_item', 'incomeOtherIncomeSaleOfItem'),
    ('income.other.other_income', 'incomeOtherIncomeOtherIncome')
)
update public.operations operations
set category_key = category_mapping.app_category_id
from public.categories categories
join category_mapping on category_mapping.stable_key = categories.stable_key
where operations.category_id = categories.id;

with category_mapping(stable_key, app_category_id) as (
  values
    ('expense.housing.rent', 'expenseHousingRent'),
    ('expense.housing.mortgage', 'expenseHousingMortgage'),
    ('expense.housing.property_tax', 'expenseHousingPropertyTax'),
    ('expense.housing.condo_fees', 'expenseHousingCondoFees'),
    ('expense.housing.electricity', 'expenseHousingElectricity'),
    ('expense.housing.natural_gas', 'expenseHousingNaturalGas'),
    ('expense.housing.water', 'expenseHousingWater'),
    ('expense.housing.sewer', 'expenseHousingSewer'),
    ('expense.housing.garbage_collection', 'expenseHousingGarbageCollection'),
    ('expense.housing.internet', 'expenseHousingInternet'),
    ('expense.housing.mobile_phone', 'expenseHousingMobilePhone'),
    ('expense.housing.home_phone', 'expenseHousingHomePhone'),
    ('expense.housing.home_insurance', 'expenseHousingHomeInsurance'),
    ('expense.housing.home_maintenance', 'expenseHousingHomeMaintenance'),
    ('expense.housing.furniture', 'expenseHousingFurniture'),
    ('expense.housing.appliances', 'expenseHousingAppliances'),
    ('expense.housing.home_supplies', 'expenseHousingHomeSupplies'),
    ('expense.housing.home_security', 'expenseHousingHomeSecurity'),
    ('expense.food.groceries', 'expenseFoodGroceries'),
    ('expense.food.farmers_market', 'expenseFoodFarmersMarket'),
    ('expense.food.restaurant', 'expenseFoodRestaurant'),
    ('expense.food.cafe_coffee', 'expenseFoodCafeCoffee'),
    ('expense.food.fast_food', 'expenseFoodFastFood'),
    ('expense.food.food_delivery', 'expenseFoodFoodDelivery'),
    ('expense.food.snacks', 'expenseFoodSnacks'),
    ('expense.food.alcohol', 'expenseFoodAlcohol'),
    ('expense.transportation.fuel', 'expenseTransportationFuel'),
    ('expense.transportation.ev_charging', 'expenseTransportationEvCharging'),
    ('expense.transportation.public_transit', 'expenseTransportationPublicTransit'),
    ('expense.transportation.taxi_ride_sharing', 'expenseTransportationTaxiRideSharing'),
    ('expense.transportation.parking', 'expenseTransportationParking'),
    ('expense.transportation.toll_roads', 'expenseTransportationTollRoads'),
    ('expense.transportation.auto_insurance', 'expenseTransportationAutoInsurance'),
    ('expense.transportation.auto_loan', 'expenseTransportationAutoLoan'),
    ('expense.transportation.vehicle_maintenance', 'expenseTransportationVehicleMaintenance'),
    ('expense.transportation.tire_service', 'expenseTransportationTireService'),
    ('expense.transportation.vehicle_registration', 'expenseTransportationVehicleRegistration'),
    ('expense.transportation.car_wash', 'expenseTransportationCarWash'),
    ('expense.health.pharmacy', 'expenseHealthPharmacy'),
    ('expense.health.medicine', 'expenseHealthMedicine'),
    ('expense.health.doctor', 'expenseHealthDoctor'),
    ('expense.health.dentist', 'expenseHealthDentist'),
    ('expense.health.vision_care', 'expenseHealthVisionCare'),
    ('expense.health.medical_tests', 'expenseHealthMedicalTests'),
    ('expense.health.medical_procedures', 'expenseHealthMedicalProcedures'),
    ('expense.health.health_insurance', 'expenseHealthHealthInsurance'),
    ('expense.health.mental_health', 'expenseHealthMentalHealth'),
    ('expense.health.physiotherapy', 'expenseHealthPhysiotherapy'),
    ('expense.health.gym_fitness', 'expenseHealthGymFitness'),
    ('expense.health.vitamins', 'expenseHealthVitamins'),
    ('expense.family.childcare', 'expenseFamilyChildcare'),
    ('expense.family.daycare', 'expenseFamilyDaycare'),
    ('expense.family.school', 'expenseFamilySchool'),
    ('expense.family.university', 'expenseFamilyUniversity'),
    ('expense.family.tutoring', 'expenseFamilyTutoring'),
    ('expense.family.childrens_clothing', 'expenseFamilyChildrensClothing'),
    ('expense.family.baby_supplies', 'expenseFamilyBabySupplies'),
    ('expense.family.toys', 'expenseFamilyToys'),
    ('expense.family.child_support', 'expenseFamilyChildSupport'),
    ('expense.personal_care.clothing', 'expensePersonalCareClothing'),
    ('expense.personal_care.shoes', 'expensePersonalCareShoes'),
    ('expense.personal_care.cosmetics', 'expensePersonalCareCosmetics'),
    ('expense.personal_care.jewelry', 'expensePersonalCareJewelry'),
    ('expense.personal_care.haircare', 'expensePersonalCareHaircare'),
    ('expense.personal_care.nail_care', 'expensePersonalCareNailCare'),
    ('expense.personal_care.personal_hygiene', 'expensePersonalCarePersonalHygiene'),
    ('expense.personal_care.contact_lenses', 'expensePersonalCareContactLenses'),
    ('expense.entertainment_lifestyle.movies', 'expenseEntertainmentLifestyleMovies'),
    ('expense.entertainment_lifestyle.theatre', 'expenseEntertainmentLifestyleTheatre'),
    ('expense.entertainment_lifestyle.concerts', 'expenseEntertainmentLifestyleConcerts'),
    ('expense.entertainment_lifestyle.gaming', 'expenseEntertainmentLifestyleGaming'),
    ('expense.entertainment_lifestyle.streaming_subscriptions', 'expenseEntertainmentLifestyleStreamingSubscriptions'),
    ('expense.entertainment_lifestyle.music', 'expenseEntertainmentLifestyleMusic'),
    ('expense.entertainment_lifestyle.books', 'expenseEntertainmentLifestyleBooks'),
    ('expense.entertainment_lifestyle.hobbies', 'expenseEntertainmentLifestyleHobbies'),
    ('expense.entertainment_lifestyle.travel', 'expenseEntertainmentLifestyleTravel'),
    ('expense.entertainment_lifestyle.hotels', 'expenseEntertainmentLifestyleHotels'),
    ('expense.education.courses', 'expenseEducationCourses'),
    ('expense.education.online_learning', 'expenseEducationOnlineLearning'),
    ('expense.education.university_tuition', 'expenseEducationUniversityTuition'),
    ('expense.education.certifications', 'expenseEducationCertifications'),
    ('expense.education.conferences', 'expenseEducationConferences'),
    ('expense.education.language_courses', 'expenseEducationLanguageCourses'),
    ('expense.education.educational_materials', 'expenseEducationEducationalMaterials'),
    ('expense.finance.bank_fees', 'expenseFinanceBankFees'),
    ('expense.finance.atm_fees', 'expenseFinanceAtmFees'),
    ('expense.finance.credit_card_payment', 'expenseFinanceCreditCardPayment'),
    ('expense.finance.loan_payment', 'expenseFinanceLoanPayment'),
    ('expense.finance.debt_repayment', 'expenseFinanceDebtRepayment'),
    ('expense.finance.savings', 'expenseFinanceSavings'),
    ('expense.finance.emergency_fund', 'expenseFinanceEmergencyFund'),
    ('expense.finance.tfsa_contribution', 'expenseFinanceTfsaContribution'),
    ('expense.finance.rrsp_contribution', 'expenseFinanceRrspContribution'),
    ('expense.finance.resp_contribution', 'expenseFinanceRespContribution'),
    ('expense.finance.investments', 'expenseFinanceInvestments'),
    ('expense.finance.currency_exchange', 'expenseFinanceCurrencyExchange'),
    ('expense.government.income_tax', 'expenseGovernmentIncomeTax'),
    ('expense.government.driver_licence', 'expenseGovernmentDriverLicence'),
    ('expense.government.passport', 'expenseGovernmentPassport'),
    ('expense.government.immigration_fees', 'expenseGovernmentImmigrationFees'),
    ('expense.government.permits', 'expenseGovernmentPermits'),
    ('expense.government.government_services', 'expenseGovernmentGovernmentServices'),
    ('expense.pets.pet_food', 'expensePetsPetFood'),
    ('expense.pets.veterinary', 'expensePetsVeterinary'),
    ('expense.pets.pet_medicine', 'expensePetsPetMedicine'),
    ('expense.pets.pet_insurance', 'expensePetsPetInsurance'),
    ('expense.pets.grooming', 'expensePetsGrooming'),
    ('expense.pets.pet_supplies', 'expensePetsPetSupplies'),
    ('expense.giving.tithe', 'expenseGivingTithe'),
    ('expense.giving.gifts', 'expenseGivingGifts'),
    ('expense.giving.charity', 'expenseGivingCharity'),
    ('expense.giving.donations', 'expenseGivingDonations'),
    ('expense.giving.holiday_expenses', 'expenseGivingHolidayExpenses'),
    ('expense.work.office_supplies', 'expenseWorkOfficeSupplies'),
    ('expense.work.software', 'expenseWorkSoftware'),
    ('expense.work.equipment', 'expenseWorkEquipment'),
    ('expense.work.business_travel', 'expenseWorkBusinessTravel'),
    ('expense.work.professional_memberships', 'expenseWorkProfessionalMemberships'),
    ('expense.work.licences', 'expenseWorkLicences'),
    ('expense.other.cash_withdrawal', 'expenseOtherCashWithdrawal'),
    ('expense.other.adjustment', 'expenseOtherAdjustment'),
    ('expense.other.uncategorized', 'expenseOtherUncategorized'),
    ('income.employment.salary', 'incomeEmploymentSalary'),
    ('income.employment.bonus', 'incomeEmploymentBonus'),
    ('income.employment.overtime', 'incomeEmploymentOvertime'),
    ('income.employment.commission', 'incomeEmploymentCommission'),
    ('income.employment.tips', 'incomeEmploymentTips'),
    ('income.business.business_income', 'incomeBusinessBusinessIncome'),
    ('income.business.freelance', 'incomeBusinessFreelance'),
    ('income.business.consulting', 'incomeBusinessConsulting'),
    ('income.business.rental_income', 'incomeBusinessRentalIncome'),
    ('income.investments.interest_income', 'incomeInvestmentsInterestIncome'),
    ('income.investments.dividend_income', 'incomeInvestmentsDividendIncome'),
    ('income.investments.capital_gains', 'incomeInvestmentsCapitalGains'),
    ('income.investments.investment_distribution', 'incomeInvestmentsInvestmentDistribution'),
    ('income.government.tax_refund', 'incomeGovernmentTaxRefund'),
    ('income.government.government_benefits', 'incomeGovernmentGovernmentBenefits'),
    ('income.government.pension', 'incomeGovernmentPension'),
    ('income.government.child_benefit', 'incomeGovernmentChildBenefit'),
    ('income.government.employment_insurance', 'incomeGovernmentEmploymentInsurance'),
    ('income.gifts.gift_received', 'incomeGiftsGiftReceived'),
    ('income.gifts.family_support', 'incomeGiftsFamilySupport'),
    ('income.gifts.cashback', 'incomeGiftsCashback'),
    ('income.gifts.rewards', 'incomeGiftsRewards'),
    ('income.other.refund', 'incomeOtherIncomeRefund'),
    ('income.other.reimbursement', 'incomeOtherIncomeReimbursement'),
    ('income.other.sale_of_item', 'incomeOtherIncomeSaleOfItem'),
    ('income.other.other_income', 'incomeOtherIncomeOtherIncome')
)
update public.budget_income_sources budget_income_sources
set category_key = category_mapping.app_category_id
from public.categories categories
join category_mapping on category_mapping.stable_key = categories.stable_key
where budget_income_sources.category_id = categories.id;

with category_mapping(stable_key, app_category_id) as (
  values
    ('expense.housing.rent', 'expenseHousingRent'),
    ('expense.housing.mortgage', 'expenseHousingMortgage'),
    ('expense.housing.property_tax', 'expenseHousingPropertyTax'),
    ('expense.housing.condo_fees', 'expenseHousingCondoFees'),
    ('expense.housing.electricity', 'expenseHousingElectricity'),
    ('expense.housing.natural_gas', 'expenseHousingNaturalGas'),
    ('expense.housing.water', 'expenseHousingWater'),
    ('expense.housing.sewer', 'expenseHousingSewer'),
    ('expense.housing.garbage_collection', 'expenseHousingGarbageCollection'),
    ('expense.housing.internet', 'expenseHousingInternet'),
    ('expense.housing.mobile_phone', 'expenseHousingMobilePhone'),
    ('expense.housing.home_phone', 'expenseHousingHomePhone'),
    ('expense.housing.home_insurance', 'expenseHousingHomeInsurance'),
    ('expense.housing.home_maintenance', 'expenseHousingHomeMaintenance'),
    ('expense.housing.furniture', 'expenseHousingFurniture'),
    ('expense.housing.appliances', 'expenseHousingAppliances'),
    ('expense.housing.home_supplies', 'expenseHousingHomeSupplies'),
    ('expense.housing.home_security', 'expenseHousingHomeSecurity'),
    ('expense.food.groceries', 'expenseFoodGroceries'),
    ('expense.food.farmers_market', 'expenseFoodFarmersMarket'),
    ('expense.food.restaurant', 'expenseFoodRestaurant'),
    ('expense.food.cafe_coffee', 'expenseFoodCafeCoffee'),
    ('expense.food.fast_food', 'expenseFoodFastFood'),
    ('expense.food.food_delivery', 'expenseFoodFoodDelivery'),
    ('expense.food.snacks', 'expenseFoodSnacks'),
    ('expense.food.alcohol', 'expenseFoodAlcohol'),
    ('expense.transportation.fuel', 'expenseTransportationFuel'),
    ('expense.transportation.ev_charging', 'expenseTransportationEvCharging'),
    ('expense.transportation.public_transit', 'expenseTransportationPublicTransit'),
    ('expense.transportation.taxi_ride_sharing', 'expenseTransportationTaxiRideSharing'),
    ('expense.transportation.parking', 'expenseTransportationParking'),
    ('expense.transportation.toll_roads', 'expenseTransportationTollRoads'),
    ('expense.transportation.auto_insurance', 'expenseTransportationAutoInsurance'),
    ('expense.transportation.auto_loan', 'expenseTransportationAutoLoan'),
    ('expense.transportation.vehicle_maintenance', 'expenseTransportationVehicleMaintenance'),
    ('expense.transportation.tire_service', 'expenseTransportationTireService'),
    ('expense.transportation.vehicle_registration', 'expenseTransportationVehicleRegistration'),
    ('expense.transportation.car_wash', 'expenseTransportationCarWash'),
    ('expense.health.pharmacy', 'expenseHealthPharmacy'),
    ('expense.health.medicine', 'expenseHealthMedicine'),
    ('expense.health.doctor', 'expenseHealthDoctor'),
    ('expense.health.dentist', 'expenseHealthDentist'),
    ('expense.health.vision_care', 'expenseHealthVisionCare'),
    ('expense.health.medical_tests', 'expenseHealthMedicalTests'),
    ('expense.health.medical_procedures', 'expenseHealthMedicalProcedures'),
    ('expense.health.health_insurance', 'expenseHealthHealthInsurance'),
    ('expense.health.mental_health', 'expenseHealthMentalHealth'),
    ('expense.health.physiotherapy', 'expenseHealthPhysiotherapy'),
    ('expense.health.gym_fitness', 'expenseHealthGymFitness'),
    ('expense.health.vitamins', 'expenseHealthVitamins'),
    ('expense.family.childcare', 'expenseFamilyChildcare'),
    ('expense.family.daycare', 'expenseFamilyDaycare'),
    ('expense.family.school', 'expenseFamilySchool'),
    ('expense.family.university', 'expenseFamilyUniversity'),
    ('expense.family.tutoring', 'expenseFamilyTutoring'),
    ('expense.family.childrens_clothing', 'expenseFamilyChildrensClothing'),
    ('expense.family.baby_supplies', 'expenseFamilyBabySupplies'),
    ('expense.family.toys', 'expenseFamilyToys'),
    ('expense.family.child_support', 'expenseFamilyChildSupport'),
    ('expense.personal_care.clothing', 'expensePersonalCareClothing'),
    ('expense.personal_care.shoes', 'expensePersonalCareShoes'),
    ('expense.personal_care.cosmetics', 'expensePersonalCareCosmetics'),
    ('expense.personal_care.jewelry', 'expensePersonalCareJewelry'),
    ('expense.personal_care.haircare', 'expensePersonalCareHaircare'),
    ('expense.personal_care.nail_care', 'expensePersonalCareNailCare'),
    ('expense.personal_care.personal_hygiene', 'expensePersonalCarePersonalHygiene'),
    ('expense.personal_care.contact_lenses', 'expensePersonalCareContactLenses'),
    ('expense.entertainment_lifestyle.movies', 'expenseEntertainmentLifestyleMovies'),
    ('expense.entertainment_lifestyle.theatre', 'expenseEntertainmentLifestyleTheatre'),
    ('expense.entertainment_lifestyle.concerts', 'expenseEntertainmentLifestyleConcerts'),
    ('expense.entertainment_lifestyle.gaming', 'expenseEntertainmentLifestyleGaming'),
    ('expense.entertainment_lifestyle.streaming_subscriptions', 'expenseEntertainmentLifestyleStreamingSubscriptions'),
    ('expense.entertainment_lifestyle.music', 'expenseEntertainmentLifestyleMusic'),
    ('expense.entertainment_lifestyle.books', 'expenseEntertainmentLifestyleBooks'),
    ('expense.entertainment_lifestyle.hobbies', 'expenseEntertainmentLifestyleHobbies'),
    ('expense.entertainment_lifestyle.travel', 'expenseEntertainmentLifestyleTravel'),
    ('expense.entertainment_lifestyle.hotels', 'expenseEntertainmentLifestyleHotels'),
    ('expense.education.courses', 'expenseEducationCourses'),
    ('expense.education.online_learning', 'expenseEducationOnlineLearning'),
    ('expense.education.university_tuition', 'expenseEducationUniversityTuition'),
    ('expense.education.certifications', 'expenseEducationCertifications'),
    ('expense.education.conferences', 'expenseEducationConferences'),
    ('expense.education.language_courses', 'expenseEducationLanguageCourses'),
    ('expense.education.educational_materials', 'expenseEducationEducationalMaterials'),
    ('expense.finance.bank_fees', 'expenseFinanceBankFees'),
    ('expense.finance.atm_fees', 'expenseFinanceAtmFees'),
    ('expense.finance.credit_card_payment', 'expenseFinanceCreditCardPayment'),
    ('expense.finance.loan_payment', 'expenseFinanceLoanPayment'),
    ('expense.finance.debt_repayment', 'expenseFinanceDebtRepayment'),
    ('expense.finance.savings', 'expenseFinanceSavings'),
    ('expense.finance.emergency_fund', 'expenseFinanceEmergencyFund'),
    ('expense.finance.tfsa_contribution', 'expenseFinanceTfsaContribution'),
    ('expense.finance.rrsp_contribution', 'expenseFinanceRrspContribution'),
    ('expense.finance.resp_contribution', 'expenseFinanceRespContribution'),
    ('expense.finance.investments', 'expenseFinanceInvestments'),
    ('expense.finance.currency_exchange', 'expenseFinanceCurrencyExchange'),
    ('expense.government.income_tax', 'expenseGovernmentIncomeTax'),
    ('expense.government.driver_licence', 'expenseGovernmentDriverLicence'),
    ('expense.government.passport', 'expenseGovernmentPassport'),
    ('expense.government.immigration_fees', 'expenseGovernmentImmigrationFees'),
    ('expense.government.permits', 'expenseGovernmentPermits'),
    ('expense.government.government_services', 'expenseGovernmentGovernmentServices'),
    ('expense.pets.pet_food', 'expensePetsPetFood'),
    ('expense.pets.veterinary', 'expensePetsVeterinary'),
    ('expense.pets.pet_medicine', 'expensePetsPetMedicine'),
    ('expense.pets.pet_insurance', 'expensePetsPetInsurance'),
    ('expense.pets.grooming', 'expensePetsGrooming'),
    ('expense.pets.pet_supplies', 'expensePetsPetSupplies'),
    ('expense.giving.tithe', 'expenseGivingTithe'),
    ('expense.giving.gifts', 'expenseGivingGifts'),
    ('expense.giving.charity', 'expenseGivingCharity'),
    ('expense.giving.donations', 'expenseGivingDonations'),
    ('expense.giving.holiday_expenses', 'expenseGivingHolidayExpenses'),
    ('expense.work.office_supplies', 'expenseWorkOfficeSupplies'),
    ('expense.work.software', 'expenseWorkSoftware'),
    ('expense.work.equipment', 'expenseWorkEquipment'),
    ('expense.work.business_travel', 'expenseWorkBusinessTravel'),
    ('expense.work.professional_memberships', 'expenseWorkProfessionalMemberships'),
    ('expense.work.licences', 'expenseWorkLicences'),
    ('expense.other.cash_withdrawal', 'expenseOtherCashWithdrawal'),
    ('expense.other.adjustment', 'expenseOtherAdjustment'),
    ('expense.other.uncategorized', 'expenseOtherUncategorized'),
    ('income.employment.salary', 'incomeEmploymentSalary'),
    ('income.employment.bonus', 'incomeEmploymentBonus'),
    ('income.employment.overtime', 'incomeEmploymentOvertime'),
    ('income.employment.commission', 'incomeEmploymentCommission'),
    ('income.employment.tips', 'incomeEmploymentTips'),
    ('income.business.business_income', 'incomeBusinessBusinessIncome'),
    ('income.business.freelance', 'incomeBusinessFreelance'),
    ('income.business.consulting', 'incomeBusinessConsulting'),
    ('income.business.rental_income', 'incomeBusinessRentalIncome'),
    ('income.investments.interest_income', 'incomeInvestmentsInterestIncome'),
    ('income.investments.dividend_income', 'incomeInvestmentsDividendIncome'),
    ('income.investments.capital_gains', 'incomeInvestmentsCapitalGains'),
    ('income.investments.investment_distribution', 'incomeInvestmentsInvestmentDistribution'),
    ('income.government.tax_refund', 'incomeGovernmentTaxRefund'),
    ('income.government.government_benefits', 'incomeGovernmentGovernmentBenefits'),
    ('income.government.pension', 'incomeGovernmentPension'),
    ('income.government.child_benefit', 'incomeGovernmentChildBenefit'),
    ('income.government.employment_insurance', 'incomeGovernmentEmploymentInsurance'),
    ('income.gifts.gift_received', 'incomeGiftsGiftReceived'),
    ('income.gifts.family_support', 'incomeGiftsFamilySupport'),
    ('income.gifts.cashback', 'incomeGiftsCashback'),
    ('income.gifts.rewards', 'incomeGiftsRewards'),
    ('income.other.refund', 'incomeOtherIncomeRefund'),
    ('income.other.reimbursement', 'incomeOtherIncomeReimbursement'),
    ('income.other.sale_of_item', 'incomeOtherIncomeSaleOfItem'),
    ('income.other.other_income', 'incomeOtherIncomeOtherIncome')
)
update public.budget_obligations budget_obligations
set category_key = category_mapping.app_category_id
from public.categories categories
join category_mapping on category_mapping.stable_key = categories.stable_key
where budget_obligations.category_id = categories.id;

update public.operations operations
set category_key = null
from public.categories categories
where operations.category_id = categories.id
  and categories.stable_key is null;

do $$
declare
  budget_income_sources_null_stable_key_count integer;
  budget_obligations_null_stable_key_count integer;
  operations_unmapped_count integer;
  budget_income_sources_unmapped_count integer;
  budget_obligations_unmapped_count integer;
begin
  select count(*)
  into budget_income_sources_null_stable_key_count
  from public.budget_income_sources budget_income_sources
  join public.categories categories on categories.id = budget_income_sources.category_id
  where budget_income_sources.category_id is not null
    and categories.stable_key is null;

  if budget_income_sources_null_stable_key_count > 0 then
    raise exception 'Cannot migrate budget_income_sources: % rows reference categories with null stable_key.', budget_income_sources_null_stable_key_count;
  end if;

  select count(*)
  into budget_obligations_null_stable_key_count
  from public.budget_obligations budget_obligations
  join public.categories categories on categories.id = budget_obligations.category_id
  where budget_obligations.category_id is not null
    and categories.stable_key is null;

  if budget_obligations_null_stable_key_count > 0 then
    raise exception 'Cannot migrate budget_obligations: % rows reference categories with null stable_key.', budget_obligations_null_stable_key_count;
  end if;

  select count(*)
  into operations_unmapped_count
  from public.operations operations
  left join public.categories categories on categories.id = operations.category_id
  where operations.category_id is not null
    and operations.category_key is null
    and (
      categories.id is null
      or categories.stable_key is not null
    );

  if operations_unmapped_count > 0 then
    raise exception 'Cannot migrate operations: % rows have category_id that cannot be mapped to AppCategoryId.name.', operations_unmapped_count;
  end if;

  select count(*)
  into budget_income_sources_unmapped_count
  from public.budget_income_sources
  where category_id is not null
    and category_key is null;

  if budget_income_sources_unmapped_count > 0 then
    raise exception 'Cannot migrate budget_income_sources: % rows have category_id that cannot be mapped to AppCategoryId.name.', budget_income_sources_unmapped_count;
  end if;

  select count(*)
  into budget_obligations_unmapped_count
  from public.budget_obligations
  where category_id is not null
    and category_key is null;

  if budget_obligations_unmapped_count > 0 then
    raise exception 'Cannot migrate budget_obligations: % rows have category_id that cannot be mapped to AppCategoryId.name.', budget_obligations_unmapped_count;
  end if;
end;
$$;

alter table public.operations
drop constraint if exists operations_category_id_fkey;

alter table public.operations
drop constraint if exists operations_transfer_category_check;

alter table public.operations
drop constraint if exists operations_transfer_check;

drop index if exists operations_category_id_idx;

alter table public.operations
drop column category_id;

alter table public.operations
rename column category_key to category_id;

alter table public.operations
add constraint operations_transfer_check
check (
    (
        type = 'transfer'
        and category_id is null
        and to_account_id is not null
        and from_account_id <> to_account_id
    )
    or
    (
        type in ('expense', 'income')
        and category_id is not null
        and to_account_id is null
    )
) not valid;

create index operations_category_id_idx
on public.operations(category_id);

alter table public.budget_income_sources
drop constraint if exists budget_income_sources_category_id_fkey;

drop index if exists budget_income_sources_category_id_idx;

alter table public.budget_income_sources
drop column category_id;

alter table public.budget_income_sources
rename column category_key to category_id;

create index budget_income_sources_category_id_idx
on public.budget_income_sources(category_id);

alter table public.budget_obligations
drop constraint if exists budget_obligations_category_id_fkey;

drop index if exists budget_obligations_category_id_idx;

alter table public.budget_obligations
drop column category_id;

alter table public.budget_obligations
rename column category_key to category_id;

create index budget_obligations_category_id_idx
on public.budget_obligations(category_id);

drop table public.categories;
