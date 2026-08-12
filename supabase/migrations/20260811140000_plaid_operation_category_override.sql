create or replace function public.ophir_operation_category_type(
    p_category_id text
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when p_category_id in (
            'expenseHousingRent',
            'expenseHousingMortgage',
            'expenseHousingPropertyTax',
            'expenseHousingCondoFees',
            'expenseHousingElectricity',
            'expenseHousingNaturalGas',
            'expenseHousingWater',
            'expenseHousingSewer',
            'expenseHousingGarbageCollection',
            'expenseHousingInternet',
            'expenseHousingMobilePhone',
            'expenseHousingHomePhone',
            'expenseHousingHomeInsurance',
            'expenseHousingHomeMaintenance',
            'expenseHousingFurniture',
            'expenseHousingAppliances',
            'expenseHousingHomeSupplies',
            'expenseHousingHomeSecurity',
            'expenseFoodGroceries',
            'expenseFoodFarmersMarket',
            'expenseFoodRestaurant',
            'expenseFoodCafeCoffee',
            'expenseFoodFastFood',
            'expenseFoodFoodDelivery',
            'expenseFoodSnacks',
            'expenseFoodAlcohol',
            'expenseTransportationFuel',
            'expenseTransportationEvCharging',
            'expenseTransportationPublicTransit',
            'expenseTransportationTaxiRideSharing',
            'expenseTransportationParking',
            'expenseTransportationTollRoads',
            'expenseTransportationAutoInsurance',
            'expenseTransportationAutoLoan',
            'expenseTransportationVehicleMaintenance',
            'expenseTransportationTireService',
            'expenseTransportationVehicleRegistration',
            'expenseTransportationCarWash',
            'expenseHealthPharmacy',
            'expenseHealthMedicine',
            'expenseHealthDoctor',
            'expenseHealthDentist',
            'expenseHealthVisionCare',
            'expenseHealthMedicalTests',
            'expenseHealthMedicalProcedures',
            'expenseHealthHealthInsurance',
            'expenseHealthMentalHealth',
            'expenseHealthPhysiotherapy',
            'expenseHealthGymFitness',
            'expenseHealthVitamins',
            'expenseFamilyChildcare',
            'expenseFamilyDaycare',
            'expenseFamilySchool',
            'expenseFamilyUniversity',
            'expenseFamilyTutoring',
            'expenseFamilyChildrensClothing',
            'expenseFamilyBabySupplies',
            'expenseFamilyToys',
            'expenseFamilyChildSupport',
            'expensePersonalCareClothing',
            'expensePersonalCareShoes',
            'expensePersonalCareCosmetics',
            'expensePersonalCareJewelry',
            'expensePersonalCareHaircare',
            'expensePersonalCareNailCare',
            'expensePersonalCarePersonalHygiene',
            'expensePersonalCareContactLenses',
            'expenseEntertainmentLifestyleMovies',
            'expenseEntertainmentLifestyleTheatre',
            'expenseEntertainmentLifestyleConcerts',
            'expenseEntertainmentLifestyleGaming',
            'expenseEntertainmentLifestyleStreamingSubscriptions',
            'expenseEntertainmentLifestyleMusic',
            'expenseEntertainmentLifestyleBooks',
            'expenseEntertainmentLifestyleHobbies',
            'expenseEntertainmentLifestyleTravel',
            'expenseEntertainmentLifestyleHotels',
            'expenseEducationCourses',
            'expenseEducationOnlineLearning',
            'expenseEducationUniversityTuition',
            'expenseEducationCertifications',
            'expenseEducationConferences',
            'expenseEducationLanguageCourses',
            'expenseEducationEducationalMaterials',
            'expenseFinanceBankFees',
            'expenseFinanceAtmFees',
            'expenseFinanceCreditCardPayment',
            'expenseFinanceLoanPayment',
            'expenseFinanceDebtRepayment',
            'expenseFinanceSavings',
            'expenseFinanceEmergencyFund',
            'expenseFinanceTfsaContribution',
            'expenseFinanceRrspContribution',
            'expenseFinanceRespContribution',
            'expenseFinanceInvestments',
            'expenseFinanceCurrencyExchange',
            'expenseGovernmentIncomeTax',
            'expenseGovernmentDriverLicence',
            'expenseGovernmentPassport',
            'expenseGovernmentImmigrationFees',
            'expenseGovernmentPermits',
            'expenseGovernmentGovernmentServices',
            'expensePetsPetFood',
            'expensePetsVeterinary',
            'expensePetsPetMedicine',
            'expensePetsPetInsurance',
            'expensePetsGrooming',
            'expensePetsPetSupplies',
            'expenseGivingTithe',
            'expenseGivingGifts',
            'expenseGivingCharity',
            'expenseGivingDonations',
            'expenseGivingHolidayExpenses',
            'expenseWorkOfficeSupplies',
            'expenseWorkSoftware',
            'expenseWorkEquipment',
            'expenseWorkBusinessTravel',
            'expenseWorkProfessionalMemberships',
            'expenseWorkLicences',
            'expenseOtherCashWithdrawal',
            'expenseOtherAdjustment',
            'expenseOtherUncategorized'
        ) then 'expense'
        when p_category_id in (
            'incomeEmploymentSalary',
            'incomeEmploymentBonus',
            'incomeEmploymentOvertime',
            'incomeEmploymentCommission',
            'incomeEmploymentTips',
            'incomeBusinessBusinessIncome',
            'incomeBusinessFreelance',
            'incomeBusinessConsulting',
            'incomeBusinessRentalIncome',
            'incomeInvestmentsInterestIncome',
            'incomeInvestmentsDividendIncome',
            'incomeInvestmentsCapitalGains',
            'incomeInvestmentsInvestmentDistribution',
            'incomeGovernmentTaxRefund',
            'incomeGovernmentGovernmentBenefits',
            'incomeGovernmentPension',
            'incomeGovernmentChildBenefit',
            'incomeGovernmentEmploymentInsurance',
            'incomeGiftsGiftReceived',
            'incomeGiftsFamilySupport',
            'incomeGiftsCashback',
            'incomeGiftsRewards',
            'incomeOtherIncomeRefund',
            'incomeOtherIncomeReimbursement',
            'incomeOtherIncomeSaleOfItem',
            'incomeOtherIncomeOtherIncome'
        ) then 'income'
        else null
    end;
$$;

comment on function public.ophir_operation_category_type(text) is
    'Server-side validation helper for canonical Ophir AppCategoryId.name values used by narrow Operation RPCs.';

create or replace function public.plaid_override_operation_category(
    p_operation_id uuid,
    p_category_id text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_operation public.operations%rowtype;
    v_category_id text := nullif(btrim(p_category_id), '');
    v_category_type text;
begin
    if v_user_id is null then
        raise exception 'unauthenticated' using errcode = '28000';
    end if;

    if p_operation_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_operation
    from public.operations
    where id = p_operation_id
      and user_id = v_user_id
      and source = 'plaid'
      and archived_at is null
    for update;

    if not found then
        return jsonb_build_object('status', 'not_found');
    end if;

    if v_operation.type not in ('expense', 'income') then
        raise exception 'unsupported_operation_type' using errcode = '22023';
    end if;

    if v_category_id is not null then
        v_category_type := public.ophir_operation_category_type(v_category_id);

        if v_category_type is null then
            raise exception 'invalid_category' using errcode = '22023';
        end if;

        if v_operation.type is distinct from v_category_type then
            raise exception 'category_type_mismatch' using errcode = '22023';
        end if;
    end if;

    update public.operations
    set
        category_id = v_category_id,
        category_overridden = true
    where id = v_operation.id
      and user_id = v_user_id
      and source = 'plaid'
      and archived_at is null
    returning * into v_operation;

    return jsonb_build_object(
        'status', 'updated',
        'category_id', v_operation.category_id,
        'category_overridden', v_operation.category_overridden
    );
end;
$$;

comment on function public.plaid_override_operation_category(uuid, text) is
    'Authenticated owner-only RPC to change only category_id on an active Plaid Operation and mark category_overridden=true. NULL category_id is explicit user uncategorized.';

create or replace function public.plaid_reset_operation_category_override(
    p_operation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_operation public.operations%rowtype;
    v_mapped_category_id text;
begin
    if v_user_id is null then
        raise exception 'unauthenticated' using errcode = '28000';
    end if;

    if p_operation_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_operation
    from public.operations
    where id = p_operation_id
      and user_id = v_user_id
      and source = 'plaid'
      and archived_at is null
    for update;

    if not found then
        return jsonb_build_object('status', 'not_found');
    end if;

    if v_operation.type not in ('expense', 'income') then
        raise exception 'unsupported_operation_type' using errcode = '22023';
    end if;

    select mapped.category_id
    into v_mapped_category_id
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    cross join lateral public.plaid_map_pfc_v2_to_ophir_category(
        v_operation.type,
        raw.personal_finance_category_version,
        raw.personal_finance_category_primary,
        raw.personal_finance_category_detailed,
        raw.personal_finance_category_confidence_level
    ) mapped
    where projection.operation_id = v_operation.id
      and projection.user_id = v_user_id
    limit 1;

    update public.operations
    set
        category_id = v_mapped_category_id,
        category_overridden = false
    where id = v_operation.id
      and user_id = v_user_id
      and source = 'plaid'
      and archived_at is null
    returning * into v_operation;

    return jsonb_build_object(
        'status', 'reset',
        'category_id', v_operation.category_id,
        'category_overridden', v_operation.category_overridden
    );
end;
$$;

comment on function public.plaid_reset_operation_category_override(uuid) is
    'Authenticated owner-only RPC to return an active Plaid Operation category to automatic PFC management without accepting client-provided PFC/category suggestions.';

revoke all on function public.ophir_operation_category_type(text)
from public;
revoke all on function public.ophir_operation_category_type(text)
from anon;
revoke all on function public.ophir_operation_category_type(text)
from authenticated;
grant execute on function public.ophir_operation_category_type(text)
to service_role;

revoke all on function public.plaid_override_operation_category(uuid, text)
from public;
revoke all on function public.plaid_override_operation_category(uuid, text)
from anon;
grant execute on function public.plaid_override_operation_category(uuid, text)
to authenticated;

revoke all on function public.plaid_reset_operation_category_override(uuid)
from public;
revoke all on function public.plaid_reset_operation_category_override(uuid)
from anon;
grant execute on function public.plaid_reset_operation_category_override(uuid)
to authenticated;
