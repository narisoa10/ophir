create table public.operations (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    account_id uuid not null
        references public.accounts(id)
        on delete restrict,

    category_id uuid
        references public.categories(id)
        on delete restrict,

    type text not null,

    amount numeric(14, 2) not null,

    currency_code char(3) not null,

    occurred_at timestamptz not null,

    note text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint operations_type_check
        check (type in ('expense', 'income', 'transfer')),

    constraint operations_amount_check
        check (amount > 0),

    constraint operations_currency_code_check
        check (char_length(currency_code) = 3),

    constraint operations_transfer_category_check
        check (
            (type = 'transfer' and category_id is null)
            or
            (type in ('expense', 'income') and category_id is not null)
        )
);

create index operations_user_id_idx
on public.operations(user_id);

create index operations_account_id_idx
on public.operations(account_id);

create index operations_category_id_idx
on public.operations(category_id);

create index operations_user_id_occurred_at_idx
on public.operations(user_id, occurred_at desc);

create trigger operations_set_updated_at
before update on public.operations
for each row
execute function public.set_updated_at();

alter table public.operations enable row level security;

create policy "Users can read own operations"
on public.operations
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own operations"
on public.operations
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own operations"
on public.operations
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own operations"
on public.operations
for delete
to authenticated
using (auth.uid() = user_id);