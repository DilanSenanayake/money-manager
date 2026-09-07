-- Production hardening: ownership invariants, RLS WITH CHECK, composite indexes.
-- Run in Supabase SQL Editor after 001–003 (or via supabase db push).

-- ---------------------------------------------------------------------------
-- 1. Reject transactions whose account/category belong to another user
--    (defense in depth with SECURITY DEFINER balance trigger)
-- ---------------------------------------------------------------------------
create or replace function public.enforce_transaction_ownership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  account_owner uuid;
  category_owner uuid;
begin
  select user_id into account_owner
  from public.accounts
  where id = new.account_id;

  if account_owner is null then
    raise exception 'account_not_found';
  end if;

  if account_owner <> new.user_id then
    raise exception 'account_ownership_mismatch';
  end if;

  if new.category_id is not null then
    select user_id into category_owner
    from public.categories
    where id = new.category_id;

    if category_owner is null then
      raise exception 'category_not_found';
    end if;

    if category_owner <> new.user_id then
      raise exception 'category_ownership_mismatch';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_transaction_ownership on public.transactions;
create trigger trg_enforce_transaction_ownership
  before insert or update of account_id, category_id, user_id
  on public.transactions
  for each row
  execute function public.enforce_transaction_ownership();

-- ---------------------------------------------------------------------------
-- 2. RLS UPDATE policies: require WITH CHECK so user_id cannot be reassigned
-- ---------------------------------------------------------------------------
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "accounts_update_own" on public.accounts;
create policy "accounts_update_own" on public.accounts
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "categories_update_own" on public.categories;
create policy "categories_update_own" on public.categories
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own" on public.transactions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "exchange_rates_update_own" on public.exchange_rates;
create policy "exchange_rates_update_own" on public.exchange_rates
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3. Composite indexes for common dashboard / list filters
-- ---------------------------------------------------------------------------
create index if not exists idx_transactions_user_date
  on public.transactions (user_id, date desc);

create index if not exists idx_transactions_user_category_date
  on public.transactions (user_id, category_id, date desc);

create index if not exists idx_transactions_user_recurring
  on public.transactions (user_id, is_recurring)
  where is_recurring = true;

create index if not exists idx_accounts_user_created
  on public.accounts (user_id, created_at asc);
