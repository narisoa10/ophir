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
begin
    if p_mark_initial_sync_completed is null then
        raise exception 'invalid_input' using errcode = '22023';
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
    'Applies a complete Plaid /transactions/sync batch atomically and can mark initial historical readiness when the server validated HISTORICAL_UPDATE_COMPLETE.';

revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    boolean,
    jsonb,
    jsonb,
    jsonb
) from public;
revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    boolean,
    jsonb,
    jsonb,
    jsonb
) from anon;
revoke all on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    boolean,
    jsonb,
    jsonb,
    jsonb
) from authenticated;
grant execute on function public.plaid_apply_transactions_sync_batch(
    uuid,
    uuid,
    text,
    text,
    boolean,
    jsonb,
    jsonb,
    jsonb
) to service_role;
