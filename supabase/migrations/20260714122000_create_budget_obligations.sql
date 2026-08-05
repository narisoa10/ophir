create table public.budget_obligations (
    id uuid primary key default gen_random_uuid(),

    setup_id uuid not null
        references public.budget_setups(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    category_id uuid,

    obligation_type text not null,
    amount numeric not null,
    currency_code char(3) not null,

    frequency text not null,
    frequency_interval integer,
    times_per_year integer,
    next_due_date date,

    minimum_debt_payment numeric,
    is_overdue boolean not null default false,

    source text not null default 'declared',
    confidence text not null default 'estimated',
    is_active boolean not null default true,
    note text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint budget_obligations_amount_check
        check (amount > 0),

    constraint budget_obligations_minimum_debt_payment_check
        check (
            minimum_debt_payment is null
            or minimum_debt_payment >= 0
        ),

    constraint budget_obligations_currency_code_check
        check (char_length(currency_code) = 3),

    constraint budget_obligations_obligation_type_check
        check (
            obligation_type in (
                'living_expense',
                'debt_minimum',
                'yearly_expense',
                'urgent_expense'
            )
        ),

    constraint budget_obligations_source_check
        check (
            source in (
                'declared',
                'manual_operation',
                'bank_detected',
                'confirmed',
                'system_calculated'
            )
        ),

    constraint budget_obligations_confidence_check
        check (
            confidence in (
                'estimated',
                'partially_observed',
                'verified'
            )
        ),

    constraint budget_obligations_frequency_check
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

    constraint budget_obligations_frequency_interval_check
        check (frequency_interval is null or frequency_interval >= 1),

    constraint budget_obligations_times_per_year_check
        check (times_per_year is null or times_per_year >= 1),

    constraint budget_obligations_every_n_months_check
        check (
            frequency <> 'every_n_months'
            or frequency_interval is not null
        ),

    constraint budget_obligations_times_per_year_required_check
        check (
            frequency <> 'times_per_year'
            or times_per_year is not null
        ),

    constraint budget_obligations_debt_minimum_payment_required_check
        check (
            obligation_type <> 'debt_minimum'
            or minimum_debt_payment is not null
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
        alter table public.budget_obligations
        add constraint budget_obligations_category_id_fkey
        foreign key (category_id)
        references public.categories(id)
        on delete set null;
    end if;
end;
$$;

create index budget_obligations_setup_id_idx
on public.budget_obligations(setup_id);

create index budget_obligations_user_id_idx
on public.budget_obligations(user_id);

create index budget_obligations_next_due_date_idx
on public.budget_obligations(next_due_date);

create index budget_obligations_is_overdue_idx
on public.budget_obligations(is_overdue);

create trigger budget_obligations_set_updated_at
before update on public.budget_obligations
for each row
execute function public.set_updated_at();

alter table public.budget_obligations enable row level security;

create policy "budget_obligations_select_own"
on public.budget_obligations
for select
to authenticated
using (auth.uid() = user_id);

create policy "budget_obligations_insert_own"
on public.budget_obligations
for insert
to authenticated
with check (
    auth.uid() = user_id
    and exists (
        select 1
        from public.budget_setups
        where budget_setups.id = budget_obligations.setup_id
          and budget_setups.user_id = auth.uid()
    )
);

create policy "budget_obligations_update_own"
on public.budget_obligations
for update
to authenticated
using (auth.uid() = user_id)
with check (
    auth.uid() = user_id
    and exists (
        select 1
        from public.budget_setups
        where budget_setups.id = budget_obligations.setup_id
          and budget_setups.user_id = auth.uid()
    )
);

create policy "budget_obligations_delete_own"
on public.budget_obligations
for delete
to authenticated
using (auth.uid() = user_id);
