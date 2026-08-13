-- Stage G: internal transfer confirmation foundation.
-- Backend confirm + reverse + source-sync freeze + consistency reconciliation +
-- Stage E protection + terminal reversed + immutable confirmation snapshot +
-- source plaid_internal_transfer. No confirm/reverse UI.
-- Does NOT modify Stage A–F migration files. Does NOT redesign remove-item.

-- ---------------------------------------------------------------------------
-- 1) operations.source: allow plaid_internal_transfer
-- ---------------------------------------------------------------------------

alter table public.operations
    drop constraint if exists operations_source_check;

alter table public.operations
    add constraint operations_source_check
    check (source in ('manual', 'plaid', 'plaid_internal_transfer'))
    not valid;

alter table public.operations
    validate constraint operations_source_check;

-- ---------------------------------------------------------------------------
-- 2) Reconciliation table: confirmation / reverse / inconsistency columns
-- ---------------------------------------------------------------------------

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists transfer_operation_id uuid null;

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists confirmed_at timestamptz null;

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists reversed_at timestamptz null;

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists confirmed_snapshot jsonb null;

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists inconsistent_at timestamptz null;

alter table public.plaid_internal_transfer_reconciliations
    add column if not exists inconsistency_code text null;

-- updated_at already exists from Stage F.

alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_internal_transfer_reconciliations_state_check;

alter table public.plaid_internal_transfer_reconciliations
    add constraint plaid_internal_transfer_reconciliations_state_check
    check (state in ('candidate', 'invalidated', 'confirmed', 'reversed'));

alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_internal_transfer_reconciliations_state_invalidated_at_ch;

alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_internal_transfer_reconciliations_state_invalidated_at_check;

alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_itr_lifecycle_check;

alter table public.plaid_internal_transfer_reconciliations
    add constraint plaid_itr_lifecycle_check
    check (
        (
            state = 'candidate'
            and transfer_operation_id is null
            and confirmed_at is null
            and reversed_at is null
            and confirmed_snapshot is null
            and inconsistent_at is null
            and inconsistency_code is null
            and invalidated_at is null
        )
        or (
            state = 'invalidated'
            and transfer_operation_id is null
            and confirmed_at is null
            and reversed_at is null
            and confirmed_snapshot is null
            and inconsistent_at is null
            and inconsistency_code is null
            and invalidated_at is not null
        )
        or (
            state = 'confirmed'
            and transfer_operation_id is not null
            and confirmed_at is not null
            and reversed_at is null
            and invalidated_at is null
            and confirmed_snapshot is not null
            and jsonb_typeof(confirmed_snapshot) = 'object'
            and (
                (inconsistent_at is null and inconsistency_code is null)
                or (inconsistent_at is not null and inconsistency_code is not null)
            )
        )
        or (
            state = 'reversed'
            and transfer_operation_id is not null
            and confirmed_at is not null
            and reversed_at is not null
            and invalidated_at is null
            and confirmed_snapshot is not null
            and jsonb_typeof(confirmed_snapshot) = 'object'
            and (
                (inconsistent_at is null and inconsistency_code is null)
                or (inconsistent_at is not null and inconsistency_code is not null)
            )
        )
    );

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
            'item_unavailable'
        )
    );

alter table public.plaid_internal_transfer_reconciliations
    drop constraint if exists plaid_itr_transfer_operation_user_fkey;

alter table public.plaid_internal_transfer_reconciliations
    add constraint plaid_itr_transfer_operation_user_fkey
    foreign key (transfer_operation_id, user_id)
    references public.operations(id, user_id)
    on delete restrict;

create unique index if not exists plaid_itr_transfer_operation_uidx
on public.plaid_internal_transfer_reconciliations(transfer_operation_id)
where transfer_operation_id is not null;

create unique index if not exists plaid_itr_confirmed_outgoing_projection_uidx
on public.plaid_internal_transfer_reconciliations(outgoing_projection_id)
where state = 'confirmed';

create unique index if not exists plaid_itr_confirmed_incoming_projection_uidx
on public.plaid_internal_transfer_reconciliations(incoming_projection_id)
where state = 'confirmed';

