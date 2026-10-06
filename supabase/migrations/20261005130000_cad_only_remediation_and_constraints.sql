-- CAD-only remediation and database invariants. Requires
-- 20261005120000_cad_only_product_currency.sql (public.product_currency_code()).
--
-- Product-owned currency (profiles, budget items, manual Operations) becomes
-- CAD-only. External currency (accounts.currency_code / unofficial_currency_code,
-- plaid_transactions, Plaid Operations) keeps what Plaid reports; an account in
-- any other currency is kept but can never take part in finances.
--
-- Amounts are never changed. Relabelling is limited to the one provable legacy
-- case: 'USD' that came from the old profiles default and was inherited by the
-- budget (no UI ever offered a currency choice for either). Anything else that
-- is not CAD aborts the migration instead of being rewritten.

-- ---------------------------------------------------------------------------
-- 1) Legacy product currency
-- ---------------------------------------------------------------------------

do $$
declare
    -- The old profiles.currency_code default and handle_new_user value.
    c_legacy_default constant char(3) := 'USD';
    c_product constant char(3) := public.product_currency_code();
begin
    if exists (
        select 1 from public.profiles
        where currency_code not in (c_product, c_legacy_default)
    ) then
        raise exception 'CAD-only remediation: a profile has a currency other than % or %', c_product, c_legacy_default
            using errcode = 'P0001';
    end if;

    -- A budget item may only be relabelled if it inherited the legacy default
    -- from its owner's profile.
    if exists (
        select 1
        from (
            select user_id, currency_code from public.budget_income_sources
            union all
            select user_id, currency_code from public.budget_obligations
        ) item
        left join public.profiles profile on profile.id = item.user_id
        where item.currency_code <> c_product
          and (item.currency_code <> c_legacy_default
               or profile.currency_code is distinct from c_legacy_default)
    ) then
        raise exception 'CAD-only remediation: a budget item has a currency not inherited from the legacy profile default'
            using errcode = 'P0001';
    end if;

    -- Manual Operations were always created in the product currency; another
    -- currency here has no provable origin.
    if exists (
        select 1 from public.operations
        where source = 'manual' and currency_code <> c_product
    ) then
        raise exception 'CAD-only remediation: a manual Operation is not in %', c_product
            using errcode = 'P0001';
    end if;

    update public.budget_income_sources
    set currency_code = c_product
    where currency_code = c_legacy_default;

    update public.budget_obligations
    set currency_code = c_product
    where currency_code = c_legacy_default;

    update public.profiles
    set currency_code = c_product
    where currency_code = c_legacy_default;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Product-owned currency invariants
-- ---------------------------------------------------------------------------

-- Validated: a violating row aborts this migration. Authenticated clients write
-- these tables directly under RLS, so the database is the only complete guard.

alter table public.profiles
    add constraint profiles_product_currency_check
        check (currency_code = public.product_currency_code());

alter table public.budget_income_sources
    add constraint budget_income_sources_product_currency_check
        check (currency_code = public.product_currency_code());

alter table public.budget_obligations
    add constraint budget_obligations_product_currency_check
        check (currency_code = public.product_currency_code());

alter table public.operations
    add constraint operations_manual_product_currency_check
        check (source <> 'manual' or currency_code = public.product_currency_code());

comment on constraint operations_manual_product_currency_check on public.operations is
    'A manual Operation is in the product currency. Plaid Operations keep the currency Plaid reports.';

-- ---------------------------------------------------------------------------
-- 3) Financial participation of accounts
-- ---------------------------------------------------------------------------

-- is_included_in_finances is the user's choice to count an account in finances
-- (the only accounts column clients may update). An account that is not in the
-- product currency cannot be counted, so the choice is always false for it.

update public.accounts
set is_included_in_finances = false
where is_included_in_finances
  and currency_code is distinct from public.product_currency_code();

-- Plaid writes accounts through several RPCs (connect, sync, presence,
-- disconnect); this keeps every one of them, now and later, within the check
-- below. A user's own update of is_included_in_finances does not fire it and is
-- rejected by the check instead.
create or replace function public.accounts_exclude_unsupported_currency()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.currency_code is distinct from public.product_currency_code() then
        new.is_included_in_finances := false;
    end if;
    return new;
end;
$$;

create trigger accounts_exclude_unsupported_currency
before insert or update of currency_code on public.accounts
for each row
execute function public.accounts_exclude_unsupported_currency();

alter table public.accounts
    add constraint accounts_financial_participation_currency_check
        check (
            not is_included_in_finances
            or currency_code is not distinct from public.product_currency_code()
        );

comment on constraint accounts_financial_participation_currency_check on public.accounts is
    'Only an account in the product currency can be included in finances. The account and its Plaid currency are kept as reported.';
