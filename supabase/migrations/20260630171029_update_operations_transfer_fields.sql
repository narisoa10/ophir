alter table public.operations
rename column account_id to from_account_id;

alter table public.operations
add column to_account_id uuid
    references public.accounts(id)
    on delete restrict;

alter table public.operations
add column is_recurring boolean not null default false;

drop index if exists operations_account_id_idx;

create index operations_from_account_id_idx
on public.operations(from_account_id);

create index operations_to_account_id_idx
on public.operations(to_account_id);

alter table public.operations
drop constraint operations_transfer_category_check;

alter table public.operations
add constraint operations_transfer_check
check (
    (
        type = 'transfer'
        and category_id is null
        and to_account_id is not null
        and from_account_id <> to_account_id
    )
    or
    (
        type in ('expense', 'income')
        and category_id is not null
        and to_account_id is null
    )
);