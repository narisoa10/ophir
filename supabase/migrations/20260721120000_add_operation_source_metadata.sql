alter table public.operations
add column source text not null default 'manual',
add column external_id text null,
add column is_pending boolean not null default false;
