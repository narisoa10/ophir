create or replace function public.plaid_remove_item_local_cleanup(
    p_user_id uuid,
    p_connection_id uuid,
    p_access_token_secret_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_accounts_deleted integer := 0;
    v_plaid_items_deleted integer := 0;
    v_vault_secrets_deleted integer := 0;
begin
    if p_user_id is null
       or p_connection_id is null
       or p_access_token_secret_id is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if not exists (
        select 1
        from public.plaid_items
        where id = p_connection_id
          and user_id = p_user_id
          and access_token_secret_id = p_access_token_secret_id
    ) then
        raise exception 'plaid_item_not_found' using errcode = '22023';
    end if;

    delete from public.accounts
    where plaid_item_id = p_connection_id
      and user_id = p_user_id;
    get diagnostics v_accounts_deleted = row_count;

    delete from public.plaid_items
    where id = p_connection_id
      and user_id = p_user_id
      and access_token_secret_id = p_access_token_secret_id;
    get diagnostics v_plaid_items_deleted = row_count;

    if v_plaid_items_deleted <> 1 then
        raise exception 'plaid_item_cleanup_failed' using errcode = '22023';
    end if;

    delete from vault.secrets
    where id = p_access_token_secret_id;
    get diagnostics v_vault_secrets_deleted = row_count;

    if v_vault_secrets_deleted <> 1 then
        raise exception 'vault_secret_cleanup_failed' using errcode = '22023';
    end if;

    return jsonb_build_object(
        'accounts_deleted', v_accounts_deleted,
        'plaid_items_deleted', v_plaid_items_deleted,
        'vault_secrets_deleted', v_vault_secrets_deleted
    );
end;
$$;

revoke all on function public.plaid_remove_item_local_cleanup(uuid, uuid, uuid) from public;
revoke all on function public.plaid_remove_item_local_cleanup(uuid, uuid, uuid) from anon;
revoke all on function public.plaid_remove_item_local_cleanup(uuid, uuid, uuid) from authenticated;
grant execute on function public.plaid_remove_item_local_cleanup(uuid, uuid, uuid) to service_role;
