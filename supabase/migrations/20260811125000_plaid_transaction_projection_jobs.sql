create table public.plaid_transaction_projection_jobs (
    plaid_item_id uuid primary key,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text not null
        constraint plaid_transaction_projection_jobs_status_check
        check (status in ('pending', 'processing', 'retry_wait')),

    requested_at timestamptz not null default now(),

    next_attempt_at timestamptz not null default now(),

    attempt_count integer not null default 0
        constraint plaid_transaction_projection_jobs_attempt_count_check
        check (attempt_count >= 0),

    rerun_requested boolean not null default false,

    lease_token uuid null,

    lease_expires_at timestamptz null,

    last_error_code text null
        constraint plaid_transaction_projection_jobs_last_error_code_check
        check (
            last_error_code is null
            or trim(last_error_code) <> ''
        ),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_transaction_projection_jobs_item_user_fkey
        foreign key (plaid_item_id, user_id)
        references public.plaid_items(id, user_id)
        on delete cascade
);

comment on table public.plaid_transaction_projection_jobs is
    'Internal durable coalescing queue for Plaid transaction projection work. One row per Plaid Item; no Plaid credentials or transaction payloads are stored.';

comment on column public.plaid_transaction_projection_jobs.rerun_requested is
    'Set when raw Plaid transaction changes are committed while a projection worker is processing the same Item, so completion schedules one more projection pass instead of losing the wakeup.';

create index plaid_transaction_projection_jobs_next_attempt_at_idx
on public.plaid_transaction_projection_jobs(status, next_attempt_at, requested_at, plaid_item_id);

create trigger plaid_transaction_projection_jobs_set_updated_at
before update on public.plaid_transaction_projection_jobs
for each row
execute function public.set_updated_at();

alter table public.plaid_transaction_projection_jobs enable row level security;

revoke all on table public.plaid_transaction_projection_jobs
from public, anon, authenticated;

grant select, insert, update, delete on table public.plaid_transaction_projection_jobs
to service_role;

