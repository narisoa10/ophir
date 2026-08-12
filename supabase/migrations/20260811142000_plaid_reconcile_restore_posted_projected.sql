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
        expected_replaced_pending_projection_id uuid null
    ) on commit drop;

    insert into pg_temp.plaid_projection_reconcile_batch (
        user_id,
        plaid_item_id,
        plaid_transaction_id,
        pending_transaction_id,
        expected_state,
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
            else 'posted_ready'
        end as expected_state,
        pending_projection.id as expected_replaced_pending_projection_id
    from public.plaid_transactions raw
    left join public.plaid_transaction_operation_projections projection
      on projection.plaid_item_id = raw.plaid_item_id
     and projection.plaid_transaction_id = raw.transaction_id
    left join public.plaid_transaction_operation_projections pending_projection
      on pending_projection.plaid_item_id = raw.plaid_item_id
     and pending_projection.plaid_transaction_id = raw.pending_transaction_id
     and raw.pending_transaction_id is not null
    where raw.user_id = p_user_id
      and raw.plaid_item_id = p_plaid_item_id
      and (
          projection.id is null
          or projection.state is distinct from case
              when raw.removed_at is not null then 'removed_inactive'
              when raw.pending then 'raw_pending'
              when projection.operation_id is not null then 'posted_projected'
              else 'posted_ready'
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
        null
    from pg_temp.plaid_projection_reconcile_batch batch
    on conflict (plaid_item_id, plaid_transaction_id)
    do update
    set
        pending_transaction_id = excluded.pending_transaction_id,
        replaced_pending_projection_id = excluded.replaced_pending_projection_id,
        state = excluded.state,
        last_error_code = null,
        last_error_at = null,
        suppressed_reason = null,
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
        where raw.user_id = p_user_id
          and raw.plaid_item_id = p_plaid_item_id
          and (
              projection.id is null
              or projection.state is distinct from case
                  when raw.removed_at is not null then 'removed_inactive'
                  when raw.pending then 'raw_pending'
                  when projection.operation_id is not null then 'posted_projected'
                  else 'posted_ready'
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
    'Fenced service-role reconciliation from authoritative raw Plaid transactions to projection lifecycle rows. Active posted raw with an existing operation_id converges to posted_projected. Does not read or write public.operations.';

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

update public.plaid_transaction_operation_projections p
set
    state = 'posted_projected',
    updated_at = now()
from public.plaid_transactions raw
where raw.plaid_item_id = p.plaid_item_id
  and raw.transaction_id = p.plaid_transaction_id
  and raw.user_id = p.user_id
  and p.state = 'posted_ready'
  and p.operation_id is not null
  and raw.removed_at is null
  and raw.pending = false;
