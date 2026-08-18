-- Identity foundation P4: residual Plaid account identity backfill capability.
-- Additive only. Reuses P2 ensure + P3 reconcile. No identity semantics rewrite.
-- Migration apply creates RPC/grants ONLY — does NOT mutate existing accounts.
-- Applied Stage A–G / H1 / P1 / F-hardening / P2 / P3 migration files are not edited.

-- ---------------------------------------------------------------------------
-- Controlled per-user bounded backfill RPC (operator-invoked; not auto-run)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_backfill_account_identity(
    p_user_id uuid,
    p_limit integer default 50,
    p_after_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_limit integer;
    v_account_id uuid;
    v_ensure jsonb;
    v_reconcile jsonb;
    v_ensure_status text;
    v_reconcile_status text;
    v_processed integer := 0;
    v_ensure_created integer := 0;
    v_ensure_already_membered integer := 0;
    v_reconciled integer := 0;
    v_already_reconciled integer := 0;
    v_not_applicable integer := 0;
    v_last_account_id uuid := null;
    v_has_more boolean := false;
begin
    if p_user_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_limit := coalesce(p_limit, 50);

    if v_limit <= 0 or v_limit > 100 then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    for v_account_id in
        select accounts.id
        from public.accounts as accounts
        where accounts.user_id = p_user_id
          and accounts.plaid_account_id is not null
          and accounts.plaid_item_id is not null
          and (
              p_after_account_id is null
              or accounts.id > p_after_account_id
          )
        order by accounts.id
        limit v_limit
    loop
        v_ensure := public.plaid_ensure_account_identity(p_user_id, v_account_id);
        v_ensure_status := coalesce(v_ensure->>'status', '');

        if v_ensure_status = 'created' then
            v_ensure_created := v_ensure_created + 1;
        elsif v_ensure_status = 'already_membered' then
            v_ensure_already_membered := v_ensure_already_membered + 1;
        else
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        v_reconcile := public.plaid_reconcile_account_identity_by_pai(
            p_user_id,
            v_account_id
        );
        v_reconcile_status := coalesce(v_reconcile->>'status', '');

        if v_reconcile_status = 'reconciled' then
            v_reconciled := v_reconciled + 1;
        elsif v_reconcile_status = 'already_reconciled' then
            v_already_reconciled := v_already_reconciled + 1;
        elsif v_reconcile_status = 'not_applicable' then
            v_not_applicable := v_not_applicable + 1;
        else
            raise exception 'canonical_authority_invalid' using errcode = '22023';
        end if;

        v_processed := v_processed + 1;
        v_last_account_id := v_account_id;
    end loop;

    if v_last_account_id is not null then
        select exists (
            select 1
            from public.accounts as accounts
            where accounts.user_id = p_user_id
              and accounts.plaid_account_id is not null
              and accounts.plaid_item_id is not null
              and accounts.id > v_last_account_id
        )
        into v_has_more;
    else
        v_has_more := false;
    end if;

    return jsonb_build_object(
        'processed', v_processed,
        'ensure_created', v_ensure_created,
        'ensure_already_membered', v_ensure_already_membered,
        'reconciled', v_reconciled,
        'already_reconciled', v_already_reconciled,
        'not_applicable', v_not_applicable,
        'next_after_account_id', v_last_account_id,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_backfill_account_identity(uuid, integer, uuid) is
    'Identity P4: per-user bounded residual backfill via P2 ensure then P3 PAI reconcile. Operator-invoked only. Service-role only. No auto-run on migration apply.';

revoke all on function public.plaid_backfill_account_identity(uuid, integer, uuid) from public;
revoke all on function public.plaid_backfill_account_identity(uuid, integer, uuid) from anon;
revoke all on function public.plaid_backfill_account_identity(uuid, integer, uuid) from authenticated;
grant execute on function public.plaid_backfill_account_identity(uuid, integer, uuid) to service_role;
