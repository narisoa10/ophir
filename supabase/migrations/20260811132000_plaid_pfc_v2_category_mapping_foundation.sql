create table public.plaid_pfc_v2_category_mappings (
    pfc_primary text not null
        constraint plaid_pfc_v2_category_mappings_primary_check
        check (btrim(pfc_primary) <> ''),

    pfc_detailed text not null
        constraint plaid_pfc_v2_category_mappings_detailed_check
        check (btrim(pfc_detailed) <> ''),

    operation_type text not null
        constraint plaid_pfc_v2_category_mappings_operation_type_check
        check (operation_type in ('expense', 'income')),

    min_confidence text not null
        constraint plaid_pfc_v2_category_mappings_confidence_check
        check (min_confidence in ('VERY_HIGH', 'HIGH', 'MEDIUM')),

    category_id text not null
        constraint plaid_pfc_v2_category_mappings_category_check
        check (
            (
                operation_type = 'expense'
                and category_id in (
                    'expenseHousingRent',
                    'expenseHousingMortgage',
                    'expenseHousingWater',
                    'expenseHousingSewer',
                    'expenseHousingGarbageCollection',
                    'expenseHousingInternet',
                    'expenseHousingMobilePhone',
                    'expenseHousingFurniture',
                    'expenseHousingAppliances',
                    'expenseHousingHomeMaintenance',
                    'expenseHousingHomeSecurity',
                    'expenseFoodGroceries',
                    'expenseFoodRestaurant',
                    'expenseFoodCafeCoffee',
                    'expenseFoodFastFood',
                    'expenseFoodSnacks',
                    'expenseFoodAlcohol',
                    'expenseTransportationFuel',
                    'expenseTransportationEvCharging',
                    'expenseTransportationPublicTransit',
                    'expenseTransportationTaxiRideSharing',
                    'expenseTransportationParking',
                    'expenseTransportationTollRoads',
                    'expenseTransportationAutoLoan',
                    'expenseTransportationVehicleMaintenance',
                    'expenseHealthPharmacy',
                    'expenseHealthDoctor',
                    'expenseHealthDentist',
                    'expenseHealthVisionCare',
                    'expenseHealthMedicalTests',
                    'expenseHealthMedicalProcedures',
                    'expenseHealthGymFitness',
                    'expenseFamilyChildcare',
                    'expensePetsVeterinary',
                    'expensePersonalCareClothing',
                    'expensePersonalCareHaircare',
                    'expenseEntertainmentLifestyleMovies',
                    'expenseEntertainmentLifestyleConcerts',
                    'expenseEntertainmentLifestyleGaming',
                    'expenseEntertainmentLifestyleMusic',
                    'expenseEntertainmentLifestyleBooks',
                    'expenseEntertainmentLifestyleTravel',
                    'expenseEntertainmentLifestyleHotels',
                    'expenseEducationCourses',
                    'expenseFinanceBankFees',
                    'expenseFinanceAtmFees',
                    'expenseFinanceLoanPayment',
                    'expenseGivingDonations',
                    'expenseGovernmentIncomeTax',
                    'expenseGovernmentGovernmentServices'
                )
            )
            or
            (
                operation_type = 'income'
                and category_id in (
                    'incomeEmploymentSalary',
                    'incomeEmploymentBonus',
                    'incomeEmploymentOvertime',
                    'incomeEmploymentCommission',
                    'incomeEmploymentTips',
                    'incomeInvestmentsInterestIncome',
                    'incomeInvestmentsDividendIncome',
                    'incomeGovernmentTaxRefund',
                    'incomeGovernmentPension',
                    'incomeGovernmentEmploymentInsurance',
                    'incomeGiftsCashback',
                    'incomeGiftsRewards',
                    'incomeOtherIncomeRefund',
                    'incomeOtherIncomeReimbursement',
                    'incomeOtherIncomeOtherIncome'
                )
            )
        ),

    match_level text not null default 'detailed'
        constraint plaid_pfc_v2_category_mappings_match_level_check
        check (match_level in ('detailed')),

    created_at timestamptz not null default now(),

    constraint plaid_pfc_v2_category_mappings_pkey
        primary key (pfc_primary, pfc_detailed, operation_type)
);

comment on table public.plaid_pfc_v2_category_mappings is
    'Static server-owned deterministic mapping from Plaid PFCv2 detailed categories to canonical Ophir AppCategoryId names. No client mutation and no Plaid payload storage.';

alter table public.plaid_pfc_v2_category_mappings enable row level security;

revoke all on table public.plaid_pfc_v2_category_mappings
from public, anon, authenticated;

