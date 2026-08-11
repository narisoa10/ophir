create or replace function public.plaid_renew_transaction_sync_job_lease(
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_lease_seconds integer default 900
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_renewed boolean := false;
begin
    if p_plaid_item_id is null
       or p_lease_token is null
       or p_lease_seconds is null
       or p_lease_seconds < 60
       or p_lease_seconds > 900
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    update public.plaid_transaction_sync_jobs
    set
        lease_expires_at = now() + make_interval(secs => p_lease_seconds),
        updated_at = now()
    where plaid_item_id = p_plaid_item_id
      and status = 'processing'
      and lease_token = p_lease_token
      and lease_expires_at > now()
    returning true into v_renewed;

    return coalesce(v_renewed, false);
end;
$$;

revoke all on function public.plaid_renew_transaction_sync_job_lease(uuid, uuid, integer) from public;
revoke all on function public.plaid_renew_transaction_sync_job_lease(uuid, uuid, integer) from anon;
revoke all on function public.plaid_renew_transaction_sync_job_lease(uuid, uuid, integer) from authenticated;
grant execute on function public.plaid_renew_transaction_sync_job_lease(uuid, uuid, integer) to service_role;
