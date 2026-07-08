create table public.accounts (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    name text not null,
    type text not null,
    currency_code char(3) not null,

    initial_balance numeric(14, 2) not null default 0,

    icon_key text not null,
    color_key text not null,

    sort_order integer not null default 0,
    is_archived boolean not null default false,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint accounts_name_check
        check (name <> ''),

    constraint accounts_type_check
        check (
            type in (
                'cash',
                'bank',
                'card',
                'credit_card',
                'savings',
                'investment',
                'loan',
                'wallet',
                'other'
            )
        ),

    constraint accounts_currency_code_check
        check (char_length(currency_code) = 3),

    constraint accounts_icon_key_check
        check (icon_key <> ''),

    constraint accounts_color_key_check
        check (color_key <> '')
);

create index accounts_user_id_idx
on public.accounts(user_id);

create index accounts_user_id_is_archived_idx
on public.accounts(user_id, is_archived);

create trigger accounts_set_updated_at
before update on public.accounts
for each row
execute function public.set_updated_at();

alter table public.accounts enable row level security;

create policy "Users can read own accounts"
on public.accounts
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own accounts"
on public.accounts
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own accounts"
on public.accounts
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own accounts"
on public.accounts
for delete
to authenticated
using (auth.uid() = user_id);