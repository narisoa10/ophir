-- Project B / B2 (M1): snapshot freshness for plaid_persist_accounts_sync.
-- Additive. plaid_items.accounts_observed_at is the Item-level watermark of the
-- last accepted /accounts/get snapshot; nothing is backfilled (NULL accepts the
-- first snapshot). The new 10-argument overload is the only writer of the
-- watermark. The 9-argument overload stays for the rollout only: it applies a
-- snapshot while the Item has no watermark, never writes it, and refuses once a
-- watermark exists. It is dropped by a later migration (M2) after the deployed
-- Edge Functions have drained.

alter table public.plaid_items
    add column accounts_observed_at timestamptz null;

comment on column public.plaid_items.accounts_observed_at is
    'Authoritative observation watermark: when the request of the last accepted /accounts/get snapshot of this Item started. A snapshot observed at or before it is refused and changes nothing. Not a balance time, not a database update time and not a lifecycle timestamp. Written only by plaid_persist_accounts_sync(..., p_accounts_observed_at).';

create function public.plaid_persist_accounts_sync(
    p_user_id uuid,
    p_connection_id uuid,
    p_plaid_institution_id text,
    p_institution_name text,
    p_logo_base64 text,
    p_primary_color text,
    p_url text,
    p_balance_fetched_at timestamptz,
    p_accounts jsonb,
    p_accounts_observed_at timestamptz
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
    v_accounts_observed_at timestamptz;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_accounts is null or jsonb_typeof(p_accounts) <> 'array' then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    -- Exactly now() + 1 minute is accepted; the margin covers Edge/database clock skew.
    if p_accounts_observed_at is null
       or p_accounts_observed_at > now() + interval '1 minute'
    then
        raise exception 'invalid_accounts_observed_at' using errcode = '22023';
    end if;

    select plaid_items.disconnected_at, plaid_items.accounts_observed_at
    into v_disconnected_at, v_accounts_observed_at
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

    -- Read under the Item lock, so a snapshot that waited for a newer one sees it.
    if v_accounts_observed_at is not null
       and p_accounts_observed_at <= v_accounts_observed_at
    then
        raise exception 'plaid_accounts_snapshot_superseded' using errcode = '22023';
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

    -- Last write: the watermark moves only together with the applied snapshot.
    update public.plaid_items
    set accounts_observed_at = p_accounts_observed_at
    where plaid_items.id = p_connection_id;

    return v_synced_count;
end;
$$;

comment on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb, timestamptz
) is
    'Persists one complete /accounts/get snapshot (institution and accounts) of a connected Item and reconciles account presence: returned accounts get plaid_missing_since = NULL, persisted accounts of the Item absent from the snapshot get it set once. Nothing is deleted. Applies the snapshot only if p_accounts_observed_at (when its /accounts/get request started) is strictly later than plaid_items.accounts_observed_at, read under the Item row lock; otherwise raises plaid_accounts_snapshot_superseded before any write. Advances the watermark as its last write. Refuses a disconnected Item (plaid_item_disconnected). Service-role only.';

revoke all on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb, timestamptz
) from public;
revoke all on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb, timestamptz
) from anon;
revoke all on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb, timestamptz
) from authenticated;
grant execute on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb, timestamptz
) to service_role;

-- Temporary B2 rollout compatibility for Edge Functions deployed before B2.
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
    v_accounts_observed_at timestamptz;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_accounts is null or jsonb_typeof(p_accounts) <> 'array' then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    select plaid_items.disconnected_at, plaid_items.accounts_observed_at
    into v_disconnected_at, v_accounts_observed_at
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

    -- A legacy caller has no observation time, so it can never prove it is newer
    -- than an accepted watermarked snapshot.
    if v_accounts_observed_at is not null then
        raise exception 'plaid_accounts_snapshot_superseded' using errcode = '22023';
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
    'Temporary B2 rollout compatibility for Edge Functions deployed before B2; dropped by M2 only after the drain of those deployments is proven. Applies the snapshot exactly like B1 while the Item has no accounts_observed_at watermark and never writes the watermark; once a watermark exists it raises plaid_accounts_snapshot_superseded before any write. Refuses a disconnected Item (plaid_item_disconnected). Service-role only.';
