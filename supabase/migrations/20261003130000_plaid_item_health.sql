alter table public.plaid_items
    add column status text not null default 'active',
    add column status_reason text null,
    add column status_changed_at timestamptz not null default now(),
    add column health_observed_at timestamptz null,
    add column consent_expires_at timestamptz null,
    add column pending_disconnect_at timestamptz null;

alter table public.plaid_items
    add constraint plaid_items_status_check
        check (status in ('active', 'login_required')),
    add constraint plaid_items_status_reason_check
        check (
            status_reason is null
            or status_reason in ('login_required', 'consent_expired', 'permission_revoked')
        ),
    add constraint plaid_items_status_reason_consistency_check
        check ((status = 'active') = (status_reason is null));

comment on column public.plaid_items.status is
    'Ophir health state of the Item: active, or login_required when the user must repair it through Link update mode.';

comment on column public.plaid_items.status_reason is
    'Stable internal reason for login_required; null exactly when status is active.';

comment on column public.plaid_items.status_changed_at is
    'When status last changed value. Not touched by observations that keep the same status.';

comment on column public.plaid_items.health_observed_at is
    'Observation time of the last applied health observation; older or equal observations are ignored.';

comment on column public.plaid_items.consent_expires_at is
    'Plaid consent_expiration_time only. Written as-is by /item/get observations and by PENDING_EXPIRATION.';

comment on column public.plaid_items.pending_disconnect_at is
    'Plaid disconnect_time only. Written by PENDING_DISCONNECT; cleared only by a confirmed repair.';

create or replace function public.plaid_record_item_status_observation(
    p_connection_id uuid,
    p_observed_at timestamptz,
    p_status text,
    p_status_reason text,
    p_from_item_get boolean,
    p_consent_expires_at timestamptz,
    p_clear_pending_disconnect boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item public.plaid_items%rowtype;
begin
    if p_connection_id is null
       or p_observed_at is null
       or p_status is null
       or p_status not in ('active', 'login_required')
       or (p_status = 'active') <> (p_status_reason is null)
       or (
           p_status_reason is not null
           and p_status_reason not in ('login_required', 'consent_expired', 'permission_revoked')
       )
       or p_from_item_get is null
       or p_clear_pending_disconnect is null
       or (not p_from_item_get and p_consent_expires_at is not null)
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select *
    into v_item
    from public.plaid_items
    where plaid_items.id = p_connection_id
    for update;

    if not found then
        return null;
    end if;

    if v_item.health_observed_at is not null
       and p_observed_at <= v_item.health_observed_at
    then
        return jsonb_build_object(
            'applied', false,
            'previous_status', v_item.status,
            'status', v_item.status,
            'plaid_item_id', v_item.plaid_item_id
        );
    end if;

    update public.plaid_items
    set status = p_status,
        status_reason = p_status_reason,
        status_changed_at = case
            when plaid_items.status <> p_status then now()
            else plaid_items.status_changed_at
        end,
        health_observed_at = p_observed_at,
        consent_expires_at = case
            when p_from_item_get then p_consent_expires_at
            else plaid_items.consent_expires_at
        end,
        pending_disconnect_at = case
            when p_clear_pending_disconnect then null
            else plaid_items.pending_disconnect_at
        end
    where plaid_items.id = p_connection_id;

    return jsonb_build_object(
        'applied', true,
        'previous_status', v_item.status,
        'status', p_status,
        'plaid_item_id', v_item.plaid_item_id
    );
end;
$$;

comment on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) is
    'Single writer of Item health. Applies an observation only when it is newer than the last applied one. Returns null for an unknown connection. Service-role only.';

revoke all on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) from public;
revoke all on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) from anon;
revoke all on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) from authenticated;
grant execute on function public.plaid_record_item_status_observation(
    uuid, timestamptz, text, text, boolean, timestamptz, boolean
) to service_role;

