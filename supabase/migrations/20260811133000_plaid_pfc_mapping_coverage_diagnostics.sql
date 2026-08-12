create or replace function public.plaid_diagnose_pfc_category_mapping_for_item(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_max_rows integer default 5000
)
returns table (
    operation_type text,
    pfc_primary text,
    pfc_detailed text,
    confidence_level text,
    mapping_reason text,
    count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_max_rows integer;
    v_scoped_rows bigint;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_max_rows is null
       or p_max_rows < 1
       or p_max_rows > 20000
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

    v_max_rows := p_max_rows;

    select count(*)
    into v_scoped_rows
    from public.plaid_transaction_operation_projections projection
    join public.operations
      on operations.id = projection.operation_id
     and operations.user_id = projection.user_id
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    where projection.user_id = p_user_id
      and projection.plaid_item_id = p_plaid_item_id
      and projection.operation_id is not null
      and operations.source = 'plaid'
      and operations.category_overridden = false;

    if v_scoped_rows > v_max_rows then
        raise exception 'diagnostic_scope_too_large' using errcode = '54000';
    end if;

    return query
    with evaluated as (
        select
            operations.type as operation_type,
            raw.personal_finance_category_primary as pfc_primary,
            raw.personal_finance_category_detailed as pfc_detailed,
            raw.personal_finance_category_confidence_level as confidence_level,
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
          and projection.operation_id is not null
          and operations.source = 'plaid'
          and operations.category_overridden = false
    )
    select
        evaluated.operation_type,
        evaluated.pfc_primary,
        evaluated.pfc_detailed,
        evaluated.confidence_level,
        evaluated.mapping_reason,
        count(*)::bigint as count
    from evaluated
    where evaluated.mapping_reason in (
        'unmapped',
        'transfer_excluded',
        'skipped_confidence',
        'type_mismatch'
    )
    group by
        evaluated.operation_type,
        evaluated.pfc_primary,
        evaluated.pfc_detailed,
        evaluated.confidence_level,
        evaluated.mapping_reason
    order by
        count(*) desc,
        evaluated.pfc_primary nulls last,
        evaluated.pfc_detailed nulls last,
        evaluated.operation_type,
        evaluated.confidence_level nulls last,
        evaluated.mapping_reason;
end;
$$;

comment on function public.plaid_diagnose_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) is
    'Service-role read-only aggregate diagnostics for unmapped, confidence-skipped, transfer-excluded, and type-mismatched Plaid PFCv2 category mapping groups on one Item. Returns no transaction, operation, user, merchant, amount, date, account, or payload data.';

revoke all on function public.plaid_diagnose_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_diagnose_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_diagnose_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_diagnose_pfc_category_mapping_for_item(
    uuid,
    uuid,
    integer
) to service_role;
