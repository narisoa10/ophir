create table public.plaid_transaction_sync_leases (
    plaid_item_id uuid primary key,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    owner_token uuid not null,

    expires_at timestamptz not null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_transaction_sync_leases_item_user_fkey
        foreign key (plaid_item_id, user_id)
        references public.plaid_items(id, user_id)
        on delete cascade
);

comment on table public.plaid_transaction_sync_leases is
    'Short-lived per-Plaid-Item lease for server-side /transactions/sync pagination. Service-role RPC access only.';

create index plaid_transaction_sync_leases_expires_at_idx
on public.plaid_transaction_sync_leases(expires_at);

create trigger plaid_transaction_sync_leases_set_updated_at
before update on public.plaid_transaction_sync_leases
for each row
execute function public.set_updated_at();

alter table public.plaid_transaction_sync_leases enable row level security;

revoke all on table public.plaid_transaction_sync_leases from public, anon, authenticated;

create or replace function public.plaid_acquire_transactions_sync_lease(
    p_user_id uuid,
    p_connection_id uuid,
    p_owner_token uuid,
    p_lease_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_original_cursor text;
    v_plaid_environment text;
    v_expires_at timestamptz;
    v_acquired boolean := false;
begin
    if p_user_id is null
       or p_connection_id is null
       or p_owner_token is null
       or p_lease_seconds is null
       or p_lease_seconds < 30
       or p_lease_seconds > 900
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select plaid_items.transactions_cursor,
           plaid_items.plaid_environment
    into v_original_cursor,
         v_plaid_environment
    from public.plaid_items
    where plaid_items.id = p_connection_id
      and plaid_items.user_id = p_user_id;

    if not found then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    v_expires_at := now() + make_interval(secs => p_lease_seconds);

    insert into public.plaid_transaction_sync_leases (
        plaid_item_id,
        user_id,
        owner_token,
        expires_at
    )
    values (
        p_connection_id,
        p_user_id,
        p_owner_token,
        v_expires_at
    )
    on conflict (plaid_item_id) do update
    set
        user_id = excluded.user_id,
        owner_token = excluded.owner_token,
        expires_at = excluded.expires_at,
        updated_at = now()
    where public.plaid_transaction_sync_leases.expires_at <= now()
       or public.plaid_transaction_sync_leases.owner_token = excluded.owner_token
    returning true into v_acquired;

    if v_acquired is not true then
        return jsonb_build_object(
            'acquired', false
        );
    end if;

    return jsonb_build_object(
        'acquired', true,
        'original_cursor', v_original_cursor,
        'plaid_environment', v_plaid_environment,
        'lease_expires_at', v_expires_at
    );
end;
$$;

create or replace function public.plaid_renew_transactions_sync_lease(
    p_user_id uuid,
    p_connection_id uuid,
    p_owner_token uuid,
    p_lease_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_renewed boolean := false;
begin
    if p_user_id is null
       or p_connection_id is null
       or p_owner_token is null
       or p_lease_seconds is null
       or p_lease_seconds < 30
       or p_lease_seconds > 900
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    update public.plaid_transaction_sync_leases
    set
        expires_at = now() + make_interval(secs => p_lease_seconds),
        updated_at = now()
    where plaid_item_id = p_connection_id
      and user_id = p_user_id
      and owner_token = p_owner_token
      and expires_at > now()
    returning true into v_renewed;

    return coalesce(v_renewed, false);
end;
$$;

create or replace function public.plaid_release_transactions_sync_lease(
    p_user_id uuid,
    p_connection_id uuid,
    p_owner_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_released boolean := false;
begin
    if p_user_id is null
       or p_connection_id is null
       or p_owner_token is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    delete from public.plaid_transaction_sync_leases
    where plaid_item_id = p_connection_id
      and user_id = p_user_id
      and owner_token = p_owner_token
    returning true into v_released;

    return coalesce(v_released, false);
end;
$$;

revoke all on function public.plaid_acquire_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_acquire_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_acquire_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_acquire_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;

revoke all on function public.plaid_renew_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_renew_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_renew_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_renew_transactions_sync_lease(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;

revoke all on function public.plaid_release_transactions_sync_lease(
    uuid,
    uuid,
    uuid
) from public;
revoke all on function public.plaid_release_transactions_sync_lease(
    uuid,
    uuid,
    uuid
) from anon;
revoke all on function public.plaid_release_transactions_sync_lease(
    uuid,
    uuid,
    uuid
) from authenticated;
grant execute on function public.plaid_release_transactions_sync_lease(
    uuid,
    uuid,
    uuid
) to service_role;
