create table public.institutions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    plaid_item_id uuid not null
        references public.plaid_items(id)
        on delete cascade,

    plaid_institution_id text null,

    name text not null
        constraint institutions_name_check
        check (trim(name) <> ''),

    logo_base64 text null,
    primary_color text null,
    url text null,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint institutions_plaid_item_unique
        unique (plaid_item_id)
);

create index institutions_user_id_idx
on public.institutions(user_id);

create trigger institutions_set_updated_at
before update on public.institutions
for each row
execute function public.set_updated_at();

alter table public.institutions enable row level security;

create policy "institutions_select_own"
on public.institutions
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.institutions from anon, authenticated;

alter table public.accounts
    add column plaid_item_id uuid null
        references public.plaid_items(id)
        on delete set null,
    add column institution_id uuid null
        references public.institutions(id)
        on delete set null,
    add column plaid_account_id text null,
    add column official_name text null,
    add column mask text null,
    add column plaid_type text null,
    add column plaid_subtype text null,
    add column current_balance numeric(14, 2) null,
    add column available_balance numeric(14, 2) null,
    add column balance_fetched_at timestamptz null;

alter table public.accounts
    add constraint accounts_plaid_account_id_check
        check (plaid_account_id is null or trim(plaid_account_id) <> '');

create index accounts_plaid_item_id_idx
on public.accounts(plaid_item_id);

create index accounts_institution_id_idx
on public.accounts(institution_id);

create unique index accounts_user_plaid_account_unique
on public.accounts(user_id, plaid_account_id)
where plaid_account_id is not null;

create unique index accounts_plaid_item_plaid_account_unique
on public.accounts(plaid_item_id, plaid_account_id)
where plaid_item_id is not null
  and plaid_account_id is not null;
