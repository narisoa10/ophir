create table public.budget_income_sources (
    id uuid primary key default gen_random_uuid(),

    setup_id uuid not null
        references public.budget_setups(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    category_id uuid,

    income_type text not null,
    amount numeric not null,
    currency_code char(3) not null,

    frequency text not null,
    frequency_interval integer,
    times_per_year integer,
    next_date date,

    variability text not null,
    priority text not null,
    source text not null default 'declared',
    confidence text not null default 'estimated',
    is_active boolean not null default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint budget_income_sources_amount_check
        check (amount > 0),

    constraint budget_income_sources_currency_code_check
        check (char_length(currency_code) = 3),

    constraint budget_income_sources_variability_check
        check (variability in ('fixed', 'variable')),

    constraint budget_income_sources_priority_check
        check (priority in ('primary', 'secondary')),

    constraint budget_income_sources_source_check
        check (
            source in (
                'declared',
                'manual_operation',
                'bank_detected',
                'confirmed',
                'system_calculated'
            )
        ),

    constraint budget_income_sources_confidence_check
        check (
            confidence in (
                'estimated',
                'partially_observed',
                'verified'
            )
        ),

    constraint budget_income_sources_frequency_check
        check (
            frequency in (
                'daily',
                'weekly',
                'biweekly',
                'semi_monthly',
                'monthly',
                'every_n_months',
                'times_per_year',
                'yearly',
                'irregular'
            )
        ),

    constraint budget_income_sources_frequency_interval_check
        check (frequency_interval is null or frequency_interval >= 1),

    constraint budget_income_sources_times_per_year_check
        check (times_per_year is null or times_per_year >= 1),

    constraint budget_income_sources_every_n_months_check
        check (
            frequency <> 'every_n_months'
            or frequency_interval is not null
        ),

    constraint budget_income_sources_times_per_year_required_check
        check (
            frequency <> 'times_per_year'
            or times_per_year is not null
        )
);

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'categories'
          and column_name = 'id'
          and data_type = 'uuid'
    ) then
        alter table public.budget_income_sources
        add constraint budget_income_sources_category_id_fkey
        foreign key (category_id)
        references public.categories(id)
        on delete set null;
    end if;
end;
$$;

create index budget_income_sources_setup_id_idx
on public.budget_income_sources(setup_id);

create index budget_income_sources_user_id_idx
on public.budget_income_sources(user_id);

create index budget_income_sources_next_date_idx
on public.budget_income_sources(next_date);

create trigger budget_income_sources_set_updated_at
before update on public.budget_income_sources
for each row
execute function public.set_updated_at();

alter table public.budget_income_sources enable row level security;

create policy "budget_income_sources_select_own"
on public.budget_income_sources
for select
to authenticated
using (auth.uid() = user_id);

create policy "budget_income_sources_insert_own"
on public.budget_income_sources
for insert
to authenticated
with check (
    auth.uid() = user_id
    and exists (
        select 1
        from public.budget_setups
        where budget_setups.id = budget_income_sources.setup_id
          and budget_setups.user_id = auth.uid()
    )
);

create policy "budget_income_sources_update_own"
on public.budget_income_sources
for update
to authenticated
using (auth.uid() = user_id)
with check (
    auth.uid() = user_id
    and exists (
        select 1
        from public.budget_setups
        where budget_setups.id = budget_income_sources.setup_id
          and budget_setups.user_id = auth.uid()
    )
);

create policy "budget_income_sources_delete_own"
on public.budget_income_sources
for delete
to authenticated
using (auth.uid() = user_id);
