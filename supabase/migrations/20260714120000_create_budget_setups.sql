create table public.budget_setups (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text not null default 'draft',
    version integer not null default 1,
    current_step integer not null default 0,

    adults_count integer not null default 1,
    children_count integer not null default 0,

    declared_current_balance numeric,
    reserve_amount numeric,
    overdue_amount numeric,
    upcoming_large_mandatory_amount numeric,
    upcoming_large_mandatory_date date,

    completed_at timestamptz,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint budget_setups_status_check
        check (status in ('draft', 'completed', 'archived')),

    constraint budget_setups_version_check
        check (version >= 1),

    constraint budget_setups_current_step_check
        check (current_step >= 0),

    constraint budget_setups_adults_count_check
        check (adults_count >= 1),

    constraint budget_setups_children_count_check
        check (children_count >= 0),

    constraint budget_setups_declared_current_balance_check
        check (declared_current_balance is null or declared_current_balance >= 0),

    constraint budget_setups_reserve_amount_check
        check (reserve_amount is null or reserve_amount >= 0),

    constraint budget_setups_overdue_amount_check
        check (overdue_amount is null or overdue_amount >= 0),

    constraint budget_setups_upcoming_large_mandatory_amount_check
        check (
            upcoming_large_mandatory_amount is null
            or upcoming_large_mandatory_amount >= 0
        ),

    constraint budget_setups_user_id_unique
        unique (user_id)
);

create index budget_setups_user_id_idx
on public.budget_setups(user_id);

create trigger budget_setups_set_updated_at
before update on public.budget_setups
for each row
execute function public.set_updated_at();

alter table public.budget_setups enable row level security;

create policy "budget_setups_select_own"
on public.budget_setups
for select
to authenticated
using (auth.uid() = user_id);

create policy "budget_setups_insert_own"
on public.budget_setups
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "budget_setups_update_own"
on public.budget_setups
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "budget_setups_delete_own"
on public.budget_setups
for delete
to authenticated
using (auth.uid() = user_id);
