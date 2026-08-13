-- Stage F: internal transfer candidate foundation (candidate-only).
-- Persists high-confidence two-sided candidates between DIFFERENT authoritative
-- canonical financial accounts. Does not mutate Operations, does not create
-- transfer Operations, does not archive legs, does not freeze source-sync.
-- Stage C/E RPC bodies intentionally unchanged (eventual convergence via
-- projection worker). Stage G confirm/synthetic transfer is OUT OF SCOPE.

-- ---------------------------------------------------------------------------
-- 1) Reconciliation table
-- ---------------------------------------------------------------------------

create table public.plaid_internal_transfer_reconciliations (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    outgoing_projection_id uuid not null
        references public.plaid_transaction_operation_projections(id)
        on delete restrict,

    incoming_projection_id uuid not null
        references public.plaid_transaction_operation_projections(id)
        on delete restrict,

    outgoing_operation_id uuid not null,

    incoming_operation_id uuid not null,

    outgoing_canonical_account_id uuid not null,

    incoming_canonical_account_id uuid not null,

    state text not null
        constraint plaid_internal_transfer_reconciliations_state_check
        check (state in ('candidate', 'invalidated')),

    evidence_snapshot jsonb not null
        constraint plaid_internal_transfer_reconciliations_evidence_object_check
        check (jsonb_typeof(evidence_snapshot) = 'object'),

    candidate_detected_at timestamptz not null,

    last_detected_at timestamptz not null,

    invalidated_at timestamptz null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_internal_transfer_reconciliations_pair_distinct_check
        check (outgoing_projection_id <> incoming_projection_id),

    constraint plaid_internal_transfer_reconciliations_canonical_distinct_check
        check (outgoing_canonical_account_id <> incoming_canonical_account_id),

    constraint plaid_internal_transfer_reconciliations_state_invalidated_at_check
        check (
            (state = 'candidate' and invalidated_at is null)
            or
            (state = 'invalidated' and invalidated_at is not null)
        ),

    constraint plaid_internal_transfer_reconciliations_pair_unique
        unique (user_id, outgoing_projection_id, incoming_projection_id),

    constraint plaid_internal_transfer_reconciliations_outgoing_op_user_fkey
        foreign key (outgoing_operation_id, user_id)
        references public.operations(id, user_id)
        on delete restrict,

    constraint plaid_internal_transfer_reconciliations_incoming_op_user_fkey
        foreign key (incoming_operation_id, user_id)
        references public.operations(id, user_id)
        on delete restrict,

    constraint plaid_internal_transfer_reconciliations_outgoing_canonical_user_fkey
        foreign key (outgoing_canonical_account_id, user_id)
        references public.plaid_canonical_financial_accounts(id, user_id)
        on delete restrict,

    constraint plaid_internal_transfer_reconciliations_incoming_canonical_user_fkey
        foreign key (incoming_canonical_account_id, user_id)
        references public.plaid_canonical_financial_accounts(id, user_id)
        on delete restrict
);

comment on table public.plaid_internal_transfer_reconciliations is
    'Stage F candidate-only internal transfer reconciliations. Stable identity is (user_id, outgoing_projection_id, incoming_projection_id). Not financial truth. Not Stage G confirmed transfer. Not fuzzy single-sided PFC classification.';

comment on column public.plaid_internal_transfer_reconciliations.outgoing_projection_id is
    'Posted projection for the outgoing leg (raw.amount > 0). Part of stable reconciliation identity.';

comment on column public.plaid_internal_transfer_reconciliations.incoming_projection_id is
    'Posted projection for the incoming leg (raw.amount < 0). Part of stable reconciliation identity.';

comment on column public.plaid_internal_transfer_reconciliations.state is
    'candidate = currently eligible high-confidence pair; invalidated = previously or currently ineligible. Same row is reused across candidate↔invalidated.';

comment on column public.plaid_internal_transfer_reconciliations.evidence_snapshot is
    'Current evidence only (amounts, dates, currencies, PFC fields, match_reason, policy_version). Not identity. Overwritten on each successful detect/reactivate.';

comment on column public.plaid_internal_transfer_reconciliations.candidate_detected_at is
    'First time this exact pair entered candidate state. Preserved across invalidate→candidate reactivation.';

comment on column public.plaid_internal_transfer_reconciliations.last_detected_at is
    'Last time eligibility was confirmed and the row was written as candidate.';

comment on column public.plaid_internal_transfer_reconciliations.invalidated_at is
    'Non-null iff state=invalidated.';

-- One projection may participate in at most one ACTIVE candidate.
create unique index plaid_itr_active_outgoing_projection_uidx
on public.plaid_internal_transfer_reconciliations(outgoing_projection_id)
where state = 'candidate';