create index if not exists plaid_itr_confirmed_leg_outgoing_op_idx
on public.plaid_internal_transfer_reconciliations(user_id, outgoing_operation_id)
where state = 'confirmed';

create index if not exists plaid_itr_confirmed_leg_incoming_op_idx
on public.plaid_internal_transfer_reconciliations(user_id, incoming_operation_id)
where state = 'confirmed';

create index if not exists plaid_itr_user_confirmed_idx
on public.plaid_internal_transfer_reconciliations(user_id)
where state = 'confirmed';

comment on column public.plaid_internal_transfer_reconciliations.transfer_operation_id is
    'Stage G synthetic transfer Operation id. Set once on first confirm; never cleared or overwritten.';

comment on column public.plaid_internal_transfer_reconciliations.confirmed_snapshot is
    'Immutable financial/evidence truth captured at confirmation. Not refreshed after confirm.';

comment on column public.plaid_internal_transfer_reconciliations.inconsistency_code is
    'Highest-priority closed-set inconsistency reason while state=confirmed (or preserved on reverse).';

-- ---------------------------------------------------------------------------
-- 3) Helpers
-- ---------------------------------------------------------------------------

create or replace function public.plaid_operation_is_confirmed_internal_transfer_leg(
    p_user_id uuid,
    p_operation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.plaid_internal_transfer_reconciliations as reconciliation
        where reconciliation.user_id = p_user_id
          and reconciliation.state = 'confirmed'
          and (
              reconciliation.outgoing_operation_id = p_operation_id
              or reconciliation.incoming_operation_id = p_operation_id
          )
    );
$$;

revoke all on function public.plaid_operation_is_confirmed_internal_transfer_leg(uuid, uuid)
from public;
revoke all on function public.plaid_operation_is_confirmed_internal_transfer_leg(uuid, uuid)
from anon;
revoke all on function public.plaid_operation_is_confirmed_internal_transfer_leg(uuid, uuid)
from authenticated;
grant execute on function public.plaid_operation_is_confirmed_internal_transfer_leg(uuid, uuid)
to service_role;

create or replace function public.plaid_internal_transfer_pfc_allowlisted(
    p_version text,
    p_detailed text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select
        lower(nullif(btrim(coalesce(p_version, '')), '')) = 'v2'
        and upper(nullif(btrim(coalesce(p_detailed, '')), '')) in (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_IN_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_SAVINGS',
            'TRANSFER_IN_SAVINGS',
            'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        );
$$;

revoke all on function public.plaid_internal_transfer_pfc_allowlisted(text, text)
from public;
grant execute on function public.plaid_internal_transfer_pfc_allowlisted(text, text)
to service_role;


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

    v_pfc_ok := (
        public.plaid_internal_transfer_pfc_allowlisted(
            v_out_raw.personal_finance_category_version,
            v_out_raw.personal_finance_category_detailed
        )
        or public.plaid_internal_transfer_pfc_allowlisted(
            v_in_raw.personal_finance_category_version,
            v_in_raw.personal_finance_category_detailed
        )
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

    -- Snapshot account ids are historical; require current authoritative mapping
    -- still resolves to the same canonicals already checked above.
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

create or replace function public.plaid_reconcile_confirmed_internal_transfers_for_user(
    p_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_row public.plaid_internal_transfer_reconciliations%rowtype;
    v_code text;
    v_checked integer := 0;
    v_marked integer := 0;
    v_cleared integer := 0;
    v_now timestamptz := now();
begin
    if p_user_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        872514002,
        pg_catalog.hashtext(p_user_id::text)
    );

    for v_row in
        select *
        from public.plaid_internal_transfer_reconciliations
        where user_id = p_user_id
          and state = 'confirmed'
        order by id
        for update
    loop
        v_checked := v_checked + 1;
        v_code := public.plaid_confirmed_internal_transfer_inconsistency_code(
            p_user_id,
            v_row.id
        );

        if v_code is null then
            if v_row.inconsistent_at is not null or v_row.inconsistency_code is not null then
                update public.plaid_internal_transfer_reconciliations
                set
                    inconsistent_at = null,
                    inconsistency_code = null,
                    updated_at = v_now
                where id = v_row.id
                  and user_id = p_user_id
                  and state = 'confirmed';
                v_cleared := v_cleared + 1;
            end if;
        else
            if v_row.inconsistency_code is distinct from v_code
               or v_row.inconsistent_at is null
            then
                update public.plaid_internal_transfer_reconciliations
                set
                    inconsistent_at = coalesce(v_row.inconsistent_at, v_now),
                    inconsistency_code = v_code,
                    updated_at = v_now
                where id = v_row.id
                  and user_id = p_user_id
                  and state = 'confirmed';
                v_marked := v_marked + 1;
            end if;
        end if;
    end loop;

    return jsonb_build_object(
        'status', 'processed',
        'checked', v_checked,
        'marked_inconsistent', v_marked,
        'cleared', v_cleared
    );
end;
$$;

revoke all on function public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)
from public;
revoke all on function public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)
from anon;
revoke all on function public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)
from authenticated;
grant execute on function public.plaid_reconcile_confirmed_internal_transfers_for_user(uuid)
to service_role;


