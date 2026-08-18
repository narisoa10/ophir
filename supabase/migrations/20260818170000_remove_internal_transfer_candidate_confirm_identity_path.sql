-- Cleanup: remove Internal Transfer candidate/confirm path + identity P1–P5 runtime.
-- Additive only. Does NOT edit previously applied migration files.
-- Restores Stage A–E shared function bodies from historical migrations:
--   20260813130000 (persist), 20260813140000 (link), 20260813160000 (Stage E resolve/sync).
-- Aborts on unexpected LIVE state (IT history, mixed bootstrap topology, residual sync_bootstrap).

-- ============================================================================
-- 0) Preconditions: no IT financial history; no residual non-active sync_bootstrap
-- ============================================================================

do $$
declare
    v_recon_count bigint;
    v_synthetic_count bigint;
    v_unlinked_bootstrap bigint;
begin
    select count(*) into v_recon_count
    from public.plaid_internal_transfer_reconciliations;

    if v_recon_count <> 0 then
        raise exception
            'cleanup_abort_it_reconciliations_present: count=%',
            v_recon_count
            using errcode = 'P0001';
    end if;

    select count(*) into v_synthetic_count
    from public.operations
    where source = 'plaid_internal_transfer';

    if v_synthetic_count <> 0 then
        raise exception
            'cleanup_abort_synthetic_internal_transfers_present: count=%',
            v_synthetic_count
            using errcode = 'P0001';
    end if;

    select count(*) into v_unlinked_bootstrap
    from public.plaid_canonical_financial_account_members
    where link_origin = 'sync_bootstrap'
      and unlinked_at is not null;

    if v_unlinked_bootstrap <> 0 then
        raise exception
            'cleanup_abort_historical_sync_bootstrap_memberships_present: count=%',
            v_unlinked_bootstrap
            using errcode = 'P0001';
    end if;
end;
$$;

-- ============================================================================
-- 1–2) LIVE data: remove proven P2/P4 sync_bootstrap memberships + their
--     singleton canonicals only (tracked by canonical_id collected below)
-- ============================================================================

do $$
declare
    r record;
    v_member_count integer;
    v_other_origin_count integer;
    v_plaid_account_id text;
    v_bootstrap_canonical_ids uuid[] := array[]::uuid[];
    v_canonical_id uuid;
    v_dup_refs bigint;
    v_member_refs bigint;
begin
    for r in
        select
            m.id as membership_id,
            m.user_id,
            m.account_id,
            m.canonical_account_id,
            m.role,
            m.link_origin,
            m.unlinked_at
        from public.plaid_canonical_financial_account_members as m
        where m.link_origin = 'sync_bootstrap'
          and m.unlinked_at is null
        for update
    loop
        if r.role <> 'authoritative' then
            raise exception
                'cleanup_abort_sync_bootstrap_non_authoritative: membership_id=% role=%',
                r.membership_id, r.role
                using errcode = 'P0001';
        end if;

        select accounts.plaid_account_id
        into v_plaid_account_id
        from public.accounts as accounts
        where accounts.id = r.account_id
          and accounts.user_id = r.user_id
        for update;

        if v_plaid_account_id is null then
            raise exception
                'cleanup_abort_sync_bootstrap_not_plaid_backed: membership_id=% account_id=%',
                r.membership_id, r.account_id
                using errcode = 'P0001';
        end if;

        select count(*)::integer
        into v_member_count
        from public.plaid_canonical_financial_account_members as m2
        where m2.canonical_account_id = r.canonical_account_id
          and m2.unlinked_at is null;

        if v_member_count <> 1 then
            raise exception
                'cleanup_abort_sync_bootstrap_not_singleton: canonical_id=% active_members=%',
                r.canonical_account_id, v_member_count
                using errcode = 'P0001';
        end if;

        select count(*)::integer
        into v_other_origin_count
        from public.plaid_canonical_financial_account_members as m3
        where m3.canonical_account_id = r.canonical_account_id
          and m3.link_origin <> 'sync_bootstrap';

        if v_other_origin_count <> 0 then
            raise exception
                'cleanup_abort_sync_bootstrap_canonical_has_non_bootstrap_history: canonical_id=%',
                r.canonical_account_id
                using errcode = 'P0001';
        end if;

        if not (r.canonical_account_id = any (v_bootstrap_canonical_ids)) then
            v_bootstrap_canonical_ids :=
                array_append(v_bootstrap_canonical_ids, r.canonical_account_id);
        end if;
    end loop;

    delete from public.plaid_canonical_financial_account_members as m
    where m.link_origin = 'sync_bootstrap'
      and m.unlinked_at is null;

    if exists (
        select 1
        from public.plaid_canonical_financial_account_members
        where link_origin = 'sync_bootstrap'
    ) then
        raise exception
            'cleanup_abort_sync_bootstrap_rows_remain_after_delete'
            using errcode = 'P0001';
    end if;

    foreach v_canonical_id in array v_bootstrap_canonical_ids
    loop
        select count(*) into v_member_refs
        from public.plaid_canonical_financial_account_members as m
        where m.canonical_account_id = v_canonical_id;

        if v_member_refs <> 0 then
            raise exception
                'cleanup_abort_targeted_canonical_still_has_membership_rows: canonical_id=%',
                v_canonical_id
                using errcode = 'P0001';
        end if;

        select count(*) into v_dup_refs
        from public.plaid_duplicate_operation_resolutions as d
        where d.canonical_account_id = v_canonical_id;

        if v_dup_refs <> 0 then
            raise exception
                'cleanup_abort_orphan_canonical_referenced_by_duplicate_resolutions: canonical_id=%',
                v_canonical_id
                using errcode = 'P0001';
        end if;

        if exists (
            select 1
            from public.plaid_internal_transfer_reconciliations as itr
            where itr.outgoing_canonical_account_id = v_canonical_id
               or itr.incoming_canonical_account_id = v_canonical_id
        ) then
            raise exception
                'cleanup_abort_orphan_canonical_referenced_by_it_reconciliations: canonical_id=%',
                v_canonical_id
                using errcode = 'P0001';
        end if;

        delete from public.plaid_canonical_financial_accounts as c
        where c.id = v_canonical_id;
    end loop;
