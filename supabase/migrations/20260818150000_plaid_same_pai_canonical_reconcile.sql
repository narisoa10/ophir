-- Identity foundation P3: automatic same-PAI canonical reconciliation.
-- Additive only. Reuses P1 merge + P2 ensure. No backfill / Stage F/G / H2 changes.
-- Applied Stage A–G / H1 / P1 / F-hardening / P2 migration files are not edited.
-- Lock order: group advisory(user+effective PAI) BEFORE account upsert / FOR UPDATE.

-- ---------------------------------------------------------------------------
-- 0) Shared same-PAI group advisory lock (identical key for persist + reconcile)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_lock_account_identity_pai_group(
    p_user_id uuid,
    p_persistent_account_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_user_id is null or p_persistent_account_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Namespace 872514003 = Identity P3 PAI reconcile.
    -- Key: user_id || SOH || PAI (exact same derivation for persist and reconcile).
    perform pg_catalog.pg_advisory_xact_lock(
        872514003,
        pg_catalog.hashtext(p_user_id::text || chr(1) || p_persistent_account_id)
    );
end;
$$;

comment on function public.plaid_lock_account_identity_pai_group(uuid, text) is
    'Identity P3: transaction-scoped advisory lock for same-user same-PAI identity group. Service-role only.';

revoke all on function public.plaid_lock_account_identity_pai_group(uuid, text) from public;
revoke all on function public.plaid_lock_account_identity_pai_group(uuid, text) from anon;
revoke all on function public.plaid_lock_account_identity_pai_group(uuid, text) from authenticated;
grant execute on function public.plaid_lock_account_identity_pai_group(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 1) Same-PAI reconcile helper
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reconcile_account_identity_by_pai(
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
    v_pai text;
    v_sibling_id uuid;
    v_group_ids uuid[];
    v_authority_id uuid;
    v_survivor_canonical_id uuid;
    v_other_canonical_id uuid;
    v_link_result jsonb;
    v_merged_any boolean := false;
    v_distinct_canonicals integer;
begin
    if p_user_id is null or p_account_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Unlocked identity/PAI read for lock-key only (no FOR UPDATE before advisory).
    select
        accounts.plaid_account_id,
        accounts.plaid_item_id,
        accounts.persistent_account_id
    into
        v_plaid_account_id,
        v_plaid_item_id,
        v_pai
    from public.accounts as accounts
    where accounts.id = p_account_id
      and accounts.user_id = p_user_id;

    if not found then
        raise exception 'account_not_found' using errcode = '22023';
    end if;

    if v_plaid_account_id is null or v_plaid_item_id is null then
        raise exception 'account_not_plaid' using errcode = '22023';
    end if;

    if v_pai is null then
        return jsonb_build_object(
            'status', 'not_applicable',
            'account_id', p_account_id
        );
    end if;

    -- Group advisory BEFORE any account FOR UPDATE / sibling ensure.
    perform public.plaid_lock_account_identity_pai_group(p_user_id, v_pai);

    -- After advisory: lock current account row, re-validate stored PAI.
    select
        accounts.plaid_account_id,
        accounts.plaid_item_id,
        accounts.persistent_account_id
    into
        v_plaid_account_id,
        v_plaid_item_id,
        v_pai
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

    if v_pai is null then
        return jsonb_build_object(
            'status', 'not_applicable',
            'account_id', p_account_id
        );
    end if;

    select coalesce(array_agg(siblings.id order by siblings.id), array[]::uuid[])
    into v_group_ids
    from public.accounts as siblings
    where siblings.user_id = p_user_id
      and siblings.id <> p_account_id
      and siblings.plaid_account_id is not null
      and siblings.plaid_item_id is not null
      and siblings.persistent_account_id is not null
      and siblings.persistent_account_id = v_pai;

    if coalesce(cardinality(v_group_ids), 0) = 0 then
        return jsonb_build_object(
            'status', 'already_reconciled',
            'account_id', p_account_id,
            'persistent_account_id', v_pai
        );
    end if;

    -- Group = current + siblings (deterministic id order).
    v_group_ids := array_append(v_group_ids, p_account_id);
    select array_agg(gid order by gid)
    into v_group_ids
    from unnest(v_group_ids) as gid;

    -- Ensure every group member has membership (reuse P2; after advisory).
    foreach v_sibling_id in array v_group_ids
    loop
        perform public.plaid_ensure_account_identity(p_user_id, v_sibling_id);
    end loop;

    -- Group-wide authority: oldest active authoritative linked_at, tie → least account_id.
    select members.account_id
    into v_authority_id
    from public.plaid_canonical_financial_account_members as members
    where members.user_id = p_user_id
      and members.unlinked_at is null
      and members.role = 'authoritative'
      and members.account_id = any (v_group_ids)
    order by members.linked_at asc, members.account_id asc
    limit 1;

    if v_authority_id is null then
        raise exception 'canonical_authority_invalid' using errcode = '22023';
    end if;

    select members.canonical_account_id
    into v_survivor_canonical_id
    from public.plaid_canonical_financial_account_members as members
    where members.user_id = p_user_id
      and members.account_id = v_authority_id
      and members.unlinked_at is null
      and members.role = 'authoritative';

    if v_survivor_canonical_id is null then
        raise exception 'canonical_authority_invalid' using errcode = '22023';
    end if;

    -- Merge every other group member into authority canonical via P1.
    foreach v_sibling_id in array v_group_ids
    loop
        if v_sibling_id = v_authority_id then
            continue;
        end if;

        select members.canonical_account_id
        into v_other_canonical_id
        from public.plaid_canonical_financial_account_members as members
        where members.user_id = p_user_id
          and members.account_id = v_sibling_id
          and members.unlinked_at is null;

        if v_other_canonical_id is null then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        if v_other_canonical_id = v_survivor_canonical_id then
            continue;
        end if;

        v_link_result := public.plaid_link_canonical_financial_accounts(
            p_user_id,
            v_authority_id,
            v_sibling_id,
            v_authority_id
        );

        if coalesce(v_link_result->>'status', '') not in (
            'merged',
            'linked',
            'already_linked',
            'created'
        ) then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        if coalesce(v_link_result->>'status', '') in ('merged', 'linked', 'created') then
            v_merged_any := true;
        end if;

        -- Survivor may only stay authority's canonical (P1 contract).
        select members.canonical_account_id
        into v_survivor_canonical_id
        from public.plaid_canonical_financial_account_members as members
        where members.user_id = p_user_id
          and members.account_id = v_authority_id
          and members.unlinked_at is null
          and members.role = 'authoritative';
    end loop;

    select count(distinct members.canonical_account_id)::integer
    into v_distinct_canonicals
    from public.plaid_canonical_financial_account_members as members
    where members.user_id = p_user_id
      and members.unlinked_at is null
      and members.account_id = any (v_group_ids);

    if v_distinct_canonicals is distinct from 1 then
        raise exception 'canonical_authority_invalid' using errcode = '22023';
    end if;

    if v_merged_any then
        return jsonb_build_object(
            'status', 'reconciled',
            'account_id', p_account_id,
            'authoritative_account_id', v_authority_id,
            'canonical_account_id', v_survivor_canonical_id,
            'persistent_account_id', v_pai
        );
    end if;

    return jsonb_build_object(
        'status', 'already_reconciled',
        'account_id', p_account_id,
        'authoritative_account_id', v_authority_id,
        'canonical_account_id', v_survivor_canonical_id,
        'persistent_account_id', v_pai
    );
end;
$$;

comment on function public.plaid_reconcile_account_identity_by_pai(uuid, uuid) is
    'Identity P3: reconcile same non-null PAI Plaid representations into one canonical via P1 merge. Group advisory before account locks. Service-role only. No backfill.';

revoke all on function public.plaid_reconcile_account_identity_by_pai(uuid, uuid) from public;
revoke all on function public.plaid_reconcile_account_identity_by_pai(uuid, uuid) from anon;
revoke all on function public.plaid_reconcile_account_identity_by_pai(uuid, uuid) from authenticated;
grant execute on function public.plaid_reconcile_account_identity_by_pai(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 2) Wire P3 after P2 ensure in persist (signature unchanged)
--    Lock order: effective PAI advisory → upsert → ensure → reconcile
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
    v_existing_pai text;
    v_effective_pai text;
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

        -- Effective PAI = same first-wins coalesce as upsert (unlocked pre-read).
        select accounts.persistent_account_id
        into v_existing_pai
        from public.accounts as accounts
        where accounts.user_id = p_user_id
          and accounts.plaid_account_id = v_plaid_account_id;

        v_effective_pai := coalesce(v_existing_pai, v_persistent_account_id);

        -- Group advisory BEFORE account upsert row lock when PAI will be non-null.
        if v_effective_pai is not null then
            perform public.plaid_lock_account_identity_pai_group(
                p_user_id,
                v_effective_pai
            );
        end if;

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

        -- P2 then P3: singleton identity, then same-PAI converge via P1.
        perform public.plaid_ensure_account_identity(p_user_id, v_account_id);
        perform public.plaid_reconcile_account_identity_by_pai(p_user_id, v_account_id);

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
    'Persist Plaid accounts sync: PAI-group advisory (if effective PAI) → upsert → P2 ensure → P3 reconcile. Signature unchanged. Service-role only. No backfill.';

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
