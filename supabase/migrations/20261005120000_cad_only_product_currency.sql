-- CAD-only product currency: defaults and creation paths.
-- Additive. No existing row is read or changed: profiles, budgets and
-- operations that already carry another currency are left for a separate,
-- preflighted remediation (supabase/validation/currency_cad_only_preflight.sql).
-- Plaid raw fields (accounts.currency_code, accounts.unofficial_currency_code,
-- plaid_transactions.iso_currency_code / unofficial_currency_code) keep the
-- currency Plaid reports.

-- ---------------------------------------------------------------------------
-- 1) Product currency
-- ---------------------------------------------------------------------------

create or replace function public.product_currency_code()
returns char(3)
language sql
immutable
parallel safe
set search_path = ''
as $$
    select 'CAD'::char(3);
$$;

comment on function public.product_currency_code() is
    'The only currency Ophir supports. Client counterpart: productCurrencyCode in lib/core/currency/product_currency.dart.';

-- ---------------------------------------------------------------------------
-- 2) New profiles
-- ---------------------------------------------------------------------------

alter table public.profiles
    alter column currency_code set default public.product_currency_code();

-- The column default is the single source of a new profile's currency.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (
        id,
        email,
        full_name,
        avatar_url,
        locale,
        timezone
    )
    values (
        new.id,
        coalesce(new.email, ''),
        coalesce(
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'name'
        ),
        new.raw_user_meta_data ->> 'avatar_url',
        coalesce(new.raw_user_meta_data ->> 'locale', 'en'),
        'UTC'
    )
    on conflict (id) do update
    set
        email = excluded.email,
        full_name = coalesce(public.profiles.full_name, excluded.full_name),
        avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url);

    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Legacy materializer
-- ---------------------------------------------------------------------------

-- Never called and not runnable (it reads plaid_transactions.plaid_transaction_id
-- and archive_plaid_bank_sync_operation, neither of which exists), but it would
-- label a transaction without an ISO currency as CAD.
drop function if exists public.materialize_plaid_operation(uuid, uuid, text);

-- ---------------------------------------------------------------------------
-- 4) Materialize: only product-currency transactions become Operations
-- ---------------------------------------------------------------------------

-- A posted transaction whose currency is not the product currency (including
-- one with only an unofficial currency) is suppressed as unsupported_currency.
-- The raw row keeps its currency and no Operation is created, so it never
-- reaches balances or totals. Like zero_amount, reconcile resets the row to
-- posted_ready and the next materialization suppresses it again.
-- Body otherwise identical to 20261003150000_plaid_item_disconnect_delete_lifecycle.sql.

