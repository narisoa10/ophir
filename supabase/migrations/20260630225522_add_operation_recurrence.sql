alter table public.operations
add column recurrence text not null default 'none';

alter table public.operations
add constraint operations_recurrence_check
check (
    recurrence in (
        'none',
        'daily',
        'weekly',
        'biweekly',
        'monthly',
        'yearly'
    )
);