-- ---------------------------------------------------------------------------
-- 4) Confirm / Reverse RPCs
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
    v_out_cur text;
    v_in_cur text;
    v_amount numeric(14, 2);
    v_currency char(3);
    v_transfer_id uuid;
    v_now timestamptz := now();
    v_snapshot jsonb;
    v_date_ok boolean;
    v_pfc_ok boolean;
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

    -- Reload legs in outgoing/incoming roles under locks.
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

    -- Prefer authoritative account ids from membership role rows.
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
    v_pfc_ok := (
        public.plaid_internal_transfer_pfc_allowlisted(
            v_out_raw.personal_finance_category_version,
            v_out_raw.personal_finance_category_detailed
        )
        or public.plaid_internal_transfer_pfc_allowlisted(
            v_in_raw.personal_finance_category_version,
            v_in_raw.personal_finance_category_detailed
        )
    );

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

    -- Bijective uniqueness: each stored leg still has exactly one complementary eligible partner,
    -- and that partner is the other stored projection.
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
          and (
              public.plaid_internal_transfer_pfc_allowlisted(
                  v_out_raw.personal_finance_category_version,
                  v_out_raw.personal_finance_category_detailed
              )
              or public.plaid_internal_transfer_pfc_allowlisted(
                  r2.personal_finance_category_version,
                  r2.personal_finance_category_detailed
              )
          )
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
          and (
              public.plaid_internal_transfer_pfc_allowlisted(
                  v_in_raw.personal_finance_category_version,
                  v_in_raw.personal_finance_category_detailed
              )
              or public.plaid_internal_transfer_pfc_allowlisted(
                  r2.personal_finance_category_version,
                  r2.personal_finance_category_detailed
              )
          )
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

