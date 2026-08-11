create or replace function public.plaid_claim_transaction_sync_jobs(
    p_batch_size integer default 5,
    p_lease_seconds integer default 600
)
returns table (
    connection_id uuid,
    user_id uuid,
    lease_token uuid,
    claimed_requested_at timestamptz,
    attempt_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_lease_seconds integer;
begin
    if p_batch_size is null
       or p_lease_seconds is null
       or p_batch_size < 1
       or p_batch_size > 5
       or p_lease_seconds < 60
       or p_lease_seconds > 900
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_batch_size := p_batch_size;
    v_lease_seconds := p_lease_seconds;

    return query
    with eligible as (
        select plaid_transaction_sync_jobs.plaid_item_id
        from public.plaid_transaction_sync_jobs
        where (
                plaid_transaction_sync_jobs.status in ('pending', 'retry_wait')
                and plaid_transaction_sync_jobs.next_attempt_at <= now()
            )
            or (
                plaid_transaction_sync_jobs.status = 'processing'
                and plaid_transaction_sync_jobs.lease_expires_at < now()
            )
        order by plaid_transaction_sync_jobs.next_attempt_at,
                 plaid_transaction_sync_jobs.requested_at
        limit v_batch_size
        for update skip locked
    ),
    claimed as (
        update public.plaid_transaction_sync_jobs
        set
            status = 'processing',
            lease_token = gen_random_uuid(),
            lease_expires_at = now() + make_interval(secs => v_lease_seconds),
            attempt_count = public.plaid_transaction_sync_jobs.attempt_count + 1,
            updated_at = now()
        from eligible
        where public.plaid_transaction_sync_jobs.plaid_item_id = eligible.plaid_item_id
        returning
            public.plaid_transaction_sync_jobs.plaid_item_id,
            public.plaid_transaction_sync_jobs.user_id,
            public.plaid_transaction_sync_jobs.lease_token,
            public.plaid_transaction_sync_jobs.requested_at,
            public.plaid_transaction_sync_jobs.attempt_count
    )
    select
        claimed.plaid_item_id as connection_id,
        claimed.user_id,
        claimed.lease_token,
        claimed.requested_at as claimed_requested_at,
        claimed.attempt_count
    from claimed;
end;
$$;

create or replace function public.plaid_validate_transaction_sync_job_lease(
    p_plaid_item_id uuid,
    p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_valid boolean := false;
begin
    if p_plaid_item_id is null or p_lease_token is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select true
    into v_valid
    from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_plaid_item_id
      and status = 'processing'
      and lease_token = p_lease_token
      and lease_expires_at > now();

    return coalesce(v_valid, false);
end;
$$;

create or replace function public.plaid_complete_transaction_sync_job(
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_claimed_requested_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_job public.plaid_transaction_sync_jobs%rowtype;
begin
    if p_plaid_item_id is null
       or p_lease_token is null
       or p_claimed_requested_at is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_job
    from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_plaid_item_id
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

    if v_job.rerun_requested
       or v_job.requested_at > p_claimed_requested_at
    then
        update public.plaid_transaction_sync_jobs
        set
            status = 'pending',
            next_attempt_at = now(),
            rerun_requested = false,
            lease_token = null,
            lease_expires_at = null,
            last_error_code = null,
            updated_at = now()
        where plaid_item_id = p_plaid_item_id;

        return jsonb_build_object('status', 'rerun_scheduled');
    end if;

    delete from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_plaid_item_id;

    return jsonb_build_object('status', 'completed');
end;
$$;

create or replace function public.plaid_drop_transaction_sync_job(
    p_plaid_item_id uuid,
    p_lease_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_job public.plaid_transaction_sync_jobs%rowtype;
begin
    if p_plaid_item_id is null or p_lease_token is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_job
    from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_plaid_item_id
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

    delete from public.plaid_transaction_sync_jobs
    where plaid_item_id = p_plaid_item_id;

    return jsonb_build_object('status', 'dropped');
end;
$$;

create or replace function public.plaid_fail_transaction_sync_job(
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_error_code text,
    p_backoff_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_failed boolean := false;
    v_error_code text;
begin
    if p_plaid_item_id is null
       or p_lease_token is null
       or p_error_code is null
       or trim(p_error_code) = ''
       or p_backoff_seconds is null
       or p_backoff_seconds < 15
       or p_backoff_seconds > 900
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_error_code := left(
        regexp_replace(lower(trim(p_error_code)), '[^a-z0-9_]', '_', 'g'),
        80
    );

    update public.plaid_transaction_sync_jobs
    set
        status = 'retry_wait',
        next_attempt_at = now() + make_interval(secs => p_backoff_seconds),
        lease_token = null,
        lease_expires_at = null,
        last_error_code = v_error_code,
        updated_at = now()
    where plaid_item_id = p_plaid_item_id
      and status = 'processing'
      and lease_token = p_lease_token
      and lease_expires_at > now()
    returning true into v_failed;

    if coalesce(v_failed, false) then
        return jsonb_build_object('status', 'rescheduled');
    end if;

    if exists (
        select 1
        from public.plaid_transaction_sync_jobs
        where plaid_item_id = p_plaid_item_id
    ) then
        return jsonb_build_object('status', 'lease_lost');
    end if;

    return jsonb_build_object('status', 'missing');
end;
$$;

revoke all on function public.plaid_claim_transaction_sync_jobs(integer, integer) from public;
revoke all on function public.plaid_claim_transaction_sync_jobs(integer, integer) from anon;
revoke all on function public.plaid_claim_transaction_sync_jobs(integer, integer) from authenticated;
grant execute on function public.plaid_claim_transaction_sync_jobs(integer, integer) to service_role;

revoke all on function public.plaid_validate_transaction_sync_job_lease(uuid, uuid) from public;
revoke all on function public.plaid_validate_transaction_sync_job_lease(uuid, uuid) from anon;
revoke all on function public.plaid_validate_transaction_sync_job_lease(uuid, uuid) from authenticated;
grant execute on function public.plaid_validate_transaction_sync_job_lease(uuid, uuid) to service_role;

revoke all on function public.plaid_complete_transaction_sync_job(uuid, uuid, timestamptz) from public;
revoke all on function public.plaid_complete_transaction_sync_job(uuid, uuid, timestamptz) from anon;
revoke all on function public.plaid_complete_transaction_sync_job(uuid, uuid, timestamptz) from authenticated;
grant execute on function public.plaid_complete_transaction_sync_job(uuid, uuid, timestamptz) to service_role;

revoke all on function public.plaid_drop_transaction_sync_job(uuid, uuid) from public;
revoke all on function public.plaid_drop_transaction_sync_job(uuid, uuid) from anon;
revoke all on function public.plaid_drop_transaction_sync_job(uuid, uuid) from authenticated;
grant execute on function public.plaid_drop_transaction_sync_job(uuid, uuid) to service_role;

revoke all on function public.plaid_fail_transaction_sync_job(uuid, uuid, text, integer) from public;
revoke all on function public.plaid_fail_transaction_sync_job(uuid, uuid, text, integer) from anon;
revoke all on function public.plaid_fail_transaction_sync_job(uuid, uuid, text, integer) from authenticated;
grant execute on function public.plaid_fail_transaction_sync_job(uuid, uuid, text, integer) to service_role;
