-- Project A / A2: atomic Plaid connection RPC (database only).
-- Additive. Inert until a caller invokes plaid_connect_item: the exchange handler
-- still persists through plaid_persist_sandbox_item, which is left unchanged as
-- the rollback path.

-- One transaction persists a freshly exchanged Item completely or not at all:
-- Vault secret, plaid_items row, institution, every account of the full
-- /accounts/get snapshot and the initial transaction sync job.
--
-- Outcomes (jsonb `outcome`):
--   created             everything above was written;
--   idempotent_existing this user already owns the connected Item; nothing written;
--   strong_duplicate    an account of the snapshot strongly matches a stored Plaid
--                       account of this user; nothing written.
-- Ambiguous matches never block; they are reported per account in `decisions`.
-- Everything else raises and rolls the whole transaction back, Vault included.
--
-- Account matching is the Level 1 rule of
-- plaid-exchange-public-token/account_identity.ts (matchCandidate/classifyAccount),
-- over the same candidate pool: accounts of this user's Items whose institution
-- has the same plaid_institution_id. Stored accounts with the same
-- plaid_account_id are added to the pool whatever their institution, so the
-- plain inserts below never collide with, or re-home, an existing account.
create or replace function public.plaid_connect_item(
    p_user_id uuid,
    p_plaid_environment text,
    p_plaid_item_id text,
    p_access_token text,
    p_plaid_institution_id text,
    p_institution_name text,
    p_logo_base64 text,
    p_primary_color text,
    p_url text,
    p_balance_fetched_at timestamptz,
    p_accounts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_environment text := nullif(trim(p_plaid_environment), '');
    v_plaid_item_id text := nullif(trim(p_plaid_item_id), '');
    v_plaid_institution_id text := nullif(trim(p_plaid_institution_id), '');
    v_institution_name text := nullif(trim(p_institution_name), '');
    v_account jsonb;
    v_plaid_account_id text;
    v_name text;
    v_plaid_type text;
    v_currency_code text;
    v_unofficial_currency_code text;
    v_existing_id uuid;
    v_existing_user_id uuid;
    v_existing_disconnected_at timestamptz;
    v_decisions jsonb;
    v_blocked boolean;
    v_secret_id uuid;
    v_connection_id uuid;
    v_institution_id uuid;
    v_account_count integer;
    v_enqueue jsonb;
begin
    if p_user_id is null
       or v_environment is null
       or v_plaid_item_id is null
       or p_access_token is null
       or trim(p_access_token) = ''
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if v_environment <> 'sandbox' then
        raise exception 'unsupported_plaid_environment' using errcode = '22023';
    end if;

    if not exists (
        select 1
        from public.profiles
        where profiles.id = p_user_id
    ) then
        raise exception 'user_not_found' using errcode = '22023';
    end if;

    -- An Item without accounts could never sync (plaid_transaction_account_not_found).
    if p_accounts is null
       or jsonb_typeof(p_accounts) <> 'array'
       or jsonb_array_length(p_accounts) = 0
    then
        raise exception 'accounts_required' using errcode = '22023';
    end if;

    for v_account in
        select value
        from jsonb_array_elements(p_accounts)
    loop
        if jsonb_typeof(v_account) <> 'object' then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;

        v_plaid_account_id := nullif(trim(v_account ->> 'plaid_account_id'), '');
        v_name := nullif(trim(v_account ->> 'name'), '');
        v_plaid_type := nullif(trim(v_account ->> 'plaid_type'), '');

        if v_plaid_account_id is null or v_name is null or v_plaid_type is null then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;

        v_currency_code := nullif(trim(v_account ->> 'currency_code'), '');
        v_unofficial_currency_code := nullif(
            trim(v_account ->> 'unofficial_currency_code'),
            ''
        );

        if v_currency_code is null and v_unofficial_currency_code is null then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;

        if v_currency_code is not null and char_length(v_currency_code) <> 3 then
            raise exception 'invalid_plaid_account_payload' using errcode = '22023';
        end if;
    end loop;

    if (
        select count(distinct trim(payload.value ->> 'plaid_account_id'))
        from jsonb_array_elements(p_accounts) as payload(value)
    ) <> jsonb_array_length(p_accounts) then
        raise exception 'invalid_plaid_account_payload' using errcode = '22023';
    end if;

    -- Namespace 872514004 = Plaid connect. Serializes every connection of one user,
    -- so the checks below and the writes after them see one consistent state.
    perform pg_catalog.pg_advisory_xact_lock(
        872514004,
        pg_catalog.hashtext(p_user_id::text)
    );

    select plaid_items.id,
           plaid_items.user_id,
           plaid_items.disconnected_at
    into v_existing_id,
         v_existing_user_id,
         v_existing_disconnected_at
    from public.plaid_items
    where plaid_items.plaid_environment = v_environment
      and plaid_items.plaid_item_id = v_plaid_item_id;

    if found then
        if v_existing_user_id <> p_user_id then
            raise exception 'plaid_item_conflict' using errcode = '23505';
        end if;

        if v_existing_disconnected_at is not null then
            raise exception 'plaid_item_disconnected' using errcode = '22023';
        end if;

        return jsonb_build_object(
            'outcome', 'idempotent_existing',
            'connection_id', v_existing_id
        );
    end if;

    with incoming as (
        select
            (payload.ordinality - 1)::integer as account_index,
            trim(payload.value ->> 'plaid_account_id') as plaid_account_id,
            trim(payload.value ->> 'name') as name,
            nullif(trim(payload.value ->> 'mask'), '') as mask,
            nullif(trim(payload.value ->> 'plaid_type'), '') as plaid_type,
            nullif(trim(payload.value ->> 'plaid_subtype'), '') as plaid_subtype
        from jsonb_array_elements(p_accounts) with ordinality as payload(value, ordinality)
    ),
    existing as (
        select
            nullif(trim(accounts.plaid_account_id), '') as plaid_account_id,
            nullif(trim(accounts.name), '') as name,
            nullif(trim(accounts.official_name), '') as official_name,
            nullif(trim(accounts.mask), '') as mask,
            nullif(trim(accounts.plaid_type), '') as plaid_type,
            nullif(trim(accounts.plaid_subtype), '') as plaid_subtype,
            plaid_items.disconnected_at is not null as item_disconnected
        from public.accounts
        join public.plaid_items
          on plaid_items.id = accounts.plaid_item_id
         and plaid_items.user_id = p_user_id
        where accounts.user_id = p_user_id
          and (
              accounts.plaid_item_id in (
                  select institutions.plaid_item_id
                  from public.institutions
                  where institutions.user_id = p_user_id
                    and v_plaid_institution_id is not null
                    and institutions.plaid_institution_id = v_plaid_institution_id
              )
              or accounts.plaid_account_id in (
                  select incoming.plaid_account_id
                  from incoming
              )
          )
    ),
    matches as (
        select
            incoming.account_index,
            existing.item_disconnected,
            case
                when existing.plaid_account_id is not null
                     and existing.plaid_account_id = incoming.plaid_account_id
                    then 'strong'
                when not coalesce(incoming.name = existing.name, false)
                     and not coalesce(incoming.name = existing.official_name, false)
                    then 'none'
                when incoming.mask is null or existing.mask is null
                    then 'ambiguous'
                when incoming.mask <> existing.mask
                    then case
                        when coalesce(incoming.plaid_type <> existing.plaid_type, false)
                             or coalesce(incoming.plaid_subtype <> existing.plaid_subtype, false)
                            then 'none'
                        else 'ambiguous'
                    end
                else case
                    when coalesce(incoming.plaid_type <> existing.plaid_type, false)
                         or coalesce(incoming.plaid_subtype <> existing.plaid_subtype, false)
                        then 'ambiguous'
                    else 'strong'
                end
            end as match
        from incoming
        cross join existing
    ),
    decisions as (
        select
            incoming.account_index,
            case
                when bool_or(matches.match = 'strong' and not matches.item_disconnected)
                    then 'duplicate'
                when bool_or(matches.match = 'strong' and matches.item_disconnected)
                    then 'disconnected_existing'
                when bool_or(matches.match = 'ambiguous')
                    then 'ambiguous'
                else 'new'
            end as decision
        from incoming
        left join matches
          on matches.account_index = incoming.account_index
        group by incoming.account_index
    )
    select
        jsonb_agg(
            jsonb_build_object('index', decisions.account_index, 'decision', decisions.decision)
            order by decisions.account_index
        ),
        bool_or(decisions.decision in ('duplicate', 'disconnected_existing'))
    into v_decisions,
         v_blocked
    from decisions;

    if v_blocked then
        return jsonb_build_object(
            'outcome', 'strong_duplicate',
            'decisions', v_decisions
        );
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
        v_environment,
        v_plaid_item_id,
        v_secret_id
    )
    returning id into v_connection_id;

    -- institutions.name is required; without it the connection proceeds without an
    -- institution row, and a later accounts refresh creates it.
    if v_institution_name is not null then
        insert into public.institutions (
            user_id,
            plaid_item_id,
            plaid_institution_id,
            name,
            logo_base64,
            primary_color,
            url
        )
        values (
            p_user_id,
            v_connection_id,
            v_plaid_institution_id,
            v_institution_name,
            nullif(trim(p_logo_base64), ''),
            nullif(trim(p_primary_color), ''),
            nullif(trim(p_url), '')
        )
        returning id into v_institution_id;
    end if;

    insert into public.accounts (
        user_id,
        name,
        currency_code,
        unofficial_currency_code,
        plaid_item_id,
        institution_id,
        plaid_account_id,
        official_name,
        mask,
        plaid_type,
        plaid_subtype,
        current_balance,
        available_balance,
        balance_fetched_at,
        persistent_account_id
    )
    select
        p_user_id,
        trim(payload.value ->> 'name'),
        nullif(trim(payload.value ->> 'currency_code'), ''),
        nullif(trim(payload.value ->> 'unofficial_currency_code'), ''),
        v_connection_id,
        v_institution_id,
        trim(payload.value ->> 'plaid_account_id'),
        nullif(trim(payload.value ->> 'official_name'), ''),
        nullif(trim(payload.value ->> 'mask'), ''),
        trim(payload.value ->> 'plaid_type'),
        nullif(trim(payload.value ->> 'plaid_subtype'), ''),
        nullif(payload.value ->> 'current_balance', '')::numeric(14, 2),
        nullif(payload.value ->> 'available_balance', '')::numeric(14, 2),
        p_balance_fetched_at,
        case
            when jsonb_typeof(payload.value -> 'persistent_account_id') = 'string'
                then nullif(trim(payload.value ->> 'persistent_account_id'), '')
            else null
        end
    from jsonb_array_elements(p_accounts) with ordinality as payload(value, ordinality)
    order by payload.ordinality;

    get diagnostics v_account_count = row_count;

    v_enqueue := public.plaid_enqueue_transaction_sync_job(v_plaid_item_id);

    if v_enqueue ->> 'status' is distinct from 'accepted' then
        raise exception 'transaction_sync_enqueue_failed' using errcode = 'P0001';
    end if;

    return jsonb_build_object(
        'outcome', 'created',
        'connection_id', v_connection_id,
        'accounts_persisted', v_account_count,
        'institution_persisted', v_institution_id is not null,
        'decisions', v_decisions
    );
end;
$$;

comment on function public.plaid_connect_item(
    uuid, text, text, text, text, text, text, text, text, timestamptz, jsonb
) is
    'Atomically persists a freshly exchanged Plaid Item: Vault secret, plaid_items row, institution, the full /accounts/get account snapshot and the initial transaction sync job, under a per-user advisory lock. Returns outcome created, idempotent_existing (Item already owned by this user; nothing written) or strong_duplicate (nothing written), with per-account decisions; ambiguous matches do not block. Never returns the access token or Vault ids. Service-role only; p_user_id must be verified by the caller.';

revoke all on function public.plaid_connect_item(
    uuid, text, text, text, text, text, text, text, text, timestamptz, jsonb
) from public;
revoke all on function public.plaid_connect_item(
    uuid, text, text, text, text, text, text, text, text, timestamptz, jsonb
) from anon;
revoke all on function public.plaid_connect_item(
    uuid, text, text, text, text, text, text, text, text, timestamptz, jsonb
) from authenticated;
grant execute on function public.plaid_connect_item(
    uuid, text, text, text, text, text, text, text, text, timestamptz, jsonb
) to service_role;
