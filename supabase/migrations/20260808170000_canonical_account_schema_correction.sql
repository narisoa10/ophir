-- Checkpoint 4: canonical schema correction for faithful Plaid bank-account persistence.

alter table public.accounts
    alter column type drop not null;

alter table public.accounts
    alter column currency_code drop not null;

alter table public.accounts
    add column unofficial_currency_code text null;

alter table public.accounts
    alter column initial_balance drop not null;

alter table public.accounts
    alter column initial_balance drop default;

alter table public.accounts
    alter column icon_key drop not null;

alter table public.accounts
    alter column color_key drop not null;

alter table public.accounts
    add constraint accounts_plaid_currency_required
    check (
        plaid_account_id is null
        or currency_code is not null
        or unofficial_currency_code is not null
    );

alter table public.institutions
    alter column name drop not null;