create unique index plaid_itr_active_incoming_projection_uidx
on public.plaid_internal_transfer_reconciliations(incoming_projection_id)
where state = 'candidate';

create index plaid_itr_user_state_idx
on public.plaid_internal_transfer_reconciliations(user_id, state);

create trigger plaid_internal_transfer_reconciliations_set_updated_at
before update on public.plaid_internal_transfer_reconciliations
for each row
execute function public.set_updated_at();

alter table public.plaid_internal_transfer_reconciliations enable row level security;

create policy "plaid_internal_transfer_reconciliations_select_own"
on public.plaid_internal_transfer_reconciliations
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.plaid_internal_transfer_reconciliations
from public, anon, authenticated;

grant select on table public.plaid_internal_transfer_reconciliations to authenticated;

grant select, insert, update, delete on table public.plaid_internal_transfer_reconciliations
to service_role;

-- ---------------------------------------------------------------------------
-- 2) User-scoped reconcile RPC
-- ---------------------------------------------------------------------------

create or replace function public.plaid_reconcile_internal_transfer_candidates_for_user(
    p_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_candidates_created integer := 0;
    v_candidates_reactivated integer := 0;
    v_candidates_invalidated integer := 0;
    v_candidates_unchanged integer := 0;
    v_candidates_active integer := 0;
    v_now timestamptz := now();
    v_pair record;
    v_existing public.plaid_internal_transfer_reconciliations%rowtype;
begin
    if p_user_id is null then
        raise exception 'invalid_input' using errcode = '22023';
    end if;

    -- Serialize Stage F per user. Namespace 872514001 = Stage F ITR.
    perform pg_catalog.pg_advisory_xact_lock(
        872514001,
        pg_catalog.hashtext(p_user_id::text)
    );

    -- Lock existing reconciliation rows for this user in stable order.
    perform 1
    from public.plaid_internal_transfer_reconciliations as reconciliation
    where reconciliation.user_id = p_user_id
    order by reconciliation.outgoing_projection_id, reconciliation.incoming_projection_id
    for update;

    drop table if exists pg_temp.plaid_itr_eligible_legs;
    drop table if exists pg_temp.plaid_itr_pair_edges;
    drop table if exists pg_temp.plaid_itr_bijective_pairs;

    create temporary table pg_temp.plaid_itr_eligible_legs (
        projection_id uuid primary key,
        operation_id uuid not null,
        account_id uuid not null,
        canonical_account_id uuid not null,
        amount numeric not null,
        abs_amount numeric not null,
        direction text not null
            check (direction in ('outgoing', 'incoming')),
        currency_code text not null,
        txn_date date not null,
        authorized_date date null,
        pfc_version text null,
        pfc_primary text null,
        pfc_detailed text null,
        pfc_confidence text null,
        allowlisted boolean not null
    ) on commit drop;

    create temporary table pg_temp.plaid_itr_pair_edges (
        outgoing_projection_id uuid not null,
        incoming_projection_id uuid not null,
        primary key (outgoing_projection_id, incoming_projection_id)
    ) on commit drop;

    create temporary table pg_temp.plaid_itr_bijective_pairs (
        outgoing_projection_id uuid not null,
        incoming_projection_id uuid not null,
        outgoing_operation_id uuid not null,
        incoming_operation_id uuid not null,
        outgoing_canonical_account_id uuid not null,
        incoming_canonical_account_id uuid not null,
        evidence_snapshot jsonb not null,
        primary key (outgoing_projection_id, incoming_projection_id)
    ) on commit drop;

    -- Eligible legs: authoritative active canonical membership required.
    -- Currency v1: both sides must have non-null non-empty iso_currency_code later;
    -- store normalized ISO here and skip legs without ISO.
    insert into pg_temp.plaid_itr_eligible_legs (
        projection_id,
        operation_id,
        account_id,
        canonical_account_id,
        amount,
        abs_amount,
        direction,
        currency_code,
        txn_date,
        authorized_date,
        pfc_version,
        pfc_primary,
        pfc_detailed,
        pfc_confidence,
        allowlisted
    )
    select
        projection.id,
        operations.id,
        raw.account_id,
        members.canonical_account_id,
        raw.amount,
        abs(raw.amount),
        case
            when raw.amount > 0 then 'outgoing'
            else 'incoming'
        end,
        upper(btrim(raw.iso_currency_code)),
        raw.date,
        raw.authorized_date,
        nullif(btrim(coalesce(raw.personal_finance_category_version, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_primary, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_detailed, '')), ''),
        nullif(btrim(coalesce(raw.personal_finance_category_confidence_level, '')), ''),
        (
            lower(nullif(btrim(coalesce(raw.personal_finance_category_version, '')), '')) = 'v2'
            and upper(nullif(btrim(coalesce(raw.personal_finance_category_detailed, '')), '')) in (
                'TRANSFER_OUT_ACCOUNT_TRANSFER',
                'TRANSFER_IN_ACCOUNT_TRANSFER',
                'TRANSFER_OUT_SAVINGS',
                'TRANSFER_IN_SAVINGS',
                'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
            )
        ) as allowlisted
    from public.plaid_transaction_operation_projections as projection
    join public.plaid_transactions as raw
      on raw.plaid_item_id = projection.plaid_item_id
     and raw.transaction_id = projection.plaid_transaction_id
     and raw.user_id = projection.user_id
    join public.operations as operations
      on operations.id = projection.operation_id
     and operations.user_id = projection.user_id
    join public.plaid_canonical_financial_account_members as members
      on members.account_id = raw.account_id
     and members.user_id = raw.user_id
     and members.unlinked_at is null
     and members.role = 'authoritative'
    where projection.user_id = p_user_id
      and projection.state = 'posted_projected'
      and projection.operation_id is not null
      and raw.pending = false
      and raw.removed_at is null
      and raw.amount <> 0
      and nullif(btrim(coalesce(raw.iso_currency_code, '')), '') is not null
      and operations.source = 'plaid'
      and operations.archived_at is null
      and not exists (
          select 1
          from public.plaid_duplicate_operation_resolutions as resolution
          where resolution.suppressed_operation_id = operations.id
            and resolution.user_id = operations.user_id
            and resolution.reversed_at is null
      );

    -- All amount/currency/date/canonical-compatible directed edges (not yet bijective).
    insert into pg_temp.plaid_itr_pair_edges (
        outgoing_projection_id,
        incoming_projection_id
    )
    select
        outgoing.projection_id,
        incoming.projection_id
    from pg_temp.plaid_itr_eligible_legs as outgoing
    join pg_temp.plaid_itr_eligible_legs as incoming
      on incoming.direction = 'incoming'
     and outgoing.direction = 'outgoing'
     and incoming.abs_amount = outgoing.abs_amount
     and incoming.currency_code = outgoing.currency_code
     and incoming.canonical_account_id <> outgoing.canonical_account_id
     and (
         incoming.txn_date = outgoing.txn_date
         or (
             incoming.authorized_date is not null
             and outgoing.authorized_date is not null
             and incoming.authorized_date = outgoing.authorized_date
         )
     )
     and (outgoing.allowlisted or incoming.allowlisted);

    -- Bijective uniqueness: each side has exactly one complementary edge.
    insert into pg_temp.plaid_itr_bijective_pairs (
        outgoing_projection_id,
        incoming_projection_id,
        outgoing_operation_id,
        incoming_operation_id,
        outgoing_canonical_account_id,
        incoming_canonical_account_id,
        evidence_snapshot
    )
    select
        edges.outgoing_projection_id,
        edges.incoming_projection_id,
        outgoing.operation_id,
        incoming.operation_id,
        outgoing.canonical_account_id,
        incoming.canonical_account_id,
        jsonb_build_object(
            'policy_version', 'stage_f_v1',
            'match_reason', case
                when outgoing.txn_date = incoming.txn_date then 'exact_date'
                else 'equal_authorized_date'
            end,
            'outgoing', jsonb_build_object(
                'amount', outgoing.amount,
                'date', outgoing.txn_date,
                'authorized_date', outgoing.authorized_date,
                'iso_currency_code', outgoing.currency_code,
                'pfc_version', outgoing.pfc_version,
                'pfc_primary', outgoing.pfc_primary,
                'pfc_detailed', outgoing.pfc_detailed,
                'pfc_confidence', outgoing.pfc_confidence,
                'canonical_account_id', outgoing.canonical_account_id
            ),
            'incoming', jsonb_build_object(
                'amount', incoming.amount,
                'date', incoming.txn_date,
                'authorized_date', incoming.authorized_date,
                'iso_currency_code', incoming.currency_code,
                'pfc_version', incoming.pfc_version,
                'pfc_primary', incoming.pfc_primary,
                'pfc_detailed', incoming.pfc_detailed,
                'pfc_confidence', incoming.pfc_confidence,
                'canonical_account_id', incoming.canonical_account_id
            )
        )
    from pg_temp.plaid_itr_pair_edges as edges
    join pg_temp.plaid_itr_eligible_legs as outgoing
      on outgoing.projection_id = edges.outgoing_projection_id
    join pg_temp.plaid_itr_eligible_legs as incoming
      on incoming.projection_id = edges.incoming_projection_id
    where (
        select count(*)::integer
        from pg_temp.plaid_itr_pair_edges as out_edges
        where out_edges.outgoing_projection_id = edges.outgoing_projection_id
    ) = 1
      and (
        select count(*)::integer
        from pg_temp.plaid_itr_pair_edges as in_edges
        where in_edges.incoming_projection_id = edges.incoming_projection_id
    ) = 1;

    -- Invalidate active candidates that are no longer bijective-eligible.
    update public.plaid_internal_transfer_reconciliations as reconciliation
    set
        state = 'invalidated',
        invalidated_at = v_now,
        updated_at = v_now
    where reconciliation.user_id = p_user_id
      and reconciliation.state = 'candidate'
      and not exists (
          select 1
          from pg_temp.plaid_itr_bijective_pairs as pairs
          where pairs.outgoing_projection_id = reconciliation.outgoing_projection_id
            and pairs.incoming_projection_id = reconciliation.incoming_projection_id
      );

    get diagnostics v_candidates_invalidated = row_count;

    -- Insert / reactivate / refresh stable rows for current bijective pairs.
    for v_pair in
        select *
        from pg_temp.plaid_itr_bijective_pairs
        order by outgoing_projection_id, incoming_projection_id
    loop
        select *
        into v_existing
        from public.plaid_internal_transfer_reconciliations as reconciliation
        where reconciliation.user_id = p_user_id
          and reconciliation.outgoing_projection_id = v_pair.outgoing_projection_id
          and reconciliation.incoming_projection_id = v_pair.incoming_projection_id;

        if not found then
            insert into public.plaid_internal_transfer_reconciliations (
                user_id,
                outgoing_projection_id,
                incoming_projection_id,
                outgoing_operation_id,
                incoming_operation_id,
                outgoing_canonical_account_id,
                incoming_canonical_account_id,
                state,
                evidence_snapshot,
                candidate_detected_at,
                last_detected_at,
                invalidated_at
            )
            values (
                p_user_id,
                v_pair.outgoing_projection_id,
                v_pair.incoming_projection_id,
                v_pair.outgoing_operation_id,
                v_pair.incoming_operation_id,
                v_pair.outgoing_canonical_account_id,
                v_pair.incoming_canonical_account_id,
                'candidate',
                v_pair.evidence_snapshot,
                v_now,
                v_now,
                null
            );
            v_candidates_created := v_candidates_created + 1;
        elsif v_existing.state = 'invalidated' then
            update public.plaid_internal_transfer_reconciliations as reconciliation
            set
                outgoing_operation_id = v_pair.outgoing_operation_id,
                incoming_operation_id = v_pair.incoming_operation_id,
                outgoing_canonical_account_id = v_pair.outgoing_canonical_account_id,
                incoming_canonical_account_id = v_pair.incoming_canonical_account_id,
                state = 'candidate',
                evidence_snapshot = v_pair.evidence_snapshot,
                last_detected_at = v_now,
                invalidated_at = null,
                updated_at = v_now
            where reconciliation.id = v_existing.id;
            v_candidates_reactivated := v_candidates_reactivated + 1;
        else
            update public.plaid_internal_transfer_reconciliations as reconciliation
            set
                outgoing_operation_id = v_pair.outgoing_operation_id,
                incoming_operation_id = v_pair.incoming_operation_id,
                outgoing_canonical_account_id = v_pair.outgoing_canonical_account_id,
                incoming_canonical_account_id = v_pair.incoming_canonical_account_id,
                evidence_snapshot = v_pair.evidence_snapshot,
                last_detected_at = v_now,
                updated_at = v_now
            where reconciliation.id = v_existing.id;
            v_candidates_unchanged := v_candidates_unchanged + 1;
        end if;
    end loop;

    select count(*)::integer
    into v_candidates_active
    from public.plaid_internal_transfer_reconciliations as reconciliation
    where reconciliation.user_id = p_user_id
      and reconciliation.state = 'candidate';

    return jsonb_build_object(
        'status', 'processed',
        'candidates_active', v_candidates_active,
        'candidates_created', v_candidates_created,
        'candidates_reactivated', v_candidates_reactivated,
        'candidates_invalidated', v_candidates_invalidated,
        'candidates_unchanged', v_candidates_unchanged
    );
end;
$$;

comment on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid) is
    'Stage F user-scoped candidate reconcile. Invalidates stale pairs and upserts bijective high-confidence internal-transfer candidates. Aggregate metrics only. Does not mutate Operations. Service-role only.';

revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from public;
revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from anon;
revoke all on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
from authenticated;
grant execute on function public.plaid_reconcile_internal_transfer_candidates_for_user(uuid)
to service_role;
