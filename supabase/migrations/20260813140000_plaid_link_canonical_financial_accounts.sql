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