end;
$$;

-- ============================================================================
-- 3) Restore Stage A-E shared function bodies BEFORE dropping late-path helpers
-- ============================================================================

-- Restored from 20260813130000_plaid_persist_accounts_sync_persistent_account_id.sql
-- Stage B (Edge Case №11): persist Plaid persistent_account_id via existing
-- plaid_persist_accounts_sync. Signature unchanged. First-wins on UPDATE.
-- Does not link, detect duplicates, or touch canonical/membership tables.

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

-- Restored from 20260813140000_plaid_link_canonical_financial_accounts.sql
-- Stage C (Edge Case №11): atomic user-confirmed canonical account linking RPC.
-- Account-level relationship only (not Item-level). No materialization effect.
-- PAI equal non-null = evidence (link_origin); different non-null PAI = hard reject.
-- Existing active authority is preserved and may be outside input pair A/B (N > 2).
-- Only M1 (both independent) requires p_authoritative_account_id ∈ {A,B}.
-- No canonical merge; unlink OUT OF SCOPE.
-- Known dependency: membership → accounts ON DELETE RESTRICT may block remove-item
-- physical account DELETE until Stage G. No production linking UX in Stage C.

create or replace function public.plaid_link_canonical_financial_accounts(
    p_user_id uuid,
    p_account_id_a uuid,
    p_account_id_b uuid,
    p_authoritative_account_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_lock_id_1 uuid;
    v_lock_id_2 uuid;

    v_a_plaid_account_id text;
    v_a_plaid_type text;
    v_a_persistent_account_id text;

    v_b_plaid_account_id text;
    v_b_plaid_type text;
    v_b_persistent_account_id text;

    v_link_origin text;
    v_m1_secondary_account_id uuid;

    v_mem_a_canonical_id uuid;
    v_mem_b_canonical_id uuid;

    v_tmp_account_id uuid;
    v_tmp_canonical_id uuid;

    v_canonical_id uuid;
    v_existing_authoritative_account_id uuid;
    v_authority_count integer;
begin
    if p_user_id is null
       or p_account_id_a is null
       or p_account_id_b is null
       or p_authoritative_account_id is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_account_id_a = p_account_id_b then
        raise exception 'same_account_forbidden' using errcode = '22023';
    end if;

    -- Deterministic account lock order (by id) to reduce A/B vs B/A deadlocks.
    v_lock_id_1 := least(p_account_id_a, p_account_id_b);
    v_lock_id_2 := greatest(p_account_id_a, p_account_id_b);

    perform 1
    from public.accounts
    where id = v_lock_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'account_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.accounts
    where id = v_lock_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'account_not_found' using errcode = '22023';
    end if;

    select
        accounts.plaid_account_id,
        accounts.plaid_type,
        accounts.persistent_account_id
    into
        v_a_plaid_account_id,
        v_a_plaid_type,
        v_a_persistent_account_id
    from public.accounts
    where accounts.id = p_account_id_a
      and accounts.user_id = p_user_id;

    select
        accounts.plaid_account_id,
        accounts.plaid_type,
        accounts.persistent_account_id
    into
        v_b_plaid_account_id,
        v_b_plaid_type,
        v_b_persistent_account_id
    from public.accounts
    where accounts.id = p_account_id_b
      and accounts.user_id = p_user_id;

    if v_a_plaid_account_id is null or v_b_plaid_account_id is null then
        raise exception 'account_not_plaid' using errcode = '22023';
    end if;

    if v_a_plaid_type is null
       or v_b_plaid_type is null
       or lower(trim(v_a_plaid_type)) <> lower(trim(v_b_plaid_type))
    then
        raise exception 'incompatible_account_types' using errcode = '22023';
    end if;

    -- PAI matrix: equal non-null = evidence; different non-null = hard reject; NULL = confirmation-only.
    if v_a_persistent_account_id is not null
       and v_b_persistent_account_id is not null
    then
        if v_a_persistent_account_id <> v_b_persistent_account_id then
            raise exception 'persistent_account_identity_conflict' using errcode = '22023';
        end if;
        v_link_origin := 'persistent_account_identity';
    else
        v_link_origin := 'user_confirmed';
    end if;

    -- Lock active memberships for A/B in deterministic account_id order, then map to A/B.
    v_mem_a_canonical_id := null;
    v_mem_b_canonical_id := null;

    for v_tmp_account_id, v_tmp_canonical_id in
        select
            members.account_id,
            members.canonical_account_id
        from public.plaid_canonical_financial_account_members as members
        where members.user_id = p_user_id
          and members.unlinked_at is null
          and members.account_id in (p_account_id_a, p_account_id_b)
        order by members.account_id
        for update
    loop
        if v_tmp_account_id = p_account_id_a then
            v_mem_a_canonical_id := v_tmp_canonical_id;
        elsif v_tmp_account_id = p_account_id_b then
            v_mem_b_canonical_id := v_tmp_canonical_id;
        end if;
    end loop;

    -- M4: both already active in the same canonical.
    -- Existing authority E may be outside {A,B}; client must pass E (no switch).
    if v_mem_a_canonical_id is not null
       and v_mem_b_canonical_id is not null
       and v_mem_a_canonical_id = v_mem_b_canonical_id
    then
        v_canonical_id := v_mem_a_canonical_id;

        perform 1
        from public.plaid_canonical_financial_accounts as canonical
        where canonical.id = v_canonical_id
          and canonical.user_id = p_user_id
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select members.account_id
        into v_existing_authoritative_account_id
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative'
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        if p_authoritative_account_id <> v_existing_authoritative_account_id then
            raise exception 'invalid_authority' using errcode = '22023';
        end if;

        return jsonb_build_object(
            'status', 'already_linked',
            'canonical_account_id', v_canonical_id,
            'authoritative_account_id', v_existing_authoritative_account_id,
            'added_account_id', null
        );
    end if;

    -- M5: different active canonical groups — no merge.
    if v_mem_a_canonical_id is not null
       and v_mem_b_canonical_id is not null
       and v_mem_a_canonical_id <> v_mem_b_canonical_id
    then
        raise exception 'canonical_conflict' using errcode = '22023';
    end if;

    -- M2: A in canonical, B free → add B as secondary; preserve existing authority E
    -- (E may be A or a third member outside the input pair).
    if v_mem_a_canonical_id is not null and v_mem_b_canonical_id is null then
        v_canonical_id := v_mem_a_canonical_id;

        perform 1
        from public.plaid_canonical_financial_accounts as canonical
        where canonical.id = v_canonical_id
          and canonical.user_id = p_user_id
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select members.account_id
        into v_existing_authoritative_account_id
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative'
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        if p_authoritative_account_id <> v_existing_authoritative_account_id then
            raise exception 'invalid_authority' using errcode = '22023';
        end if;

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
            p_account_id_b,
            'secondary',
            v_link_origin
        );

        return jsonb_build_object(
            'status', 'linked',
            'canonical_account_id', v_canonical_id,
            'authoritative_account_id', v_existing_authoritative_account_id,
            'added_account_id', p_account_id_b
        );
    end if;

    -- M3: B in canonical, A free → add A as secondary; preserve existing authority E.
    if v_mem_b_canonical_id is not null and v_mem_a_canonical_id is null then
        v_canonical_id := v_mem_b_canonical_id;

        perform 1
        from public.plaid_canonical_financial_accounts as canonical
        where canonical.id = v_canonical_id
          and canonical.user_id = p_user_id
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select members.account_id
        into v_existing_authoritative_account_id
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative'
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        if p_authoritative_account_id <> v_existing_authoritative_account_id then
            raise exception 'invalid_authority' using errcode = '22023';
        end if;

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
            p_account_id_a,
            'secondary',
            v_link_origin
        );

        return jsonb_build_object(
            'status', 'linked',
            'canonical_account_id', v_canonical_id,
            'authoritative_account_id', v_existing_authoritative_account_id,
            'added_account_id', p_account_id_a
        );
    end if;

    -- M1: both independent. Only this branch requires authority ∈ {A,B}.
    if p_authoritative_account_id <> p_account_id_a
       and p_authoritative_account_id <> p_account_id_b
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_m1_secondary_account_id := case
        when p_authoritative_account_id = p_account_id_a then p_account_id_b
        else p_account_id_a
    end;

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
        p_authoritative_account_id,
        'authoritative',
        v_link_origin
    );

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
        v_m1_secondary_account_id,
        'secondary',
        v_link_origin
    );

    return jsonb_build_object(
        'status', 'created',
        'canonical_account_id', v_canonical_id,
        'authoritative_account_id', p_authoritative_account_id,
        'added_account_id', null
    );
