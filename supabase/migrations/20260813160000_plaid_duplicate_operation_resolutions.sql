-- Stage E (Edge Case №11): explicit historical duplicate Operation resolution.
-- Persistent user-selected kept/suppressed pair; G1 star active graph.
-- No fuzzy transaction matching. No cross-Item transaction identity.
-- Plaid transaction identity remains (plaid_item_id, transaction_id).
-- Source-sync freeze gate for active suppressed Operations.
-- Reverse clears resolution only; does not unarchive.
-- Reconcile / materializer / link / category RPCs intentionally unchanged.
-- Known Stage G dependency: resolution → operations ON DELETE RESTRICT;
-- membership → accounts ON DELETE RESTRICT (from Stage A) may still block remove-item.

-- ---------------------------------------------------------------------------
-- 1) Resolution table
-- ---------------------------------------------------------------------------

create table public.plaid_duplicate_operation_resolutions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    canonical_account_id uuid not null,

    kept_operation_id uuid not null,

    suppressed_operation_id uuid not null,

    created_at timestamptz not null default now(),

    resolved_at timestamptz not null default now(),

    reversed_at timestamptz null,

    constraint plaid_duplicate_operation_resolutions_canonical_user_fkey
        foreign key (canonical_account_id, user_id)
        references public.plaid_canonical_financial_accounts(id, user_id)
        on delete cascade,

    constraint plaid_duplicate_operation_resolutions_kept_user_fkey
        foreign key (kept_operation_id, user_id)
        references public.operations(id, user_id)
        on delete restrict,

    constraint plaid_duplicate_operation_resolutions_suppressed_user_fkey
        foreign key (suppressed_operation_id, user_id)
        references public.operations(id, user_id)
        on delete restrict,

    constraint plaid_duplicate_operation_resolutions_pair_distinct_check
        check (kept_operation_id <> suppressed_operation_id),

    constraint plaid_duplicate_operation_resolutions_reverse_order_check
        check (
            reversed_at is null
            or reversed_at >= resolved_at
        )
);

comment on table public.plaid_duplicate_operation_resolutions is
    'Persistent explicit user decision that one Plaid Operation (kept) is the survivor and another (suppressed) is a historical duplicate representation of the same economic event for UI cleanup. Not fuzzy transaction identity and not cross-Item Plaid transaction identity. Pairing evidence is only the user-selected Operation IDs plus same active canonical membership. Active resolution (reversed_at IS NULL) freezes the suppressed Operation archived; reverse ends freeze without directly unarchiving. Role (kept/suppressed) is a historical pair decision and does not depend on current canonical authority.';

comment on column public.plaid_duplicate_operation_resolutions.kept_operation_id is
    'Survivor Operation chosen explicitly by the user. Remains visible/mutable per normal lifecycle. May be kept for many active suppressed Operations (G1 star).';

comment on column public.plaid_duplicate_operation_resolutions.suppressed_operation_id is
    'Historical duplicate Operation chosen explicitly by the user. Remains linked to its Plaid projection/raw history via projection.operation_id. While reversed_at IS NULL it stays archived/frozen against source-sync resurrection. No Stage E hard delete.';

comment on column public.plaid_duplicate_operation_resolutions.canonical_account_id is
    'Canonical financial account whose active memberships contain both Operation account representations at resolve time. Not a uniqueness key: N>2 may have many active resolutions under one canonical.';

comment on column public.plaid_duplicate_operation_resolutions.reversed_at is
    'When non-null, resolution is inactive. Ends Stage E freeze; does not set operations.archived_at. Subsequent source-sync applies normal raw lifecycle.';

comment on column public.plaid_duplicate_operation_resolutions.resolved_at is
    'Server timestamp when the explicit resolution became active.';

-- One Operation may be active suppressed in at most one resolution.
create unique index plaid_dup_op_resolutions_active_suppressed_uidx
on public.plaid_duplicate_operation_resolutions(suppressed_operation_id)
where reversed_at is null;

-- Kept may suppress many; lookup only.
create index plaid_dup_op_resolutions_active_kept_idx
on public.plaid_duplicate_operation_resolutions(kept_operation_id)
where reversed_at is null;

create index plaid_dup_op_resolutions_user_canonical_idx
on public.plaid_duplicate_operation_resolutions(user_id, canonical_account_id);

alter table public.plaid_duplicate_operation_resolutions enable row level security;

