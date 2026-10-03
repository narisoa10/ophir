-- Operations integrity: manual Operations are income or expense only, and every
-- account an Operation references belongs to the Operation's user.
--
-- type = 'transfer' stays part of the general model (operations_type_check,
-- operations_transfer_check) for system and legacy rows; only source = 'manual'
-- is restricted. Authenticated clients write public.operations directly under RLS,
-- which checks the row's user_id but not the owner of a referenced account; FK
-- checks bypass RLS.
--
-- Constraints are added validated: a violating row aborts this migration.

alter table public.operations
    add constraint operations_manual_income_expense_check
        check (
            source <> 'manual'
            or (
                type in ('income', 'expense')
                and to_account_id is null
            )
        );

comment on constraint operations_manual_income_expense_check on public.operations is
    'A manual Operation is income or expense and has no destination account. Transfers are system-only.';

-- Same columns, target and ON DELETE RESTRICT as the single-column FKs they
-- replace, plus the owner. A NULL account is not checked (MATCH SIMPLE).
alter table public.operations
    add constraint operations_from_account_user_fkey
        foreign key (from_account_id, user_id)
        references public.accounts(id, user_id)
        on delete restrict;

alter table public.operations
    add constraint operations_to_account_user_fkey
        foreign key (to_account_id, user_id)
        references public.accounts(id, user_id)
        on delete restrict;

alter table public.operations
    drop constraint operations_account_id_fkey;

alter table public.operations
    drop constraint operations_to_account_id_fkey;
