-- Identity foundation P2: singleton Plaid account identity bootstrap.
-- Additive only. No same-PAI merge, no LIVE backfill, no Stage F/G/H2 changes.
-- Applied Stage A–G / H1 / P1 / Stage F hardening migration files are not edited.

-- ---------------------------------------------------------------------------
-- 1) Allow sync_bootstrap link_origin evidence
-- ---------------------------------------------------------------------------

alter table public.plaid_canonical_financial_account_members
    drop constraint if exists plaid_canonical_financial_account_members_link_origin_check;

alter table public.plaid_canonical_financial_account_members
    add constraint plaid_canonical_financial_account_members_link_origin_check
    check (
        link_origin in (
            'user_confirmed',
            'persistent_account_identity',
            'sync_bootstrap'
        )
    );

comment on column public.plaid_canonical_financial_account_members.link_origin is
    'Evidence/provenance for the link. user_confirmed = explicit user confirmation without PAI evidence. persistent_account_identity = PAI contributed same-account evidence at link/merge time. sync_bootstrap = automatic singleton canonical created during Plaid account persistence (not same-account proof, not user confirmation, not PAI match).';

-- ---------------------------------------------------------------------------
-- 2) Ensure helper
-- ---------------------------------------------------------------------------

create or replace function public.plaid_ensure_account_identity(
    p_user_id uuid,
    p_account_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_plaid_account_id text;
    v_plaid_item_id uuid;
    v_existing_canonical_id uuid;
    v_existing_role text;
    v_canonical_id uuid;
begin
    if p_user_id is null or p_account_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Serialize concurrent ensure for this account.
    select
        accounts.plaid_account_id,
        accounts.plaid_item_id
    into
        v_plaid_account_id,
        v_plaid_item_id
    from public.accounts as accounts
    where accounts.id = p_account_id
      and accounts.user_id = p_user_id
    for update;

    if not found then
        raise exception 'account_not_found' using errcode = '22023';
    end if;

    if v_plaid_account_id is null or v_plaid_item_id is null then
        raise exception 'account_not_plaid' using errcode = '22023';
    end if;

    select
        members.canonical_account_id,
        members.role
    into
        v_existing_canonical_id,
        v_existing_role
    from public.plaid_canonical_financial_account_members as members
    where members.user_id = p_user_id
      and members.account_id = p_account_id
      and members.unlinked_at is null
    for update;

    if found then
        -- Existing active membership: no-op (do not promote/rehome/repair).
        return jsonb_build_object(
            'status', 'already_membered',
            'canonical_account_id', v_existing_canonical_id,
            'account_id', p_account_id,
            'role', v_existing_role
        );
    end if;

    insert into public.plaid_canonical_financial_accounts (user_id)
    values (p_user_id)
    returning id into v_canonical_id;

    insert into public.plaid_canonical_financial_account_members (
        user_id,
        canonical_account_id,
        account_id,
        role,
        link_origin
    )
    values (
        p_user_id,
        v_canonical_id,
        p_account_id,
        'authoritative',
        'sync_bootstrap'
    );

    return jsonb_build_object(
        'status', 'created',
        'canonical_account_id', v_canonical_id,
        'account_id', p_account_id,
        'role', 'authoritative'
    );
end;
$$;

comment on function public.plaid_ensure_account_identity(uuid, uuid) is
    'Identity P2: ensure Plaid-backed account has singleton active authoritative membership (sync_bootstrap). Idempotent. No PAI sibling merge. Service-role only.';

revoke all on function public.plaid_ensure_account_identity(uuid, uuid) from public;
revoke all on function public.plaid_ensure_account_identity(uuid, uuid) from anon;
revoke all on function public.plaid_ensure_account_identity(uuid, uuid) from authenticated;
grant execute on function public.plaid_ensure_account_identity(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3) Wire ensure into persist RPC (signature unchanged)
-- ---------------------------------------------------------------------------

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
    v_account_id uuid;
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
            updated_at = now()
        returning id into v_account_id;

        -- P2: successful persistence implies singleton identity for this account.
        perform public.plaid_ensure_account_identity(p_user_id, v_account_id);

        v_synced_count := v_synced_count + 1;
    end loop;

    return v_synced_count;
end;
$$;

comment on function public.plaid_persist_accounts_sync(
    uuid,
    uuid,
    text,
    text,
    text,
    text,
    text,
    timestamptz,
    jsonb
) is
    'Persist Plaid accounts sync payload and ensure each Plaid-backed account has singleton canonical identity (P2). Signature unchanged. Service-role only. No PAI merge/backfill.';

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