grant select on table public.plaid_pfc_v2_category_mappings
to service_role;

insert into public.plaid_pfc_v2_category_mappings (
    pfc_primary,
    pfc_detailed,
    operation_type,
    min_confidence,
    category_id
)
values
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_GROCERIES', 'expense', 'MEDIUM', 'expenseFoodGroceries'),
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_COFFEE', 'expense', 'HIGH', 'expenseFoodCafeCoffee'),
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_FAST_FOOD', 'expense', 'HIGH', 'expenseFoodFastFood'),
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_RESTAURANT', 'expense', 'MEDIUM', 'expenseFoodRestaurant'),
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_BEER_WINE_AND_LIQUOR', 'expense', 'HIGH', 'expenseFoodAlcohol'),
    ('FOOD_AND_DRINK', 'FOOD_AND_DRINK_VENDING_MACHINES', 'expense', 'HIGH', 'expenseFoodSnacks'),

    ('TRANSPORTATION', 'TRANSPORTATION_GAS', 'expense', 'MEDIUM', 'expenseTransportationFuel'),
    ('TRANSPORTATION', 'TRANSPORTATION_PARKING', 'expense', 'HIGH', 'expenseTransportationParking'),
    ('TRANSPORTATION', 'TRANSPORTATION_PUBLIC_TRANSIT', 'expense', 'HIGH', 'expenseTransportationPublicTransit'),
    ('TRANSPORTATION', 'TRANSPORTATION_TAXIS_AND_RIDE_SHARES', 'expense', 'HIGH', 'expenseTransportationTaxiRideSharing'),
    ('TRANSPORTATION', 'TRANSPORTATION_TOLLS', 'expense', 'HIGH', 'expenseTransportationTollRoads'),

    ('TRAVEL', 'TRAVEL_FLIGHTS', 'expense', 'HIGH', 'expenseEntertainmentLifestyleTravel'),
    ('TRAVEL', 'TRAVEL_LODGING', 'expense', 'HIGH', 'expenseEntertainmentLifestyleHotels'),
    ('TRAVEL', 'TRAVEL_RENTAL_CARS', 'expense', 'HIGH', 'expenseEntertainmentLifestyleTravel'),

    ('ENTERTAINMENT', 'ENTERTAINMENT_MUSIC_AND_AUDIO', 'expense', 'HIGH', 'expenseEntertainmentLifestyleMusic'),
    ('ENTERTAINMENT', 'ENTERTAINMENT_TV_AND_MOVIES', 'expense', 'HIGH', 'expenseEntertainmentLifestyleMovies'),
    ('ENTERTAINMENT', 'ENTERTAINMENT_VIDEO_GAMES', 'expense', 'HIGH', 'expenseEntertainmentLifestyleGaming'),
    ('ENTERTAINMENT', 'ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS', 'expense', 'HIGH', 'expenseEntertainmentLifestyleConcerts'),

    ('GENERAL_MERCHANDISE', 'GENERAL_MERCHANDISE_BOOKSTORES_AND_NEWSSTANDS', 'expense', 'HIGH', 'expenseEntertainmentLifestyleBooks'),
    ('GENERAL_MERCHANDISE', 'GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES', 'expense', 'HIGH', 'expensePersonalCareClothing'),

    ('GENERAL_SERVICES', 'GENERAL_SERVICES_AUTOMOTIVE', 'expense', 'HIGH', 'expenseTransportationVehicleMaintenance'),
    ('GENERAL_SERVICES', 'GENERAL_SERVICES_CHILDCARE', 'expense', 'HIGH', 'expenseFamilyChildcare'),
    ('GENERAL_SERVICES', 'GENERAL_SERVICES_EDUCATION', 'expense', 'HIGH', 'expenseEducationCourses'),

    ('GOVERNMENT_AND_NON_PROFIT', 'GOVERNMENT_AND_NON_PROFIT_DONATIONS', 'expense', 'HIGH', 'expenseGivingDonations'),
    ('GOVERNMENT_AND_NON_PROFIT', 'GOVERNMENT_AND_NON_PROFIT_TAX_PAYMENT', 'expense', 'HIGH', 'expenseGovernmentIncomeTax'),
    ('GOVERNMENT_AND_NON_PROFIT', 'GOVERNMENT_AND_NON_PROFIT_GOVERNMENT_DEPARTMENTS_AND_AGENCIES', 'expense', 'HIGH', 'expenseGovernmentGovernmentServices'),

    ('HOME_IMPROVEMENT', 'HOME_IMPROVEMENT_FURNITURE', 'expense', 'HIGH', 'expenseHousingFurniture'),
    ('HOME_IMPROVEMENT', 'HOME_IMPROVEMENT_HARDWARE', 'expense', 'HIGH', 'expenseHousingHomeMaintenance'),
    ('HOME_IMPROVEMENT', 'HOME_IMPROVEMENT_REPAIR_AND_MAINTENANCE', 'expense', 'HIGH', 'expenseHousingHomeMaintenance'),
    ('HOME_IMPROVEMENT', 'HOME_IMPROVEMENT_SECURITY', 'expense', 'HIGH', 'expenseHousingHomeSecurity'),

    ('MEDICAL', 'MEDICAL_DENTAL_CARE', 'expense', 'HIGH', 'expenseHealthDentist'),
    ('MEDICAL', 'MEDICAL_EYE_CARE', 'expense', 'HIGH', 'expenseHealthVisionCare'),
    ('MEDICAL', 'MEDICAL_PHARMACIES_AND_SUPPLEMENTS', 'expense', 'MEDIUM', 'expenseHealthPharmacy'),
    ('MEDICAL', 'MEDICAL_PRIMARY_CARE', 'expense', 'HIGH', 'expenseHealthDoctor'),
    ('MEDICAL', 'MEDICAL_VETERINARY_SERVICES', 'expense', 'HIGH', 'expensePetsVeterinary'),

    ('PERSONAL_CARE', 'PERSONAL_CARE_GYMS_AND_FITNESS_CENTERS', 'expense', 'HIGH', 'expenseHealthGymFitness'),
    ('PERSONAL_CARE', 'PERSONAL_CARE_HAIR_AND_BEAUTY', 'expense', 'HIGH', 'expensePersonalCareHaircare'),

    ('RENT_AND_UTILITIES', 'RENT_AND_UTILITIES_RENT', 'expense', 'MEDIUM', 'expenseHousingRent'),
    ('RENT_AND_UTILITIES', 'RENT_AND_UTILITIES_INTERNET_AND_CABLE', 'expense', 'HIGH', 'expenseHousingInternet'),
    ('RENT_AND_UTILITIES', 'RENT_AND_UTILITIES_TELEPHONE', 'expense', 'HIGH', 'expenseHousingMobilePhone'),
    ('RENT_AND_UTILITIES', 'RENT_AND_UTILITIES_WATER', 'expense', 'HIGH', 'expenseHousingWater'),
    ('RENT_AND_UTILITIES', 'RENT_AND_UTILITIES_SEWAGE_AND_WASTE_MANAGEMENT', 'expense', 'HIGH', 'expenseHousingGarbageCollection'),

    ('BANK_FEES', 'BANK_FEES_ATM_FEES', 'expense', 'MEDIUM', 'expenseFinanceAtmFees'),
    ('BANK_FEES', 'BANK_FEES_FOREIGN_TRANSACTION_FEES', 'expense', 'HIGH', 'expenseFinanceBankFees'),
    ('BANK_FEES', 'BANK_FEES_INSUFFICIENT_FUNDS', 'expense', 'HIGH', 'expenseFinanceBankFees'),
    ('BANK_FEES', 'BANK_FEES_INTEREST_CHARGE', 'expense', 'HIGH', 'expenseFinanceBankFees'),
    ('BANK_FEES', 'BANK_FEES_LATE_FEES', 'expense', 'HIGH', 'expenseFinanceBankFees'),
    ('BANK_FEES', 'BANK_FEES_OVERDRAFT_FEES', 'expense', 'HIGH', 'expenseFinanceBankFees'),
    ('BANK_FEES', 'BANK_FEES_OTHER_BANK_FEES', 'expense', 'HIGH', 'expenseFinanceBankFees'),

    ('LOAN_PAYMENTS', 'LOAN_PAYMENTS_CAR_PAYMENT', 'expense', 'HIGH', 'expenseTransportationAutoLoan'),
    ('LOAN_PAYMENTS', 'LOAN_PAYMENTS_MORTGAGE_PAYMENT', 'expense', 'HIGH', 'expenseHousingMortgage'),
    ('LOAN_PAYMENTS', 'LOAN_PAYMENTS_PERSONAL_LOAN_PAYMENT', 'expense', 'HIGH', 'expenseFinanceLoanPayment'),
    ('LOAN_PAYMENTS', 'LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT', 'expense', 'HIGH', 'expenseFinanceLoanPayment'),
    ('LOAN_PAYMENTS', 'LOAN_PAYMENTS_OTHER_PAYMENT', 'expense', 'HIGH', 'expenseFinanceLoanPayment'),

    ('INCOME', 'INCOME_WAGES', 'income', 'MEDIUM', 'incomeEmploymentSalary'),
    ('INCOME', 'INCOME_BONUS', 'income', 'HIGH', 'incomeEmploymentBonus'),
    ('INCOME', 'INCOME_OVERTIME', 'income', 'HIGH', 'incomeEmploymentOvertime'),
    ('INCOME', 'INCOME_COMMISSION', 'income', 'HIGH', 'incomeEmploymentCommission'),
    ('INCOME', 'INCOME_TIPS', 'income', 'HIGH', 'incomeEmploymentTips'),
    ('INCOME', 'INCOME_INTEREST_EARNED', 'income', 'HIGH', 'incomeInvestmentsInterestIncome'),
    ('INCOME', 'INCOME_DIVIDENDS', 'income', 'MEDIUM', 'incomeInvestmentsDividendIncome'),
    ('INCOME', 'INCOME_TAX_REFUND', 'income', 'HIGH', 'incomeGovernmentTaxRefund'),
    ('INCOME', 'INCOME_UNEMPLOYMENT', 'income', 'HIGH', 'incomeGovernmentEmploymentInsurance'),
    ('INCOME', 'INCOME_RETIREMENT_PENSION', 'income', 'HIGH', 'incomeGovernmentPension'),
    ('INCOME', 'INCOME_CASHBACK', 'income', 'HIGH', 'incomeGiftsCashback'),
    ('INCOME', 'INCOME_REWARDS', 'income', 'HIGH', 'incomeGiftsRewards'),
    ('INCOME', 'INCOME_REFUND', 'income', 'HIGH', 'incomeOtherIncomeRefund'),
    ('INCOME', 'INCOME_REIMBURSEMENT', 'income', 'HIGH', 'incomeOtherIncomeReimbursement');