create or replace function public.plaid_enqueue_transaction_projection_job(
    p_user_id uuid,
    p_plaid_item_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_existing_status text;
    v_result text := 'accepted';
begin
    if p_user_id is null
       or p_plaid_item_id is null
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

    select plaid_transaction_projection_jobs.status
    into v_existing_status
    from public.plaid_transaction_projection_jobs
    where plaid_transaction_projection_jobs.plaid_item_id = p_plaid_item_id
    for update;

    if not found then
        insert into public.plaid_transaction_projection_jobs (
            plaid_item_id,
            user_id,
            status,
            requested_at,
            next_attempt_at,
            attempt_count,
            rerun_requested,
            lease_token,
            lease_expires_at,
            last_error_code
        )
        values (
            p_plaid_item_id,
            p_user_id,
            'pending',
            now(),
            now(),
            0,
            false,
            null,
            null,
            null
        );

        return jsonb_build_object('status', v_result);
    end if;

    v_result := 'coalesced';

    if v_existing_status = 'processing' then
        update public.plaid_transaction_projection_jobs
        set
            requested_at = now(),
            rerun_requested = true,
            updated_at = now()
        where plaid_item_id = p_plaid_item_id;
    else
        update public.plaid_transaction_projection_jobs
        set
            status = 'pending',
            requested_at = now(),
            next_attempt_at = least(next_attempt_at, now()),
            rerun_requested = false,
            last_error_code = null,
            updated_at = now()
        where plaid_item_id = p_plaid_item_id;
    end if;

    return jsonb_build_object('status', v_result);
end;
$$;

comment on function public.plaid_enqueue_transaction_projection_job(uuid, uuid) is
    'Atomically enqueues or coalesces one Plaid transaction projection job after raw transaction changes are committed in the same DB transaction. Service-role only.';

create or replace function public.plaid_claim_transaction_projection_jobs(
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
        select plaid_transaction_projection_jobs.plaid_item_id
        from public.plaid_transaction_projection_jobs
        where (
                plaid_transaction_projection_jobs.status in ('pending', 'retry_wait')
                and plaid_transaction_projection_jobs.next_attempt_at <= now()
            )
            or (
                plaid_transaction_projection_jobs.status = 'processing'
                and plaid_transaction_projection_jobs.lease_expires_at < now()
            )
        order by plaid_transaction_projection_jobs.next_attempt_at,
                 plaid_transaction_projection_jobs.requested_at,
                 plaid_transaction_projection_jobs.plaid_item_id
        limit v_batch_size
        for update skip locked
    ),
    claimed as (
        update public.plaid_transaction_projection_jobs
        set
            status = 'processing',
            lease_token = gen_random_uuid(),
            lease_expires_at = now() + make_interval(secs => v_lease_seconds),
            attempt_count = public.plaid_transaction_projection_jobs.attempt_count + 1,
            updated_at = now()
        from eligible
        where public.plaid_transaction_projection_jobs.plaid_item_id = eligible.plaid_item_id
        returning
            public.plaid_transaction_projection_jobs.plaid_item_id,
            public.plaid_transaction_projection_jobs.user_id,
            public.plaid_transaction_projection_jobs.lease_token,
            public.plaid_transaction_projection_jobs.requested_at,
            public.plaid_transaction_projection_jobs.attempt_count
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

create or replace function public.plaid_complete_transaction_projection_job(
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
    v_job public.plaid_transaction_projection_jobs%rowtype;
begin
    if p_plaid_item_id is null
       or p_lease_token is null
       or p_claimed_requested_at is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_job
    from public.plaid_transaction_projection_jobs
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
        update public.plaid_transaction_projection_jobs
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

    delete from public.plaid_transaction_projection_jobs
    where plaid_item_id = p_plaid_item_id;

    return jsonb_build_object('status', 'completed');
end;
$$;

create or replace function public.plaid_fail_transaction_projection_job(
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
       or p_backoff_seconds > 3600
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_error_code := left(
        regexp_replace(lower(trim(p_error_code)), '[^a-z0-9_]', '_', 'g'),
        80
    );

    update public.plaid_transaction_projection_jobs
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
        from public.plaid_transaction_projection_jobs
        where plaid_item_id = p_plaid_item_id
    ) then
        return jsonb_build_object('status', 'lease_lost');
    end if;

    return jsonb_build_object('status', 'missing');
end;
$$;

create or replace function public.plaid_renew_transaction_projection_job_lease(
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

    update public.plaid_transaction_projection_jobs
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
    v_added_count integer;
    v_modified_count integer;
    v_removed_count integer;
    v_known_removed_transaction boolean := false;
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

    v_added_count := coalesce((v_result ->> 'added_count')::integer, 0);
    v_modified_count := coalesce((v_result ->> 'modified_count')::integer, 0);
    v_removed_count := coalesce((v_result ->> 'removed_count')::integer, 0);

    if v_removed_count > 0 then
        select exists (
            select 1
            from jsonb_array_elements(p_removed) removed_transaction(value)
            join public.plaid_transactions
              on plaid_transactions.plaid_item_id = p_connection_id
             and plaid_transactions.user_id = p_user_id
             and plaid_transactions.transaction_id = nullif(
                 trim(removed_transaction.value ->> 'transaction_id'),
                 ''
             )
        )
        into v_known_removed_transaction;
    end if;

    if v_added_count > 0
       or v_modified_count > 0
       or v_known_removed_transaction
    then
        perform public.plaid_enqueue_transaction_projection_job(
            p_user_id,
            p_connection_id
        );
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
    'Applies a complete Plaid /transactions/sync batch atomically, marks initial readiness when requested, and enqueues projection work only when raw transaction deltas were persisted.';

revoke all on function public.plaid_enqueue_transaction_projection_job(uuid, uuid) from public;
revoke all on function public.plaid_enqueue_transaction_projection_job(uuid, uuid) from anon;
revoke all on function public.plaid_enqueue_transaction_projection_job(uuid, uuid) from authenticated;
grant execute on function public.plaid_enqueue_transaction_projection_job(uuid, uuid) to service_role;

revoke all on function public.plaid_claim_transaction_projection_jobs(integer, integer) from public;
revoke all on function public.plaid_claim_transaction_projection_jobs(integer, integer) from anon;
revoke all on function public.plaid_claim_transaction_projection_jobs(integer, integer) from authenticated;
grant execute on function public.plaid_claim_transaction_projection_jobs(integer, integer) to service_role;

revoke all on function public.plaid_complete_transaction_projection_job(uuid, uuid, timestamptz) from public;
revoke all on function public.plaid_complete_transaction_projection_job(uuid, uuid, timestamptz) from anon;
revoke all on function public.plaid_complete_transaction_projection_job(uuid, uuid, timestamptz) from authenticated;
grant execute on function public.plaid_complete_transaction_projection_job(uuid, uuid, timestamptz) to service_role;

revoke all on function public.plaid_fail_transaction_projection_job(uuid, uuid, text, integer) from public;
revoke all on function public.plaid_fail_transaction_projection_job(uuid, uuid, text, integer) from anon;
revoke all on function public.plaid_fail_transaction_projection_job(uuid, uuid, text, integer) from authenticated;
grant execute on function public.plaid_fail_transaction_projection_job(uuid, uuid, text, integer) to service_role;

revoke all on function public.plaid_renew_transaction_projection_job_lease(uuid, uuid, integer) from public;
revoke all on function public.plaid_renew_transaction_projection_job_lease(uuid, uuid, integer) from anon;
revoke all on function public.plaid_renew_transaction_projection_job_lease(uuid, uuid, integer) from authenticated;
grant execute on function public.plaid_renew_transaction_projection_job_lease(uuid, uuid, integer) to service_role;

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
