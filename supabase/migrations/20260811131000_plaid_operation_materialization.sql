alter table public.operations
add column if not exists category_overridden boolean not null default false;

alter table public.operations
drop constraint if exists operations_source_check;

alter table public.operations
add constraint operations_source_check
check (source in ('manual', 'plaid')) not valid;

alter table public.operations
drop constraint if exists operations_transfer_check;

alter table public.operations
add constraint operations_transfer_check
check (
    (
        type = 'transfer'
        and category_id is null
        and to_account_id is not null
        and from_account_id <> to_account_id
    )
    or
    (
        type in ('expense', 'income')
        and to_account_id is null
        and (
            category_id is not null
            or source = 'plaid'
        )
    )
) not valid;

create unique index if not exists operations_id_user_id_unique
on public.operations(id, user_id);

alter table public.plaid_transaction_operation_projections
drop constraint if exists plaid_transaction_operation_projections_operation_user_fkey;

alter table public.plaid_transaction_operation_projections
add constraint plaid_transaction_operation_projections_operation_user_fkey
foreign key (operation_id, user_id)
references public.operations(id, user_id)
on delete set null (operation_id);

drop policy if exists "Users can insert own operations"
on public.operations;

drop policy if exists "Users can update own operations"
on public.operations;

drop policy if exists "Users can delete own operations"
on public.operations;

create policy "Users can insert own manual operations"
on public.operations
for insert
to authenticated
with check (
    auth.uid() = user_id
    and source = 'manual'
);

create policy "Users can update own manual operations"
on public.operations
for update
to authenticated
using (
    auth.uid() = user_id
    and source = 'manual'
)
with check (
    auth.uid() = user_id
    and source = 'manual'
);

create policy "Users can delete own manual operations"
on public.operations
for delete
to authenticated
using (
    auth.uid() = user_id
    and source = 'manual'
);

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
            when projection.operation_id is not null
                 and projection.state = 'posted_projected'
              then 'posted_projected'
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
              when projection.operation_id is not null
                   and projection.state = 'posted_projected'
                then 'posted_projected'
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
                  when projection.operation_id is not null
                       and projection.state = 'posted_projected'
                    then 'posted_projected'
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
        raw_amount numeric not null
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
        raw_amount
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
        raw.amount as raw_amount
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
    where batch.raw_amount <> 0;

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
      and batch.raw_amount <> 0;

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
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'materialized', v_materialized,
        'suppressed_zero_amount', v_suppressed_zero_amount,
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
    'Fenced service-role materialization from posted Plaid projections to canonical Operations. Creates no pending Operations and performs no PFC/category mapping.';

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
