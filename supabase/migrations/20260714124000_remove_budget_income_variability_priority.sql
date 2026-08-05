alter table public.budget_income_sources
  drop constraint if exists budget_income_sources_variability_check;

alter table public.budget_income_sources
  drop constraint if exists budget_income_sources_priority_check;

alter table public.budget_income_sources
  drop column if exists variability;

alter table public.budget_income_sources
  drop column if exists priority;