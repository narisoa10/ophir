begin;

alter table public.operations
alter column occurred_at type date
using (occurred_at at time zone 'UTC')::date;

commit;
