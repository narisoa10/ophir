create or replace function public.plaid_apply_pfc_category_mapping_for_item(
    p_user_id uuid,
    p_plaid_item_id uuid,
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
    v_result jsonb;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_batch_size is null
       or p_batch_size < 1
       or p_batch_size > 250
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if not exists (
        select 1
        from public.plaid_items
        where plaid_items.id = p_plaid_item_id
          and plaid_items.user_id = p_user_id
    ) then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    v_batch_size := p_batch_size;

    with locked_candidates as (
        select
            operations.id as operation_id,
            operations.category_id as current_category_id,
            mapped.category_id as mapped_category_id,
            mapped.reason as mapping_reason
        from public.plaid_transaction_operation_projections projection
        join public.operations
          on operations.id = projection.operation_id
         and operations.user_id = projection.user_id
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        cross join lateral public.plaid_map_pfc_v2_to_ophir_category(
            operations.type,
            raw.personal_finance_category_version,
            raw.personal_finance_category_primary,
            raw.personal_finance_category_detailed,
            raw.personal_finance_category_confidence_level
        ) mapped
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.operation_id = operations.id
          and operations.source = 'plaid'
          and operations.category_overridden = false
          and operations.archived_at is null
          and raw.personal_finance_category_version = 'v2'
          and mapped.category_id is not null
          and operations.category_id is distinct from mapped.category_id
        order by operations.created_at, operations.id
        limit v_batch_size
        for update of operations skip locked
    ),
    updated as (
        update public.operations operations
        set category_id = locked_candidates.mapped_category_id
        from locked_candidates
        where operations.id = locked_candidates.operation_id
          and operations.user_id = p_user_id
          and operations.source = 'plaid'
          and operations.category_overridden = false
          and operations.archived_at is null
          and operations.category_id is distinct from locked_candidates.mapped_category_id
        returning operations.id
    ),
    scoped as (
        select
            operations.id as operation_id,
            operations.category_overridden,
            operations.archived_at,
            operations.category_id as current_category_id,
            mapped.category_id as mapped_category_id,
            mapped.reason as mapping_reason
        from public.plaid_transaction_operation_projections projection
        join public.operations
          on operations.id = projection.operation_id
         and operations.user_id = projection.user_id
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        cross join lateral public.plaid_map_pfc_v2_to_ophir_category(
            operations.type,
            raw.personal_finance_category_version,
            raw.personal_finance_category_primary,
            raw.personal_finance_category_detailed,
            raw.personal_finance_category_confidence_level
        ) mapped
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.operation_id = operations.id
          and operations.source = 'plaid'
    ),
    remaining_changes as (
        select 1
        from scoped
        where category_overridden = false
          and archived_at is null
          and mapped_category_id is not null
          and current_category_id is distinct from mapped_category_id
          and not exists (
              select 1
              from locked_candidates
              where locked_candidates.operation_id = scoped.operation_id
          )
        limit 1
    )
    select jsonb_build_object(
        'scanned', count(*),
        'mapped', count(*) filter (
            where category_overridden = false
              and archived_at is null
              and mapped_category_id is not null
        ),
        'updated', (select count(*) from updated),
        'unchanged', count(*) filter (
            where category_overridden = false
              and archived_at is null
              and mapped_category_id is not null
              and current_category_id is not distinct from mapped_category_id
        ),
        'skipped_override', count(*) filter (
            where category_overridden = true
        ),
        'skipped_unmapped', count(*) filter (
            where category_overridden = false
              and (
                  archived_at is not null
                  or mapped_category_id is null
              )
        ),
        'has_more', exists (select 1 from remaining_changes)
    )
    into v_result
    from scoped;

    return coalesce(
        v_result,
        jsonb_build_object(
            'scanned', 0,
            'mapped', 0,
            'updated', 0,
            'unchanged', 0,
            'skipped_override', 0,
            'skipped_unmapped', 0,
            'has_more', false
        )
    );
end;
$$;

comment on function public.plaid_apply_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) is
    'Service-role bounded write path that applies existing safe Plaid PFCv2 category mappings to active Plaid operations for one Item. Updates only operations.category_id and returns aggregate counts.';

revoke all on function public.plaid_apply_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_apply_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_apply_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_apply_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) to service_role;
