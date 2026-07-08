create table public.categories (
    id uuid primary key default gen_random_uuid(),

    type text not null,
    group_key text not null,
    name_key text not null,
    icon_key text not null,
    color_key text not null,

    sort_order integer not null default 0,
    is_active boolean not null default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint categories_type_check
        check (type in ('expense', 'income')),

    constraint categories_group_key_check
        check (group_key <> ''),

    constraint categories_name_key_check
        check (name_key <> ''),

    constraint categories_icon_key_check
        check (icon_key <> ''),

    constraint categories_color_key_check
        check (color_key <> '')
);

create unique index categories_type_name_key_idx
on public.categories(type, name_key);

create index categories_type_idx
on public.categories(type);

create index categories_group_key_idx
on public.categories(group_key);

create trigger categories_set_updated_at
before update on public.categories
for each row
execute function public.set_updated_at();

alter table public.categories enable row level security;

create policy "Anyone authenticated can read active categories"
on public.categories
for select
to authenticated
using (is_active = true);

insert into public.categories (
    type,
    group_key,
    name_key,
    icon_key,
    color_key,
    sort_order
)
values
-- Expense: obligations
('expense', 'housing', 'categoryRent', 'housing', 'orange', 10),
('expense', 'housing', 'categoryMortgage', 'housing', 'orange', 20),
('expense', 'housing', 'categoryUtilities', 'utilities', 'blue', 30),
('expense', 'housing', 'categoryInsurance', 'insurance', 'purple', 40),

-- Expense: food
('expense', 'food', 'categoryGroceries', 'groceries', 'green', 100),
('expense', 'food', 'categoryRestaurants', 'restaurant', 'orange', 110),
('expense', 'food', 'categoryCoffee', 'coffee', 'yellow', 120),

-- Expense: transport
('expense', 'transport', 'categoryFuel', 'fuel', 'red', 200),
('expense', 'transport', 'categoryPublicTransit', 'transport', 'blue', 210),
('expense', 'transport', 'categoryCar', 'car', 'purple', 220),

-- Expense: health
('expense', 'health', 'categoryHealth', 'health', 'red', 300),
('expense', 'health', 'categoryPharmacy', 'pharmacy', 'green', 310),

-- Expense: lifestyle
('expense', 'lifestyle', 'categoryShopping', 'shopping', 'purple', 400),
('expense', 'lifestyle', 'categoryEntertainment', 'entertainment', 'blue', 410),
('expense', 'lifestyle', 'categorySubscriptions', 'subscriptions', 'cyan', 420),
('expense', 'lifestyle', 'categoryTravel', 'travel', 'orange', 430),
('expense', 'lifestyle', 'categoryEducation', 'education', 'blue', 440),

-- Expense: finance
('expense', 'finance', 'categoryDebtPayment', 'debt', 'red', 500),
('expense', 'finance', 'categoryBankFees', 'bank', 'gray', 510),
('expense', 'finance', 'categorySavings', 'savings', 'green', 520),
('expense', 'finance', 'categoryInvestments', 'investment', 'purple', 530),

-- Expense: other
('expense', 'other', 'categoryOtherExpense', 'other', 'gray', 900),

-- Income
('income', 'salary', 'categorySalary', 'salary', 'green', 1000),
('income', 'business', 'categoryBusiness', 'business', 'blue', 1010),
('income', 'benefits', 'categoryBenefits', 'benefits', 'purple', 1020),
('income', 'investments', 'categoryDividends', 'investment', 'orange', 1030),
('income', 'other', 'categoryOtherIncome', 'other', 'gray', 1090);