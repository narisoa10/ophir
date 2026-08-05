alter table public.budget_obligations
add column name text;

alter table public.budget_obligations
add constraint budget_obligations_name_check
check (name is null or length(trim(name)) > 0);
