alter table public.operations
add column if not exists archived_at timestamptz null;
