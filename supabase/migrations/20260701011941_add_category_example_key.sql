alter table public.categories
add column example_key text not null default 'categoryExampleDefault';

alter table public.categories
add constraint categories_example_key_check
check (example_key <> '');

update public.categories
set example_key = case name_key
  when 'categoryRent' then 'categoryExampleRent'
  when 'categoryMortgage' then 'categoryExampleMortgage'
  when 'categoryUtilities' then 'categoryExampleUtilities'
  when 'categoryInsurance' then 'categoryExampleInsurance'
  when 'categoryGroceries' then 'categoryExampleGroceries'
  when 'categoryRestaurants' then 'categoryExampleRestaurants'
  when 'categoryCoffee' then 'categoryExampleCoffee'
  when 'categoryFuel' then 'categoryExampleFuel'
  when 'categoryPublicTransit' then 'categoryExamplePublicTransit'
  when 'categoryCar' then 'categoryExampleCar'
  when 'categoryHealth' then 'categoryExampleHealth'
  when 'categoryPharmacy' then 'categoryExamplePharmacy'
  when 'categoryShopping' then 'categoryExampleShopping'
  when 'categoryEntertainment' then 'categoryExampleEntertainment'
  when 'categorySubscriptions' then 'categoryExampleSubscriptions'
  when 'categoryTravel' then 'categoryExampleTravel'
  when 'categoryEducation' then 'categoryExampleEducation'
  when 'categoryDebtPayment' then 'categoryExampleDebtPayment'
  when 'categoryBankFees' then 'categoryExampleBankFees'
  when 'categorySavings' then 'categoryExampleSavings'
  when 'categoryInvestments' then 'categoryExampleInvestments'
  when 'categoryOtherExpense' then 'categoryExampleOtherExpense'
  when 'categorySalary' then 'categoryExampleSalary'
  when 'categoryBusiness' then 'categoryExampleBusiness'
  when 'categoryBenefits' then 'categoryExampleBenefits'
  when 'categoryDividends' then 'categoryExampleDividends'
  when 'categoryOtherIncome' then 'categoryExampleOtherIncome'
  else 'categoryExampleDefault'
end;