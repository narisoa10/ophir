-- Project B / B1: Plaid account presence.
-- Additive. Every existing row starts present (NULL); nothing is backfilled.
-- plaid_persist_accounts_sync keeps its signature, grants and return value and
-- reconciles presence inside the same transaction that persists the snapshot.

alter table public.accounts
    add column plaid_missing_since timestamptz null;

alter table public.accounts
    add constraint accounts_plaid_missing_since_plaid_only_check
        check (plaid_missing_since is null or plaid_account_id is not null);

comment on column public.accounts.plaid_missing_since is
    'When this previously persisted plaid_account_id was first absent from an accepted /accounts/get snapshot of its Item. NULL while the latest accepted snapshot returns it. An observation only: it does not mean the account was closed, deleted or its access revoked. The row, balances, preference and history are kept.';

comment on constraint accounts_plaid_missing_since_plaid_only_check on public.accounts is
    'Only Plaid accounts can be missing from a Plaid snapshot.';

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
    v_persistent_account_id text;
    v_synced_count integer := 0;
    v_disconnected_at timestamptz;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_accounts is null or jsonb_typeof(p_accounts) <> 'array' then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    select plaid_items.disconnected_at
    into v_disconnected_at
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id
    for no key update;

    if not found then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    if v_disconnected_at is not null then
        raise exception 'plaid_item_disconnected' using errcode = '22023';
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

    -- Rows of this Item that are absent from the snapshot are updated below, so
    -- they are locked here too, in the same account id order.
    perform 1
    from public.accounts
    where accounts.user_id = p_user_id
      and (
          accounts.plaid_item_id = p_connection_id
          or accounts.plaid_account_id in (
              select nullif(trim(payload.value ->> 'plaid_account_id'), '')
              from jsonb_array_elements(p_accounts) as payload(value)
          )
      )
    order by accounts.id
    for no key update;

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
        v_persistent_account_id :=
            case
                when jsonb_typeof(v_account -> 'persistent_account_id') = 'string'
                    then nullif(trim(v_account ->> 'persistent_account_id'), '')
                else null
            end;

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
            balance_fetched_at,
            persistent_account_id
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
            p_balance_fetched_at,
            v_persistent_account_id
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
            persistent_account_id = coalesce(
                accounts.persistent_account_id,
                excluded.persistent_account_id
            ),
            plaid_missing_since = null,
            updated_at = now();

        v_synced_count := v_synced_count + 1;
    end loop;

    -- An empty snapshot marks every persisted account of the Item missing.
    -- Rows already missing keep their first timestamp and are not rewritten.
    update public.accounts
    set plaid_missing_since = coalesce(p_balance_fetched_at, now())
    where accounts.user_id = p_user_id
      and accounts.plaid_item_id = p_connection_id
      and accounts.plaid_account_id is not null
      and accounts.plaid_missing_since is null
      and not exists (
          select 1
          from jsonb_array_elements(p_accounts) as payload(value)
          where nullif(trim(payload.value ->> 'plaid_account_id'), '') = accounts.plaid_account_id
      );

    return v_synced_count;
end;
$$;

comment on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb
) is
    'Persists one complete /accounts/get snapshot (institution and accounts) of a connected Item and reconciles account presence: returned accounts get plaid_missing_since = NULL, persisted accounts of the Item absent from the snapshot get it set once. Nothing is deleted. Refuses a disconnected Item (plaid_item_disconnected) under the Item row lock, so a snapshot fetched before a Disconnect is never written after it. Service-role only.';
