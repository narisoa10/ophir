create table public.plaid_items (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    plaid_environment text not null
        constraint plaid_items_plaid_environment_check
        check (plaid_environment = 'sandbox'),

    plaid_item_id text not null
        constraint plaid_items_plaid_item_id_check
        check (trim(plaid_item_id) <> ''),

    access_token_secret_id uuid not null,

    created_at timestamptz not null default now(),

    constraint plaid_items_environment_item_unique
        unique (plaid_environment, plaid_item_id)
);

alter table public.plaid_items enable row level security;

create policy "plaid_items_select_own"
on public.plaid_items
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.plaid_persist_sandbox_item(
    p_user_id uuid,
    p_plaid_item_id text,
    p_access_token text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_secret_id uuid;
    v_connection_id uuid;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or trim(p_plaid_item_id) = ''
       or p_access_token is null
       or trim(p_access_token) = ''
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    select vault.create_secret(p_access_token) into v_secret_id;

    insert into public.plaid_items (
        user_id,
        plaid_environment,
        plaid_item_id,
        access_token_secret_id
    )
    values (
        p_user_id,
        'sandbox',
        p_plaid_item_id,
        v_secret_id
    )
    returning id into v_connection_id;

    return v_connection_id;
end;
$$;

revoke all on function public.plaid_persist_sandbox_item(uuid, text, text) from public;
revoke all on function public.plaid_persist_sandbox_item(uuid, text, text) from anon;
revoke all on function public.plaid_persist_sandbox_item(uuid, text, text) from authenticated;
grant execute on function public.plaid_persist_sandbox_item(uuid, text, text) to service_role;