create or replace function public.plaid_materialize_transaction_operations(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_batch_size integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_job public.plaid_transaction_projection_jobs%rowtype;
    v_materialized integer := 0;
    v_suppressed_zero_amount integer := 0;
    v_suppressed_canonical_secondary integer := 0;
    v_suppressed_unsupported_currency integer := 0;
    v_has_more boolean := false;
begin
    if p_user_id is null
       or p_plaid_item_id is null
       or p_lease_token is null
       or p_batch_size is null
       or p_batch_size < 1
       or p_batch_size > 250
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    v_batch_size := p_batch_size;

    select *
    into v_job
    from public.plaid_transaction_projection_jobs
    where plaid_item_id = p_plaid_item_id
      and user_id = p_user_id
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

    if not exists (
        select 1
        from public.plaid_items
        where plaid_items.id = p_plaid_item_id
          and plaid_items.user_id = p_user_id
    ) then
        return jsonb_build_object('status', 'missing_item');
    end if;

    drop table if exists pg_temp.plaid_operation_materialize_batch;

    create temporary table pg_temp.plaid_operation_materialize_batch (
        projection_id uuid primary key,
        operation_id uuid null,
        user_id uuid not null,
        from_account_id uuid not null,
        operation_type text not null,
        operation_amount numeric(14, 2) not null,
        currency_code text null,
        occurred_at date not null,
        note text null,
        raw_amount numeric not null,
        canonical_suppressed_reason text null,
        is_canonical_secondary boolean not null default false
    ) on commit drop;

    insert into pg_temp.plaid_operation_materialize_batch (
        projection_id,
        operation_id,
        user_id,
        from_account_id,
        operation_type,
        operation_amount,
        currency_code,
        occurred_at,
        note,
        raw_amount,
        canonical_suppressed_reason,
        is_canonical_secondary
    )
    select
        projection.id,
        case
            when raw.amount = 0 then null
            else gen_random_uuid()
        end as operation_id,
        raw.user_id,
        raw.account_id,
        case
            when raw.amount > 0 then 'expense'
            else 'income'
        end as operation_type,
        round(abs(raw.amount), 2)::numeric(14, 2) as operation_amount,
        upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code)) as currency_code,
        raw.date as occurred_at,
        nullif(trim(coalesce(raw.merchant_name, raw.name)), '') as note,
        raw.amount as raw_amount,
        null as canonical_suppressed_reason,
        false as is_canonical_secondary
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id
    where projection.user_id = p_user_id
      and projection.plaid_item_id = p_plaid_item_id
      and projection.state = 'posted_ready'
      and projection.operation_id is null
      and raw.pending = false
      and raw.removed_at is null
    order by raw.date, raw.transaction_id
    limit v_batch_size
    for update of projection skip locked;

    -- Serialize with Stage C linking: lock involved accounts in deterministic id order.
    perform locked.id
    from public.accounts as locked
    where locked.user_id = p_user_id
      and locked.id in (
          select distinct batch.from_account_id
          from pg_temp.plaid_operation_materialize_batch batch
      )
    order by locked.id
    for update;

    update pg_temp.plaid_operation_materialize_batch batch
    set canonical_suppressed_reason = gate.reason,
        is_canonical_secondary = true
    from (
        select candidate.projection_id,
               public.plaid_canonical_suppression_reason(
                   candidate.user_id,
                   candidate.from_account_id,
                   null
               ) as reason
        from pg_temp.plaid_operation_materialize_batch candidate
    ) gate
    where gate.projection_id = batch.projection_id
      and gate.reason is not null;

    -- Secondary wins over unsupported_currency, which wins over zero_amount.
    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = batch.canonical_suppressed_reason,
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and batch.is_canonical_secondary;

    get diagnostics v_suppressed_canonical_secondary = row_count;

    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = 'unsupported_currency',
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and not batch.is_canonical_secondary
      and batch.currency_code is distinct from public.product_currency_code();

    get diagnostics v_suppressed_unsupported_currency = row_count;

    update public.plaid_transaction_operation_projections projection
    set
        state = 'suppressed',
        suppressed_reason = 'zero_amount',
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and not batch.is_canonical_secondary
      and batch.currency_code = public.product_currency_code()
      and batch.raw_amount = 0;

    get diagnostics v_suppressed_zero_amount = row_count;

    insert into public.operations (
        id,
        user_id,
        from_account_id,
        to_account_id,
        category_id,
        type,
        amount,
        currency_code,
        occurred_at,
        recurrence,
        is_recurring,
        note,
        source,
        category_overridden,
        archived_at
    )
    select
        batch.operation_id,
        batch.user_id,
        batch.from_account_id,
        null,
        null,
        batch.operation_type,
        batch.operation_amount,
        batch.currency_code::char(3),
        batch.occurred_at,
        'none',
        false,
        batch.note,
        'plaid',
        false,
        null
    from pg_temp.plaid_operation_materialize_batch batch
    where not batch.is_canonical_secondary
      and batch.currency_code = public.product_currency_code()
      and batch.raw_amount <> 0
      and batch.operation_id is not null;

    get diagnostics v_materialized = row_count;

    update public.plaid_transaction_operation_projections projection
    set
        operation_id = batch.operation_id,
        state = 'posted_projected',
        last_error_code = null,
        last_error_at = null,
        last_projected_at = now(),
        suppressed_reason = null,
        updated_at = now()
    from pg_temp.plaid_operation_materialize_batch batch
    where projection.id = batch.projection_id
      and not batch.is_canonical_secondary
      and batch.currency_code = public.product_currency_code()
      and batch.raw_amount <> 0
      and batch.operation_id is not null;

    select exists (
        select 1
        from public.plaid_transaction_operation_projections projection
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.state = 'posted_ready'
          and projection.operation_id is null
          and raw.pending = false
          and raw.removed_at is null
          and not public.plaid_raw_canonical_suppressed(
              raw.user_id,
              raw.account_id
          )
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'materialized', v_materialized,
        'suppressed_zero_amount', v_suppressed_zero_amount,
        'suppressed_canonical_secondary', v_suppressed_canonical_secondary,
        'suppressed_unsupported_currency', v_suppressed_unsupported_currency,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role materialization from posted Plaid projections to Operations. Serializes with Stage C via accounts FOR UPDATE (id order). Raw rows of an active secondary cannot create new Operations and are suppressed with the reason from plaid_canonical_suppression_reason; pre-linked Operations are out of scope here. Only transactions in public.product_currency_code() become Operations; any other currency is suppressed as unsupported_currency and keeps its raw currency.';

revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_materialize_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;
