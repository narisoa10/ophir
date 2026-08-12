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

    drop table if exists pg_temp.plaid_materialized_operation_source_sync_batch;

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
            when raw.removed_at is not null then coalesce(operations.archived_at, raw.removed_at)
            when raw.pending = false and raw.amount = 0 then coalesce(operations.archived_at, now())
            else null
        end as expected_archived_at,
        operations.archived_at as current_archived_at,
        operations.category_id as current_category_id,
        operations.category_overridden,
        public.ophir_operation_category_type(operations.category_id) as current_category_type,
        (
            raw.removed_at is null
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
            )
            and operations.archived_at is null
        ) as archive_needed,
        (
            raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.archived_at is not null
        ) as unarchive_needed,
        (
            raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.category_overridden = true
            and operations.category_id is not null
            and public.ophir_operation_category_type(operations.category_id)
                is distinct from case when raw.amount > 0 then 'expense' else 'income' end
        ) as override_invalidated
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
              raw.removed_at is null
              and raw.pending = false
              and raw.amount <> 0
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
    order by raw.date, raw.transaction_id
    limit v_batch_size
    for update of projection, operations skip locked;

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
                  raw.removed_at is null
                  and raw.pending = false
                  and raw.amount <> 0
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

comment on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role convergence from authoritative raw Plaid transaction lifecycle to already materialized Plaid Operations. Updates source-owned Operation fields and server-owned archive state only.';

revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;
