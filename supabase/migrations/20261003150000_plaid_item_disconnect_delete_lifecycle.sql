-- Phase 2.3A Step 1: Plaid connection Disconnect / Delete lifecycle (database only).
-- Additive. Inert until a caller invokes plaid_disconnect_item_local or
-- plaid_delete_item_local: no existing Item is disconnected, so no canonical has
-- frozen authority and every gate below reduces to the previous behavior.
-- plaid_remove_item_local_cleanup is intentionally left unchanged.

-- ---------------------------------------------------------------------------
-- 1) Disconnected state
-- ---------------------------------------------------------------------------

alter table public.plaid_items
    add column disconnected_at timestamptz null;

alter table public.plaid_items
    alter column access_token_secret_id drop not null;

alter table public.plaid_items
    add constraint plaid_items_disconnected_token_consistency_check
        check ((disconnected_at is null) = (access_token_secret_id is not null));

comment on column public.plaid_items.disconnected_at is
    'When the user disconnected this Item. The Plaid Item was removed and the access token deleted; local financial history is retained. Anchor for a future retention lifecycle.';

comment on column public.plaid_items.access_token_secret_id is
    'Vault secret holding the Plaid access token. NULL exactly when the Item is disconnected.';

-- ---------------------------------------------------------------------------
-- 2) Canonical suppression gate
-- ---------------------------------------------------------------------------

-- Disconnect keeps canonical memberships. A canonical whose active authoritative
-- member belongs to a disconnected Item has frozen authority: its secondaries keep
-- the suppression they had before the Disconnect (canonical_secondary, sticky) and
-- every row classified afterwards is canonical_handoff_ambiguous. Without
-- cross-Item transaction identity such a row may be a late copy of an event the
-- frozen authority already materialized, or a new event; neither date nor arrival
-- time distinguishes the two, so it never materializes automatically. Delete of the
-- frozen authority removes its membership and releases both classes exactly once.