create policy "plaid_duplicate_operation_resolutions_select_own"
on public.plaid_duplicate_operation_resolutions
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.plaid_duplicate_operation_resolutions
from public, anon, authenticated;

grant select on table public.plaid_duplicate_operation_resolutions to authenticated;

grant select, insert, update, delete on table public.plaid_duplicate_operation_resolutions
to service_role;

-- ---------------------------------------------------------------------------
-- 2) Resolve RPC
-- ---------------------------------------------------------------------------

create or replace function public.plaid_resolve_duplicate_operations(
    p_user_id uuid,
    p_kept_operation_id uuid,
    p_suppressed_operation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_kept public.operations%rowtype;
    v_suppressed public.operations%rowtype;
    v_kept_projection_id uuid;
    v_suppressed_projection_id uuid;
    v_lock_projection_id_1 uuid;
    v_lock_projection_id_2 uuid;
    v_lock_operation_id_1 uuid;
    v_lock_operation_id_2 uuid;
    v_kept_account_id uuid;
    v_suppressed_account_id uuid;
    v_kept_canonical_id uuid;
    v_suppressed_canonical_id uuid;
    v_existing_id uuid;
    v_resolution_id uuid;
begin
    if p_user_id is null
       or p_kept_operation_id is null
       or p_suppressed_operation_id is null
    then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    if p_kept_operation_id = p_suppressed_operation_id then
        raise exception 'same_operation_forbidden' using errcode = '22023';
    end if;

    select *
    into v_kept
    from public.operations
    where id = p_kept_operation_id
      and user_id = p_user_id;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_suppressed
    from public.operations
    where id = p_suppressed_operation_id
      and user_id = p_user_id;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    if v_kept.source is distinct from 'plaid'
       or v_suppressed.source is distinct from 'plaid'
    then
        raise exception 'operation_not_plaid' using errcode = '22023';
    end if;

    select projection.id
    into v_kept_projection_id
    from public.plaid_transaction_operation_projections projection
    where projection.operation_id = p_kept_operation_id
      and projection.user_id = p_user_id;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    select projection.id
    into v_suppressed_projection_id
    from public.plaid_transaction_operation_projections projection
    where projection.operation_id = p_suppressed_operation_id
      and projection.user_id = p_user_id;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    -- Lock order: PROJECTION → OPERATION (compatible with source-sync).
    v_lock_projection_id_1 := least(v_kept_projection_id, v_suppressed_projection_id);
    v_lock_projection_id_2 := greatest(v_kept_projection_id, v_suppressed_projection_id);

    perform 1
    from public.plaid_transaction_operation_projections
    where id = v_lock_projection_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.plaid_transaction_operation_projections
    where id = v_lock_projection_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    v_lock_operation_id_1 := least(p_kept_operation_id, p_suppressed_operation_id);
    v_lock_operation_id_2 := greatest(p_kept_operation_id, p_suppressed_operation_id);

    perform 1
    from public.operations
    where id = v_lock_operation_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.operations
    where id = v_lock_operation_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    -- Re-load under locks.
    select *
    into v_kept
    from public.operations
    where id = p_kept_operation_id
      and user_id = p_user_id
      and source = 'plaid';

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_suppressed
    from public.operations
    where id = p_suppressed_operation_id
      and user_id = p_user_id
      and source = 'plaid';

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    -- Confirm projection↔operation linkage still holds under locks.
    if not exists (
        select 1
        from public.plaid_transaction_operation_projections
        where id = v_kept_projection_id
          and user_id = p_user_id
          and operation_id = p_kept_operation_id
    ) or not exists (
        select 1
        from public.plaid_transaction_operation_projections
        where id = v_suppressed_projection_id
          and user_id = p_user_id
          and operation_id = p_suppressed_operation_id
    ) then
        raise exception 'projection_not_found' using errcode = '22023';
    end if;

    -- G1 graph checks under both Operation locks.
    select id
    into v_existing_id
    from public.plaid_duplicate_operation_resolutions
    where user_id = p_user_id
      and kept_operation_id = p_kept_operation_id
      and suppressed_operation_id = p_suppressed_operation_id
      and reversed_at is null;

    if found then
        return jsonb_build_object(
            'status', 'already_resolved',
            'resolution_id', v_existing_id,
            'kept_operation_id', p_kept_operation_id,
            'suppressed_operation_id', p_suppressed_operation_id
        );
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and suppressed_operation_id = p_suppressed_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and suppressed_operation_id = p_kept_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    if exists (
        select 1
        from public.plaid_duplicate_operation_resolutions
        where user_id = p_user_id
          and kept_operation_id = p_suppressed_operation_id
          and reversed_at is null
    ) then
        raise exception 'resolution_conflict' using errcode = '22023';
    end if;

    -- Canonical membership: same active canonical; no authority-role requirement.
    select raw.account_id
    into v_kept_account_id
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    where projection.id = v_kept_projection_id
      and projection.user_id = p_user_id;

    if v_kept_account_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select raw.account_id
    into v_suppressed_account_id
    from public.plaid_transaction_operation_projections projection
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    where projection.id = v_suppressed_projection_id
      and projection.user_id = p_user_id;

    if v_suppressed_account_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select m.canonical_account_id
    into v_kept_canonical_id
    from public.plaid_canonical_financial_account_members m
    where m.account_id = v_kept_account_id
      and m.user_id = p_user_id
      and m.unlinked_at is null;

    if v_kept_canonical_id is null then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    select m.canonical_account_id
    into v_suppressed_canonical_id
    from public.plaid_canonical_financial_account_members m
    where m.account_id = v_suppressed_account_id
      and m.user_id = p_user_id
      and m.unlinked_at is null;

    if v_suppressed_canonical_id is null
       or v_suppressed_canonical_id is distinct from v_kept_canonical_id
    then
        raise exception 'canonical_mismatch' using errcode = '22023';
    end if;

    insert into public.plaid_duplicate_operation_resolutions (
        user_id,
        canonical_account_id,
        kept_operation_id,
        suppressed_operation_id
    )
    values (
        p_user_id,
        v_kept_canonical_id,
        p_kept_operation_id,
        p_suppressed_operation_id
    )
    returning id into v_resolution_id;

    if v_suppressed.archived_at is null then
        update public.operations
        set archived_at = now()
        where id = p_suppressed_operation_id
          and user_id = p_user_id
          and source = 'plaid'
          and archived_at is null;
    end if;

    return jsonb_build_object(
        'status', 'resolved',
        'resolution_id', v_resolution_id,
        'kept_operation_id', p_kept_operation_id,
        'suppressed_operation_id', p_suppressed_operation_id
    );
end;
$$;

comment on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid) is
    'Service-role Stage E RPC: persist explicit user-selected kept/suppressed Plaid Operation pair under the same active canonical. G1 star graph. Locks projections then operations. Archives suppressed Operation if not already archived. No fuzzy matching. No JOB/ACCOUNT locks.';

revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from public;
revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from anon;
revoke all on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
from authenticated;
grant execute on function public.plaid_resolve_duplicate_operations(uuid, uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 3) Reverse RPC
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reverse_duplicate_operation_resolution(
    p_user_id uuid,
    p_resolution_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_resolution public.plaid_duplicate_operation_resolutions%rowtype;
    v_lock_operation_id_1 uuid;
    v_lock_operation_id_2 uuid;
begin
    if p_user_id is null or p_resolution_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Identity read without locking resolution yet.
    select *
    into v_resolution
    from public.plaid_duplicate_operation_resolutions
    where id = p_resolution_id
      and user_id = p_user_id;

    if not found then
        raise exception 'resolution_not_found' using errcode = '22023';
    end if;

    -- Lock BOTH Operations first (never RESOLUTION → OPERATION).
    v_lock_operation_id_1 := least(
        v_resolution.kept_operation_id,
        v_resolution.suppressed_operation_id
    );
    v_lock_operation_id_2 := greatest(
        v_resolution.kept_operation_id,
        v_resolution.suppressed_operation_id
    );

    perform 1
    from public.operations
    where id = v_lock_operation_id_1
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    perform 1
    from public.operations
    where id = v_lock_operation_id_2
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'operation_not_found' using errcode = '22023';
    end if;

    select *
    into v_resolution
    from public.plaid_duplicate_operation_resolutions
    where id = p_resolution_id
      and user_id = p_user_id
    for update;

    if not found then
        raise exception 'resolution_not_found' using errcode = '22023';
    end if;

    if v_resolution.reversed_at is not null then
        return jsonb_build_object(
            'status', 'already_reversed',
            'resolution_id', v_resolution.id
        );
    end if;

    update public.plaid_duplicate_operation_resolutions
    set reversed_at = now()
    where id = v_resolution.id
      and user_id = p_user_id
      and reversed_at is null;

    -- Intentionally do NOT touch operations.archived_at.
    return jsonb_build_object(
        'status', 'reversed',
        'resolution_id', v_resolution.id
    );
end;
$$;

comment on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid) is
    'Service-role Stage E RPC: reverse an explicit duplicate Operation resolution by setting reversed_at. Locks both Operations then the resolution row. Never unarchives Operations; source-sync resumes normal lifecycle after freeze ends.';

revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from public;
revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from anon;
revoke all on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
from authenticated;
grant execute on function public.plaid_reverse_duplicate_operation_resolution(uuid, uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 4) Source-sync freeze gate (CREATE OR REPLACE latest)
-- ---------------------------------------------------------------------------

create or replace function public.plaid_sync_materialized_transaction_operations(
    p_user_id uuid,
    p_plaid_item_id uuid,
    p_lease_token uuid,
    p_batch_size integer default 250
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_batch_size integer;
    v_job public.plaid_transaction_projection_jobs%rowtype;
    v_scanned integer := 0;
    v_source_updated integer := 0;
    v_source_archived integer := 0;
    v_source_unarchived integer := 0;
    v_override_preserved integer := 0;
    v_override_invalidated integer := 0;
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

    -- Two-phase Stage E freeze visibility (READ COMMITTED):
    -- PHASE 1 locks candidate projection/operation rows only.
    -- PHASE 2 is a separate SQL statement that re-reads active resolutions
    -- under those held locks and only then classifies freeze / expected state.
    drop table if exists pg_temp.plaid_materialized_operation_source_sync_locked;
    drop table if exists pg_temp.plaid_materialized_operation_source_sync_batch;

    create temporary table pg_temp.plaid_materialized_operation_source_sync_locked (
        projection_id uuid primary key,
        operation_id uuid not null
    ) on commit drop;

    create temporary table pg_temp.plaid_materialized_operation_source_sync_batch (
        projection_id uuid primary key,
        operation_id uuid not null,
        expected_from_account_id uuid not null,
        expected_type text not null,
        expected_amount numeric(14, 2) not null,
        expected_currency_code char(3) not null,
        expected_occurred_at date not null,
        expected_note text null,
        expected_archived_at timestamptz null,
        current_archived_at timestamptz null,
        current_category_id text null,
        category_overridden boolean not null,
        current_category_type text null,
        source_fields_differ boolean not null,
        archive_needed boolean not null,
        unarchive_needed boolean not null,
        override_invalidated boolean not null
    ) on commit drop;

    -- PHASE 1: acquire locks. Candidate pruning may use resolution EXISTS for
    -- convergence only; it must NOT compute freeze/expected_* here.
    -- Lifecycle-shaped WHERE (same candidate classes as Stage E): archive-needed,
    -- defensive null-archive under active suppression, or unarchive/field/category
    -- work for non-pruned active posted rows.
    insert into pg_temp.plaid_materialized_operation_source_sync_locked (
        projection_id,
        operation_id
    )
    select
        projection.id,
        operations.id
    from public.plaid_transaction_operation_projections projection
    join public.operations operations
      on operations.id = projection.operation_id
     and operations.user_id = projection.user_id
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id
    where projection.user_id = p_user_id
      and projection.plaid_item_id = p_plaid_item_id
      and projection.operation_id is not null
      and operations.source = 'plaid'
      and (
          (
              (
                  raw.removed_at is not null
                  or (
                      raw.removed_at is null
                      and raw.pending = false
                      and raw.amount = 0
                  )
              )
              and operations.archived_at is null
          )
          or (
              exists (
                  select 1
                  from public.plaid_duplicate_operation_resolutions resolution
                  where resolution.suppressed_operation_id = operations.id
                    and resolution.user_id = operations.user_id
                    and resolution.reversed_at is null
              )
              and operations.archived_at is null
          )
          or (
              raw.removed_at is null
              and raw.pending = false
              and raw.amount <> 0
              and not exists (
                  select 1
                  from public.plaid_duplicate_operation_resolutions resolution
                  where resolution.suppressed_operation_id = operations.id
                    and resolution.user_id = operations.user_id
                    and resolution.reversed_at is null
              )
              and (
                  operations.archived_at is not null
                  or operations.from_account_id is distinct from raw.account_id
                  or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                  or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                  or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                  or operations.occurred_at is distinct from raw.date
                  or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
                  or (
                      operations.category_id is not null
                      and public.ophir_operation_category_type(operations.category_id)
                          is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                  )
              )
          )
      )
    order by raw.date, raw.transaction_id
    limit v_batch_size
    for update of projection, operations skip locked;

    -- PHASE 2: new SQL statement / new READ COMMITTED snapshot while locks held.
    -- Active-resolution freeze classification happens only here.
    insert into pg_temp.plaid_materialized_operation_source_sync_batch (
        projection_id,
        operation_id,
        expected_from_account_id,
        expected_type,
        expected_amount,
        expected_currency_code,
        expected_occurred_at,
        expected_note,
        expected_archived_at,
        current_archived_at,
        current_category_id,
        category_overridden,
        current_category_type,
        source_fields_differ,
        archive_needed,
        unarchive_needed,
        override_invalidated
    )
    select
        projection.id,
        operations.id,
        raw.account_id,
        case when raw.amount > 0 then 'expense' else 'income' end as expected_type,
        round(abs(raw.amount), 2)::numeric(14, 2) as expected_amount,
        upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3) as expected_currency_code,
        raw.date as expected_occurred_at,
        nullif(trim(coalesce(raw.merchant_name, raw.name)), '') as expected_note,
        case
            when exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            ) then
                coalesce(
                    operations.archived_at,
                    case
                        when raw.removed_at is not null then raw.removed_at
                        when raw.pending = false and raw.amount = 0 then now()
                        else now()
                    end
                )
            when raw.removed_at is not null then coalesce(operations.archived_at, raw.removed_at)
            when raw.pending = false and raw.amount = 0 then coalesce(operations.archived_at, now())
            else null
        end as expected_archived_at,
        operations.archived_at as current_archived_at,
        operations.category_id as current_category_id,
        operations.category_overridden,
        public.ophir_operation_category_type(operations.category_id) as current_category_type,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and (
                operations.from_account_id is distinct from raw.account_id
                or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                or operations.occurred_at is distinct from raw.date
                or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
            )
        ) as source_fields_differ,
        (
            (
                raw.removed_at is not null
                or (
                    raw.removed_at is null
                    and raw.pending = false
                    and raw.amount = 0
                )
                or exists (
                    select 1
                    from public.plaid_duplicate_operation_resolutions resolution
                    where resolution.suppressed_operation_id = operations.id
                      and resolution.user_id = operations.user_id
                      and resolution.reversed_at is null
                )
            )
            and operations.archived_at is null
        ) as archive_needed,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.archived_at is not null
        ) as unarchive_needed,
        (
            not exists (
                select 1
                from public.plaid_duplicate_operation_resolutions resolution
                where resolution.suppressed_operation_id = operations.id
                  and resolution.user_id = operations.user_id
                  and resolution.reversed_at is null
            )
            and raw.removed_at is null
            and raw.pending = false
            and raw.amount <> 0
            and operations.category_overridden = true
            and operations.category_id is not null
            and public.ophir_operation_category_type(operations.category_id)
                is distinct from case when raw.amount > 0 then 'expense' else 'income' end
        ) as override_invalidated
    from pg_temp.plaid_materialized_operation_source_sync_locked locked
    join public.plaid_transaction_operation_projections projection
      on projection.id = locked.projection_id
     and projection.user_id = p_user_id
    join public.operations operations
      on operations.id = locked.operation_id
     and operations.user_id = p_user_id
     and operations.id = projection.operation_id
    join public.plaid_transactions raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.accounts account
      on account.id = raw.account_id
     and account.user_id = raw.user_id;

    select
        count(*),
        count(*) filter (where source_fields_differ),
        count(*) filter (where archive_needed),
        count(*) filter (where unarchive_needed),
        count(*) filter (where category_overridden and not override_invalidated),
        count(*) filter (where override_invalidated)
    into
        v_scanned,
        v_source_updated,
        v_source_archived,
        v_source_unarchived,
        v_override_preserved,
        v_override_invalidated
    from pg_temp.plaid_materialized_operation_source_sync_batch;

    update public.operations operations
    set
        from_account_id = case
            when batch.expected_archived_at is null then batch.expected_from_account_id
            else operations.from_account_id
        end,
        to_account_id = case
            when batch.expected_archived_at is null then null
            else operations.to_account_id
        end,
        type = case
            when batch.expected_archived_at is null then batch.expected_type
            else operations.type
        end,
        amount = case
            when batch.expected_archived_at is null then batch.expected_amount
            else operations.amount
        end,
        currency_code = case
            when batch.expected_archived_at is null then batch.expected_currency_code
            else operations.currency_code
        end,
        occurred_at = case
            when batch.expected_archived_at is null then batch.expected_occurred_at
            else operations.occurred_at
        end,
        note = case
            when batch.expected_archived_at is null then batch.expected_note
            else operations.note
        end,
        category_id = case
            when batch.expected_archived_at is null
                 and batch.current_category_id is not null
                 and batch.current_category_type is distinct from batch.expected_type
              then null
            else operations.category_id
        end,
        archived_at = batch.expected_archived_at
    from pg_temp.plaid_materialized_operation_source_sync_batch batch
    where operations.id = batch.operation_id
      and operations.user_id = p_user_id
      and operations.source = 'plaid';

    select exists (
        select 1
        from public.plaid_transaction_operation_projections projection
        join public.operations operations
          on operations.id = projection.operation_id
         and operations.user_id = projection.user_id
        join public.plaid_transactions raw
          on raw.plaid_item_id = projection.plaid_item_id
         and raw.transaction_id = projection.plaid_transaction_id
         and raw.user_id = projection.user_id
        join public.accounts account
          on account.id = raw.account_id
         and account.user_id = raw.user_id
        where projection.user_id = p_user_id
          and projection.plaid_item_id = p_plaid_item_id
          and projection.operation_id is not null
          and operations.source = 'plaid'
          and not exists (
              select 1
              from pg_temp.plaid_materialized_operation_source_sync_batch batch
              where batch.projection_id = projection.id
          )
          and (
              (
                  (
                      raw.removed_at is not null
                      or (
                          raw.removed_at is null
                          and raw.pending = false
                          and raw.amount = 0
                      )
                  )
                  and operations.archived_at is null
              )
              or (
                  exists (
                      select 1
                      from public.plaid_duplicate_operation_resolutions resolution
                      where resolution.suppressed_operation_id = operations.id
                        and resolution.user_id = operations.user_id
                        and resolution.reversed_at is null
                  )
                  and operations.archived_at is null
              )
              or (
                  raw.removed_at is null
                  and raw.pending = false
                  and raw.amount <> 0
                  and not exists (
                      select 1
                      from public.plaid_duplicate_operation_resolutions resolution
                      where resolution.suppressed_operation_id = operations.id
                        and resolution.user_id = operations.user_id
                        and resolution.reversed_at is null
                  )
                  and (
                      operations.archived_at is not null
                      or operations.from_account_id is distinct from raw.account_id
                      or operations.type is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                      or operations.amount is distinct from round(abs(raw.amount), 2)::numeric(14, 2)
                      or operations.currency_code is distinct from upper(coalesce(nullif(raw.iso_currency_code, ''), account.currency_code))::char(3)
                      or operations.occurred_at is distinct from raw.date
                      or operations.note is distinct from nullif(trim(coalesce(raw.merchant_name, raw.name)), '')
                      or (
                          operations.category_id is not null
                          and public.ophir_operation_category_type(operations.category_id)
                              is distinct from case when raw.amount > 0 then 'expense' else 'income' end
                      )
                  )
              )
          )
    )
    into v_has_more;

    return jsonb_build_object(
        'status', 'processed',
        'source_scanned', v_scanned,
        'source_updated', v_source_updated,
        'source_archived', v_source_archived,
        'source_unarchived', v_source_unarchived,
        'source_unchanged', 0,
        'override_preserved', v_override_preserved,
        'override_invalidated', v_override_invalidated,
        'has_more', v_has_more
    );
end;
$$;

comment on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) is
    'Fenced service-role convergence from authoritative raw Plaid transaction lifecycle to already materialized Plaid Operations. Updates source-owned Operation fields and server-owned archive state only. Stage E: locks candidate projection/operation rows first, then classifies active duplicate-resolution freeze in a separate SQL statement under those locks (READ COMMITTED). Active suppressed Operations remain archived/frozen; freeze ends when resolution.reversed_at is set.';

revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from public;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from anon;
revoke all on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) from authenticated;
grant execute on function public.plaid_sync_materialized_transaction_operations(
    uuid,
    uuid,
    uuid,
    integer
) to service_role;
