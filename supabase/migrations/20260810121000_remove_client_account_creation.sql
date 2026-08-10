drop policy if exists "Users can insert own accounts"
on public.accounts;

revoke insert on table public.accounts from anon, authenticated;
