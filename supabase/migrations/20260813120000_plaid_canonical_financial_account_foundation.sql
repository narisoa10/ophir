-- Stage A (Edge Case №11): additive schema foundation only.
-- Does not backfill, link, or change runtime materialization behavior.

-- ---------------------------------------------------------------------------
-- 1) Optional Plaid persistent_account_id on account representations
-- ---------------------------------------------------------------------------

alter table public.accounts
    add column persistent_account_id text null
        constraint accounts_persistent_account_id_check
        check (
            persistent_account_id is null
            or trim(persistent_account_id) <> ''
        );

comment on column public.accounts.persistent_account_id is
    'Optional Plaid Accounts.persistent_account_id for this Plaid account representation. May be NULL; support is limited to Plaid-documented institutions/products. Not a universal identity. Equality may be used later only under official Plaid-supported semantics. Stage A does not ingest, link, or merge accounts from this column.';

create index accounts_user_persistent_account_id_idx
on public.accounts(user_id, persistent_account_id)
where persistent_account_id is not null;

-- ---------------------------------------------------------------------------
-- 2) Canonical financial account (one underlying economic ledger per user)
-- ---------------------------------------------------------------------------

create table public.plaid_canonical_financial_accounts (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_canonical_financial_accounts_id_user_id_unique
        unique (id, user_id)
);

comment on table public.plaid_canonical_financial_accounts is
    'Plaid-specific container for one underlying financial account / economic ledger owned by a single Ophir user. Physical cards, Items, and institution logins are not this identity. Stage A creates no rows and does not affect Operations or transaction identity (plaid_item_id, transaction_id).';

create index plaid_canonical_financial_accounts_user_id_idx
on public.plaid_canonical_financial_accounts(user_id);

create trigger plaid_canonical_financial_accounts_set_updated_at
before update on public.plaid_canonical_financial_accounts
for each row
execute function public.set_updated_at();

alter table public.plaid_canonical_financial_accounts enable row level security;

create policy "plaid_canonical_financial_accounts_select_own"
on public.plaid_canonical_financial_accounts
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.plaid_canonical_financial_accounts
from public, anon, authenticated;

grant select on table public.plaid_canonical_financial_accounts to authenticated;

grant select, insert, update, delete on table public.plaid_canonical_financial_accounts
to service_role;

-- ---------------------------------------------------------------------------
-- 3) Account-level membership (not Item-level)
-- ---------------------------------------------------------------------------

create table public.plaid_canonical_financial_account_members (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    canonical_account_id uuid not null,

    account_id uuid not null,

    role text not null
        constraint plaid_canonical_financial_account_members_role_check
        check (role in ('authoritative', 'secondary')),

    link_origin text not null
        constraint plaid_canonical_financial_account_members_link_origin_check
        check (
            link_origin in (
                'user_confirmed',
                'persistent_account_identity'
            )
        ),

    linked_at timestamptz not null default now(),

    unlinked_at timestamptz null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint plaid_canonical_financial_account_members_canonical_user_fkey
        foreign key (canonical_account_id, user_id)
        references public.plaid_canonical_financial_accounts(id, user_id)
        on delete cascade,

    constraint plaid_canonical_financial_account_members_account_user_fkey
        foreign key (account_id, user_id)
        references public.accounts(id, user_id)
        on delete restrict,

    constraint plaid_canonical_financial_account_members_unlink_order_check
        check (
            unlinked_at is null
            or unlinked_at >= linked_at
        )
);

comment on table public.plaid_canonical_financial_account_members is
    'Account-level membership of a concrete public.accounts row (Plaid representation) in a plaid_canonical_financial_accounts ledger. Not Item-level: sibling accounts on the same Item are not auto-linked. Manual accounts must not be linked (enforced by future linking domain; Stage A creates no memberships). Stage A does not enforce materialization authority.';

comment on column public.plaid_canonical_financial_account_members.role is
    'authoritative = sole active transaction-authority representation for the canonical ledger; secondary = retained Plaid representation without Stage A materialization effects. Authority enforcement is a future stage.';

comment on column public.plaid_canonical_financial_account_members.link_origin is
    'Evidence/provenance for the link. persistent_account_identity means PAI contributed evidence; V1 still expects explicit user confirmation at linking time (future stage). user_confirmed means user confirmation without PAI evidence. Stage A does not create links.';

comment on column public.plaid_canonical_financial_account_members.unlinked_at is
    'NULL means active membership. Non-NULL ends membership reversibly without destroying audit history or raw Plaid rows.';

-- One active membership per account representation.
create unique index plaid_canonical_financial_account_members_active_account_uidx
on public.plaid_canonical_financial_account_members(account_id)
where unlinked_at is null;

-- At most one active authoritative member per canonical ledger.
create unique index plaid_canonical_financial_account_members_active_authority_uidx
on public.plaid_canonical_financial_account_members(canonical_account_id)
where unlinked_at is null
  and role = 'authoritative';

create index plaid_canonical_financial_account_members_canonical_active_idx
on public.plaid_canonical_financial_account_members(canonical_account_id, linked_at)
where unlinked_at is null;

create index plaid_canonical_financial_account_members_user_id_idx
on public.plaid_canonical_financial_account_members(user_id);

create trigger plaid_canonical_financial_account_members_set_updated_at
before update on public.plaid_canonical_financial_account_members
for each row
execute function public.set_updated_at();

alter table public.plaid_canonical_financial_account_members enable row level security;

create policy "plaid_canonical_financial_account_members_select_own"
on public.plaid_canonical_financial_account_members
for select
to authenticated
using (auth.uid() = user_id);

revoke insert, update, delete on table public.plaid_canonical_financial_account_members
from public, anon, authenticated;

grant select on table public.plaid_canonical_financial_account_members to authenticated;

grant select, insert, update, delete on table public.plaid_canonical_financial_account_members
to service_role;