end;
$$;

revoke all on function public.plaid_link_canonical_financial_accounts(
    uuid,
    uuid,
    uuid,
    uuid
) from public;
revoke all on function public.plaid_link_canonical_financial_accounts(
    uuid,
    uuid,
    uuid,
    uuid
) from anon;
revoke all on function public.plaid_link_canonical_financial_accounts(
    uuid,
    uuid,
    uuid,
    uuid
) from authenticated;
grant execute on function public.plaid_link_canonical_financial_accounts(
    uuid,
    uuid,
    uuid,
    uuid
) to service_role;

-- Restored from 20260813160000_plaid_duplicate_operation_resolutions.sql (resolve/reverse/sync)
create or replace function public.plaid_resolve_duplicate_operations(
    p_user_id uuid,
    p_kept_operation_id uuid,
    p_suppressed_operation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_kept public.operations%rowtype;
    v_suppressed public.operations%rowtype;
    v_kept_projection_id uuid;
    v_suppressed_projection_id uuid;
    v_lock_projection_id_1 uuid;
    v_lock_projection_id_2 uuid;
    v_lock_operation_id_1 uuid;
    v_lock_operation_id_2 uuid;
    v_kept_account_id uuid;
    v_suppressed_account_id uuid;
    v_kept_canonical_id uuid;
    v_suppressed_canonical_id uuid;
    v_existing_id uuid;
    v_resolution_id uuid;
begin
    if p_user_id is null
       or p_kept_operation_id is null
       or p_suppressed_operation_id is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_kept_operation_id = p_suppressed_operation_id then
        raise exception 'same_operation_forbidden' using errcode = '22023';
    end if;

    select *
    into v_kept
    from public.operations
    where id = p_kept_operation_id
      and user_id = p_user_id;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_suppressed
    from public.operations
    where id = p_suppressed_operation_id
      and user_id = p_user_id;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    if v_kept.source is distinct from 'plaid'
       or v_suppressed.source is distinct from 'plaid'
    then
        raise exception 'operation_not_plaid' using errcode = '22023';
    end if;

    select projection.id
    into v_kept_projection_id
    from public.plaid_transaction_operation_projections projection
    where projection.operation_id = p_kept_operation_id
      and projection.user_id = p_user_id;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    select projection.id
    into v_suppressed_projection_id
    from public.plaid_transaction_operation_projections projection
    where projection.operation_id = p_suppressed_operation_id
      and projection.user_id = p_user_id;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    -- Lock order: PROJECTION → OPERATION (compatible with source-sync).
    v_lock_projection_id_1 := least(v_kept_projection_id, v_suppressed_projection_id);
    v_lock_projection_id_2 := greatest(v_kept_projection_id, v_suppressed_projection_id);

    perform 1
    from public.plaid_transaction_operation_projections
    where id = v_lock_projection_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.plaid_transaction_operation_projections
    where id = v_lock_projection_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    v_lock_operation_id_1 := least(p_kept_operation_id, p_suppressed_operation_id);
    v_lock_operation_id_2 := greatest(p_kept_operation_id, p_suppressed_operation_id);

    perform 1
    from public.operations
    where id = v_lock_operation_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.operations
    where id = v_lock_operation_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    -- Re-load under locks.
    select *
    into v_kept
    from public.operations
    where id = p_kept_operation_id
      and user_id = p_user_id
      and source = 'plaid';

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_suppressed
    from public.operations
    where id = p_suppressed_operation_id
      and user_id = p_user_id
      and source = 'plaid';

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    -- Confirm projection↔operation linkage still holds under locks.
    if not exists (
        select 1
        from public.plaid_transaction_operation_projections
        where id = v_kept_projection_id
          and user_id = p_user_id
          and operation_id = p_kept_operation_id
    ) or not exists (
        select 1
        from public.plaid_transaction_operation_projections
        where id = v_suppressed_projection_id
          and user_id = p_user_id
          and operation_id = p_suppressed_operation_id
    ) then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    -- G1 graph checks under both Operation locks.
    select id
    into v_existing_id
    from public.plaid_duplicate_operation_resolutions
    where user_id = p_user_id
      and kept_operation_id = p_kept_operation_id
      and suppressed_operation_id = p_suppressed_operation_id
      and reversed_at is null;

    if found then
        return jsonb_build_object(
            'status', 'already_resolved',
            'resolution_id', v_existing_id,
            'kept_operation_id', p_kept_operation_id,
            'suppressed_operation_id', p_suppressed_operation_id
        );
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and suppressed_operation_id = p_suppressed_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and suppressed_operation_id = p_kept_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and kept_operation_id = p_suppressed_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    -- Canonical membership: same active canonical; no authority-role requirement.
    select raw.account_id
    into v_kept_account_id
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    where projection.id = v_kept_projection_id
      and projection.user_id = p_user_id;

    if v_kept_account_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select raw.account_id
    into v_suppressed_account_id
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    where projection.id = v_suppressed_projection_id
      and projection.user_id = p_user_id;

    if v_suppressed_account_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select m.canonical_account_id
    into v_kept_canonical_id
    from public.plaid_canonical_financial_account_members m
    where m.account_id = v_kept_account_id
      and m.user_id = p_user_id
      and m.unlinked_at is null;

    if v_kept_canonical_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select m.canonical_account_id
    into v_suppressed_canonical_id
    from public.plaid_canonical_financial_account_members m
    where m.account_id = v_suppressed_account_id
      and m.user_id = p_user_id
      and m.unlinked_at is null;

    if v_suppressed_canonical_id is null
       or v_suppressed_canonical_id is distinct from v_kept_canonical_id
    then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    insert into public.plaid_duplicate_operation_resolutions (
        user_id,
        canonical_account_id,
        kept_operation_id,
        suppressed_operation_id
    )
    values (
        p_user_id,
        v_kept_canonical_id,
        p_kept_operation_id,
        p_suppressed_operation_id
    )
    returning id into v_resolution_id;

    if v_suppressed.archived_at is null then
        update public.operations
        set archived_at = now()
        where id = p_suppressed_operation_id
          and user_id = p_user_id
          and source = 'plaid'
          and archived_at is null;
    end if;

    return jsonb_build_object(
        'status', 'resolved',
        'resolution_id', v_resolution_id,
        'kept_operation_id', p_kept_operation_id,
        'suppressed_operation_id', p_suppressed_operation_id
    );
end;
$$;

comment on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid) is
    'Service-role Stage E RPC: persist explicit user-selected kept/suppressed Plaid Operation pair under the same active canonical. G1 star graph. Locks projections then operations. Archives suppressed Operation if not already archived. No fuzzy matching. No JOB/ACCOUNT locks.';

revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from public;
revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from anon;
revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from authenticated;
grant execute on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 3) Reverse RPC
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reverse_duplicate_operation_resolution(
    p_user_id uuid,
    p_resolution_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_resolution public.plaid_duplicate_operation_resolutions%rowtype;
    v_lock_operation_id_1 uuid;
    v_lock_operation_id_2 uuid;
begin
    if p_user_id is null or p_resolution_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Identity read without locking resolution yet.
    select *
    into v_resolution
    from public.plaid_duplicate_operation_resolutions
    where id = p_resolution_id
      and user_id = p_user_id;

    if not found then
        raise exception 'resolution_not_found' using errcode = '22023';
    end if;

    -- Lock BOTH Operations first (never RESOLUTION → OPERATION).
    v_lock_operation_id_1 := least(
        v_resolution.kept_operation_id,
        v_resolution.suppressed_operation_id
    );
    v_lock_operation_id_2 := greatest(
        v_resolution.kept_operation_id,
        v_resolution.suppressed_operation_id
    );

    perform 1
    from public.operations
    where id = v_lock_operation_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.operations
    where id = v_lock_operation_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_resolution
    from public.plaid_duplicate_operation_resolutions
    where id = p_resolution_id
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'resolution_not_found' using errcode = '22023';
    end if;

    if v_resolution.reversed_at is not null then
        return jsonb_build_object(
            'status', 'already_reversed',
            'resolution_id', v_resolution.id
        );
    end if;

    update public.plaid_duplicate_operation_resolutions
    set reversed_at = now()
    where id = v_resolution.id
      and user_id = p_user_id
      and reversed_at is null;

    -- Intentionally do NOT touch operations.archived_at.
    return jsonb_build_object(
        'status', 'reversed',
        'resolution_id', v_resolution.id
    );
end;
$$;

comment on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid) is
    'Service-role Stage E RPC: reverse an explicit duplicate Operation resolution by setting reversed_at. Locks both Operations then the resolution row. Never unarchives Operations; source-sync resumes normal lifecycle after freeze ends.';

revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from public;
revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from anon;
revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from authenticated;
grant execute on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 4) Source-sync freeze gate (CREATE OR REPLACE latest)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_sync_materialized_transaction_operations(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_batch_size integer default 250
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_job public.plaid_transaction_projection_jobs%rowtype;
    v_scanned integer := 0;
    v_source_updated integer := 0;
    v_source_archived integer := 0;
    v_source_unarchived integer := 0;
    v_override_preserved integer := 0;
    v_override_invalidated integer := 0;
    v_has_more boolean := false;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_lease_token is null
       or p_batch_size is null
       or p_batch_size < 1
       or p_batch_size > 250
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_batch_size := p_batch_size;

    select *
    into v_job
    from public.plaid_transaction_projection_jobs
    where plaid_item_id = p_plaid_item_id
      and user_id = p_user_id
    for update;

    if not found then
        return jsonb_build_object('status', 'missing');
    end if;

    if v_job.status <> 'processing'
       or v_job.lease_token is distinct from p_lease_token
       or v_job.lease_expires_at is null
       or v_job.lease_expires_at <= now()
    then
        return jsonb_build_object('status', 'lease_lost');
    end if;

    if not exists (
        select 1
        from public.plaid_items
        where plaid_items.id = p_plaid_item_id
          and plaid_items.user_id = p_user_id
    ) then
        return jsonb_build_object('status', 'missing_item');
    end if;

    -- Two-phase Stage E freeze visibility (READ COMMITTED):
    -- PHASE 1 locks candidate projection/operation rows only.
    -- PHASE 2 is a separate SQL statement that re-reads active resolutions
    -- under those held locks and only then classifies freeze / expected state.
    drop table if exists pg_temp.plaid_materialized_operation_source_sync_locked;
    drop table if exists pg_temp.plaid_materialized_operation_source_sync_batch;

    create temporary table pg_temp.plaid_materialized_operation_source_sync_locked (
        projection_id uuid primary key,
        operation_id uuid not null
    ) on commit drop;

    create temporary table pg_temp.plaid_materialized_operation_source_sync_batch (
        projection_id uuid primary key,
        operation_id uuid not null,
        expected_from_account_id uuid not null,
        expected_type text not null,
        expected_amount numeric(14, 2) not null,
        expected_currency_code char(3) not null,
        expected_occurred_at date not null,
        expected_note text null,
        expected_archived_at timestamptz null,
        current_archived_at timestamptz null,
        current_category_id text null,
        category_overridden boolean not null,
        current_category_type text null,
        source_fields_differ boolean not null,
        archive_needed boolean not null,
        unarchive_needed boolean not null,
        override_invalidated boolean not null
    ) on commit drop;

    -- PHASE 1: acquire locks. Candidate pruning may use resolution EXISTS for
    -- convergence only; it must NOT compute freeze/expected_* here.
    -- Lifecycle-shaped WHERE (same candidate classes as Stage E): archive-needed,
    -- defensive null-archive under active suppression, or unarchive/field/category
    -- work for non-pruned active posted rows.
    insert into pg_temp.plaid_materialized_operation_source_sync_locked (
        projection_id,
        operation_id
    )
    select
        projection.id,
        operations.id
    from public.plaid_transaction_operation_projections projection
    join public.operations operations
      on operations.id = projection.operation_id
     and operations.user_id = projection.user_id
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id
    where projection.user_id = p_user_id
      and projection.plaid_item_id = p_plaid_item_id
      and projection.operation_id is not null
      and operations.source = 'plaid'
      and (
          (
              (
                  raw.removed_at is not null
                  or (
                      raw.removed_at is null
                      and raw.pending = false
                      and raw.amount = 0
                  )
              )
              and operations.archived_at is null
          )
          or (
              exists (
                  select 1
                  from public.plaid_duplicate_operation_resolutions resolution
                  where resolution.suppressed_operation_id = operations.id
                    and resolution.user_id = operations.user_id
                    and resolution.reversed_at is null
              )
              and operations.archived_at is null
          )
          or (
              raw.removed_at is null
              and raw.pending = false
              and raw.amount <> 0
              and not exists (
                  select 1
                  from public.plaid_duplicate_operation_resolutions resolution
                  where resolution.suppressed_operation_id = operations.id
                    and resolution.user_id = operations.user_id
                    and resolution.reversed_at is null
              )
              and (
                  operations.archived_at is not null
                  or operations.from_account_id is distinct from raw.account_id
                  or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                  or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                  or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                  or operations.occurred_at is distinct from raw.date
                  or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
                  or (
                      operations.category_id is not null
                      and public.ophir_operation_category_type(operations.category_id)
                          is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                  )
              )
          )
      )
    order by raw.date, raw.transaction_id
    limit v_batch_size
    for update of projection, operations skip locked;

    -- PHASE 2: new SQL statement / new READ COMMITTED snapshot while locks held.
    -- Active-resolution freeze classification happens only here.
    insert into pg_temp.plaid_materialized_operation_source_sync_batch (
        projection_id,
        operation_id,
        expected_from_account_id,
        expected_type,
        expected_amount,
        expected_currency_code,
        expected_occurred_at,
        expected_note,
        expected_archived_at,
        current_archived_at,
        current_category_id,
        category_overridden,
        current_category_type,
        source_fields_differ,
        archive_needed,
        unarchive_needed,
        override_invalidated
    )
    select
        projection.id,
        operations.id,
        raw.account_id,
        case when raw.amount > 0 then 'expense' else 'income' end as expected_type,
        round(abs(raw.amount), 2)::numeric(14, 2) as expected_amount,
        upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3) as expected_currency_code,
        raw.date as expected_occurred_at,
        nullif(trim(coalesce(raw.merchant_name, raw.name)), '') as expected_note,
        case
            when exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            ) then
                coalesce(
                    operations.archived_at,
                    case
                        when raw.removed_at is not null then raw.removed_at
                        when raw.pending = false and raw.amount = 0 then now()
                        else now()
                    end
                )
            when raw.removed_at is not null then coalesce(operations.archived_at, raw.removed_at)
            when raw.pending = false and raw.amount = 0 then coalesce(operations.archived_at, now())
            else null
        end as expected_archived_at,
        operations.archived_at as current_archived_at,
        operations.category_id as current_category_id,
        operations.category_overridden,
        public.ophir_operation_category_type(operations.category_id) as current_category_type,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and (
                operations.from_account_id is distinct from raw.account_id
                or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                or operations.occurred_at is distinct from raw.date
                or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
            )
        ) as source_fields_differ,
        (
            (
                raw.removed_at is not null
                or (
                    raw.removed_at is null
                    and raw.pending = false
                    and raw.amount = 0
                )
                or exists (
                    select 1
                    from public.plaid_duplicate_operation_resolutions resolution
                    where resolution.suppressed_operation_id = operations.id
                      and resolution.user_id = operations.user_id
                      and resolution.reversed_at is null
                )
            )
            and operations.archived_at is null
        ) as archive_needed,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.archived_at is not null
        ) as unarchive_needed,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.category_overridden = true
            and operations.category_id is not null
            and public.ophir_operation_category_type(operations.category_id)
                is distinct from case when raw.amount > 0 then 'expense' else 'income' end
        ) as override_invalidated
    from pg_temp.plaid_materialized_operation_source_sync_locked locked
    join public.plaid_transaction_operation_projections projection
      on projection.id = locked.projection_id
     and projection.user_id = p_user_id
    join public.operations operations
      on operations.id = locked.operation_id
     and operations.user_id = p_user_id
     and operations.id = projection.operation_id
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id;

    select
        count(*),
        count(*) filter (where source_fields_differ),
        count(*) filter (where archive_needed),
        count(*) filter (where unarchive_needed),
        count(*) filter (where category_overridden and not override_invalidated),
        count(*) filter (where override_invalidated)
    into
        v_scanned,
        v_source_updated,
        v_source_archived,
        v_source_unarchived,
        v_override_preserved,
        v_override_invalidated
    from pg_temp.plaid_materialized_operation_source_sync_batch;

    update public.operations operations
    set
        from_account_id = case
            when batch.expected_archived_at is null then batch.expected_from_account_id
            else operations.from_account_id
        end,
        to_account_id = case
            when batch.expected_archived_at is null then null
            else operations.to_account_id
        end,
        type = case
            when batch.expected_archived_at is null then batch.expected_type
            else operations.type
        end,
        amount = case
            when batch.expected_archived_at is null then batch.expected_amount
            else operations.amount
        end,
        currency_code = case
            when batch.expected_archived_at is null then batch.expected_currency_code
            else operations.currency_code
        end,
        occurred_at = case
            when batch.expected_archived_at is null then batch.expected_occurred_at
            else operations.occurred_at
        end,
        note = case
            when batch.expected_archived_at is null then batch.expected_note
            else operations.note
        end,
        category_id = case
            when batch.expected_archived_at is null
                 and batch.current_category_id is not null
                 and batch.current_category_type is distinct from batch.expected_type
              then null
            else operations.category_id
        end,
        archived_at = batch.expected_archived_at
    from pg_temp.plaid_materialized_operation_source_sync_batch batch
    where operations.id = batch.operation_id
      and operations.user_id = p_user_id
      and operations.source = 'plaid';

    select exists (
        select 1
        from public.plaid_transaction_operation_projections projection
        join public.operations operations
          on operations.id = projection.operation_id
         and operations.user_id = projection.user_id
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        join public.accounts account
          on account.id = raw.account_id
         and account.user_id = raw.user_id
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.operation_id is not null
          and operations.source = 'plaid'
          and not exists (
              select 1
              from pg_temp.plaid_materialized_operation_source_sync_batch batch
              where batch.projection_id = projection.id
          )
          and (
              (
                  (
                      raw.removed_at is not null
                      or (
                          raw.removed_at is null
                          and raw.pending = false
                          and raw.amount = 0
                      )
                  )
                  and operations.archived_at is null
              )
              or (
                  exists (
                      select 1
                      from public.plaid_duplicate_operation_resolutions resolution
                      where resolution.suppressed_operation_id = operations.id
                        and resolution.user_id = operations.user_id
                        and resolution.reversed_at is null
                  )
                  and operations.archived_at is null
              )
              or (
                  raw.removed_at is null
                  and raw.pending = false
                  and raw.amount <> 0
                  and not exists (
                      select 1
                      from public.plaid_duplicate_operation_resolutions resolution
                      where resolution.suppressed_operation_id = operations.id
                        and resolution.user_id = operations.user_id
                        and resolution.reversed_at is null
                  )
                  and (
                      operations.archived_at is not null
                      or operations.from_account_id is distinct from raw.account_id
                      or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                      or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                      or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                      or operations.occurred_at is distinct from raw.date
                      or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
                      or (
                          operations.category_id is not null
                          and public.ophir_operation_category_type(operations.category_id)
                              is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                      )
                  )
              )
          )
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'source_scanned', v_scanned,
        'source_updated', v_source_updated,
        'source_archived', v_source_archived,
        'source_unarchived', v_source_unarchived,
        'source_unchanged', 0,
        'override_preserved', v_override_preserved,
        'override_invalidated', v_override_invalidated,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role convergence from authoritative raw Plaid transaction lifecycle to already materialized Plaid Operations. Updates source-owned Operation fields and server-owned archive state only. Stage E: locks candidate projection/operation rows first, then classifies active duplicate-resolution freeze in a separate SQL statement under those locks (READ COMMITTED). Active suppressed Operations remain archived/frozen; freeze ends when resolution.reversed_at is set.';

revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;

-- ============================================================================
-- 4) Drop F/G/H1/P path-only functions (explicit, no CASCADE)
-- ============================================================================