create or replace function public.plaid_reverse_internal_transfer_resolution(
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
    v_transfer public.operations%rowtype;
    v_now timestamptz := now();
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

    if v_row.state = 'reversed' then
        return jsonb_build_object(
            'status', 'already_reversed',
            'reconciliation_id', v_row.id,
            'transfer_operation_id', v_row.transfer_operation_id
        );
    end if;

    if v_row.state is distinct from 'confirmed' then
        raise exception 'invalid_state' using errcode = '22023';
    end if;

    select *
    into v_transfer
    from public.operations
    where id = v_row.transfer_operation_id
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'transfer_operation_not_found' using errcode = '22023';
    end if;

    if v_transfer.archived_at is null then
        update public.operations
        set archived_at = v_now
        where id = v_transfer.id
          and user_id = p_user_id
          and source = 'plaid_internal_transfer'
          and archived_at is null;
    end if;

    update public.plaid_internal_transfer_reconciliations
    set
        state = 'reversed',
        reversed_at = v_now,
        updated_at = v_now
    where id = v_row.id
      and user_id = p_user_id
      and state = 'confirmed';

    return jsonb_build_object(
        'status', 'reversed',
        'reconciliation_id', v_row.id,
        'transfer_operation_id', v_row.transfer_operation_id
    );
end;
$$;

revoke all on function public.plaid_reverse_internal_transfer_resolution(uuid, uuid)
from public;
revoke all on function public.plaid_reverse_internal_transfer_resolution(uuid, uuid)
from anon;
revoke all on function public.plaid_reverse_internal_transfer_resolution(uuid, uuid)
from authenticated;
grant execute on function public.plaid_reverse_internal_transfer_resolution(uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 5) Stage F detector (state-aware REPLACE)
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

    -- Serialize Stage F per user. Namespace 872514001 = Stage F ITR.
    perform pg_catalog.pg_advisory_xact_lock(
        872514001,
        pg_catalog.hashtext(p_user_id::text)
    );

    -- Lock existing reconciliation rows for this user in stable order.
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
        pfc_confidence text null,
        allowlisted boolean not null
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

    -- Eligible legs: authoritative active canonical membership required.
    -- Currency v1: both sides must have non-null non-empty iso_currency_code later;
    -- store normalized ISO here and skip legs without ISO.
    insert into pg_temp.plaid_itr_eligible_legs (
        projection_id,
        operation_id,
        account_id,
        canonical_account_id,
        amount,
        abs_amount,
        direction,
        currency_code,
        txn_date,
        authorized_date,
        pfc_version,
        pfc_primary,
        pfc_detailed,
        pfc_confidence,
        allowlisted
    )
    select
        projection.id,
        operations.id,
        raw.account_id,
        members.canonical_account_id,
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
        nullif(btrim(coalesce(raw.personal_finance_category_confidence_level, '')), ''),
        (
            lower(nullif(btrim(coalesce(raw.personal_finance_category_version, '')), '')) = 'v2'
            and upper(nullif(btrim(coalesce(raw.personal_finance_category_detailed, '')), '')) in (
                'TRANSFER_OUT_ACCOUNT_TRANSFER',
                'TRANSFER_IN_ACCOUNT_TRANSFER',
                'TRANSFER_OUT_SAVINGS',
                'TRANSFER_IN_SAVINGS',
                'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
            )
        ) as allowlisted
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

    -- All amount/currency/date/canonical-compatible directed edges (not yet bijective).
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
     and (outgoing.allowlisted or incoming.allowlisted);

    -- Bijective uniqueness: each side has exactly one complementary edge.
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
            'policy_version', 'stage_f_v1',
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

    -- Invalidate active candidates that are no longer bijective-eligible.
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

    -- Insert / reactivate / refresh stable rows for current bijective pairs.
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
            -- Stage G: confirmed/reversed are terminal for detector mutation.
            -- Never refresh evidence; never reactivate reversed → candidate.
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

-- ---------------------------------------------------------------------------
-- 6) Stage E resolve gate (REPLACE)
-- ---------------------------------------------------------------------------

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

    if public.plaid_operation_is_confirmed_internal_transfer_leg(p_user_id, p_kept_operation_id)
       or public.plaid_operation_is_confirmed_internal_transfer_leg(p_user_id, p_suppressed_operation_id)
    then
        raise exception 'confirmed_internal_transfer_leg' using errcode = '22023';
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

-- ---------------------------------------------------------------------------
-- 7) Source-sync freeze + consistency (REPLACE)
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
              (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
              and operations.archived_at is null
          )
          or (
              raw.removed_at is null
              and raw.pending = false
              and raw.amount <> 0
              and not (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
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

          or (
              public.plaid_operation_is_confirmed_internal_transfer_leg(
                  operations.user_id,
                  operations.id
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
            when (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id)) then
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
            not (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
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
                or (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
            )
            and operations.archived_at is null
        ) as archive_needed,
        (
            not (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.archived_at is not null
        ) as unarchive_needed,
        (
            not (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
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

    perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);

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
                  (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
                  and operations.archived_at is null
              )
              or (
                  raw.removed_at is null
                  and raw.pending = false
                  and raw.amount <> 0
                  and not (exists (select 1 from public.plaid_duplicate_operation_resolutions resolution where resolution.suppressed_operation_id = operations.id and resolution.user_id = operations.user_id and resolution.reversed_at is null) or public.plaid_operation_is_confirmed_internal_transfer_leg(operations.user_id, operations.id))
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

-- ---------------------------------------------------------------------------
-- 8) Canonical link C1 hook (REPLACE)
-- ---------------------------------------------------------------------------

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

        perform public.plaid_reconcile_confirmed_internal_transfers_for_user(p_user_id);
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
