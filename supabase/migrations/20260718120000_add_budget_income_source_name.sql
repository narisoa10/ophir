alter table public.budget_income_sources
add column if not exists name text;

update public.budget_income_sources
set name = coalesce(nullif(name, ''), category_id::text, '')
where name is null or name = '';

alter table public.budget_income_sources
alter column name set not null;
