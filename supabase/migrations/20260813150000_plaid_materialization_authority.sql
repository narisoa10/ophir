-- Stage D (Edge Case №11): account-level materialization authority.
-- Active secondary representations cannot create NEW Operations.
-- Pre-link Operations (operation_id already set) are preserved (D8).
-- Serialization: materialize locks public.accounts FOR UPDATE in id order
-- (same primitive as Stage C linking).
-- Reconcile writes truthful suppressed/canonical_secondary snapshot.
-- Link RPC does not enqueue projection jobs inside the account-locked transaction.
-- Projection heal/convergence is deferred to a post-commit/future enqueue path.
-- No transaction matching. No Item-level authority. No historical Op cleanup.
-- Raw ingestion / source-sync RPCs unchanged.

-- ---------------------------------------------------------------------------
-- 1) Reconcile: secondary → suppressed / canonical_secondary
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
            when secondary_member.account_id is not null then 'suppressed'
            else 'posted_ready'
        end as expected_state,
        case
            when raw.removed_at is not null then null
            when raw.pending then null
            when projection.operation_id is not null then null
            when secondary_member.account_id is not null then 'canonical_secondary'
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
    left join public.plaid_canonical_financial_account_members secondary_member
      on secondary_member.account_id = raw.account_id
     and secondary_member.user_id = raw.user_id
     and secondary_member.unlinked_at is null
     and secondary_member.role = 'secondary'
    where raw.user_id = p_user_id
      and raw.plaid_item_id = p_plaid_item_id
      and (
          projection.id is null
          or projection.state is distinct from case
              when raw.removed_at is not null then 'removed_inactive'
              when raw.pending then 'raw_pending'
              when projection.operation_id is not null then 'posted_projected'
              when secondary_member.account_id is not null then 'suppressed'
              else 'posted_ready'
          end
          or projection.suppressed_reason is distinct from case
              when raw.removed_at is not null then null
              when raw.pending then null
              when projection.operation_id is not null then null
              when secondary_member.account_id is not null then 'canonical_secondary'
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
        left join public.plaid_canonical_financial_account_members secondary_member
          on secondary_member.account_id = raw.account_id
         and secondary_member.user_id = raw.user_id
         and secondary_member.unlinked_at is null
         and secondary_member.role = 'secondary'
        where raw.user_id = p_user_id
          and raw.plaid_item_id = p_plaid_item_id
          and (
              projection.id is null
              or projection.state is distinct from case
                  when raw.removed_at is not null then 'removed_inactive'
                  when raw.pending then 'raw_pending'
                  when projection.operation_id is not null then 'posted_projected'
                  when secondary_member.account_id is not null then 'suppressed'
                  else 'posted_ready'
              end
              or projection.suppressed_reason is distinct from case
                  when raw.removed_at is not null then null
                  when raw.pending then null
                  when projection.operation_id is not null then null
                  when secondary_member.account_id is not null then 'canonical_secondary'
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
    'Fenced service-role reconciliation from authoritative raw Plaid transactions to projection lifecycle rows. Active secondary account representations without an Operation converge to suppressed/canonical_secondary. Does not read or write public.operations.';

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
-- 2) Materialize: account FOR UPDATE + secondary hard gate
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
    set is_canonical_secondary = true
    where exists (
        select 1
        from public.plaid_canonical_financial_account_members as members
        where members.account_id = batch.from_account_id
          and members.user_id = batch.user_id
          and members.unlinked_at is null
          and members.role = 'secondary'
    );

    -- Secondary wins over zero_amount for suppressed_reason.
    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = 'canonical_secondary',
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
          and not exists (
              select 1
              from public.plaid_canonical_financial_account_members as members
              where members.account_id = raw.account_id
                and members.user_id = raw.user_id
                and members.unlinked_at is null
                and members.role = 'secondary'
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
    'Fenced service-role materialization from posted Plaid projections to Operations. Serializes with Stage C via accounts FOR UPDATE (id order). Active secondary representations cannot create new Operations; pre-linked Operations are out of scope here.';

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
