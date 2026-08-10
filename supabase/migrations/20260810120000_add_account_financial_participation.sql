alter table public.accounts
    add column is_included_in_finances boolean not null default true;
