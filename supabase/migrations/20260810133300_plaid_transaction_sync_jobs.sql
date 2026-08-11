create table public.plaid_transaction_sync_jobs (
    plaid_item_id uuid primary key,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text not null
        constraint plaid_transaction_sync_jobs_status_check
        check (status in ('pending', 'processing', 'retry_wait')),

    requested_at timestamptz not null default now(),

    next_attempt_at timestamptz not null default now(),

    attempt_count integer not null default 0
        constraint plaid_transaction_sync_jobs_attempt_count_check
        check (attempt_count >= 0),

    rerun_requested boolean not null default false,

    lease_token uuid null,

    lease_expires_at timestamptz null,

    last_error_code text null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_transaction_sync_jobs_item_user_fkey
        foreign key (plaid_item_id, user_id)
        references public.plaid_items(id, user_id)
        on delete cascade
);

comment on table public.plaid_transaction_sync_jobs is
    'Internal durable coalescing queue for Plaid transaction sync work. One row per Plaid Item.';

comment on column public.plaid_transaction_sync_jobs.rerun_requested is
    'Set when a webhook arrives while a worker is processing the same Item, so completion can schedule one more sync instead of losing the update.';

create index plaid_transaction_sync_jobs_next_attempt_at_idx
on public.plaid_transaction_sync_jobs(status, next_attempt_at);

create trigger plaid_transaction_sync_jobs_set_updated_at
before update on public.plaid_transaction_sync_jobs
for each row
execute function public.set_updated_at();

alter table public.plaid_transaction_sync_jobs enable row level security;

revoke all on table public.plaid_transaction_sync_jobs from public, anon, authenticated;

create or replace function public.plaid_enqueue_transaction_sync_job(
    p_external_plaid_item_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_plaid_item_id uuid;
    v_user_id uuid;
    v_existing_status text;
    v_result text := 'accepted';
begin
    if p_external_plaid_item_id is null
       or trim(p_external_plaid_item_id) = ''
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select plaid_items.id,
           plaid_items.user_id
    into v_plaid_item_id,
         v_user_id
    from public.plaid_items
    where plaid_items.plaid_environment = 'sandbox'
      and plaid_items.plaid_item_id = trim(p_external_plaid_item_id);

    if not found then
        return jsonb_build_object('status', 'ignored');
    end if;

    select plaid_transaction_sync_jobs.status
    into v_existing_status
    from public.plaid_transaction_sync_jobs
    where plaid_transaction_sync_jobs.plaid_item_id = v_plaid_item_id
    for update;

    if not found then
        insert into public.plaid_transaction_sync_jobs (
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
            v_plaid_item_id,
            v_user_id,
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
        update public.plaid_transaction_sync_jobs
        set
            requested_at = now(),
            rerun_requested = true
        where plaid_item_id = v_plaid_item_id;
    else
        update public.plaid_transaction_sync_jobs
        set
            status = 'pending',
            requested_at = now(),
            next_attempt_at = least(next_attempt_at, now()),
            rerun_requested = false,
            last_error_code = null
        where plaid_item_id = v_plaid_item_id;
    end if;

    return jsonb_build_object('status', v_result);
end;
$$;

comment on function public.plaid_enqueue_transaction_sync_job(text) is
    'Resolves a verified Plaid external item_id and atomically enqueues or coalesces one transaction sync job. Service-role only.';

revoke all on function public.plaid_enqueue_transaction_sync_job(text) from public;
revoke all on function public.plaid_enqueue_transaction_sync_job(text) from anon;
revoke all on function public.plaid_enqueue_transaction_sync_job(text) from authenticated;
grant execute on function public.plaid_enqueue_transaction_sync_job(text) to service_role;