create or replace function public.plaid_set_item_access_deadline(
    p_external_plaid_item_id text,
    p_kind text,
    p_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_connection_id uuid;
begin
    if p_external_plaid_item_id is null
       or trim(p_external_plaid_item_id) = ''
       or p_kind is null
       or p_kind not in ('pending_disconnect', 'consent_expiration')
       or p_at is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    update public.plaid_items
    set pending_disconnect_at = case
            when p_kind = 'pending_disconnect' then p_at
            else plaid_items.pending_disconnect_at
        end,
        consent_expires_at = case
            when p_kind = 'consent_expiration' then p_at
            else plaid_items.consent_expires_at
        end
    where plaid_items.plaid_environment = 'sandbox'
      and plaid_items.plaid_item_id = trim(p_external_plaid_item_id)
    returning plaid_items.id into v_connection_id;

    if v_connection_id is null then
        return jsonb_build_object('status', 'ignored');
    end if;

    return jsonb_build_object('status', 'applied', 'connection_id', v_connection_id);
end;
$$;

comment on function public.plaid_set_item_access_deadline(text, text, timestamptz) is
    'Records a Plaid access deadline from a verified ITEM webhook: pending_disconnect writes only pending_disconnect_at, consent_expiration writes only consent_expires_at. Service-role only.';

revoke all on function public.plaid_set_item_access_deadline(text, text, timestamptz) from public;
revoke all on function public.plaid_set_item_access_deadline(text, text, timestamptz) from anon;
revoke all on function public.plaid_set_item_access_deadline(text, text, timestamptz) from authenticated;
grant execute on function public.plaid_set_item_access_deadline(text, text, timestamptz) to service_role;

create or replace function public.plaid_resolve_item_connection(
    p_external_plaid_item_id text
)
returns table (
    connection_id uuid,
    user_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if p_external_plaid_item_id is null
       or trim(p_external_plaid_item_id) = ''
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    return query
    select plaid_items.id,
           plaid_items.user_id
    from public.plaid_items
    where plaid_items.plaid_environment = 'sandbox'
      and plaid_items.plaid_item_id = trim(p_external_plaid_item_id);
end;
$$;

comment on function public.plaid_resolve_item_connection(text) is
    'Resolves a verified Plaid external item_id to the Ophir connection and owner. Service-role only.';

revoke all on function public.plaid_resolve_item_connection(text) from public;
revoke all on function public.plaid_resolve_item_connection(text) from anon;
revoke all on function public.plaid_resolve_item_connection(text) from authenticated;
grant execute on function public.plaid_resolve_item_connection(text) to service_role;

create or replace function public.plaid_list_items_for_health_reconcile(
    p_limit integer
)
returns table (
    connection_id uuid,
    user_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if p_limit is null or p_limit < 1 or p_limit > 500 then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    return query
    select plaid_items.id,
           plaid_items.user_id
    from public.plaid_items
    order by plaid_items.health_observed_at asc nulls first,
             plaid_items.created_at asc,
             plaid_items.id asc
    limit p_limit;
end;
$$;

comment on function public.plaid_list_items_for_health_reconcile(integer) is
    'Lists Items for one-off health backfill or operator recovery, never-observed Items first. Service-role only.';

revoke all on function public.plaid_list_items_for_health_reconcile(integer) from public;
revoke all on function public.plaid_list_items_for_health_reconcile(integer) from anon;
revoke all on function public.plaid_list_items_for_health_reconcile(integer) from authenticated;
grant execute on function public.plaid_list_items_for_health_reconcile(integer) to service_role;

create or replace function public.plaid_list_connection_health()
returns table (
    connection_id uuid,
    status text,
    status_reason text,
    status_changed_at timestamptz,
    consent_expires_at timestamptz,
    pending_disconnect_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    select plaid_items.id,
           plaid_items.status,
           plaid_items.status_reason,
           plaid_items.status_changed_at,
           plaid_items.consent_expires_at,
           plaid_items.pending_disconnect_at
    from public.plaid_items
    where plaid_items.user_id = auth.uid()
    order by plaid_items.created_at asc, plaid_items.id asc
$$;

comment on function public.plaid_list_connection_health() is
    'Health of the calling user''s Plaid connections, without secrets or sync internals.';

revoke all on function public.plaid_list_connection_health() from public;
revoke all on function public.plaid_list_connection_health() from anon;
grant execute on function public.plaid_list_connection_health() to authenticated;
grant execute on function public.plaid_list_connection_health() to service_role;

revoke all on table public.plaid_items from anon;
revoke insert, update, delete, truncate, references, trigger
    on table public.plaid_items
    from authenticated;
