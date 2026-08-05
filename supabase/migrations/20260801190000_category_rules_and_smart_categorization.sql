-- Stage 2/3: merchant category rules + apply to history.

create or replace function public.normalize_merchant_key(p_text text)
returns text
language sql
immutable
as $$
    select lower(
        trim(
            regexp_replace(coalesce(p_text, ''), '\s+#\d+.*$', '', 'g')
        )
    );
$$;

create table public.category_rules (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    merchant_key text not null,
    category_id text not null,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint category_rules_merchant_key_not_empty
        check (btrim(merchant_key) <> ''),

    constraint category_rules_category_id_not_empty
        check (btrim(category_id) <> ''),

    constraint category_rules_user_merchant_unique
        unique (user_id, merchant_key)
);

create index category_rules_user_id_idx
on public.category_rules(user_id);

create trigger category_rules_set_updated_at
before update on public.category_rules
for each row
execute function public.set_updated_at();

alter table public.category_rules enable row level security;

create policy "category_rules_select_own"
on public.category_rules
for select
to authenticated
using (auth.uid() = user_id);

create policy "category_rules_insert_own"
on public.category_rules
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "category_rules_update_own"
on public.category_rules
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "category_rules_delete_own"
on public.category_rules
for delete
to authenticated
using (auth.uid() = user_id);

-- Stage 3: backfill matching uncategorized bank-sync operations.
create or replace function public.apply_category_rule_to_operations(
    p_user_id uuid,
    p_merchant_key text,
    p_category_id text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_updated integer;
begin
    update public.operations
    set
        category_id = p_category_id,
        category_overridden = true,
        updated_at = now()
    where user_id = p_user_id
      and source = 'bankSync'
      and archived_at is null
      and category_overridden = false
      and public.normalize_merchant_key(note) = p_merchant_key;

    get diagnostics v_updated = row_count;
    return v_updated;
end;
$$;

revoke all on function public.apply_category_rule_to_operations(uuid, text, text)
from public;

grant execute on function public.apply_category_rule_to_operations(uuid, text, text)
to authenticated;

-- Stage 2: apply saved rules during Plaid materialization.
create or replace function public.materialize_plaid_operation(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_plaid_transaction_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tx public.plaid_transactions%rowtype;
    v_account_currency char(3);
    v_operation_type text;
    v_operation_amount numeric(14, 2);
    v_category_id text;
    v_rule_category_id text;
    v_currency_code char(3);
    v_note text;
    v_merchant_key text;
    v_occurred_at timestamptz;
begin
    if p_plaid_transaction_id is null or p_plaid_transaction_id = '' then
        return;
    end if;

    select *
    into v_tx
    from public.plaid_transactions
    where user_id = p_user_id
      and plaid_item_id = p_plaid_item_id
      and plaid_transaction_id = p_plaid_transaction_id;

    if not found then
        perform public.archive_plaid_bank_sync_operation(
            p_user_id,
            p_plaid_transaction_id
        );
        return;
    end if;

    if v_tx.removed_at is not null then
        perform public.archive_plaid_bank_sync_operation(
            p_user_id,
            p_plaid_transaction_id
        );
        return;
    end if;

    if v_tx.amount = 0 then
        return;
    end if;

    if v_tx.amount > 0 then
        v_operation_type := 'expense';
        v_category_id := public.map_plaid_pfc_to_category_id(
            v_tx.personal_finance_category_primary,
            v_tx.personal_finance_category_detailed,
            'expense'
        );
    else
        v_operation_type := 'income';
        v_category_id := public.map_plaid_pfc_to_category_id(
            v_tx.personal_finance_category_primary,
            v_tx.personal_finance_category_detailed,
            'income'
        );
    end if;

    v_operation_amount := round(abs(v_tx.amount), 2);

    if v_operation_amount <= 0 then
        return;
    end if;

    select accounts.currency_code
    into v_account_currency
    from public.accounts
    where accounts.id = v_tx.account_id
      and accounts.user_id = p_user_id;

    v_currency_code := upper(
        coalesce(
            nullif(v_tx.iso_currency_code, ''),
            v_account_currency,
            'CAD'
        )
    )::char(3);

    v_note := coalesce(nullif(v_tx.merchant_name, ''), v_tx.name);
    v_merchant_key := public.normalize_merchant_key(v_note);

    if v_merchant_key <> '' then
        select cr.category_id
        into v_rule_category_id
        from public.category_rules cr
        where cr.user_id = p_user_id
          and cr.merchant_key = v_merchant_key;

        if v_rule_category_id is not null then
            v_category_id := v_rule_category_id;
        end if;
    end if;

    v_occurred_at := (
        v_tx.date::timestamp + interval '12 hours'
    ) at time zone 'UTC';

    if v_tx.pending = false
        and v_tx.pending_transaction_id is not null
    then
        perform public.archive_plaid_bank_sync_operation(
            p_user_id,
            v_tx.pending_transaction_id
        );
    end if;

    insert into public.operations (
        user_id,
        from_account_id,
        to_account_id,
        category_id,
        type,
        amount,
        currency_code,
        occurred_at,
        recurrence,
        is_recurring,
        note,
        source,
        external_id,
        is_pending,
        category_overridden,
        archived_at
    )
    values (
        v_tx.user_id,
        v_tx.account_id,
        null,
        v_category_id,
        v_operation_type,
        v_operation_amount,
        v_currency_code,
        v_occurred_at,
        'none',
        false,
        v_note,
        'bankSync',
        v_tx.plaid_transaction_id,
        v_tx.pending,
        false,
        null
    )
    on conflict (user_id, external_id)
    where source = 'bankSync'
      and external_id is not null
    do update set
        from_account_id = excluded.from_account_id,
        category_id = case
            when operations.category_overridden then operations.category_id
            else excluded.category_id
        end,
        type = excluded.type,
        amount = excluded.amount,
        currency_code = excluded.currency_code,
        occurred_at = excluded.occurred_at,
        note = excluded.note,
        is_pending = excluded.is_pending,
        archived_at = null,
        updated_at = now();
end;
$$;
