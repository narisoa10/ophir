-- Drop the legacy bankSync columns operations.external_id and
-- operations.is_pending (added by 20260721120000). The Plaid pipeline links a
-- transaction to its operation through plaid_transaction_operation_projections
-- and keeps pending state in plaid_transactions.pending; nothing writes or reads
-- these columns.
--
-- LIVE no longer has either column. Each column is dropped only if it exists, so
-- on such a database public.operations is not altered and not locked.
-- No CASCADE: a dependent object must make this migration fail.

do $$
begin
    if exists (
        select 1
        from pg_attribute
        where attrelid = 'public.operations'::regclass
          and attname = 'external_id'
          and not attisdropped
    ) then
        alter table public.operations drop column external_id;
    end if;

    if exists (
        select 1
        from pg_attribute
        where attrelid = 'public.operations'::regclass
          and attname = 'is_pending'
          and not attisdropped
    ) then
        alter table public.operations drop column is_pending;
    end if;
end;
$$;