create or replace function public.plaid_raw_canonical_suppressed(
    p_user_id uuid,
    p_account_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
    select exists (
        select 1
        from public.plaid_canonical_financial_account_members members
        where members.account_id = p_account_id
          and members.user_id = p_user_id
          and members.role = 'secondary'
          and members.unlinked_at is null
    );
$$;

comment on function public.plaid_raw_canonical_suppressed(uuid, uuid) is
    'True when raw Plaid transactions of this account must not create new Operations: the account is an active secondary canonical member.';

revoke all on function public.plaid_raw_canonical_suppressed(uuid, uuid) from public;
revoke all on function public.plaid_raw_canonical_suppressed(uuid, uuid) from anon;
revoke all on function public.plaid_raw_canonical_suppressed(uuid, uuid) from authenticated;
grant execute on function public.plaid_raw_canonical_suppressed(uuid, uuid) to service_role;

create or replace function public.plaid_canonical_suppression_reason(
    p_user_id uuid,
    p_account_id uuid,
    p_current_reason text
)
returns text
language sql
stable
set search_path = ''
as $$
    select case
        when not public.plaid_raw_canonical_suppressed(p_user_id, p_account_id) then null
        when p_current_reason = 'canonical_secondary' then 'canonical_secondary'
        when exists (
            select 1
            from public.plaid_canonical_financial_account_members secondary_member
            join public.plaid_canonical_financial_account_members authority
              on authority.canonical_account_id = secondary_member.canonical_account_id
             and authority.user_id = secondary_member.user_id
             and authority.role = 'authoritative'
             and authority.unlinked_at is null
            join public.accounts authority_account
              on authority_account.id = authority.account_id
             and authority_account.user_id = authority.user_id
            join public.plaid_items authority_item
              on authority_item.id = authority_account.plaid_item_id
             and authority_item.user_id = authority_account.user_id
            where secondary_member.account_id = p_account_id
              and secondary_member.user_id = p_user_id
              and secondary_member.role = 'secondary'
              and secondary_member.unlinked_at is null
              and authority_item.disconnected_at is not null
        ) then 'canonical_handoff_ambiguous'
        else 'canonical_secondary'
    end;
$$;

comment on function public.plaid_canonical_suppression_reason(uuid, uuid, text) is
    'suppressed_reason for a raw row without an Operation on this account, given the projection''s current reason: NULL when the account is not an active secondary; canonical_secondary when the authority is live or the row was already canonical_secondary (sticky across a Disconnect of the authority); canonical_handoff_ambiguous when the authority belongs to a disconnected Item.';

revoke all on function public.plaid_canonical_suppression_reason(uuid, uuid, text) from public;
revoke all on function public.plaid_canonical_suppression_reason(uuid, uuid, text) from anon;
revoke all on function public.plaid_canonical_suppression_reason(uuid, uuid, text) from authenticated;
grant execute on function public.plaid_canonical_suppression_reason(uuid, uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 3) Reconcile: canonical suppression through plaid_canonical_suppression_reason
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reconcile_transaction_operation_projections(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_batch_size integer default 250
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_job public.plaid_transaction_projection_jobs%rowtype;
    v_processed integer := 0;
    v_raw_pending integer := 0;
    v_posted_ready integer := 0;
    v_removed_inactive integer := 0;
    v_links_updated integer := 0;
    v_has_more boolean := false;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_lease_token is null
       or p_batch_size is null
       or p_batch_size < 1
       or p_batch_size > 500
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

    drop table if exists pg_temp.plaid_projection_reconcile_batch;

    create temporary table pg_temp.plaid_projection_reconcile_batch (
        user_id uuid not null,
        plaid_item_id uuid not null,
        plaid_transaction_id text not null,
        pending_transaction_id text null,
        expected_state text not null,
        expected_suppressed_reason text null,
        expected_replaced_pending_projection_id uuid null
    ) on commit drop;

    insert into pg_temp.plaid_projection_reconcile_batch (
        user_id,
        plaid_item_id,
        plaid_transaction_id,
        pending_transaction_id,
        expected_state,
        expected_suppressed_reason,
        expected_replaced_pending_projection_id
    )
    select
        raw.user_id,
        raw.plaid_item_id,
        raw.transaction_id,
        raw.pending_transaction_id,
        case
            when raw.removed_at is not null then 'removed_inactive'
            when raw.pending then 'raw_pending'
            when projection.operation_id is not null then 'posted_projected'
            when canonical_gate.reason is not null then 'suppressed'
            else 'posted_ready'
        end as expected_state,
        case
            when raw.removed_at is not null then null
            when raw.pending then null
            when projection.operation_id is not null then null
            when canonical_gate.reason is not null then canonical_gate.reason
            else null
        end as expected_suppressed_reason,
        pending_projection.id as expected_replaced_pending_projection_id
    from public.plaid_transactions raw
    left join public.plaid_transaction_operation_projections projection
      on projection.plaid_item_id = raw.plaid_item_id
     and projection.plaid_transaction_id = raw.transaction_id
    left join public.plaid_transaction_operation_projections pending_projection
      on pending_projection.plaid_item_id = raw.plaid_item_id
     and pending_projection.plaid_transaction_id = raw.pending_transaction_id
     and raw.pending_transaction_id is not null
    cross join lateral (
        select public.plaid_canonical_suppression_reason(
            raw.user_id, raw.account_id, projection.suppressed_reason
        ) as reason
    ) canonical_gate
    where raw.user_id = p_user_id
      and raw.plaid_item_id = p_plaid_item_id
      and (
          projection.id is null
          or projection.state is distinct from case
              when raw.removed_at is not null then 'removed_inactive'
              when raw.pending then 'raw_pending'
              when projection.operation_id is not null then 'posted_projected'
              when canonical_gate.reason is not null then 'suppressed'
              else 'posted_ready'
          end
          or projection.suppressed_reason is distinct from case
              when raw.removed_at is not null then null
              when raw.pending then null
              when projection.operation_id is not null then null
              when canonical_gate.reason is not null then canonical_gate.reason
              else null
          end
          or projection.pending_transaction_id is distinct from raw.pending_transaction_id
          or (
              raw.pending = false
              and raw.removed_at is null
              and projection.replaced_pending_projection_id is distinct from pending_projection.id
          )
      )
    order by raw.date, raw.transaction_id
    limit v_batch_size;

    select count(*)
    into v_processed
    from pg_temp.plaid_projection_reconcile_batch;

    insert into public.plaid_transaction_operation_projections (
        user_id,
        plaid_item_id,
        plaid_transaction_id,
        pending_transaction_id,
        replaced_pending_projection_id,
        state,
        last_error_code,
        last_error_at,
        suppressed_reason
    )
    select
        batch.user_id,
        batch.plaid_item_id,
        batch.plaid_transaction_id,
        batch.pending_transaction_id,
        batch.expected_replaced_pending_projection_id,
        batch.expected_state,
        null,
        null,
        batch.expected_suppressed_reason
    from pg_temp.plaid_projection_reconcile_batch batch
    on conflict (plaid_item_id, plaid_transaction_id)
    do update
    set
        pending_transaction_id = excluded.pending_transaction_id,
        replaced_pending_projection_id = excluded.replaced_pending_projection_id,
        state = excluded.state,
        last_error_code = null,
        last_error_at = null,
        suppressed_reason = excluded.suppressed_reason,
        updated_at = now();

    select
        count(*) filter (where expected_state = 'raw_pending'),
        count(*) filter (where expected_state = 'posted_ready'),
        count(*) filter (where expected_state = 'removed_inactive'),
        count(*) filter (
            where expected_replaced_pending_projection_id is not null
        )
    into
        v_raw_pending,
        v_posted_ready,
        v_removed_inactive,
        v_links_updated
    from pg_temp.plaid_projection_reconcile_batch;

    select exists (
        select 1
        from public.plaid_transactions raw
        left join public.plaid_transaction_operation_projections projection
          on projection.plaid_item_id = raw.plaid_item_id
         and projection.plaid_transaction_id = raw.transaction_id
        left join public.plaid_transaction_operation_projections pending_projection
          on pending_projection.plaid_item_id = raw.plaid_item_id
         and pending_projection.plaid_transaction_id = raw.pending_transaction_id
         and raw.pending_transaction_id is not null
        cross join lateral (
            select public.plaid_canonical_suppression_reason(
                raw.user_id, raw.account_id, projection.suppressed_reason
            ) as reason
        ) canonical_gate
        where raw.user_id = p_user_id
          and raw.plaid_item_id = p_plaid_item_id
          and (
              projection.id is null
              or projection.state is distinct from case
                  when raw.removed_at is not null then 'removed_inactive'
                  when raw.pending then 'raw_pending'
                  when projection.operation_id is not null then 'posted_projected'
                  when canonical_gate.reason is not null then 'suppressed'
                  else 'posted_ready'
              end
              or projection.suppressed_reason is distinct from case
                  when raw.removed_at is not null then null
                  when raw.pending then null
                  when projection.operation_id is not null then null
                  when canonical_gate.reason is not null then canonical_gate.reason
                  else null
              end
              or projection.pending_transaction_id is distinct from raw.pending_transaction_id
              or (
                  raw.pending = false
                  and raw.removed_at is null
                  and projection.replaced_pending_projection_id is distinct from pending_projection.id
              )
          )
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'processed', v_processed,
        'raw_pending', v_raw_pending,
        'posted_ready', v_posted_ready,
        'removed_inactive', v_removed_inactive,
        'links_updated', v_links_updated,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_reconcile_transaction_operation_projections(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role reconciliation from authoritative raw Plaid transactions to projection lifecycle rows. Raw rows without an Operation on an active secondary converge to suppressed with the reason from plaid_canonical_suppression_reason (canonical_secondary, or canonical_handoff_ambiguous under a disconnected authority). Does not read or write public.operations.';

revoke all on function public.plaid_reconcile_transaction_operation_projections(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_reconcile_transaction_operation_projections(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_reconcile_transaction_operation_projections(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_reconcile_transaction_operation_projections(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;

-- ---------------------------------------------------------------------------
-- 4) Materialize: canonical suppression through plaid_canonical_suppression_reason
-- ---------------------------------------------------------------------------

create or replace function public.plaid_materialize_transaction_operations(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_batch_size integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_job public.plaid_transaction_projection_jobs%rowtype;
    v_materialized integer := 0;
    v_suppressed_zero_amount integer := 0;
    v_suppressed_canonical_secondary integer := 0;
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

    drop table if exists pg_temp.plaid_operation_materialize_batch;

    create temporary table pg_temp.plaid_operation_materialize_batch (
        projection_id uuid primary key,
        operation_id uuid null,
        user_id uuid not null,
        from_account_id uuid not null,
        operation_type text not null,
        operation_amount numeric(14, 2) not null,
        currency_code char(3) not null,
        occurred_at date not null,
        note text null,
        raw_amount numeric not null,
        canonical_suppressed_reason text null,
        is_canonical_secondary boolean not null default false
    ) on commit drop;

    insert into pg_temp.plaid_operation_materialize_batch (
        projection_id,
        operation_id,
        user_id,
        from_account_id,
        operation_type,
        operation_amount,
        currency_code,
        occurred_at,
        note,
        raw_amount,
        canonical_suppressed_reason,
        is_canonical_secondary
    )
    select
        projection.id,
        case
            when raw.amount = 0 then null
            else gen_random_uuid()
        end as operation_id,
        raw.user_id,
        raw.account_id,
        case
            when raw.amount > 0 then 'expense'
            else 'income'
        end as operation_type,
        round(abs(raw.amount), 2)::numeric(14, 2) as operation_amount,
        upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3) as currency_code,
        raw.date as occurred_at,
        nullif(trim(coalesce(raw.merchant_name, raw.name)), '') as note,
        raw.amount as raw_amount,
        null as canonical_suppressed_reason,
        false as is_canonical_secondary
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id
    where projection.user_id = p_user_id
      and projection.plaid_item_id = p_plaid_item_id
      and projection.state = 'posted_ready'
      and projection.operation_id is null
      and raw.pending = false
      and raw.removed_at is null
    order by raw.date, raw.transaction_id
    limit v_batch_size
    for update of projection skip locked;

    -- Serialize with Stage C linking: lock involved accounts in deterministic id order.
    perform locked.id
    from public.accounts as locked
    where locked.user_id = p_user_id
      and locked.id in (
          select distinct batch.from_account_id
          from pg_temp.plaid_operation_materialize_batch batch
      )
    order by locked.id
    for update;

    update pg_temp.plaid_operation_materialize_batch batch
    set canonical_suppressed_reason = gate.reason,
        is_canonical_secondary = true
    from (
        select candidate.projection_id,
               public.plaid_canonical_suppression_reason(
                   candidate.user_id,
                   candidate.from_account_id,
                   null
               ) as reason
        from pg_temp.plaid_operation_materialize_batch candidate
    ) gate
    where gate.projection_id = batch.projection_id
      and gate.reason is not null;

    -- Secondary wins over zero_amount for suppressed_reason.
    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = batch.canonical_suppressed_reason,
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and batch.is_canonical_secondary;

    get diagnostics v_suppressed_canonical_secondary = row_count;

    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = 'zero_amount',
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and not batch.is_canonical_secondary
      and batch.raw_amount = 0;

    get diagnostics v_suppressed_zero_amount = row_count;

    insert into public.operations (
        id,
        user_id,
        from_account_id,
        to_account_id,
        category_id,
        type,
        amount,
        currency_code,
        occurred_at,
        recurrence,
        is_recurring,
        note,
        source,
        category_overridden,
        archived_at
    )
    select
        batch.operation_id,
        batch.user_id,
        batch.from_account_id,
        null,
        null,
        batch.operation_type,
        batch.operation_amount,
        batch.currency_code,
        batch.occurred_at,
        'none',
        false,
        batch.note,
        'plaid',
        false,
        null
    from pg_temp.plaid_operation_materialize_batch batch
    where not batch.is_canonical_secondary
      and batch.raw_amount <> 0
      and batch.operation_id is not null;

    get diagnostics v_materialized = row_count;

    update public.plaid_transaction_operation_projections projection
    set
        operation_id = batch.operation_id,
        state = 'posted_projected',
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        suppressed_reason = null,
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and not batch.is_canonical_secondary
      and batch.raw_amount <> 0
      and batch.operation_id is not null;

    select exists (
        select 1
        from public.plaid_transaction_operation_projections projection
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.state = 'posted_ready'
          and projection.operation_id is null
          and raw.pending = false
          and raw.removed_at is null
          and not public.plaid_raw_canonical_suppressed(
              raw.user_id,
              raw.account_id
          )
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'materialized', v_materialized,
        'suppressed_zero_amount', v_suppressed_zero_amount,
        'suppressed_canonical_secondary', v_suppressed_canonical_secondary,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role materialization from posted Plaid projections to Operations. Serializes with Stage C via accounts FOR UPDATE (id order). Raw rows of an active secondary cannot create new Operations and are suppressed with the reason from plaid_canonical_suppression_reason; pre-linked Operations are out of scope here.';

revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;

-- ---------------------------------------------------------------------------
-- 5) Canonical authority after a lifecycle change
-- ---------------------------------------------------------------------------

create or replace function public.plaid_lifecycle_recalculate_canonical_authority(
    p_user_id uuid,
    p_canonical_account_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_canonical_id uuid;
    v_active_count integer;
    v_has_authority boolean;
    v_promoted public.plaid_canonical_financial_account_members%rowtype;
    v_promotions integer := 0;
begin
    if p_user_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    for v_canonical_id in
        select distinct ids.canonical_id
        from unnest(coalesce(p_canonical_account_ids, '{}'::uuid[])) as ids(canonical_id)
        where ids.canonical_id is not null
        order by ids.canonical_id
    loop
        select count(*),
               coalesce(bool_or(members.role = 'authoritative'), false)
        into v_active_count,
             v_has_authority
        from public.plaid_canonical_financial_account_members members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null;

        if v_active_count >= 2 and not v_has_authority then
            -- A live (connected) representation is preferred so authority is not frozen again.
            select members.*
            into v_promoted
            from public.plaid_canonical_financial_account_members members
            left join public.accounts member_account
              on member_account.id = members.account_id
             and member_account.user_id = members.user_id
            left join public.plaid_items member_item
              on member_item.id = member_account.plaid_item_id
             and member_item.user_id = member_account.user_id
            where members.canonical_account_id = v_canonical_id
              and members.user_id = p_user_id
              and members.unlinked_at is null
              and members.role = 'secondary'
            order by (member_item.disconnected_at is not null), members.linked_at, members.id
            limit 1
            for update of members;

            -- Retire-and-insert keeps the membership audit trail.
            update public.plaid_canonical_financial_account_members
            set unlinked_at = now()
            where id = v_promoted.id;

            insert into public.plaid_canonical_financial_account_members (
                user_id,
                canonical_account_id,
                account_id,
                role,
                link_origin,
                linked_at
            )
            values (
                p_user_id,
                v_canonical_id,
                v_promoted.account_id,
                'authoritative',
                v_promoted.link_origin,
                now()
            );

            v_promotions := v_promotions + 1;
        end if;
    end loop;

    return jsonb_build_object(
        'authority_promotions', v_promotions
    );
end;
$$;

comment on function public.plaid_lifecycle_recalculate_canonical_authority(uuid, uuid[]) is
    'After Delete removed an authoritative member: a canonical with two or more active members and no active authority promotes one secondary, deterministically ordered by connected Item first, then linked_at, then id, by retiring the secondary row and inserting an authoritative row. Caller must hold the account locks. Service-role only.';

revoke all on function public.plaid_lifecycle_recalculate_canonical_authority(uuid, uuid[]) from public;
revoke all on function public.plaid_lifecycle_recalculate_canonical_authority(uuid, uuid[]) from anon;
revoke all on function public.plaid_lifecycle_recalculate_canonical_authority(uuid, uuid[]) from authenticated;
grant execute on function public.plaid_lifecycle_recalculate_canonical_authority(uuid, uuid[]) to service_role;

-- ---------------------------------------------------------------------------
-- 6) Disconnect (local part; the caller has already removed the Plaid Item)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_disconnect_item_local(
    p_user_id uuid,
    p_connection_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item public.plaid_items%rowtype;
    v_accounts uuid[];
    v_canonicals uuid[];
    v_member_accounts uuid[];
    v_survivor_items uuid[];
    v_survivor_item uuid;
    v_frozen_canonicals integer := 0;
    v_vault_secrets_deleted integer := 0;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Lock order: ITEM → JOBS → ACCOUNTS (same as sync apply and materialize).
    select *
    into v_item
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id
    for update;

    if not found then
        return jsonb_build_object('status', 'not_found');
    end if;

    if v_item.disconnected_at is not null then
        return jsonb_build_object(
            'status', 'already_disconnected',
            'disconnected_at', v_item.disconnected_at
        );
    end if;

    select coalesce(array_agg(accounts.id order by accounts.id), '{}'::uuid[])
    into v_accounts
    from public.accounts
    where accounts.plaid_item_id = p_connection_id
      and accounts.user_id = p_user_id;

    select coalesce(array_agg(distinct members.canonical_account_id), '{}'::uuid[])
    into v_canonicals
    from public.plaid_canonical_financial_account_members members
    where members.user_id = p_user_id
      and members.account_id = any(v_accounts)
      and members.unlinked_at is null;

    select coalesce(array_agg(distinct members.account_id), '{}'::uuid[])
    into v_member_accounts
    from public.plaid_canonical_financial_account_members members
    where members.user_id = p_user_id
      and members.canonical_account_id = any(v_canonicals)
      and members.unlinked_at is null;

    select coalesce(array_agg(distinct accounts.plaid_item_id), '{}'::uuid[])
    into v_survivor_items
    from public.accounts
    where accounts.id = any(v_member_accounts)
      and accounts.user_id = p_user_id
      and accounts.plaid_item_id is not null
      and accounts.plaid_item_id <> p_connection_id;

    perform 1
    from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_connection_id
    for update;

    perform 1
    from public.plaid_transaction_projection_jobs
    where plaid_item_id = any(v_survivor_items || p_connection_id)
    order by plaid_item_id
    for update;

    perform 1
    from public.accounts
    where accounts.user_id = p_user_id
      and (accounts.id = any(v_accounts) or accounts.id = any(v_member_accounts))
    order by accounts.id
    for update;

    delete from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_connection_id;

    delete from public.plaid_transaction_sync_leases
    where plaid_item_id = p_connection_id;

    -- Memberships are kept: an authoritative member of this Item freezes its canonical.
    select count(distinct members.canonical_account_id)
    into v_frozen_canonicals
    from public.plaid_canonical_financial_account_members members
    where members.user_id = p_user_id
      and members.account_id = any(v_accounts)
      and members.role = 'authoritative'
      and members.unlinked_at is null;

    update public.plaid_items
    set disconnected_at = now(),
        access_token_secret_id = null
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id;

    delete from vault.secrets
    where id = v_item.access_token_secret_id;

    get diagnostics v_vault_secrets_deleted = row_count;

    foreach v_survivor_item in array v_survivor_items
    loop
        perform public.plaid_enqueue_transaction_projection_job(p_user_id, v_survivor_item);
    end loop;

    return jsonb_build_object(
        'status', 'disconnected',
        'canonical_authorities_frozen', v_frozen_canonicals,
        'vault_secrets_deleted', v_vault_secrets_deleted,
        'survivor_items_enqueued', cardinality(v_survivor_items)
    );
end;
$$;

comment on function public.plaid_disconnect_item_local(uuid, uuid) is
    'Local half of a user Disconnect, after the Plaid Item was removed: stops sync (sync job and lease deleted, disconnected_at set), deletes the access token, and keeps all local financial history and canonical memberships. An authoritative membership of this Item becomes frozen authority: surviving secondaries keep their prior suppression and new rows become canonical_handoff_ambiguous until Delete. Idempotent. Service-role only.';

revoke all on function public.plaid_disconnect_item_local(uuid, uuid) from public;
revoke all on function public.plaid_disconnect_item_local(uuid, uuid) from anon;
revoke all on function public.plaid_disconnect_item_local(uuid, uuid) from authenticated;
grant execute on function public.plaid_disconnect_item_local(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 7) Delete (local part; the caller has already removed the Plaid Item)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_delete_item_local(
    p_user_id uuid,
    p_connection_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item public.plaid_items%rowtype;
    v_accounts uuid[];
    v_canonicals uuid[];
    v_survivor_accounts uuid[];
    v_operations uuid[];
    v_unfrozen_items uuid[];
    v_affected_items uuid[];
    v_affected_item uuid;
    v_canonical_id uuid;
    v_remaining_accounts integer;
    v_recalculate uuid[] := '{}'::uuid[];
    v_projections_deleted integer := 0;
    v_raw_deleted integer := 0;
    v_resolutions_deleted integer := 0;
    v_operations_deleted integer := 0;
    v_manual_detached integer := 0;
    v_memberships_deleted integer := 0;
    v_canonical_memberships_cleared integer := 0;
    v_canonicals_deleted integer := 0;
    v_accounts_deleted integer := 0;
    v_items_deleted integer := 0;
    v_vault_secrets_deleted integer := 0;
    v_row_count integer;
    v_recalculated jsonb;
    v_enqueued integer := 0;
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_item
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id
    for update;

    if not found then
        return jsonb_build_object('status', 'not_found');
    end if;

    select coalesce(array_agg(accounts.id order by accounts.id), '{}'::uuid[])
    into v_accounts
    from public.accounts
    where accounts.plaid_item_id = p_connection_id
      and accounts.user_id = p_user_id;

    select coalesce(array_agg(distinct members.canonical_account_id), '{}'::uuid[])
    into v_canonicals
    from public.plaid_canonical_financial_account_members members
    where members.user_id = p_user_id
      and members.account_id = any(v_accounts);

    select coalesce(array_agg(distinct members.account_id), '{}'::uuid[])
    into v_survivor_accounts
    from public.plaid_canonical_financial_account_members members
    where members.user_id = p_user_id
      and members.canonical_account_id = any(v_canonicals)
      and not (members.account_id = any(v_accounts));

    -- Plaid-derived Operations of this connection only; manual Operations are never deleted.
    select coalesce(array_agg(distinct derived.operation_id), '{}'::uuid[])
    into v_operations
    from (
        select operations.id as operation_id
        from public.operations
        where operations.source = 'plaid'
          and (
              operations.from_account_id = any(v_accounts)
              or operations.to_account_id = any(v_accounts)
          )
        union
        select projection.operation_id
        from public.plaid_transaction_operation_projections projection
        where projection.plaid_item_id = p_connection_id
          and projection.user_id = p_user_id
          and projection.operation_id is not null
    ) derived;

    -- Surviving suppressed Operations whose active resolution disappears with this connection.
    select coalesce(array_agg(distinct projection.plaid_item_id), '{}'::uuid[])
    into v_unfrozen_items
    from public.plaid_duplicate_operation_resolutions resolution
    join public.plaid_transaction_operation_projections projection
      on projection.operation_id = resolution.suppressed_operation_id
     and projection.user_id = resolution.user_id
    where resolution.kept_operation_id = any(v_operations)
      and not (resolution.suppressed_operation_id = any(v_operations))
      and resolution.reversed_at is null;

    select coalesce(array_agg(distinct affected.item_id), '{}'::uuid[])
    into v_affected_items
    from (
        select accounts.plaid_item_id as item_id
        from public.accounts
        where accounts.id = any(v_survivor_accounts)
        union
        select unnest(v_unfrozen_items)
    ) affected
    where affected.item_id is not null
      and affected.item_id <> p_connection_id;

    -- Lock order: ITEM → JOBS → ACCOUNTS (same as sync apply and materialize).
    perform 1
    from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_connection_id
    for update;

    perform 1
    from public.plaid_transaction_projection_jobs
    where plaid_item_id = any(v_affected_items || p_connection_id)
    order by plaid_item_id
    for update;

    perform 1
    from public.accounts
    where accounts.id = any(v_accounts || v_survivor_accounts)
    order by accounts.id
    for update;

    delete from public.plaid_duplicate_operation_resolutions
    where kept_operation_id = any(v_operations)
       or suppressed_operation_id = any(v_operations);

    get diagnostics v_resolutions_deleted = row_count;

    delete from public.plaid_transaction_operation_projections
    where plaid_item_id = p_connection_id
      and user_id = p_user_id;

    get diagnostics v_projections_deleted = row_count;

    delete from public.operations
    where id = any(v_operations)
      and source = 'plaid';

    get diagnostics v_operations_deleted = row_count;

    update public.operations
    set from_account_id = null
    where from_account_id = any(v_accounts)
      and source <> 'plaid';

    get diagnostics v_manual_detached = row_count;

    delete from public.plaid_canonical_financial_account_members
    where user_id = p_user_id
      and account_id = any(v_accounts);

    get diagnostics v_memberships_deleted = row_count;

    foreach v_canonical_id in array v_canonicals
    loop
        select count(distinct members.account_id)
        into v_remaining_accounts
        from public.plaid_canonical_financial_account_members members
        where members.canonical_account_id = v_canonical_id
          and members.user_id = p_user_id
          and members.unlinked_at is null;

        if v_remaining_accounts < 2 then
            -- Nothing left to deduplicate against: drop the survivor's memberships so
            -- its canonical_secondary and canonical_handoff_ambiguous rows materialize.
            delete from public.plaid_canonical_financial_account_members
            where canonical_account_id = v_canonical_id
              and user_id = p_user_id;

            get diagnostics v_row_count = row_count;
            v_canonical_memberships_cleared := v_canonical_memberships_cleared + v_row_count;

            -- A remaining user resolution still anchors the canonical row.
            delete from public.plaid_canonical_financial_accounts canonical
            where canonical.id = v_canonical_id
              and canonical.user_id = p_user_id
              and not exists (
                  select 1
                  from public.plaid_duplicate_operation_resolutions resolution
                  where resolution.canonical_account_id = v_canonical_id
              );

            get diagnostics v_row_count = row_count;
            v_canonicals_deleted := v_canonicals_deleted + v_row_count;
        else
            v_recalculate := v_recalculate || v_canonical_id;
        end if;
    end loop;

    v_recalculated := public.plaid_lifecycle_recalculate_canonical_authority(
        p_user_id,
        v_recalculate
    );

    select count(*)
    into v_raw_deleted
    from public.plaid_transactions
    where plaid_item_id = p_connection_id
      and user_id = p_user_id;

    delete from public.accounts
    where id = any(v_accounts)
      and user_id = p_user_id;

    get diagnostics v_accounts_deleted = row_count;

    delete from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id;

    get diagnostics v_items_deleted = row_count;

    if v_items_deleted <> 1 then
        raise exception 'plaid_item_cleanup_failed' using errcode = '22023';
    end if;

    if v_item.access_token_secret_id is not null then
        delete from vault.secrets
        where id = v_item.access_token_secret_id;

        get diagnostics v_vault_secrets_deleted = row_count;
    end if;

    foreach v_affected_item in array v_affected_items
    loop
        if exists (
            select 1
            from public.plaid_items
            where plaid_items.id = v_affected_item
              and plaid_items.user_id = p_user_id
        ) then
            perform public.plaid_enqueue_transaction_projection_job(p_user_id, v_affected_item);
            v_enqueued := v_enqueued + 1;
        end if;
    end loop;

    return jsonb_build_object(
        'status', 'deleted',
        'accounts_deleted', v_accounts_deleted,
        'raw_transactions_deleted', v_raw_deleted,
        'projections_deleted', v_projections_deleted,
        'operations_deleted', v_operations_deleted,
        'manual_operations_detached', v_manual_detached,
        'duplicate_resolutions_deleted', v_resolutions_deleted,
        'canonical_memberships_deleted', v_memberships_deleted + v_canonical_memberships_cleared,
        'canonical_accounts_deleted', v_canonicals_deleted,
        'authority_promotions', (v_recalculated ->> 'authority_promotions')::integer,
        'plaid_items_deleted', v_items_deleted,
        'vault_secrets_deleted', v_vault_secrets_deleted,
        'survivor_items_enqueued', v_enqueued
    );
end;
$$;

comment on function public.plaid_delete_item_local(uuid, uuid) is
    'Local half of a user Delete, after the Plaid Item was removed: deletes the Item, its accounts, raw transactions, projections, Plaid-derived Operations, jobs, institution metadata and access token. Duplicate resolutions touching deleted Operations are deleted; manual Operations are detached, never deleted. Canonicals left with fewer than two accounts release their survivor; others recalculate authority. Surviving Items get a projection job. Idempotent (not_found). Service-role only.';

revoke all on function public.plaid_delete_item_local(uuid, uuid) from public;
revoke all on function public.plaid_delete_item_local(uuid, uuid) from anon;
revoke all on function public.plaid_delete_item_local(uuid, uuid) from authenticated;
grant execute on function public.plaid_delete_item_local(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 8) Disconnected gates
-- ---------------------------------------------------------------------------

create or replace function public.plaid_enqueue_transaction_sync_job(
    p_external_plaid_item_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_plaid_item_id uuid;
    v_user_id uuid;
    v_existing_status text;
    v_result text := 'accepted';
begin
    if p_external_plaid_item_id is null
       or trim(p_external_plaid_item_id) = ''
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- FOR SHARE serializes with Disconnect, which deletes the job under the Item lock.
    select plaid_items.id,
           plaid_items.user_id
    into v_plaid_item_id,
         v_user_id
    from public.plaid_items
    where plaid_items.plaid_environment = 'sandbox'
      and plaid_items.plaid_item_id = trim(p_external_plaid_item_id)
      and plaid_items.disconnected_at is null
    for share;

    if not found then
        return jsonb_build_object('status', 'ignored');
    end if;

    select plaid_transaction_sync_jobs.status
    into v_existing_status
    from public.plaid_transaction_sync_jobs
    where plaid_transaction_sync_jobs.plaid_item_id = v_plaid_item_id
    for update;

    if not found then
        insert into public.plaid_transaction_sync_jobs (
            plaid_item_id,
            user_id,
            status,
            requested_at,
            next_attempt_at,
            attempt_count,
            rerun_requested,
            lease_token,
            lease_expires_at,
            last_error_code
        )
        values (
            v_plaid_item_id,
            v_user_id,
            'pending',
            now(),
            now(),
            0,
            false,
            null,
            null,
            null
        );

        return jsonb_build_object('status', v_result);
    end if;

    v_result := 'coalesced';

    if v_existing_status = 'processing' then
        update public.plaid_transaction_sync_jobs
        set
            requested_at = now(),
            rerun_requested = true
        where plaid_item_id = v_plaid_item_id;
    else
        update public.plaid_transaction_sync_jobs
        set
            status = 'pending',
            requested_at = now(),
            next_attempt_at = least(next_attempt_at, now()),
            rerun_requested = false,
            last_error_code = null
        where plaid_item_id = v_plaid_item_id;
    end if;

    return jsonb_build_object('status', v_result);
end;
$$;

comment on function public.plaid_enqueue_transaction_sync_job(text) is
    'Resolves a verified Plaid external item_id and atomically enqueues or coalesces one transaction sync job. Disconnected Items are ignored. Service-role only.';

create or replace function public.plaid_apply_transactions_sync_batch(
    p_user_id uuid,
    p_connection_id uuid,
    p_original_cursor text,
    p_final_cursor text,
    p_mark_initial_sync_completed boolean,
    p_added jsonb,
    p_modified jsonb,
    p_removed jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_result jsonb;
    v_added_count integer;
    v_modified_count integer;
    v_removed_count integer;
    v_known_removed_transaction boolean := false;
    v_disconnected_at timestamptz;
begin
    if p_mark_initial_sync_completed is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- An in-flight sync must not write raw rows after Disconnect committed.
    select plaid_items.disconnected_at
    into v_disconnected_at
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id
    for update;

    if v_disconnected_at is not null then
        raise exception 'plaid_item_disconnected' using errcode = '22023';
    end if;

    v_result := public.plaid_apply_transactions_sync_batch(
        p_user_id,
        p_connection_id,
        p_original_cursor,
        p_final_cursor,
        p_added,
        p_modified,
        p_removed
    );

    if p_mark_initial_sync_completed then
        update public.plaid_items
        set transactions_initial_sync_completed_at = coalesce(
            transactions_initial_sync_completed_at,
            now()
        )
        where plaid_items.id = p_connection_id
          and plaid_items.user_id = p_user_id;
    end if;

    v_added_count := coalesce((v_result ->> 'added_count')::integer, 0);
    v_modified_count := coalesce((v_result ->> 'modified_count')::integer, 0);
    v_removed_count := coalesce((v_result ->> 'removed_count')::integer, 0);

    if v_removed_count > 0 then
        select exists (
            select 1
            from jsonb_array_elements(p_removed) removed_transaction(value)
            join public.plaid_transactions
              on plaid_transactions.plaid_item_id = p_connection_id
             and plaid_transactions.user_id = p_user_id
             and plaid_transactions.transaction_id = nullif(
                 trim(removed_transaction.value ->> 'transaction_id'),
                 ''
             )
        )
        into v_known_removed_transaction;
    end if;

    if v_added_count > 0
       or v_modified_count > 0
       or v_known_removed_transaction
    then
        perform public.plaid_enqueue_transaction_projection_job(
            p_user_id,
            p_connection_id
        );
    end if;

    return v_result || jsonb_build_object(
        'initial_sync_completed',
        p_mark_initial_sync_completed
    );
end;
$$;

comment on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    boolean,
    jsonb,
    jsonb,
    jsonb
) is
    'Applies a complete Plaid /transactions/sync batch atomically, marks initial readiness when requested, and enqueues projection work only when raw transaction deltas were persisted. Refuses disconnected Items (plaid_item_disconnected).';

create or replace function public.plaid_record_item_status_observation(
    p_connection_id uuid,
    p_observed_at timestamptz,
    p_status text,
    p_status_reason text,
    p_from_item_get boolean,
    p_consent_expires_at timestamptz,
    p_clear_pending_disconnect boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item public.plaid_items%rowtype;
begin
    if p_connection_id is null
       or p_observed_at is null
       or p_status is null
       or p_status not in ('active', 'login_required')
       or (p_status = 'active') <> (p_status_reason is null)
       or (
           p_status_reason is not null
           and p_status_reason not in ('login_required', 'consent_expired', 'permission_revoked')
       )
       or p_from_item_get is null
       or p_clear_pending_disconnect is null
       or (not p_from_item_get and p_consent_expires_at is not null)
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_item
    from public.plaid_items
    where plaid_items.id = p_connection_id
    for update;

    if not found then
        return null;
    end if;

    if v_item.disconnected_at is not null
       or (
           v_item.health_observed_at is not null
           and p_observed_at <= v_item.health_observed_at
       )
    then
        return jsonb_build_object(
            'applied', false,
            'previous_status', v_item.status,
            'status', v_item.status,
            'plaid_item_id', v_item.plaid_item_id
        );
    end if;

    update public.plaid_items
    set status = p_status,
        status_reason = p_status_reason,
        status_changed_at = case
            when plaid_items.status <> p_status then now()
            else plaid_items.status_changed_at
        end,
        health_observed_at = p_observed_at,
        consent_expires_at = case
            when p_from_item_get then p_consent_expires_at
            else plaid_items.consent_expires_at
        end,
        pending_disconnect_at = case
            when p_clear_pending_disconnect then null
            else plaid_items.pending_disconnect_at
        end
    where plaid_items.id = p_connection_id;

    return jsonb_build_object(
        'applied', true,
        'previous_status', v_item.status,
        'status', p_status,
        'plaid_item_id', v_item.plaid_item_id
    );
end;
$$;

comment on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) is
    'Single writer of Item health. Applies an observation only when it is newer than the last applied one and the Item is not disconnected. Returns null for an unknown connection. Service-role only.';

create or replace function public.plaid_set_item_access_deadline(
    p_external_plaid_item_id text,
    p_kind text,
    p_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_connection_id uuid;
begin
    if p_external_plaid_item_id is null
       or trim(p_external_plaid_item_id) = ''
       or p_kind is null
       or p_kind not in ('pending_disconnect', 'consent_expiration')
       or p_at is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    update public.plaid_items
    set pending_disconnect_at = case
            when p_kind = 'pending_disconnect' then p_at
            else plaid_items.pending_disconnect_at
        end,
        consent_expires_at = case
            when p_kind = 'consent_expiration' then p_at
            else plaid_items.consent_expires_at
        end
    where plaid_items.plaid_environment = 'sandbox'
      and plaid_items.plaid_item_id = trim(p_external_plaid_item_id)
      and plaid_items.disconnected_at is null
    returning plaid_items.id into v_connection_id;

    if v_connection_id is null then
        return jsonb_build_object('status', 'ignored');
    end if;

    return jsonb_build_object('status', 'applied', 'connection_id', v_connection_id);
end;
$$;

comment on function public.plaid_set_item_access_deadline(text, text, timestamptz) is
    'Records a Plaid access deadline from a verified ITEM webhook: pending_disconnect writes only pending_disconnect_at, consent_expiration writes only consent_expires_at. Disconnected Items are ignored. Service-role only.';

create or replace function public.plaid_list_items_for_health_reconcile(
    p_limit integer
)
returns table (
    connection_id uuid,
    user_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if p_limit is null or p_limit < 1 or p_limit > 500 then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    return query
    select plaid_items.id,
           plaid_items.user_id
    from public.plaid_items
    where plaid_items.disconnected_at is null
    order by plaid_items.health_observed_at asc nulls first,
             plaid_items.created_at asc,
             plaid_items.id asc
    limit p_limit;
end;
$$;

comment on function public.plaid_list_items_for_health_reconcile(integer) is
    'Lists connected Items for one-off health backfill or operator recovery, never-observed Items first. Service-role only.';

-- ---------------------------------------------------------------------------
-- 9) Client connection listing with disconnected_at
-- ---------------------------------------------------------------------------

drop function public.plaid_list_connection_health();

create function public.plaid_list_connection_health()
returns table (
    connection_id uuid,
    status text,
    status_reason text,
    status_changed_at timestamptz,
    consent_expires_at timestamptz,
    pending_disconnect_at timestamptz,
    disconnected_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select plaid_items.id,
           plaid_items.status,
           plaid_items.status_reason,
           plaid_items.status_changed_at,
           plaid_items.consent_expires_at,
           plaid_items.pending_disconnect_at,
           plaid_items.disconnected_at
    from public.plaid_items
    where plaid_items.user_id = auth.uid()
    order by plaid_items.created_at asc, plaid_items.id asc
$$;

comment on function public.plaid_list_connection_health() is
    'Health and disconnect state of the calling user''s Plaid connections, without secrets or sync internals.';

revoke all on function public.plaid_list_connection_health() from public;
revoke all on function public.plaid_list_connection_health() from anon;
grant execute on function public.plaid_list_connection_health() to authenticated;
grant execute on function public.plaid_list_connection_health() to service_role;

-- ---------------------------------------------------------------------------
-- 10) Accounts snapshot gate
-- ---------------------------------------------------------------------------

-- Body of 20260818170000 with two changes. The Item row is locked and must not be
-- disconnected: an /accounts/get snapshot fetched with a token read before the
-- Disconnect reaches this write only after the Disconnect released the Item lock,
-- and is then refused; a snapshot written first commits before the Disconnect.
-- Existing payload accounts are locked in id order before any upsert, because
-- Disconnect, Delete and materialize lock accounts (including canonical members of
-- other Items) in id order and payload order is arbitrary.
-- Lock order: ITEM (FOR NO KEY UPDATE) → ACCOUNTS (FOR NO KEY UPDATE, id order).
-- FOR NO KEY UPDATE still conflicts with the FOR UPDATE / DELETE of Disconnect,
-- Delete and materialize, but not with an FK KEY SHARE: neither with a
-- projection-job enqueue for this Item while another Item's Disconnect or Delete
-- holds its account locks, nor with an Operation write that references several of
-- these accounts. The upserts below change no key column of accounts, so they need
-- no stronger lock than the pre-lock already holds.
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
begin
    if p_user_id is null or p_connection_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_accounts is null or jsonb_typeof(p_accounts) <> 'array' then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    select plaid_items.disconnected_at
    into v_disconnected_at
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

    perform 1
    from public.accounts
    where accounts.user_id = p_user_id
      and accounts.plaid_account_id in (
          select nullif(trim(payload.value ->> 'plaid_account_id'), '')
          from jsonb_array_elements(p_accounts) as payload(value)
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
            updated_at = now();

        v_synced_count := v_synced_count + 1;
    end loop;

    return v_synced_count;
end;
$$;

comment on function public.plaid_persist_accounts_sync(
    uuid, uuid, text, text, text, text, text, timestamptz, jsonb
) is
    'Persists one complete /accounts/get snapshot (institution and accounts) of a connected Item. Refuses a disconnected Item (plaid_item_disconnected) under the Item row lock, so a snapshot fetched before a Disconnect is never written after it. Service-role only.';
