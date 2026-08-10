alter table public.plaid_items
    add column transactions_cursor text null,
    add column transactions_last_synced_at timestamptz null,
    add column transactions_initial_sync_completed_at timestamptz null;

comment on column public.plaid_items.transactions_cursor is
    'Plaid /transactions/sync cursor for this Item. Advanced only after a future sync engine atomically persists a complete consistent batch.';

comment on column public.plaid_items.transactions_initial_sync_completed_at is
    'Set only when a future transactions sync lifecycle determines the initial/historical transaction state is ready. A single /transactions/sync call is not sufficient by itself.';

create unique index plaid_items_id_user_id_unique
on public.plaid_items(id, user_id);

create unique index accounts_id_user_id_unique
on public.accounts(id, user_id);

create table public.plaid_transactions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    plaid_item_id uuid not null,

    account_id uuid not null,

    plaid_account_id text not null
        constraint plaid_transactions_plaid_account_id_check
        check (trim(plaid_account_id) <> ''),

    transaction_id text not null
        constraint plaid_transactions_transaction_id_check
        check (trim(transaction_id) <> ''),

    pending boolean not null,

    pending_transaction_id text null
        constraint plaid_transactions_pending_transaction_id_check
        check (
            pending_transaction_id is null
            or trim(pending_transaction_id) <> ''
        ),

    date date not null,

    authorized_date date null,

    datetime timestamptz null,

    authorized_datetime timestamptz null,

    amount numeric not null,

    iso_currency_code text null,

    unofficial_currency_code text null,

    name text not null
        constraint plaid_transactions_name_check
        check (trim(name) <> ''),

    merchant_name text null,

    payment_channel text null,

    merchant_entity_id text null,

    personal_finance_category_primary text null,

    personal_finance_category_detailed text null,

    personal_finance_category_confidence_level text null,

    personal_finance_category_version text null,

    removed_at timestamptz null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_transactions_item_transaction_unique
        unique (plaid_item_id, transaction_id),

    constraint plaid_transactions_plaid_item_user_fkey
        foreign key (plaid_item_id, user_id)
        references public.plaid_items(id, user_id)
        on delete cascade,

    constraint plaid_transactions_account_user_fkey
        foreign key (account_id, user_id)
        references public.accounts(id, user_id)
        on delete cascade
);

comment on table public.plaid_transactions is
    'Raw Plaid Transactions source-of-truth ingestion layer. Does not store Ophir category projection or Operation interpretation.';

comment on column public.plaid_transactions.transaction_id is
    'Case-sensitive Plaid transaction_id. Unique only within the Ophir Plaid Item connection.';

comment on column public.plaid_transactions.amount is
    'Plaid signed transaction amount stored as received. Positive means money out in Plaid semantics.';

comment on column public.plaid_transactions.removed_at is
    'Null means active Plaid transaction. Non-null means Plaid reported the transaction as removed; retained for audit/lifecycle.';

create index plaid_transactions_user_id_date_idx
on public.plaid_transactions(user_id, date desc);

create index plaid_transactions_account_id_date_idx
on public.plaid_transactions(account_id, date desc);

create index plaid_transactions_plaid_item_id_date_idx
on public.plaid_transactions(plaid_item_id, date desc);

create index plaid_transactions_active_user_id_date_idx
on public.plaid_transactions(user_id, date desc)
where removed_at is null;

create trigger plaid_transactions_set_updated_at
before update on public.plaid_transactions
for each row
execute function public.set_updated_at();

alter table public.plaid_transactions enable row level security;

create policy "plaid_transactions_select_own"
on public.plaid_transactions
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.plaid_transactions from public, anon, authenticated;
grant select on table public.plaid_transactions to authenticated;
