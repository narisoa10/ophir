alter table public.categories
add column stable_key text;

alter table public.categories
add constraint categories_stable_key_check
check (stable_key is null or stable_key <> '');

create unique index categories_stable_key_unique_idx
on public.categories(stable_key)
where stable_key is not null;

create index categories_type_stable_key_idx
on public.categories(type, stable_key)
where stable_key is not null;

update public.categories
set stable_key = case
  when type = 'expense' and name_key = 'categoryRent'
    then 'expense.housing.rent'
  when type = 'expense' and name_key = 'categoryMortgage'
    then 'expense.housing.mortgage'
  when type = 'expense' and name_key = 'categoryGroceries'
    then 'expense.food.groceries'
  when type = 'expense' and name_key = 'categoryRestaurants'
    then 'expense.food.restaurant'
  when type = 'expense' and name_key = 'categoryCoffee'
    then 'expense.food.cafe_coffee'
  when type = 'expense' and name_key = 'categoryFuel'
    then 'expense.transportation.fuel'
  when type = 'expense' and name_key = 'categoryPublicTransit'
    then 'expense.transportation.public_transit'
  when type = 'expense' and name_key = 'categoryPharmacy'
    then 'expense.health.pharmacy'
  when type = 'expense' and name_key = 'categorySubscriptions'
    then 'expense.entertainment_lifestyle.streaming_subscriptions'
  when type = 'expense' and name_key = 'categoryTravel'
    then 'expense.entertainment_lifestyle.travel'
  when type = 'expense' and name_key = 'categoryDebtPayment'
    then 'expense.finance.debt_repayment'
  when type = 'expense' and name_key = 'categoryBankFees'
    then 'expense.finance.bank_fees'
  when type = 'expense' and name_key = 'categorySavings'
    then 'expense.finance.savings'
  when type = 'expense' and name_key = 'categoryInvestments'
    then 'expense.finance.investments'
  when type = 'expense' and name_key = 'categoryOtherExpense'
    then 'expense.other.uncategorized'
  when type = 'income' and name_key = 'categorySalary'
    then 'income.employment.salary'
  when type = 'income' and name_key = 'categoryBenefits'
    then 'income.government.government_benefits'
  when type = 'income' and name_key = 'categoryDividends'
    then 'income.investments.dividend_income'
  when type = 'income' and name_key = 'categoryOtherIncome'
    then 'income.other.other_income'
  else stable_key
end
where stable_key is null
  and (
    (type = 'expense' and name_key in (
      'categoryRent',
      'categoryMortgage',
      'categoryGroceries',
      'categoryRestaurants',
      'categoryCoffee',
      'categoryFuel',
      'categoryPublicTransit',
      'categoryPharmacy',
      'categorySubscriptions',
      'categoryTravel',
      'categoryDebtPayment',
      'categoryBankFees',
      'categorySavings',
      'categoryInvestments',
      'categoryOtherExpense'
    ))
    or
    (type = 'income' and name_key in (
      'categorySalary',
      'categoryBenefits',
      'categoryDividends',
      'categoryOtherIncome'
    ))
  );
