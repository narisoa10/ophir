create or replace function public.plaid_list_sandbox_items_for_webhook_maintenance(
    p_batch_size integer default 20,
    p_offset integer default 0
)
returns table (
    connection_id uuid,
    user_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_batch_size is null
       or p_offset is null
       or p_batch_size < 1
       or p_batch_size > 50
       or p_offset < 0
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    return query
    select plaid_items.id,
           plaid_items.user_id
    from public.plaid_items
    where plaid_items.plaid_environment = 'sandbox'
    order by plaid_items.created_at,
             plaid_items.id
    limit p_batch_size
    offset p_offset;
end;
$$;

revoke all on function public.plaid_list_sandbox_items_for_webhook_maintenance(integer, integer) from public;
revoke all on function public.plaid_list_sandbox_items_for_webhook_maintenance(integer, integer) from anon;
revoke all on function public.plaid_list_sandbox_items_for_webhook_maintenance(integer, integer) from authenticated;
grant execute on function public.plaid_list_sandbox_items_for_webhook_maintenance(integer, integer) to service_role;
