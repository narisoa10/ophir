-- Identity foundation P1: canonical merge capability for Stage C link RPC.
-- Additive only. Does NOT bootstrap singletons, auto-link PAI, or backfill.
-- Replaces M5 canonical_conflict with atomic merge when identity preconditions pass.
-- Preserves M1–M4 semantics and Stage G consistency hook on every success path.
-- Applied Stage A–G / H1 migration files are not edited.

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

    v_survivor_canonical_id uuid;
    v_losing_canonical_id uuid;
    v_auth_a uuid;
    v_auth_b uuid;
    v_canon_lock_1 uuid;
    v_canon_lock_2 uuid;
    v_rehomed_count integer;
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

        perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
        return jsonb_build_object(
            'status', 'already_linked',
            'canonical_account_id', v_canonical_id,
            'authoritative_account_id', v_existing_authoritative_account_id,
            'added_account_id', null
        );
    end if;

    -- M5: both active membered in different canonicals → atomic merge.
    if v_mem_a_canonical_id is not null
       and v_mem_b_canonical_id is not null
       and v_mem_a_canonical_id <> v_mem_b_canonical_id
    then
        -- Lock both canonical rows in deterministic id order.
        v_canon_lock_1 := least(v_mem_a_canonical_id, v_mem_b_canonical_id);
        v_canon_lock_2 := greatest(v_mem_a_canonical_id, v_mem_b_canonical_id);

        perform 1
        from public.plaid_canonical_financial_accounts as canonical
        where canonical.id = v_canon_lock_1
          and canonical.user_id = p_user_id
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        perform 1
        from public.plaid_canonical_financial_accounts as canonical
        where canonical.id = v_canon_lock_2
          and canonical.user_id = p_user_id
        for update;

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        -- Lock every active membership in both canonicals (deterministic account order).
        perform 1
        from public.plaid_canonical_financial_account_members as members
        where members.user_id = p_user_id
          and members.unlinked_at is null
          and members.canonical_account_id in (
              v_mem_a_canonical_id,
              v_mem_b_canonical_id
          )
        order by members.account_id
        for update;

        select members.account_id
        into v_auth_a
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_mem_a_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_mem_a_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select members.account_id
        into v_auth_b
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_mem_b_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if not found then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_mem_b_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        -- Survivor = canonical whose existing authoritative equals p_authoritative_account_id.
        -- No authority switch across canonicals (same no-switch spirit as M4).
        if p_authoritative_account_id = v_auth_a then
            v_survivor_canonical_id := v_mem_a_canonical_id;
            v_losing_canonical_id := v_mem_b_canonical_id;
            v_existing_authoritative_account_id := v_auth_a;
        elsif p_authoritative_account_id = v_auth_b then
            v_survivor_canonical_id := v_mem_b_canonical_id;
            v_losing_canonical_id := v_mem_a_canonical_id;
            v_existing_authoritative_account_id := v_auth_b;
        else
            raise exception 'invalid_authority' using errcode = '22023';
        end if;

        -- Rehome all ACTIVE memberships from losing → survivor as secondary.
        -- Historical/unlinked rows are left untouched for auditability.
        update public.plaid_canonical_financial_account_members as members
        set
            canonical_account_id = v_survivor_canonical_id,
            role = 'secondary',
            link_origin = v_link_origin,
            updated_at = now()
        where members.user_id = p_user_id
          and members.unlinked_at is null
          and members.canonical_account_id = v_losing_canonical_id;

        get diagnostics v_rehomed_count = row_count;

        if v_rehomed_count < 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        -- Survivor must still have exactly one authoritative (the preserved authority).
        select count(*)::integer
        into v_authority_count
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_survivor_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_authority_count <> 1 then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        select members.account_id
        into v_existing_authoritative_account_id
        from public.plaid_canonical_financial_account_members as members
        where members.canonical_account_id = v_survivor_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null
          and members.role = 'authoritative';

        if v_existing_authoritative_account_id is distinct from p_authoritative_account_id then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        -- Losing canonical must have no active members (orphan empty row is allowed).
        if exists (
            select 1
            from public.plaid_canonical_financial_account_members as members
            where members.canonical_account_id = v_losing_canonical_id
              and members.user_id = p_user_id
              and members.unlinked_at is null
        ) then
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
        return jsonb_build_object(
            'status', 'merged',
            'canonical_account_id', v_survivor_canonical_id,
            'authoritative_account_id', v_existing_authoritative_account_id,
            'added_account_id', null
        );
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

        perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
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

        perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
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

    perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
    return jsonb_build_object(
        'status', 'created',
        'canonical_account_id', v_canonical_id,
        'authoritative_account_id', p_authoritative_account_id,
        'added_account_id', null
    );
end;
$$;

comment on function public.plaid_link_canonical_financial_accounts(
    uuid,
    uuid,
    uuid,
    uuid
) is
    'Identity P1: Stage C link with atomic canonical merge (M5). M1–M4 preserved. Stage G reconcile hook on all success paths. No singleton bootstrap, no auto PAI discovery, no operation mutation. Service-role only.';

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
