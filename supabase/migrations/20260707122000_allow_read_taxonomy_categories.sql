create policy "Anyone authenticated can read taxonomy categories"
on public.categories
for select
to authenticated
using (stable_key is not null);
