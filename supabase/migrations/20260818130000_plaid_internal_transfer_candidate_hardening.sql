-- Stage F hardening (stage_f_v2): directional PFC + different non-null PAI proof.
-- Additive only. Applied Stage F/G / H1 / P1 migration files are not edited.
-- No data backfill (LIVE reconciliations = 0). No auto-confirm. No P2/P3.

-- ---------------------------------------------------------------------------
-- Shared hardened helpers (single source of truth for detector + confirm)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_internal_transfer_pfc_directional_compatible(
    p_outgoing_version text,
    p_outgoing_detailed text,
    p_incoming_version text,
    p_incoming_detailed text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select
        lower(nullif(btrim(coalesce(p_outgoing_version, '')), '')) = 'v2'
        and lower(nullif(btrim(coalesce(p_incoming_version, '')), '')) = 'v2'
        and (
            (
                upper(nullif(btrim(coalesce(p_outgoing_detailed, '')), ''))
                    = 'TRANSFER_OUT_ACCOUNT_TRANSFER'
                and upper(nullif(btrim(coalesce(p_incoming_detailed, '')), ''))
                    = 'TRANSFER_IN_ACCOUNT_TRANSFER'
            )
            or
            (
                upper(nullif(btrim(coalesce(p_outgoing_detailed, '')), ''))
                    = 'TRANSFER_OUT_SAVINGS'
                and upper(nullif(btrim(coalesce(p_incoming_detailed, '')), ''))
                    = 'TRANSFER_IN_SAVINGS'
            )
        );
$$;

comment on function public.plaid_internal_transfer_pfc_directional_compatible(
    text, text, text, text
) is
    'Stage F v2: both PFC v2 and complementary directional pair only (ACCOUNT_TRANSFER↔ACCOUNT_TRANSFER or SAVINGS↔SAVINGS). CC excluded. Not a one-side allowlist.';

revoke all on function public.plaid_internal_transfer_pfc_directional_compatible(
    text, text, text, text
) from public;
revoke all on function public.plaid_internal_transfer_pfc_directional_compatible(
    text, text, text, text
) from anon;
revoke all on function public.plaid_internal_transfer_pfc_directional_compatible(
    text, text, text, text
) from authenticated;
grant execute on function public.plaid_internal_transfer_pfc_directional_compatible(
    text, text, text, text
) to service_role;

create or replace function public.plaid_internal_transfer_pai_different_proven(
    p_outgoing_persistent_account_id text,
    p_incoming_persistent_account_id text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select
        p_outgoing_persistent_account_id is not null
        and p_incoming_persistent_account_id is not null
        and p_outgoing_persistent_account_id
            <> p_incoming_persistent_account_id;
$$;

comment on function public.plaid_internal_transfer_pai_different_proven(text, text) is
    'Stage F v2: DIFFERENT_ECONOMIC_ACCOUNTS_PROVEN via both non-null PAI and inequality. Same/null PAI is not proven different.';

revoke all on function public.plaid_internal_transfer_pai_different_proven(text, text)
from public;
revoke all on function public.plaid_internal_transfer_pai_different_proven(text, text)
from anon;
revoke all on function public.plaid_internal_transfer_pai_different_proven(text, text)
from authenticated;
grant execute on function public.plaid_internal_transfer_pai_different_proven(text, text)
to service_role;

-- Optional: keep legacy one-side allowlisted helper for historical reference,
-- but Stage F pair matching must not use it. Leave body unchanged; grants unchanged.

-- Extend inconsistency closed set for PAI audit signal (confirmed rows never unconfirmed).
alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_itr_inconsistency_code_check;

alter table public.plaid_internal_transfer_reconciliations
    add constraint plaid_itr_inconsistency_code_check
    check (
        inconsistency_code is null
        or inconsistency_code in (
            'leg_removed',
            'leg_pending',
            'projection_not_posted',
            'operation_relation_broken',
            'stage_e_suppressed',
            'membership_missing',
            'authoritative_role_lost',
            'canonical_identity_changed',
            'same_canonical',
            'amount_mismatch',
            'currency_mismatch',
            'sign_broken',
            'pair_abs_mismatch',
            'date_policy_broken',
            'pfc_policy_broken',
            'economic_identity_unproven',
            'item_unavailable'
        )
    );

-- ---------------------------------------------------------------------------
-- Confirmed inconsistency helper: directional PFC + PAI (audit only)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_confirmed_internal_transfer_inconsistency_code(
    p_user_id uuid,
    p_reconciliation_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_row public.plaid_internal_transfer_reconciliations%rowtype;
    v_out_proj public.plaid_transaction_operation_projections%rowtype;
    v_in_proj public.plaid_transaction_operation_projections%rowtype;
    v_out_raw public.plaid_transactions%rowtype;
    v_in_raw public.plaid_transactions%rowtype;
    v_out_canonical uuid;
    v_in_canonical uuid;
    v_out_role text;
    v_in_role text;
    v_out_pai text;
    v_in_pai text;
    v_snap jsonb;
    v_out_amt numeric;
    v_in_amt numeric;
    v_out_cur text;
    v_in_cur text;
    v_date_ok boolean;
    v_pfc_ok boolean;
begin
    if p_user_id is null or p_reconciliation_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_row
    from public.plaid_internal_transfer_reconciliations
    where id = p_reconciliation_id
      and user_id = p_user_id
      and state = 'confirmed';

    if not found then
        return null;
    end if;

    v_snap := v_row.confirmed_snapshot;

    select * into v_out_proj
    from public.plaid_transaction_operation_projections
    where id = v_row.outgoing_projection_id
      and user_id = p_user_id;

    if not found then
        return 'operation_relation_broken';
    end if;

    select * into v_in_proj
    from public.plaid_transaction_operation_projections
    where id = v_row.incoming_projection_id
      and user_id = p_user_id;

    if not found then
        return 'operation_relation_broken';
    end if;

    select * into v_out_raw
    from public.plaid_transactions
    where plaid_item_id = v_out_proj.plaid_item_id
      and transaction_id = v_out_proj.plaid_transaction_id
      and user_id = p_user_id;

    if not found then
        return 'operation_relation_broken';
    end if;

    select * into v_in_raw
    from public.plaid_transactions
    where plaid_item_id = v_in_proj.plaid_item_id
      and transaction_id = v_in_proj.plaid_transaction_id
      and user_id = p_user_id;

    if not found then
        return 'operation_relation_broken';
    end if;

    if v_out_raw.removed_at is not null or v_in_raw.removed_at is not null then
        return 'leg_removed';
    end if;

    if v_out_raw.pending is true or v_in_raw.pending is true then
        return 'leg_pending';
    end if;

    if v_out_proj.state is distinct from 'posted_projected'
       or v_in_proj.state is distinct from 'posted_projected'
    then
        return 'projection_not_posted';
    end if;

    if v_out_proj.operation_id is distinct from v_row.outgoing_operation_id
       or v_in_proj.operation_id is distinct from v_row.incoming_operation_id
    then
        return 'operation_relation_broken';
    end if;

    if not exists (
        select 1 from public.operations o
        where o.id = v_row.outgoing_operation_id and o.user_id = p_user_id and o.source = 'plaid'
    ) or not exists (
        select 1 from public.operations o
        where o.id = v_row.incoming_operation_id and o.user_id = p_user_id and o.source = 'plaid'
    ) then
        return 'operation_relation_broken';
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions resolution
        where resolution.user_id = p_user_id
          and resolution.reversed_at is null
          and resolution.suppressed_operation_id in (
              v_row.outgoing_operation_id,
              v_row.incoming_operation_id
          )
    ) then
        return 'stage_e_suppressed';
    end if;

    select members.canonical_account_id, members.role
    into v_out_canonical, v_out_role
    from public.plaid_canonical_financial_account_members as members
    where members.account_id = v_out_raw.account_id
      and members.user_id = p_user_id
      and members.unlinked_at is null;

    if v_out_canonical is null then
        return 'membership_missing';
    end if;

    select members.canonical_account_id, members.role
    into v_in_canonical, v_in_role
    from public.plaid_canonical_financial_account_members as members
    where members.account_id = v_in_raw.account_id
      and members.user_id = p_user_id
      and members.unlinked_at is null;

    if v_in_canonical is null then
        return 'membership_missing';
    end if;

    if v_out_role is distinct from 'authoritative'
       or v_in_role is distinct from 'authoritative'
    then
        return 'authoritative_role_lost';
    end if;

    if v_out_canonical is distinct from v_row.outgoing_canonical_account_id
       or v_in_canonical is distinct from v_row.incoming_canonical_account_id
       or v_out_canonical is distinct from (v_snap->>'outgoing_canonical_account_id')::uuid
       or v_in_canonical is distinct from (v_snap->>'incoming_canonical_account_id')::uuid
    then
        return 'canonical_identity_changed';
    end if;

    if v_out_canonical = v_in_canonical then
        return 'same_canonical';
    end if;

    select accounts.persistent_account_id
    into v_out_pai
    from public.accounts as accounts
    where accounts.id = v_out_raw.account_id
      and accounts.user_id = p_user_id;

    select accounts.persistent_account_id
    into v_in_pai
    from public.accounts as accounts
    where accounts.id = v_in_raw.account_id
      and accounts.user_id = p_user_id;

    if not public.plaid_internal_transfer_pai_different_proven(v_out_pai, v_in_pai) then
        return 'economic_identity_unproven';
    end if;

    v_out_amt := v_out_raw.amount;
    v_in_amt := v_in_raw.amount;

    if v_out_amt is distinct from (v_snap->>'outgoing_raw_amount')::numeric
       or v_in_amt is distinct from (v_snap->>'incoming_raw_amount')::numeric
       or abs(v_out_amt) is distinct from (v_snap->>'amount')::numeric
    then
        return 'amount_mismatch';
    end if;

    v_out_cur := upper(btrim(coalesce(v_out_raw.iso_currency_code, '')));
    v_in_cur := upper(btrim(coalesce(v_in_raw.iso_currency_code, '')));

    if v_out_cur = '' or v_in_cur = ''
       or v_out_cur is distinct from v_in_cur
       or v_out_cur is distinct from upper(btrim(coalesce(v_snap->>'currency', '')))
    then
        return 'currency_mismatch';
    end if;

    if v_out_amt <= 0 or v_in_amt >= 0 then
        return 'sign_broken';
    end if;

    if abs(v_out_amt) is distinct from abs(v_in_amt) then
        return 'pair_abs_mismatch';
    end if;

    v_date_ok := (
        v_out_raw.date = v_in_raw.date
        or (
            v_out_raw.authorized_date is not null
            and v_in_raw.authorized_date is not null
            and v_out_raw.authorized_date = v_in_raw.authorized_date
        )
    );
    if not v_date_ok
       or v_out_raw.date is distinct from (v_snap->>'outgoing_date')::date
       or v_in_raw.date is distinct from (v_snap->>'incoming_date')::date
    then
        return 'date_policy_broken';
    end if;

    v_pfc_ok := public.plaid_internal_transfer_pfc_directional_compatible(
        v_out_raw.personal_finance_category_version,
        v_out_raw.personal_finance_category_detailed,
        v_in_raw.personal_finance_category_version,
        v_in_raw.personal_finance_category_detailed
    );
    if not v_pfc_ok then
        return 'pfc_policy_broken';
    end if;

    if not exists (
        select 1 from public.plaid_items i
        where i.id = v_out_proj.plaid_item_id and i.user_id = p_user_id
    ) or not exists (
        select 1 from public.plaid_items i
        where i.id = v_in_proj.plaid_item_id and i.user_id = p_user_id
    ) then
        return 'item_unavailable';
    end if;

    if (v_snap->>'outgoing_account_id')::uuid is distinct from (
           select m.account_id
           from public.plaid_canonical_financial_account_members m
           where m.canonical_account_id = v_out_canonical
             and m.user_id = p_user_id
             and m.unlinked_at is null
             and m.role = 'authoritative'
           limit 1
       )
       or (v_snap->>'incoming_account_id')::uuid is distinct from (
           select m.account_id
           from public.plaid_canonical_financial_account_members m
           where m.canonical_account_id = v_in_canonical
             and m.user_id = p_user_id
             and m.unlinked_at is null
             and m.role = 'authoritative'
           limit 1
       )
    then
        return 'canonical_identity_changed';
    end if;

    return null;
end;
$$;

revoke all on function public.plaid_confirmed_internal_transfer_inconsistency_code(uuid, uuid)
from public;
revoke all on function public.plaid_confirmed_internal_transfer_inconsistency_code(uuid, uuid)
from anon;
revoke all on function public.plaid_confirmed_internal_transfer_inconsistency_code(uuid, uuid)
from authenticated;
grant execute on function public.plaid_confirmed_internal_transfer_inconsistency_code(uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- Confirm RPC: hardened revalidation (Stage G mutation order unchanged)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_confirm_internal_transfer_candidate(
    p_user_id uuid,
    p_reconciliation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_row public.plaid_internal_transfer_reconciliations%rowtype;
    v_out_proj public.plaid_transaction_operation_projections%rowtype;
    v_in_proj public.plaid_transaction_operation_projections%rowtype;
    v_out_raw public.plaid_transactions%rowtype;
    v_in_raw public.plaid_transactions%rowtype;
    v_out_op public.operations%rowtype;
    v_in_op public.operations%rowtype;
    v_lock_op_1 uuid;
    v_lock_op_2 uuid;
    v_out_canonical uuid;
    v_in_canonical uuid;
    v_out_auth_account uuid;
    v_in_auth_account uuid;
    v_out_pai text;
    v_in_pai text;
    v_out_cur text;
    v_in_cur text;
    v_amount numeric(14, 2);
    v_currency char(3);
    v_transfer_id uuid;
    v_now timestamptz := now();
    v_snapshot jsonb;
    v_date_ok boolean;
    v_pfc_ok boolean;
    v_pai_ok boolean;
    v_other_count integer;
    v_updated integer;
begin
    if p_user_id is null or p_reconciliation_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        872514002,
        pg_catalog.hashtext(p_user_id::text)
    );

    select *
    into v_row
    from public.plaid_internal_transfer_reconciliations
    where id = p_reconciliation_id
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'reconciliation_not_found' using errcode = '22023';
    end if;

    if v_row.state = 'confirmed' then
        return jsonb_build_object(
            'status', 'already_confirmed',
            'reconciliation_id', v_row.id,
            'transfer_operation_id', v_row.transfer_operation_id
        );
    end if;

    if v_row.state = 'reversed' then
        raise exception 'reversed' using errcode = '22023';
    end if;

    if v_row.state = 'invalidated' then
        raise exception 'invalid_state' using errcode = '22023';
    end if;

    if v_row.state is distinct from 'candidate' then
        raise exception 'invalid_state' using errcode = '22023';
    end if;

    v_lock_op_1 := least(v_row.outgoing_operation_id, v_row.incoming_operation_id);
    v_lock_op_2 := greatest(v_row.outgoing_operation_id, v_row.incoming_operation_id);

    select * into v_out_op
    from public.operations
    where id = v_lock_op_1 and user_id = p_user_id
    for update;
    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select * into v_in_op
    from public.operations
    where id = v_lock_op_2 and user_id = p_user_id
    for update;
    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select * into v_out_op
    from public.operations
    where id = v_row.outgoing_operation_id and user_id = p_user_id;
    select * into v_in_op
    from public.operations
    where id = v_row.incoming_operation_id and user_id = p_user_id;

    select * into v_out_proj
    from public.plaid_transaction_operation_projections
    where id = v_row.outgoing_projection_id and user_id = p_user_id;
    if not found then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    select * into v_in_proj
    from public.plaid_transaction_operation_projections
    where id = v_row.incoming_projection_id and user_id = p_user_id;
    if not found then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    select * into v_out_raw
    from public.plaid_transactions
    where plaid_item_id = v_out_proj.plaid_item_id
      and transaction_id = v_out_proj.plaid_transaction_id
      and user_id = p_user_id;
    if not found then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    select * into v_in_raw
    from public.plaid_transactions
    where plaid_item_id = v_in_proj.plaid_item_id
      and transaction_id = v_in_proj.plaid_transaction_id
      and user_id = p_user_id;
    if not found then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    if v_out_proj.state is distinct from 'posted_projected'
       or v_in_proj.state is distinct from 'posted_projected'
       or v_out_proj.operation_id is distinct from v_row.outgoing_operation_id
       or v_in_proj.operation_id is distinct from v_row.incoming_operation_id
       or v_out_raw.pending is distinct from false
       or v_in_raw.pending is distinct from false
       or v_out_raw.removed_at is not null
       or v_in_raw.removed_at is not null
       or v_out_raw.amount = 0
       or v_in_raw.amount = 0
       or v_out_op.source is distinct from 'plaid'
       or v_in_op.source is distinct from 'plaid'
       or v_out_op.archived_at is not null
       or v_in_op.archived_at is not null
       or exists (
           select 1 from public.plaid_duplicate_operation_resolutions r
           where r.user_id = p_user_id
             and r.reversed_at is null
             and r.suppressed_operation_id in (v_out_op.id, v_in_op.id)
       )
    then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    select members.canonical_account_id, members.account_id
    into v_out_canonical, v_out_auth_account
    from public.plaid_canonical_financial_account_members as members
    where members.account_id = v_out_raw.account_id
      and members.user_id = p_user_id
      and members.unlinked_at is null
      and members.role = 'authoritative';

    select members.canonical_account_id, members.account_id
    into v_in_canonical, v_in_auth_account
    from public.plaid_canonical_financial_account_members as members
    where members.account_id = v_in_raw.account_id
      and members.user_id = p_user_id
      and members.unlinked_at is null
      and members.role = 'authoritative';

    select m.account_id into v_out_auth_account
    from public.plaid_canonical_financial_account_members m
    where m.canonical_account_id = v_out_canonical
      and m.user_id = p_user_id
      and m.unlinked_at is null
      and m.role = 'authoritative';

    select m.account_id into v_in_auth_account
    from public.plaid_canonical_financial_account_members m
    where m.canonical_account_id = v_in_canonical
      and m.user_id = p_user_id
      and m.unlinked_at is null
      and m.role = 'authoritative';

    select accounts.persistent_account_id
    into v_out_pai
    from public.accounts as accounts
    where accounts.id = v_out_raw.account_id
      and accounts.user_id = p_user_id;

    select accounts.persistent_account_id
    into v_in_pai
    from public.accounts as accounts
    where accounts.id = v_in_raw.account_id
      and accounts.user_id = p_user_id;

    v_out_cur := upper(btrim(coalesce(v_out_raw.iso_currency_code, '')));
    v_in_cur := upper(btrim(coalesce(v_in_raw.iso_currency_code, '')));
    v_date_ok := (
        v_out_raw.date = v_in_raw.date
        or (
            v_out_raw.authorized_date is not null
            and v_in_raw.authorized_date is not null
            and v_out_raw.authorized_date = v_in_raw.authorized_date
        )
    );
    v_pfc_ok := public.plaid_internal_transfer_pfc_directional_compatible(
        v_out_raw.personal_finance_category_version,
        v_out_raw.personal_finance_category_detailed,
        v_in_raw.personal_finance_category_version,
        v_in_raw.personal_finance_category_detailed
    );
    v_pai_ok := public.plaid_internal_transfer_pai_different_proven(v_out_pai, v_in_pai);

    select count(*)::integer into v_other_count
    from public.plaid_internal_transfer_reconciliations r
    where r.user_id = p_user_id
      and r.state = 'confirmed'
      and r.id <> v_row.id
      and (
          r.outgoing_projection_id in (v_row.outgoing_projection_id, v_row.incoming_projection_id)
          or r.incoming_projection_id in (v_row.outgoing_projection_id, v_row.incoming_projection_id)
      );

    if v_out_canonical is null
       or v_in_canonical is null
       or v_out_auth_account is null
       or v_in_auth_account is null
       or v_out_canonical is distinct from v_row.outgoing_canonical_account_id
       or v_in_canonical is distinct from v_row.incoming_canonical_account_id
       or v_out_canonical = v_in_canonical
       or v_out_raw.amount <= 0
       or v_in_raw.amount >= 0
       or abs(v_out_raw.amount) is distinct from abs(v_in_raw.amount)
       or v_out_cur = ''
       or v_in_cur = ''
       or v_out_cur is distinct from v_in_cur
       or not v_date_ok
       or not v_pfc_ok
       or not v_pai_ok
       or v_other_count > 0
       or v_out_auth_account = v_in_auth_account
    then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    -- Bijective uniqueness under HARDENED edges only.
    if (
        select count(*)::integer
        from public.plaid_transaction_operation_projections p2
        join public.plaid_transactions r2
          on r2.plaid_item_id = p2.plaid_item_id
         and r2.transaction_id = p2.plaid_transaction_id
         and r2.user_id = p2.user_id
        join public.operations o2
          on o2.id = p2.operation_id and o2.user_id = p2.user_id
        join public.plaid_canonical_financial_account_members m2
          on m2.account_id = r2.account_id
         and m2.user_id = r2.user_id
         and m2.unlinked_at is null
         and m2.role = 'authoritative'
        join public.accounts a2
          on a2.id = r2.account_id
         and a2.user_id = r2.user_id
        where p2.user_id = p_user_id
          and p2.state = 'posted_projected'
          and p2.operation_id is not null
          and r2.pending = false
          and r2.removed_at is null
          and r2.amount < 0
          and abs(r2.amount) = abs(v_out_raw.amount)
          and upper(btrim(coalesce(r2.iso_currency_code, ''))) = v_out_cur
          and m2.canonical_account_id <> v_out_canonical
          and o2.source = 'plaid'
          and o2.archived_at is null
          and (
              r2.date = v_out_raw.date
              or (
                  r2.authorized_date is not null
                  and v_out_raw.authorized_date is not null
                  and r2.authorized_date = v_out_raw.authorized_date
              )
          )
          and public.plaid_internal_transfer_pfc_directional_compatible(
              v_out_raw.personal_finance_category_version,
              v_out_raw.personal_finance_category_detailed,
              r2.personal_finance_category_version,
              r2.personal_finance_category_detailed
          )
          and public.plaid_internal_transfer_pai_different_proven(v_out_pai, a2.persistent_account_id)
          and not exists (
              select 1 from public.plaid_duplicate_operation_resolutions dr
              where dr.suppressed_operation_id = o2.id
                and dr.user_id = o2.user_id
                and dr.reversed_at is null
          )
    ) is distinct from 1
       or not exists (
        select 1
        from public.plaid_transaction_operation_projections p2
        join public.plaid_transactions r2
          on r2.plaid_item_id = p2.plaid_item_id
         and r2.transaction_id = p2.plaid_transaction_id
         and r2.user_id = p2.user_id
        where p2.id = v_row.incoming_projection_id
          and p2.user_id = p_user_id
          and r2.amount < 0
          and abs(r2.amount) = abs(v_out_raw.amount)
          and upper(btrim(coalesce(r2.iso_currency_code, ''))) = v_out_cur
    )
       or (
        select count(*)::integer
        from public.plaid_transaction_operation_projections p2
        join public.plaid_transactions r2
          on r2.plaid_item_id = p2.plaid_item_id
         and r2.transaction_id = p2.plaid_transaction_id
         and r2.user_id = p2.user_id
        join public.operations o2
          on o2.id = p2.operation_id and o2.user_id = p2.user_id
        join public.plaid_canonical_financial_account_members m2
          on m2.account_id = r2.account_id
         and m2.user_id = r2.user_id
         and m2.unlinked_at is null
         and m2.role = 'authoritative'
        join public.accounts a2
          on a2.id = r2.account_id
         and a2.user_id = r2.user_id
        where p2.user_id = p_user_id
          and p2.state = 'posted_projected'
          and p2.operation_id is not null
          and r2.pending = false
          and r2.removed_at is null
          and r2.amount > 0
          and abs(r2.amount) = abs(v_in_raw.amount)
          and upper(btrim(coalesce(r2.iso_currency_code, ''))) = v_in_cur
          and m2.canonical_account_id <> v_in_canonical
          and o2.source = 'plaid'
          and o2.archived_at is null
          and (
              r2.date = v_in_raw.date
              or (
                  r2.authorized_date is not null
                  and v_in_raw.authorized_date is not null
                  and r2.authorized_date = v_in_raw.authorized_date
              )
          )
          and public.plaid_internal_transfer_pfc_directional_compatible(
              r2.personal_finance_category_version,
              r2.personal_finance_category_detailed,
              v_in_raw.personal_finance_category_version,
              v_in_raw.personal_finance_category_detailed
          )
          and public.plaid_internal_transfer_pai_different_proven(a2.persistent_account_id, v_in_pai)
          and not exists (
              select 1 from public.plaid_duplicate_operation_resolutions dr
              where dr.suppressed_operation_id = o2.id
                and dr.user_id = o2.user_id
                and dr.reversed_at is null
          )
    ) is distinct from 1
       or not exists (
        select 1
        from public.plaid_transaction_operation_projections p2
        join public.plaid_transactions r2
          on r2.plaid_item_id = p2.plaid_item_id
         and r2.transaction_id = p2.plaid_transaction_id
         and r2.user_id = p2.user_id
        where p2.id = v_row.outgoing_projection_id
          and p2.user_id = p_user_id
          and r2.amount > 0
          and abs(r2.amount) = abs(v_in_raw.amount)
          and upper(btrim(coalesce(r2.iso_currency_code, ''))) = v_in_cur
    )
    then
        update public.plaid_internal_transfer_reconciliations
        set state = 'invalidated', invalidated_at = v_now, updated_at = v_now
        where id = v_row.id and user_id = p_user_id and state = 'candidate';
        return jsonb_build_object(
            'status', 'rejected',
            'reason', 'stale_candidate',
            'reconciliation_id', v_row.id
        );
    end if;

    v_amount := round(abs(v_out_raw.amount), 2)::numeric(14, 2);
    v_currency := v_out_cur::char(3);

    v_snapshot := jsonb_build_object(
        'amount', v_amount,
        'currency', v_currency,
        'outgoing_raw_amount', v_out_raw.amount,
        'incoming_raw_amount', v_in_raw.amount,
        'outgoing_date', v_out_raw.date,
        'incoming_date', v_in_raw.date,
        'match_reason', case
            when v_out_raw.date = v_in_raw.date then 'exact_date'
            else 'equal_authorized_date'
        end,
        'outgoing_account_id', v_out_auth_account,
        'incoming_account_id', v_in_auth_account,
        'outgoing_canonical_account_id', v_out_canonical,
        'incoming_canonical_account_id', v_in_canonical,
        'outgoing_pfc', jsonb_build_object(
            'version', nullif(btrim(coalesce(v_out_raw.personal_finance_category_version, '')), ''),
            'primary', nullif(btrim(coalesce(v_out_raw.personal_finance_category_primary, '')), ''),
            'detailed', nullif(btrim(coalesce(v_out_raw.personal_finance_category_detailed, '')), ''),
            'confidence', nullif(btrim(coalesce(v_out_raw.personal_finance_category_confidence_level, '')), '')
        ),
        'incoming_pfc', jsonb_build_object(
            'version', nullif(btrim(coalesce(v_in_raw.personal_finance_category_version, '')), ''),
            'primary', nullif(btrim(coalesce(v_in_raw.personal_finance_category_primary, '')), ''),
            'detailed', nullif(btrim(coalesce(v_in_raw.personal_finance_category_detailed, '')), ''),
            'confidence', nullif(btrim(coalesce(v_in_raw.personal_finance_category_confidence_level, '')), '')
        )
    );

    insert into public.operations (
        user_id,
        from_account_id,
        to_account_id,
        type,
        amount,
        currency_code,
        occurred_at,
        note,
        is_recurring,
        recurrence,
        archived_at,
        category_id,
        source,
        category_overridden
    ) values (
        p_user_id,
        v_out_auth_account,
        v_in_auth_account,
        'transfer',
        v_amount,
        v_currency,
        v_out_raw.date,
        null,
        false,
        'none',
        null,
        null,
        'plaid_internal_transfer',
        false
    )
    returning id into v_transfer_id;

    update public.operations
    set archived_at = v_now
    where id in (v_row.outgoing_operation_id, v_row.incoming_operation_id)
      and user_id = p_user_id
      and source = 'plaid'
      and archived_at is null;

    update public.plaid_internal_transfer_reconciliations
    set
        state = 'confirmed',
        transfer_operation_id = v_transfer_id,
        confirmed_at = v_now,
        confirmed_snapshot = v_snapshot,
        invalidated_at = null,
        inconsistent_at = null,
        inconsistency_code = null,
        reversed_at = null,
        updated_at = v_now
    where id = v_row.id
      and user_id = p_user_id
      and state = 'candidate'
      and transfer_operation_id is null;

    get diagnostics v_updated = row_count;
    if v_updated <> 1 then
        raise exception 'confirm_race' using errcode = '40001';
    end if;

    return jsonb_build_object(
        'status', 'confirmed',
        'reconciliation_id', v_row.id,
        'transfer_operation_id', v_transfer_id
    );
end;
$$;

revoke all on function public.plaid_confirm_internal_transfer_candidate(uuid, uuid)
from public;
revoke all on function public.plaid_confirm_internal_transfer_candidate(uuid, uuid)
from anon;
revoke all on function public.plaid_confirm_internal_transfer_candidate(uuid, uuid)
from authenticated;
grant execute on function public.plaid_confirm_internal_transfer_candidate(uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- Detector: hardened edges first, then bijectivity (policy_version stage_f_v2)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reconcile_internal_transfer_candidates_for_user(
    p_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_candidates_created integer := 0;
    v_candidates_reactivated integer := 0;
    v_candidates_invalidated integer := 0;
    v_candidates_unchanged integer := 0;
    v_candidates_active integer := 0;
    v_now timestamptz := now();
    v_pair record;
    v_existing public.plaid_internal_transfer_reconciliations%rowtype;
begin
    if p_user_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        872514001,
        pg_catalog.hashtext(p_user_id::text)
    );

    perform 1
    from public.plaid_internal_transfer_reconciliations as reconciliation
    where reconciliation.user_id = p_user_id
    order by reconciliation.outgoing_projection_id, reconciliation.incoming_projection_id
    for update;

    drop table if exists pg_temp.plaid_itr_eligible_legs;
    drop table if exists pg_temp.plaid_itr_pair_edges;
    drop table if exists pg_temp.plaid_itr_bijective_pairs;

    create temporary table pg_temp.plaid_itr_eligible_legs (
        projection_id uuid primary key,
        operation_id uuid not null,
        account_id uuid not null,
        canonical_account_id uuid not null,
        persistent_account_id text null,
        amount numeric not null,
        abs_amount numeric not null,
        direction text not null
            check (direction in ('outgoing', 'incoming')),
        currency_code text not null,
        txn_date date not null,
        authorized_date date null,
        pfc_version text null,
        pfc_primary text null,
        pfc_detailed text null,
        pfc_confidence text null
    ) on commit drop;

    create temporary table pg_temp.plaid_itr_pair_edges (
        outgoing_projection_id uuid not null,
        incoming_projection_id uuid not null,
        primary key (outgoing_projection_id, incoming_projection_id)
    ) on commit drop;

    create temporary table pg_temp.plaid_itr_bijective_pairs (
        outgoing_projection_id uuid not null,
        incoming_projection_id uuid not null,
        outgoing_operation_id uuid not null,
        incoming_operation_id uuid not null,
        outgoing_canonical_account_id uuid not null,
        incoming_canonical_account_id uuid not null,
        evidence_snapshot jsonb not null,
        primary key (outgoing_projection_id, incoming_projection_id)
    ) on commit drop;

    insert into pg_temp.plaid_itr_eligible_legs (
        projection_id,
        operation_id,
        account_id,
        canonical_account_id,
        persistent_account_id,
        amount,
        abs_amount,
        direction,
        currency_code,
        txn_date,
        authorized_date,
        pfc_version,
        pfc_primary,
        pfc_detailed,
        pfc_confidence
    )
    select
        projection.id,
        operations.id,
        raw.account_id,
        members.canonical_account_id,
        accounts.persistent_account_id,
        raw.amount,
        abs(raw.amount),
        case
            when raw.amount > 0 then 'outgoing'
            else 'incoming'
        end,
        upper(btrim(raw.iso_currency_code)),
        raw.date,
        raw.authorized_date,
        nullif(btrim(coalesce(raw.personal_finance_category_version, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_primary, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_detailed, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_confidence_level, '')), '')
    from public.plaid_transaction_operation_projections as projection
    join public.plaid_transactions as raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.operations as operations
      on operations.id = projection.operation_id
     and operations.user_id = projection.user_id
    join public.plaid_canonical_financial_account_members as members
      on members.account_id = raw.account_id
     and members.user_id = raw.user_id
     and members.unlinked_at is null
     and members.role = 'authoritative'
    join public.accounts as accounts
      on accounts.id = raw.account_id
     and accounts.user_id = raw.user_id
    where projection.user_id = p_user_id
      and projection.state = 'posted_projected'
      and projection.operation_id is not null
      and raw.pending = false
      and raw.removed_at is null
      and raw.amount <> 0
      and nullif(btrim(coalesce(raw.iso_currency_code, '')), '') is not null
      and operations.source = 'plaid'
      and operations.archived_at is null
      and not exists (
          select 1
          from public.plaid_duplicate_operation_resolutions as resolution
          where resolution.suppressed_operation_id = operations.id
            and resolution.user_id = operations.user_id
            and resolution.reversed_at is null
      )
      and not exists (
          select 1
          from public.plaid_internal_transfer_reconciliations as reconciliation
          where reconciliation.user_id = projection.user_id
            and reconciliation.state in ('confirmed', 'reversed')
            and (
                reconciliation.outgoing_projection_id = projection.id
                or reconciliation.incoming_projection_id = projection.id
                or reconciliation.outgoing_operation_id = operations.id
                or reconciliation.incoming_operation_id = operations.id
            )
      );

    -- HARDENED edges only (before bijectivity counts).
    insert into pg_temp.plaid_itr_pair_edges (
        outgoing_projection_id,
        incoming_projection_id
    )
    select
        outgoing.projection_id,
        incoming.projection_id
    from pg_temp.plaid_itr_eligible_legs as outgoing
    join pg_temp.plaid_itr_eligible_legs as incoming
      on incoming.direction = 'incoming'
     and outgoing.direction = 'outgoing'
     and incoming.abs_amount = outgoing.abs_amount
     and incoming.currency_code = outgoing.currency_code
     and incoming.canonical_account_id <> outgoing.canonical_account_id
     and (
         incoming.txn_date = outgoing.txn_date
         or (
             incoming.authorized_date is not null
             and outgoing.authorized_date is not null
             and incoming.authorized_date = outgoing.authorized_date
         )
     )
     and public.plaid_internal_transfer_pai_different_proven(
         outgoing.persistent_account_id,
         incoming.persistent_account_id
     )
     and public.plaid_internal_transfer_pfc_directional_compatible(
         outgoing.pfc_version,
         outgoing.pfc_detailed,
         incoming.pfc_version,
         incoming.pfc_detailed
     );

    insert into pg_temp.plaid_itr_bijective_pairs (
        outgoing_projection_id,
        incoming_projection_id,
        outgoing_operation_id,
        incoming_operation_id,
        outgoing_canonical_account_id,
        incoming_canonical_account_id,
        evidence_snapshot
    )
    select
        edges.outgoing_projection_id,
        edges.incoming_projection_id,
        outgoing.operation_id,
        incoming.operation_id,
        outgoing.canonical_account_id,
        incoming.canonical_account_id,
        jsonb_build_object(
            'policy_version', 'stage_f_v2',
            'match_reason', case
                when outgoing.txn_date = incoming.txn_date then 'exact_date'
                else 'equal_authorized_date'
            end,
            'outgoing', jsonb_build_object(
                'amount', outgoing.amount,
                'date', outgoing.txn_date,
                'authorized_date', outgoing.authorized_date,
                'iso_currency_code', outgoing.currency_code,
                'pfc_version', outgoing.pfc_version,
                'pfc_primary', outgoing.pfc_primary,
                'pfc_detailed', outgoing.pfc_detailed,
                'pfc_confidence', outgoing.pfc_confidence,
                'canonical_account_id', outgoing.canonical_account_id
            ),
            'incoming', jsonb_build_object(
                'amount', incoming.amount,
                'date', incoming.txn_date,
                'authorized_date', incoming.authorized_date,
                'iso_currency_code', incoming.currency_code,
                'pfc_version', incoming.pfc_version,
                'pfc_primary', incoming.pfc_primary,
                'pfc_detailed', incoming.pfc_detailed,
                'pfc_confidence', incoming.pfc_confidence,
                'canonical_account_id', incoming.canonical_account_id
            )
        )
    from pg_temp.plaid_itr_pair_edges as edges
    join pg_temp.plaid_itr_eligible_legs as outgoing
      on outgoing.projection_id = edges.outgoing_projection_id
    join pg_temp.plaid_itr_eligible_legs as incoming
      on incoming.projection_id = edges.incoming_projection_id
    where (
        select count(*)::integer
        from pg_temp.plaid_itr_pair_edges as out_edges
        where out_edges.outgoing_projection_id = edges.outgoing_projection_id
    ) = 1
      and (
        select count(*)::integer
        from pg_temp.plaid_itr_pair_edges as in_edges
        where in_edges.incoming_projection_id = edges.incoming_projection_id
    ) = 1;

    update public.plaid_internal_transfer_reconciliations as reconciliation
    set
        state = 'invalidated',
        invalidated_at = v_now,
        updated_at = v_now
    where reconciliation.user_id = p_user_id
      and reconciliation.state = 'candidate'
      and not exists (
          select 1
          from pg_temp.plaid_itr_bijective_pairs as pairs
          where pairs.outgoing_projection_id = reconciliation.outgoing_projection_id
            and pairs.incoming_projection_id = reconciliation.incoming_projection_id
      );

    get diagnostics v_candidates_invalidated = row_count;

    for v_pair in
        select *
        from pg_temp.plaid_itr_bijective_pairs
        order by outgoing_projection_id, incoming_projection_id
    loop
        select *
        into v_existing
        from public.plaid_internal_transfer_reconciliations as reconciliation
        where reconciliation.user_id = p_user_id
          and reconciliation.outgoing_projection_id = v_pair.outgoing_projection_id
          and reconciliation.incoming_projection_id = v_pair.incoming_projection_id;

        if not found then
            insert into public.plaid_internal_transfer_reconciliations (
                user_id,
                outgoing_projection_id,
                incoming_projection_id,
                outgoing_operation_id,
                incoming_operation_id,
                outgoing_canonical_account_id,
                incoming_canonical_account_id,
                state,
                evidence_snapshot,
                candidate_detected_at,
                last_detected_at,
                invalidated_at
            )
            values (
                p_user_id,
                v_pair.outgoing_projection_id,
                v_pair.incoming_projection_id,
                v_pair.outgoing_operation_id,
                v_pair.incoming_operation_id,
                v_pair.outgoing_canonical_account_id,
                v_pair.incoming_canonical_account_id,
                'candidate',
                v_pair.evidence_snapshot,
                v_now,
                v_now,
                null
            );
            v_candidates_created := v_candidates_created + 1;
        elsif v_existing.state in ('confirmed', 'reversed') then
            null;
        elsif v_existing.state = 'invalidated' then
            update public.plaid_internal_transfer_reconciliations as reconciliation
            set
                outgoing_operation_id = v_pair.outgoing_operation_id,
                incoming_operation_id = v_pair.incoming_operation_id,
                outgoing_canonical_account_id = v_pair.outgoing_canonical_account_id,
                incoming_canonical_account_id = v_pair.incoming_canonical_account_id,
                state = 'candidate',
                evidence_snapshot = v_pair.evidence_snapshot,
                last_detected_at = v_now,
                invalidated_at = null,
                updated_at = v_now
            where reconciliation.id = v_existing.id;
            v_candidates_reactivated := v_candidates_reactivated + 1;
        else
            update public.plaid_internal_transfer_reconciliations as reconciliation
            set
                outgoing_operation_id = v_pair.outgoing_operation_id,
                incoming_operation_id = v_pair.incoming_operation_id,
                outgoing_canonical_account_id = v_pair.outgoing_canonical_account_id,
                incoming_canonical_account_id = v_pair.incoming_canonical_account_id,
                evidence_snapshot = v_pair.evidence_snapshot,
                last_detected_at = v_now,
                updated_at = v_now
            where reconciliation.id = v_existing.id;
            v_candidates_unchanged := v_candidates_unchanged + 1;
        end if;
    end loop;

    select count(*)::integer
    into v_candidates_active
    from public.plaid_internal_transfer_reconciliations as reconciliation
    where reconciliation.user_id = p_user_id
      and reconciliation.state = 'candidate';

    return jsonb_build_object(
        'status', 'processed',
        'candidates_active', v_candidates_active,
        'candidates_created', v_candidates_created,
        'candidates_reactivated', v_candidates_reactivated,
        'candidates_invalidated', v_candidates_invalidated,
        'candidates_unchanged', v_candidates_unchanged
    );
end;
$$;

comment on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid) is
    'Stage F v2 hardened candidate reconcile: directional PFC + different non-null PAI + bijectivity on hardened edges only. Service-role only. Does not mutate Operations.';

revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from public;
revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from anon;
revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from authenticated;
grant execute on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
to service_role;
