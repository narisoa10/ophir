-- Cleanup validation: Internal Transfer candidate/confirm + identity P1–P5 path removed.
-- Read-only relative to persistent LIVE data (transaction rolled back).
-- Run AFTER applying:
--   20260818170000_remove_internal_transfer_candidate_confirm_identity_path.sql

begin;

do $$
declare
    v_persist_body text;
    v_link_body text;
    v_link_origin_def text;
    v_source_def text;
    v_user_confirmed_auth bigint;
    v_user_confirmed_secondary bigint;
    v_sync_bootstrap_active bigint;
begin
    -- R-1 Stage F reconciliation table absent
    if to_regclass('public.plaid_internal_transfer_reconciliations') is not null then
        raise exception 'R-1 FAIL: plaid_internal_transfer_reconciliations still present';
    end if;

    -- R-2 candidate detector absent
    if to_regprocedure('public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)') is not null then
        raise exception 'R-2 FAIL: candidate detector still present';
    end if;

    -- R-3 Stage F hardening helpers absent
    if to_regprocedure('public.plaid_internal_transfer_pfc_directional_compatible(text,text,text,text)') is not null
       or to_regprocedure('public.plaid_internal_transfer_pai_different_proven(text,text)') is not null
    then
        raise exception 'R-3 FAIL: Stage F hardening helpers still present';
    end if;

    -- R-4 Stage G confirm absent
    if to_regprocedure('public.plaid_confirm_internal_transfer_candidate(uuid,uuid)') is not null then
        raise exception 'R-4 FAIL: confirm function still present';
    end if;

    -- R-5 Stage G reverse absent
    if to_regprocedure('public.plaid_reverse_internal_transfer_resolution(uuid,uuid)') is not null then
        raise exception 'R-5 FAIL: reverse function still present';
    end if;

    -- R-6 / R-20 H1 review/list RPC absent
    if to_regprocedure('public.plaid_list_internal_transfer_review_items(text[])') is not null then
        raise exception 'R-6/R-20 FAIL: list review RPC still present';
    end if;

    -- R-8 P2 ensure absent
    if to_regprocedure('public.plaid_ensure_account_identity(uuid,uuid)') is not null then
        raise exception 'R-8 FAIL: plaid_ensure_account_identity still present';
    end if;

    -- R-9 P3 reconcile/lock absent
    if to_regprocedure('public.plaid_reconcile_account_identity_by_pai(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_lock_account_identity_pai_group(uuid,text)') is not null
    then
        raise exception 'R-9 FAIL: P3 helpers still present';
    end if;

    -- R-10 / R-25 P4 backfill absent
    if to_regprocedure('public.plaid_backfill_account_identity(uuid,integer,uuid)') is not null then
        raise exception 'R-10/R-25 FAIL: backfill RPC still present';
    end if;

    -- R-12 worker DB-side function dependencies gone (covered by R-2 + related)
    if to_regprocedure('public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)') is not null
       or to_regprocedure('public.plaid_confirmed_internal_transfer_inconsistency_code(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_operation_is_confirmed_internal_transfer_leg(uuid,uuid)') is not null
       or to_regprocedure('public.plaid_internal_transfer_pfc_allowlisted(text,text)') is not null
    then
        raise exception 'R-12 FAIL: residual IT helper still present';
    end if;

    -- R-15 Stage A–E canonical tables present
    if to_regclass('public.plaid_canonical_financial_accounts') is null
       or to_regclass('public.plaid_canonical_financial_account_members') is null
    then
        raise exception 'R-15 FAIL: Stage A canonical tables missing';
    end if;

    -- R-16 Stage D behavior still present (materialization authority RPCs)
    if to_regprocedure('public.plaid_reconcile_transaction_operation_projections(uuid,uuid,uuid,integer)') is null
       and to_regprocedure('public.plaid_reconcile_transaction_operation_projections(uuid, uuid, uuid, integer)') is null
    then
        -- Signature may vary by whitespace; use pg_proc name check.
        if not exists (
            select 1 from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public'
              and p.proname = 'plaid_reconcile_transaction_operation_projections'
        ) then
            raise exception 'R-16 FAIL: Stage D reconcile RPC missing';
        end if;
    end if;

    if not exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = 'plaid_materialize_transaction_operations'
    ) then
        raise exception 'R-16 FAIL: Stage D materialize RPC missing';
    end if;

    -- R-17 Stage E behavior still present
    if to_regprocedure('public.plaid_resolve_duplicate_operations(uuid,uuid,uuid)') is null
       or to_regprocedure('public.plaid_reverse_duplicate_operation_resolution(uuid,uuid)') is null
       or to_regprocedure('public.plaid_sync_materialized_transaction_operations(uuid,uuid,uuid,integer)') is null
    then
        raise exception 'R-17 FAIL: Stage E RPCs missing';
    end if;

    -- R-22 persist signature present
    if to_regprocedure(
        'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'
    ) is null then
        raise exception 'R-22 FAIL: persist signature missing';
    end if;

    -- R-23 link signature present
    if to_regprocedure('public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)') is null then
        raise exception 'R-23 FAIL: link signature missing';
    end if;

    select pg_get_functiondef(
        'public.plaid_persist_accounts_sync(uuid,uuid,text,text,text,text,text,timestamptz,jsonb)'::regprocedure
    )
    into v_persist_body;

    select pg_get_functiondef(
        'public.plaid_link_canonical_financial_accounts(uuid,uuid,uuid,uuid)'::regprocedure
    )
    into v_link_body;

    -- R-11 / R-24 P2/P3 wiring absent from persist; no same-PAI auto reconcile
    if position('plaid_ensure_account_identity' in lower(v_persist_body)) > 0
       or position('plaid_reconcile_account_identity_by_pai' in lower(v_persist_body)) > 0
       or position('plaid_lock_account_identity_pai_group' in lower(v_persist_body)) > 0
       or position('sync_bootstrap' in lower(v_persist_body)) > 0
    then
        raise exception 'R-11/R-24 FAIL: persist still references P2/P3/bootstrap path';
    end if;

    -- R-7 / R-23 P1 merge runtime absent from link body
    if position('''merged''' in lower(v_link_body)) > 0
       or position('status'', ''merged' in lower(v_link_body)) > 0
       or position('merged' in lower(v_link_body)) > 0
    then
        -- Allow the word only if somehow in comments; fail on merged status token.
        if position('''merged''' in v_link_body) > 0
           or position('status'', ''merged''' in v_link_body) > 0
           or position('''status'', ''merged''' in v_link_body) > 0
        then
            raise exception 'R-7 FAIL: link body still exposes merged status';
        end if;
        if position(' merge' in lower(v_link_body)) > 0
           or position('canonical merge' in lower(v_link_body)) > 0
        then
            -- Stage C comments may say "No canonical merge"; that is acceptable.
            null;
        end if;
    end if;

    if position('''merged''' in v_link_body) > 0 then
        raise exception 'R-7 FAIL: link body still returns merged';
    end if;

    -- R-13 sync_bootstrap active memberships absent
    select count(*) into v_sync_bootstrap_active
    from public.plaid_canonical_financial_account_members
    where link_origin = 'sync_bootstrap'
      and unlinked_at is null;

    if v_sync_bootstrap_active <> 0 then
        raise exception 'R-13 FAIL: active sync_bootstrap memberships remain: %',
            v_sync_bootstrap_active;
    end if;

    if exists (
        select 1
        from public.plaid_canonical_financial_account_members
        where link_origin = 'sync_bootstrap'
    ) then
        raise exception 'R-13 FAIL: residual sync_bootstrap membership rows remain';
    end if;

    -- R-14 A–E user_confirmed topology remains valid (semantic; no global hard counts)
    if exists (
        select 1
        from public.plaid_canonical_financial_account_members
        where link_origin = 'user_confirmed'
          and unlinked_at is null
          and role not in ('authoritative', 'secondary')
    ) then
        raise exception 'R-14 FAIL: invalid role on active user_confirmed membership';
    end if;

    select count(*) into v_user_confirmed_auth
    from public.plaid_canonical_financial_account_members
    where link_origin = 'user_confirmed'
      and role = 'authoritative'
      and unlinked_at is null;

    select count(*) into v_user_confirmed_secondary
    from public.plaid_canonical_financial_account_members
    where link_origin = 'user_confirmed'
      and role = 'secondary'
      and unlinked_at is null;

    -- If this environment still has the pre-P2 linked pair, both sides must remain.
    if v_user_confirmed_auth > 0 and v_user_confirmed_secondary = 0 then
        raise exception
            'R-14 FAIL: user_confirmed authoritative exists without secondary survivor';
    end if;

    if v_user_confirmed_secondary > 0 and v_user_confirmed_auth = 0 then
        raise exception
            'R-14 FAIL: user_confirmed secondary exists without authoritative survivor';
    end if;

    -- R-18 no synthetic IT operations
    if exists (
        select 1 from public.operations where source = 'plaid_internal_transfer'
    ) then
        raise exception 'R-18 FAIL: synthetic plaid_internal_transfer operations exist';
    end if;

    -- R-19 no IT reconciliation rows (table absent => vacuously true; double-check)
    if to_regclass('public.plaid_internal_transfer_reconciliations') is not null then
        raise exception 'R-19 FAIL: IT reconciliation table still present';
    end if;

    -- R-21 service_role grants for removed functions absent because functions absent
    if exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname in (
              'plaid_reconcile_internal_transfer_candidates_for_user',
              'plaid_confirm_internal_transfer_candidate',
              'plaid_reverse_internal_transfer_resolution',
              'plaid_list_internal_transfer_review_items',
              'plaid_ensure_account_identity',
              'plaid_reconcile_account_identity_by_pai',
              'plaid_lock_account_identity_pai_group',
              'plaid_backfill_account_identity',
              'plaid_internal_transfer_pfc_directional_compatible',
              'plaid_internal_transfer_pai_different_proven'
          )
    ) then
        raise exception 'R-21 FAIL: removed function name still exists in pg_proc';
    end if;

    -- R-26 link_origin constraint restored to pre-P2/A–E contract
    select pg_get_constraintdef(c.oid)
    into v_link_origin_def
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'plaid_canonical_financial_account_members'
      and c.conname = 'plaid_canonical_financial_account_members_link_origin_check';

    if v_link_origin_def is null then
        raise exception 'R-26 FAIL: link_origin check missing';
    end if;

    if position('sync_bootstrap' in v_link_origin_def) > 0 then
        raise exception 'R-26 FAIL: sync_bootstrap still allowed in link_origin check';
    end if;

    if position('user_confirmed' in v_link_origin_def) = 0
       or position('persistent_account_identity' in v_link_origin_def) = 0
    then
        raise exception 'R-26 FAIL: expected A–E link_origin values missing: %',
            v_link_origin_def;
    end if;

    select pg_get_constraintdef(c.oid)
    into v_source_def
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'operations'
      and c.conname = 'operations_source_check';

    if v_source_def is null
       or position('plaid_internal_transfer' in v_source_def) > 0
       or position('''manual''' in v_source_def) = 0
       or position('''plaid''' in v_source_def) = 0
    then
        raise exception 'R-18/source FAIL: operations_source_check not restored: %',
            v_source_def;
    end if;

    -- R-27 no orphan canonical created by cleanup for empty membership-less rows
    -- that are still referenced by Stage E resolutions (must not exist).
    if exists (
        select 1
        from public.plaid_canonical_financial_accounts c
        where not exists (
            select 1
            from public.plaid_canonical_financial_account_members m
            where m.canonical_account_id = c.id
        )
        and exists (
            select 1
            from public.plaid_duplicate_operation_resolutions d
            where d.canonical_account_id = c.id
        )
    ) then
        raise exception 'R-27 FAIL: membership-less canonical still referenced by duplicate resolutions';
    end if;

    -- R-28 surviving historical memberships preserved:
    -- any unlinked membership must not be sync_bootstrap (already asserted),
    -- and user_confirmed historical rows (if any) remain readable.
    if exists (
        select 1
        from public.plaid_canonical_financial_account_members
        where link_origin not in ('user_confirmed', 'persistent_account_identity')
    ) then
        raise exception 'R-28 FAIL: unexpected link_origin values remain';
    end if;

    -- R-29 Stage A–E structural prerequisites intact
    if to_regclass('public.plaid_duplicate_operation_resolutions') is null then
        raise exception 'R-29 FAIL: Stage E resolutions table missing';
    end if;

    if not exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = 'plaid_link_canonical_financial_accounts'
    ) then
        raise exception 'R-29 FAIL: Stage C link RPC missing';
    end if;
end;
$$;

select 'REMOVE_INTERNAL_TRANSFER_PATH_VALIDATION_PASS'
  as remove_internal_transfer_path_validation_result;

rollback;
