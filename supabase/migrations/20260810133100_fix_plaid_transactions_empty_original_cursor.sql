create or replace function public.plaid_apply_transactions_sync_batch(
    p_user_id uuid,
    p_connection_id uuid,
    p_original_cursor text,
    p_final_cursor text,
    p_added jsonb,
    p_modified jsonb,
    p_removed jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_current_cursor text;
    v_transaction jsonb;
    v_removed jsonb;
    v_account_id uuid;
    v_plaid_account_id text;
    v_transaction_id text;
    v_pending boolean;
    v_pending_transaction_id text;
    v_date date;
    v_authorized_date date;
    v_datetime timestamptz;
    v_authorized_datetime timestamptz;
    v_amount numeric;
    v_iso_currency_code text;
    v_unofficial_currency_code text;
    v_name text;
    v_merchant_name text;
    v_payment_channel text;
    v_merchant_entity_id text;
    v_pfc_primary text;
    v_pfc_detailed text;
    v_pfc_confidence_level text;
    v_pfc_version text;
    v_added_count integer := 0;
    v_modified_count integer := 0;
    v_removed_count integer := 0;
begin
    if p_user_id is null
       or p_connection_id is null
       or p_final_cursor is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_added is null or jsonb_typeof(p_added) <> 'array'
       or p_modified is null or jsonb_typeof(p_modified) <> 'array'
       or p_removed is null or jsonb_typeof(p_removed) <> 'array'
    then
        raise exception 'invalid_batch' using errcode = '22023';
    end if;

    select plaid_items.transactions_cursor
    into v_current_cursor
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id
    for update;

    if not found then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    if v_current_cursor is distinct from p_original_cursor then
        raise exception 'cursor_conflict' using errcode = '40001';
    end if;

    for v_transaction in
        select value from jsonb_array_elements(p_added)
        union all
        select value from jsonb_array_elements(p_modified)
    loop
        if jsonb_typeof(v_transaction) <> 'object' then
            raise exception 'invalid_transaction_payload' using errcode = '22023';
        end if;

        v_plaid_account_id := nullif(trim(v_transaction ->> 'plaid_account_id'), '');
        v_transaction_id := nullif(trim(v_transaction ->> 'transaction_id'), '');
        v_name := nullif(trim(v_transaction ->> 'name'), '');

        if v_plaid_account_id is null
           or v_transaction_id is null
           or v_name is null
           or v_transaction ->> 'date' is null
           or trim(v_transaction ->> 'date') = ''
           or v_transaction ->> 'amount' is null
           or trim(v_transaction ->> 'amount') = ''
           or jsonb_typeof(v_transaction -> 'pending') is distinct from 'boolean'
        then
            raise exception 'invalid_transaction_payload' using errcode = '22023';
        end if;

        perform (v_transaction ->> 'date')::date;
        perform (v_transaction ->> 'amount')::numeric;

        select accounts.id
        into v_account_id
        from public.accounts
        where accounts.plaid_item_id = p_connection_id
          and accounts.plaid_account_id = v_plaid_account_id
          and accounts.user_id = p_user_id;

        if v_account_id is null then
            raise exception 'plaid_transaction_account_not_found' using errcode = '22023';
        end if;
    end loop;

    for v_transaction in
        select value from jsonb_array_elements(p_added)
    loop
        v_plaid_account_id := nullif(trim(v_transaction ->> 'plaid_account_id'), '');
        v_transaction_id := nullif(trim(v_transaction ->> 'transaction_id'), '');
        v_pending := (v_transaction ->> 'pending')::boolean;
        v_pending_transaction_id := nullif(trim(v_transaction ->> 'pending_transaction_id'), '');
        v_date := (v_transaction ->> 'date')::date;
        v_authorized_date := nullif(trim(v_transaction ->> 'authorized_date'), '')::date;
        v_datetime := nullif(trim(v_transaction ->> 'datetime'), '')::timestamptz;
        v_authorized_datetime := nullif(
            trim(v_transaction ->> 'authorized_datetime'),
            ''
        )::timestamptz;
        v_amount := (v_transaction ->> 'amount')::numeric;
        v_iso_currency_code := nullif(trim(v_transaction ->> 'iso_currency_code'), '');
        v_unofficial_currency_code := nullif(
            trim(v_transaction ->> 'unofficial_currency_code'),
            ''
        );
        v_name := nullif(trim(v_transaction ->> 'name'), '');
        v_merchant_name := nullif(trim(v_transaction ->> 'merchant_name'), '');
        v_payment_channel := nullif(trim(v_transaction ->> 'payment_channel'), '');
        v_merchant_entity_id := nullif(trim(v_transaction ->> 'merchant_entity_id'), '');
        v_pfc_primary := nullif(
            trim(v_transaction ->> 'personal_finance_category_primary'),
            ''
        );
        v_pfc_detailed := nullif(
            trim(v_transaction ->> 'personal_finance_category_detailed'),
            ''
        );
        v_pfc_confidence_level := nullif(
            trim(v_transaction ->> 'personal_finance_category_confidence_level'),
            ''
        );
        v_pfc_version := nullif(
            trim(v_transaction ->> 'personal_finance_category_version'),
            ''
        );

        select accounts.id
        into v_account_id
        from public.accounts
        where accounts.plaid_item_id = p_connection_id
          and accounts.plaid_account_id = v_plaid_account_id
          and accounts.user_id = p_user_id;

        insert into public.plaid_transactions (
            user_id,
            plaid_item_id,
            account_id,
            plaid_account_id,
            transaction_id,
            pending,
            pending_transaction_id,
            date,
            authorized_date,
            datetime,
            authorized_datetime,
            amount,
            iso_currency_code,
            unofficial_currency_code,
            name,
            merchant_name,
            payment_channel,
            merchant_entity_id,
            personal_finance_category_primary,
            personal_finance_category_detailed,
            personal_finance_category_confidence_level,
            personal_finance_category_version,
            removed_at
        )
        values (
            p_user_id,
            p_connection_id,
            v_account_id,
            v_plaid_account_id,
            v_transaction_id,
            v_pending,
            v_pending_transaction_id,
            v_date,
            v_authorized_date,
            v_datetime,
            v_authorized_datetime,
            v_amount,
            v_iso_currency_code,
            v_unofficial_currency_code,
            v_name,
            v_merchant_name,
            v_payment_channel,
            v_merchant_entity_id,
            v_pfc_primary,
            v_pfc_detailed,
            v_pfc_confidence_level,
            v_pfc_version,
            null
        )
        on conflict (plaid_item_id, transaction_id)
        do update
        set
            user_id = excluded.user_id,
            account_id = excluded.account_id,
            plaid_account_id = excluded.plaid_account_id,
            pending = excluded.pending,
            pending_transaction_id = excluded.pending_transaction_id,
            date = excluded.date,
            authorized_date = excluded.authorized_date,
            datetime = excluded.datetime,
            authorized_datetime = excluded.authorized_datetime,
            amount = excluded.amount,
            iso_currency_code = excluded.iso_currency_code,
            unofficial_currency_code = excluded.unofficial_currency_code,
            name = excluded.name,
            merchant_name = excluded.merchant_name,
            payment_channel = excluded.payment_channel,
            merchant_entity_id = excluded.merchant_entity_id,
            personal_finance_category_primary = excluded.personal_finance_category_primary,
            personal_finance_category_detailed = excluded.personal_finance_category_detailed,
            personal_finance_category_confidence_level = excluded.personal_finance_category_confidence_level,
            personal_finance_category_version = excluded.personal_finance_category_version,
            removed_at = null,
            updated_at = now();

        v_added_count := v_added_count + 1;
    end loop;

    for v_transaction in
        select value from jsonb_array_elements(p_modified)
    loop
        v_plaid_account_id := nullif(trim(v_transaction ->> 'plaid_account_id'), '');
        v_transaction_id := nullif(trim(v_transaction ->> 'transaction_id'), '');
        v_pending := (v_transaction ->> 'pending')::boolean;
        v_pending_transaction_id := nullif(trim(v_transaction ->> 'pending_transaction_id'), '');
        v_date := (v_transaction ->> 'date')::date;
        v_authorized_date := nullif(trim(v_transaction ->> 'authorized_date'), '')::date;
        v_datetime := nullif(trim(v_transaction ->> 'datetime'), '')::timestamptz;
        v_authorized_datetime := nullif(
            trim(v_transaction ->> 'authorized_datetime'),
            ''
        )::timestamptz;
        v_amount := (v_transaction ->> 'amount')::numeric;
        v_iso_currency_code := nullif(trim(v_transaction ->> 'iso_currency_code'), '');
        v_unofficial_currency_code := nullif(
            trim(v_transaction ->> 'unofficial_currency_code'),
            ''
        );
        v_name := nullif(trim(v_transaction ->> 'name'), '');
        v_merchant_name := nullif(trim(v_transaction ->> 'merchant_name'), '');
        v_payment_channel := nullif(trim(v_transaction ->> 'payment_channel'), '');
        v_merchant_entity_id := nullif(trim(v_transaction ->> 'merchant_entity_id'), '');
        v_pfc_primary := nullif(
            trim(v_transaction ->> 'personal_finance_category_primary'),
            ''
        );
        v_pfc_detailed := nullif(
            trim(v_transaction ->> 'personal_finance_category_detailed'),
            ''
        );
        v_pfc_confidence_level := nullif(
            trim(v_transaction ->> 'personal_finance_category_confidence_level'),
            ''
        );
        v_pfc_version := nullif(
            trim(v_transaction ->> 'personal_finance_category_version'),
            ''
        );

        select accounts.id
        into v_account_id
        from public.accounts
        where accounts.plaid_item_id = p_connection_id
          and accounts.plaid_account_id = v_plaid_account_id
          and accounts.user_id = p_user_id;

        insert into public.plaid_transactions (
            user_id,
            plaid_item_id,
            account_id,
            plaid_account_id,
            transaction_id,
            pending,
            pending_transaction_id,
            date,
            authorized_date,
            datetime,
            authorized_datetime,
            amount,
            iso_currency_code,
            unofficial_currency_code,
            name,
            merchant_name,
            payment_channel,
            merchant_entity_id,
            personal_finance_category_primary,
            personal_finance_category_detailed,
            personal_finance_category_confidence_level,
            personal_finance_category_version,
            removed_at
        )
        values (
            p_user_id,
            p_connection_id,
            v_account_id,
            v_plaid_account_id,
            v_transaction_id,
            v_pending,
            v_pending_transaction_id,
            v_date,
            v_authorized_date,
            v_datetime,
            v_authorized_datetime,
            v_amount,
            v_iso_currency_code,
            v_unofficial_currency_code,
            v_name,
            v_merchant_name,
            v_payment_channel,
            v_merchant_entity_id,
            v_pfc_primary,
            v_pfc_detailed,
            v_pfc_confidence_level,
            v_pfc_version,
            null
        )
        on conflict (plaid_item_id, transaction_id)
        do update
        set
            user_id = excluded.user_id,
            account_id = excluded.account_id,
            plaid_account_id = excluded.plaid_account_id,
            pending = excluded.pending,
            pending_transaction_id = excluded.pending_transaction_id,
            date = excluded.date,
            authorized_date = excluded.authorized_date,
            datetime = excluded.datetime,
            authorized_datetime = excluded.authorized_datetime,
            amount = excluded.amount,
            iso_currency_code = excluded.iso_currency_code,
            unofficial_currency_code = excluded.unofficial_currency_code,
            name = excluded.name,
            merchant_name = excluded.merchant_name,
            payment_channel = excluded.payment_channel,
            merchant_entity_id = excluded.merchant_entity_id,
            personal_finance_category_primary = excluded.personal_finance_category_primary,
            personal_finance_category_detailed = excluded.personal_finance_category_detailed,
            personal_finance_category_confidence_level = excluded.personal_finance_category_confidence_level,
            personal_finance_category_version = excluded.personal_finance_category_version,
            removed_at = null,
            updated_at = now();

        v_modified_count := v_modified_count + 1;
    end loop;

    for v_removed in
        select value from jsonb_array_elements(p_removed)
    loop
        if jsonb_typeof(v_removed) <> 'object' then
            raise exception 'invalid_removed_transaction_payload' using errcode = '22023';
        end if;

        v_transaction_id := nullif(trim(v_removed ->> 'transaction_id'), '');

        if v_transaction_id is null then
            raise exception 'invalid_removed_transaction_payload' using errcode = '22023';
        end if;

        update public.plaid_transactions
        set
            removed_at = coalesce(removed_at, now()),
            updated_at = now()
        where plaid_transactions.plaid_item_id = p_connection_id
          and plaid_transactions.user_id = p_user_id
          and plaid_transactions.transaction_id = v_transaction_id;

        v_removed_count := v_removed_count + 1;
    end loop;

    update public.plaid_items
    set
        transactions_cursor = p_final_cursor,
        transactions_last_synced_at = now()
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id;

    return jsonb_build_object(
        'added_count', v_added_count,
        'modified_count', v_modified_count,
        'removed_count', v_removed_count,
        'cursor_advanced', true
    );
end;
$$;

comment on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    jsonb,
    jsonb,
    jsonb
) is
    'Applies a complete Plaid /transactions/sync batch atomically after pagination is complete. Service-role only.';

revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    jsonb,
    jsonb,
    jsonb
) from public;
revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    jsonb,
    jsonb,
    jsonb
) from anon;
revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    jsonb,
    jsonb,
    jsonb
) from authenticated;
grant execute on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    jsonb,
    jsonb,
    jsonb
) to service_role;
