do $$
declare
    constraint_record record;
begin
    for constraint_record in
        select conname
        from pg_constraint
        where conrelid = 'public.budget_income_sources'::regclass
          and pg_get_constraintdef(oid) ilike '%income_type%'
    loop
        execute format(
            'alter table public.budget_income_sources drop constraint if exists %I',
            constraint_record.conname
        );
    end loop;
end;
$$;

alter table public.budget_income_sources
drop column if exists income_type;
