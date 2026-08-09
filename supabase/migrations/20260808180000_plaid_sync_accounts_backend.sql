-- Checkpoint 6: Plaid accounts backend sync RPCs (canonical public.accounts only).

create or replace function public.plaid_get_access_token_for_item(
    p_user_id uuid,
    p_connection_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_access_token text;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select vault.decrypted_secrets.decrypted_secret
    into v_access_token
    from public.plaid_items
    inner join vault.decrypted_secrets
        on vault.decrypted_secrets.id = plaid_items.access_token_secret_id
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id;

    if v_access_token is null or trim(v_access_token) = '' then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    return v_access_token;
end;
$$;

revoke all on function public.plaid_get_access_token_for_item(uuid, uuid) from public;
revoke all on function public.plaid_get_access_token_for_item(uuid, uuid) from anon;
revoke all on function public.plaid_get_access_token_for_item(uuid, uuid) from authenticated;
grant execute on function public.plaid_get_access_token_for_item(uuid, uuid) to service_role;

create or replace function public.plaid_persist_accounts_sync(
    p_user_id uuid,
    p_connection_id uuid,
    p_plaid_institution_id text,
    p_institution_name text,
    p_logo_base64 text,
    p_primary_color text,
    p_url text,
    p_balance_fetched_at timestamptz,
    p_accounts jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_institution_id uuid;
    v_account jsonb;
    v_plaid_account_id text;
    v_name text;
    v_official_name text;
    v_mask text;
    v_plaid_type text;
    v_plaid_subtype text;
    v_currency_code text;
    v_unofficial_currency_code text;
    v_current_balance numeric(14, 2);
    v_available_balance numeric(14, 2);
    v_synced_count integer := 0;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_accounts is null or jsonb_typeof(p_accounts) <> 'array' then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    if not exists (
        select 1
        from public.plaid_items
        where id = p_connection_id
          and user_id = p_user_id
    ) then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    for v_account in
        select value
        from jsonb_array_elements(p_accounts)
    loop
        v_plaid_account_id := nullif(trim(v_account ->> 'plaid_account_id'), '');
        v_name := nullif(trim(v_account ->> 'name'), '');
        v_plaid_type := nullif(trim(v_account ->> 'plaid_type'), '');

        if v_plaid_account_id is null or v_name is null or v_plaid_type is null then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;

        v_currency_code := nullif(trim(v_account ->> 'currency_code'), '');
        v_unofficial_currency_code := nullif(
            trim(v_account ->> 'unofficial_currency_code'),
            ''
        );

        if v_currency_code is null and v_unofficial_currency_code is null then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;

        if v_currency_code is not null and char_length(v_currency_code) <> 3 then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;
    end loop;

    insert into public.institutions (
        user_id,
        plaid_item_id,
        plaid_institution_id,
        name,
        logo_base64,
        primary_color,
        url
    )
    values (
        p_user_id,
        p_connection_id,
        nullif(trim(p_plaid_institution_id), ''),
        nullif(trim(p_institution_name), ''),
        nullif(trim(p_logo_base64), ''),
        nullif(trim(p_primary_color), ''),
        nullif(trim(p_url), '')
    )
    on conflict (plaid_item_id) do update
    set
        plaid_institution_id = excluded.plaid_institution_id,
        name = excluded.name,
        logo_base64 = excluded.logo_base64,
        primary_color = excluded.primary_color,
        url = excluded.url,
        updated_at = now()
    returning id into v_institution_id;

    for v_account in
        select value
        from jsonb_array_elements(p_accounts)
    loop
        v_plaid_account_id := nullif(trim(v_account ->> 'plaid_account_id'), '');
        v_name := nullif(trim(v_account ->> 'name'), '');
        v_plaid_type := nullif(trim(v_account ->> 'plaid_type'), '');
        v_official_name := nullif(trim(v_account ->> 'official_name'), '');
        v_mask := nullif(trim(v_account ->> 'mask'), '');
        v_plaid_subtype := nullif(trim(v_account ->> 'plaid_subtype'), '');
        v_currency_code := nullif(trim(v_account ->> 'currency_code'), '');
        v_unofficial_currency_code := nullif(
            trim(v_account ->> 'unofficial_currency_code'),
            ''
        );
        v_current_balance := nullif(v_account ->> 'current_balance', '')::numeric(14, 2);
        v_available_balance := nullif(v_account ->> 'available_balance', '')::numeric(14, 2);

        insert into public.accounts (
            user_id,
            name,
            currency_code,
            unofficial_currency_code,
            plaid_item_id,
            institution_id,
            plaid_account_id,
            official_name,
            mask,
            plaid_type,
            plaid_subtype,
            current_balance,
            available_balance,
            balance_fetched_at
        )
        values (
            p_user_id,
            v_name,
            v_currency_code,
            v_unofficial_currency_code,
            p_connection_id,
            v_institution_id,
            v_plaid_account_id,
            v_official_name,
            v_mask,
            v_plaid_type,
            v_plaid_subtype,
            v_current_balance,
            v_available_balance,
            p_balance_fetched_at
        )
        on conflict (user_id, plaid_account_id)
        where plaid_account_id is not null
        do update
        set
            name = excluded.name,
            official_name = excluded.official_name,
            mask = excluded.mask,
            plaid_type = excluded.plaid_type,
            plaid_subtype = excluded.plaid_subtype,
            currency_code = excluded.currency_code,
            unofficial_currency_code = excluded.unofficial_currency_code,
            current_balance = excluded.current_balance,
            available_balance = excluded.available_balance,
            balance_fetched_at = excluded.balance_fetched_at,
            plaid_item_id = excluded.plaid_item_id,
            institution_id = excluded.institution_id,
            updated_at = now();

        v_synced_count := v_synced_count + 1;
    end loop;

    return v_synced_count;
end;
$$;

revoke all on function public.plaid_persist_accounts_sync(
    uuid,
    uuid,
    text,
    text,
    text,
    text,
    text,
    timestamptz,
    jsonb
) from public;
revoke all on function public.plaid_persist_accounts_sync(
    uuid,
    uuid,
    text,
    text,
    text,
    text,
    text,
    timestamptz,
    jsonb
) from anon;
revoke all on function public.plaid_persist_accounts_sync(
    uuid,
    uuid,
    text,
    text,
    text,
    text,
    text,
    timestamptz,
    jsonb
) from authenticated;
grant execute on function public.plaid_persist_accounts_sync(
    uuid,
    uuid,
    text,
    text,
    text,
    text,
    text,
    timestamptz,
    jsonb
) to service_role;