create or replace function public.plaid_map_pfc_v2_to_ophir_category(
    p_operation_type text,
    p_pfc_version text,
    p_pfc_primary text,
    p_pfc_detailed text,
    p_confidence_level text
)
returns table (
    category_id text,
    reason text,
    match_level text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_operation_type text := lower(nullif(btrim(coalesce(p_operation_type, '')), ''));
    v_version text := lower(nullif(btrim(coalesce(p_pfc_version, '')), ''));
    v_primary text := upper(nullif(btrim(coalesce(p_pfc_primary, '')), ''));
    v_detailed text := upper(nullif(btrim(coalesce(p_pfc_detailed, '')), ''));
    v_confidence text := upper(nullif(btrim(coalesce(p_confidence_level, '')), ''));
    v_confidence_rank integer;
    v_category_id text;
    v_match_level text;
    v_min_confidence text;
    v_min_confidence_rank integer;
begin
    if v_version is distinct from 'v2' then
        return query select null::text, 'skipped_version'::text, null::text;
        return;
    end if;

    if v_operation_type not in ('expense', 'income') then
        return query select null::text, 'type_mismatch'::text, null::text;
        return;
    end if;

    if v_primary is null or v_detailed is null then
        return query select null::text, 'unmapped'::text, null::text;
        return;
    end if;

    if v_primary in (
        'TRANSFER_IN',
        'TRANSFER_OUT',
        'CASH_ADVANCE',
        'LOAN_DISBURSEMENTS'
    )
    or v_detailed in (
        'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT',
        'TRANSFER_IN_ACCOUNT_TRANSFER',
        'TRANSFER_IN_CASH_ADVANCES_AND_LOANS',
        'TRANSFER_OUT_ACCOUNT_TRANSFER',
        'TRANSFER_OUT_CREDIT_CARD_PAYMENT',
        'TRANSFER_OUT_WITHDRAWAL'
    ) then
        return query select null::text, 'transfer_excluded'::text, null::text;
        return;
    end if;

    v_confidence_rank := case v_confidence
        when 'VERY_HIGH' then 3
        when 'HIGH' then 2
        when 'MEDIUM' then 1
        else 0
    end;

    if v_confidence_rank = 0 then
        return query select null::text, 'skipped_confidence'::text, null::text;
        return;
    end if;

    select
        mappings.category_id,
        mappings.match_level,
        mappings.min_confidence
    into
        v_category_id,
        v_match_level,
        v_min_confidence
    from public.plaid_pfc_v2_category_mappings mappings
    where mappings.pfc_primary = v_primary
      and mappings.pfc_detailed = v_detailed
      and mappings.operation_type = v_operation_type;

    if found then
        v_min_confidence_rank := case v_min_confidence
            when 'VERY_HIGH' then 3
            when 'HIGH' then 2
            when 'MEDIUM' then 1
            else 4
        end;

        if v_confidence_rank >= v_min_confidence_rank then
            return query select v_category_id, 'mapped'::text, v_match_level;
        else
            return query select null::text, 'skipped_confidence'::text, null::text;
        end if;
        return;
    end if;

    select
        mappings.min_confidence
    into v_min_confidence
    from public.plaid_pfc_v2_category_mappings mappings
    where mappings.pfc_primary = v_primary
      and mappings.pfc_detailed = v_detailed
      and mappings.operation_type <> v_operation_type
    limit 1;

    if found then
        v_min_confidence_rank := case v_min_confidence
            when 'VERY_HIGH' then 3
            when 'HIGH' then 2
            when 'MEDIUM' then 1
            else 4
        end;

        if v_confidence_rank >= v_min_confidence_rank then
            return query select null::text, 'type_mismatch'::text, null::text;
        else
            return query select null::text, 'skipped_confidence'::text, null::text;
        end if;
        return;
    end if;

    return query select null::text, 'unmapped'::text, null::text;
end;
$$;

comment on function public.plaid_map_pfc_v2_to_ophir_category(
    text,
    text,
    text,
    text,
    text
) is
    'Pure server-owned lookup from Plaid PFCv2 operation type/category/confidence to nullable canonical Ophir category_id. Performs no writes.';

create or replace function public.plaid_preview_pfc_category_mapping_for_item(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_limit integer default 500
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_limit integer;
    v_result jsonb;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_limit is null
       or p_limit < 1
       or p_limit > 1000
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if not exists (
        select 1
        from public.plaid_items
        where plaid_items.id = p_plaid_item_id
          and plaid_items.user_id = p_user_id
    ) then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    v_limit := p_limit;

    with base as (
        select
            operations.type as operation_type,
            operations.category_overridden,
            raw.personal_finance_category_version as pfc_version,
            raw.personal_finance_category_primary as pfc_primary,
            raw.personal_finance_category_detailed as pfc_detailed,
            raw.personal_finance_category_confidence_level as confidence_level
        from public.plaid_transaction_operation_projections projection
        join public.operations
          on operations.id = projection.operation_id
         and operations.user_id = projection.user_id
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.operation_id is not null
          and operations.source = 'plaid'
        order by raw.date, raw.transaction_id
        limit v_limit
    ),
    evaluated as (
        select
            base.category_overridden,
            mapped.category_id,
            mapped.reason
        from base
        cross join lateral public.plaid_map_pfc_v2_to_ophir_category(
            base.operation_type,
            base.pfc_version,
            base.pfc_primary,
            base.pfc_detailed,
            base.confidence_level
        ) mapped
    )
    select jsonb_build_object(
        'scanned', count(*),
        'eligible', count(*) filter (
            where category_overridden = false
        ),
        'mapped', count(*) filter (
            where category_overridden = false
              and reason = 'mapped'
              and category_id is not null
        ),
        'unmapped', count(*) filter (
            where category_overridden = false
              and reason in ('unmapped', 'transfer_excluded')
        ),
        'skipped_override', count(*) filter (
            where category_overridden = true
        ),
        'skipped_version', count(*) filter (
            where category_overridden = false
              and reason = 'skipped_version'
        ),
        'skipped_confidence', count(*) filter (
            where category_overridden = false
              and reason = 'skipped_confidence'
        ),
        'skipped_type_mismatch', count(*) filter (
            where category_overridden = false
              and reason = 'type_mismatch'
        )
    )
    into v_result
    from evaluated;

    return coalesce(
        v_result,
        jsonb_build_object(
            'scanned', 0,
            'eligible', 0,
            'mapped', 0,
            'unmapped', 0,
            'skipped_override', 0,
            'skipped_version', 0,
            'skipped_confidence', 0,
            'skipped_type_mismatch', 0
        )
    );
end;
$$;

comment on function public.plaid_preview_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) is
    'Service-role dry-run aggregate preview for Plaid PFCv2 category mapping coverage on one Item. Performs no writes and returns no transaction, user, operation, amount, or merchant identifiers.';

revoke all on function public.plaid_map_pfc_v2_to_ophir_category(
    text,
    text,
    text,
    text,
    text
) from public;
revoke all on function public.plaid_map_pfc_v2_to_ophir_category(
    text,
    text,
    text,
    text,
    text
) from anon;
revoke all on function public.plaid_map_pfc_v2_to_ophir_category(
    text,
    text,
    text,
    text,
    text
) from authenticated;
grant execute on function public.plaid_map_pfc_v2_to_ophir_category(
    text,
    text,
    text,
    text,
    text
) to service_role;

revoke all on function public.plaid_preview_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_preview_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_preview_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_preview_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) to service_role;