drop function if exists public.plaid_list_internal_transfer_review_items(text[]);
drop function if exists public.plaid_confirm_internal_transfer_candidate(uuid, uuid);
drop function if exists public.plaid_reverse_internal_transfer_resolution(uuid, uuid);
drop function if exists public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid);
drop function if exists public.plaid_reconcile_internal_transfer_candidates_for_user(uuid);
drop function if exists public.plaid_confirmed_internal_transfer_inconsistency_code(uuid, uuid);
drop function if exists public.plaid_operation_is_confirmed_internal_transfer_leg(uuid, uuid);
drop function if exists public.plaid_internal_transfer_pfc_allowlisted(text, text);
drop function if exists public.plaid_internal_transfer_pfc_directional_compatible(text, text, text, text);
drop function if exists public.plaid_internal_transfer_pai_different_proven(text, text);
drop function if exists public.plaid_backfill_account_identity(uuid, integer, uuid);
drop function if exists public.plaid_reconcile_account_identity_by_pai(uuid, uuid);
drop function if exists public.plaid_lock_account_identity_pai_group(uuid, text);
drop function if exists public.plaid_ensure_account_identity(uuid, uuid);

-- ============================================================================
-- 5) Drop Stage F/G reconciliation table (indexes/policies/triggers with table)
-- ============================================================================

