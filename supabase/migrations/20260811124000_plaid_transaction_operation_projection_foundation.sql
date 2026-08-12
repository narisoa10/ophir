create table public.plaid_transaction_operation_projections (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    plaid_item_id uuid not null,

    plaid_transaction_id text not null
        constraint plaid_transaction_operation_projections_transaction_id_check
        check (trim(plaid_transaction_id) <> ''),

    pending_transaction_id text null
        constraint plaid_transaction_operation_projections_pending_transaction_id_check
        check (
            pending_transaction_id is null
            or trim(pending_transaction_id) <> ''
        ),

    replaced_pending_projection_id uuid null,

    operation_id uuid null
        references public.operations(id)
        on delete set null,

    state text not null default 'raw_pending'
        constraint plaid_transaction_operation_projections_state_check
        check (
            state in (
                'raw_pending',
                'posted_ready',
                'posted_projected',
                'removed_inactive',
                'suppressed',
                'projection_failed'
            )
        ),

    projection_attempt_count integer not null default 0
        constraint plaid_transaction_operation_projections_attempt_count_check
        check (projection_attempt_count >= 0),

    last_error_code text null
        constraint plaid_transaction_operation_projections_last_error_code_check
        check (
            last_error_code is null
            or trim(last_error_code) <> ''
        ),

    last_error_at timestamptz null,

    last_projected_at timestamptz null,

    suppressed_reason text null
        constraint plaid_transaction_operation_projections_suppressed_reason_check
        check (
            suppressed_reason is null
            or trim(suppressed_reason) <> ''
        ),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint plaid_transaction_operation_projections_raw_unique
        unique (plaid_item_id, plaid_transaction_id),

    constraint plaid_transaction_operation_projections_item_user_fkey
        foreign key (plaid_item_id, user_id)
        references public.plaid_items(id, user_id)
        on delete restrict,

    constraint plaid_transaction_operation_projections_raw_fkey
        foreign key (plaid_item_id, plaid_transaction_id)
        references public.plaid_transactions(plaid_item_id, transaction_id)
        on delete restrict,

    constraint plaid_transaction_operation_projections_replaced_pending_fkey
        foreign key (replaced_pending_projection_id)
        references public.plaid_transaction_operation_projections(id)
        on delete set null,

    constraint plaid_transaction_operation_projections_not_self_replaced_check
        check (
            replaced_pending_projection_id is null
            or replaced_pending_projection_id <> id
        )
);

comment on table public.plaid_transaction_operation_projections is
    'Server-owned reconciliation foundation from raw Plaid transactions to future Ophir Operations. Does not create or mutate Operations.';

comment on column public.plaid_transaction_operation_projections.plaid_transaction_id is
    'Case-sensitive Plaid transaction_id. Projection identity is scoped to plaid_item_id and must not use merchant, date, name, or amount.';

comment on column public.plaid_transaction_operation_projections.pending_transaction_id is
    'Raw Plaid pending_transaction_id from the posted transaction when Plaid can match a pending transaction to its posted replacement.';

comment on column public.plaid_transaction_operation_projections.replaced_pending_projection_id is
    'Optional self-link from a posted projection to the pending projection it replaced.';

comment on column public.plaid_transaction_operation_projections.operation_id is
    'Nullable future Operation link. This foundation migration never writes Operations.';

create unique index plaid_transaction_operation_projections_operation_unique_idx
on public.plaid_transaction_operation_projections(operation_id)
where operation_id is not null;

create index plaid_transaction_operation_projections_item_state_idx
on public.plaid_transaction_operation_projections(plaid_item_id, state, updated_at);

create index plaid_transaction_operation_projections_replaced_pending_idx
on public.plaid_transaction_operation_projections(replaced_pending_projection_id)
where replaced_pending_projection_id is not null;

create trigger plaid_transaction_operation_projections_set_updated_at
before update on public.plaid_transaction_operation_projections
for each row
execute function public.set_updated_at();

alter table public.plaid_transaction_operation_projections enable row level security;

revoke all on table public.plaid_transaction_operation_projections
from public, anon, authenticated;

grant select, insert, update, delete on table public.plaid_transaction_operation_projections
to service_role;
