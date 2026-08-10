drop policy if exists "Users can update own accounts"
on public.accounts;

drop policy if exists "Users can delete own accounts"
on public.accounts;

revoke update on table public.accounts from public, anon, authenticated;
revoke delete on table public.accounts from public, anon, authenticated;

grant update (is_included_in_finances)
on public.accounts
to authenticated;

create policy "accounts_update_financial_participation_own"
on public.accounts
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