drop table if exists public.plaid_internal_transfer_reconciliations;

-- ============================================================================
-- 6) Restore operations.source check to pre-G contract
-- ============================================================================

alter table public.operations
    drop constraint if exists operations_source_check;

alter table public.operations
    add constraint operations_source_check
    check (source in ('manual', 'plaid')) not valid;

alter table public.operations
    validate constraint operations_source_check;

-- ============================================================================
-- 7) Restore link_origin check to Stage A–E / pre-P2 contract
-- ============================================================================

alter table public.plaid_canonical_financial_account_members
    drop constraint if exists plaid_canonical_financial_account_members_link_origin_check;

alter table public.plaid_canonical_financial_account_members
    add constraint plaid_canonical_financial_account_members_link_origin_check
    check (
        link_origin in (
            'user_confirmed',
            'persistent_account_identity'
        )
    );

comment on column public.plaid_canonical_financial_account_members.link_origin is
    'Evidence/provenance for the link. persistent_account_identity means PAI contributed evidence; V1 still expects explicit user confirmation at linking time (future stage). user_confirmed means user confirmation without PAI evidence. Stage A does not create links.';

-- ============================================================================
-- 8) Postcondition asserts
-- ============================================================================

do $$
begin
    if to_regclass('public.plaid_internal_transfer_reconciliations') is not null then
        raise exception 'cleanup_abort_it_table_still_present' using errcode = 'P0001';
    end if;

    if exists (
        select 1
        from public.plaid_canonical_financial_account_members
        where link_origin = 'sync_bootstrap'
    ) then
        raise exception 'cleanup_abort_sync_bootstrap_still_present' using errcode = 'P0001';
    end if;

    if exists (
        select 1
        from public.operations
        where source = 'plaid_internal_transfer'
    ) then
        raise exception 'cleanup_abort_synthetic_it_ops_still_present' using errcode = 'P0001';
    end if;

    if to_regprocedure('public.plaid_ensure_account_identity(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_reconcile_account_identity_by_pai(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_lock_account_identity_pai_group(uuid,text)') is not null
       or to_regprocedure('public.plaid_backfill_account_identity(uuid,integer,uuid)') is not null
       or to_regprocedure('public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)') is not null
       or to_regprocedure('public.plaid_confirm_internal_transfer_candidate(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_reverse_internal_transfer_resolution(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_list_internal_transfer_review_items(text[])') is not null
    then
        raise exception 'cleanup_abort_removed_functions_still_present' using errcode = 'P0001';
    end if;

    if to_regprocedure('public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)') is null then
        raise exception 'cleanup_abort_persist_missing' using errcode = 'P0001';
    end if;

    if to_regprocedure('public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)') is null then
        raise exception 'cleanup_abort_link_missing' using errcode = 'P0001';
    end if;
end;
$$;
