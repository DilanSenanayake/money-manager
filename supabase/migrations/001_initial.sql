-- Money Manager initial schema with RLS
-- Run in Supabase SQL Editor or via supabase db push

create extension if not exists "pgcrypto";

-- Profiles (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  base_currency text not null default 'USD',
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Accounts
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('cash', 'checking', 'savings', 'credit')),
  balance numeric(18, 2) not null default 0,
  currency text not null default 'USD',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists accounts_user_id_idx on public.accounts (user_id);

-- Categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  icon text not null default 'circle',
  type text not null check (type in ('income', 'expense')),
  monthly_budget numeric(18, 2),
  created_at timestamptz not null default now()
);

create index if not exists categories_user_id_idx on public.categories (user_id);

-- Transactions
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.accounts (id) on delete cascade,
  category_id uuid references public.categories (id) on delete set null,
  amount numeric(18, 2) not null check (amount > 0),
  type text not null check (type in ('income', 'expense', 'transfer')),
  date date not null default current_date,
  merchant text,
  notes text,
  is_recurring boolean not null default false,
  recurring_frequency text check (
    recurring_frequency is null
    or recurring_frequency in ('weekly', 'monthly', 'yearly')
  ),
  transfer_pair_id uuid,
  transfer_direction text check (
    transfer_direction is null
    or transfer_direction in ('out', 'in')
  ),
  created_at timestamptz not null default now()
);

create index if not exists transactions_user_id_idx on public.transactions (user_id);
create index if not exists transactions_account_id_idx on public.transactions (account_id);
create index if not exists transactions_date_idx on public.transactions (date);
create index if not exists transactions_transfer_pair_id_idx on public.transactions (transfer_pair_id);

-- Exchange rates (manual)
create table if not exists public.exchange_rates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  from_currency text not null,
  to_currency text not null,
  rate numeric(18, 8) not null check (rate > 0),
  updated_at timestamptz not null default now(),
  unique (user_id, from_currency, to_currency)
);

create index if not exists exchange_rates_user_id_idx on public.exchange_rates (user_id);

-- Updated_at helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists accounts_updated_at on public.accounts;
create trigger accounts_updated_at
  before update on public.accounts
  for each row execute function public.set_updated_at();

-- Seed default categories + profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, base_currency, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'base_currency', 'USD'),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );

  insert into public.categories (user_id, name, icon, type, monthly_budget) values
    (new.id, 'Salary', 'wallet', 'income', null),
    (new.id, 'Freelance', 'briefcase', 'income', null),
    (new.id, 'Investments', 'trending-up', 'income', null),
    (new.id, 'Groceries', 'shopping-cart', 'expense', 500),
    (new.id, 'Dining', 'utensils', 'expense', 200),
    (new.id, 'Transport', 'car', 'expense', 150),
    (new.id, 'Shopping', 'shopping-bag', 'expense', 200),
    (new.id, 'Utilities', 'zap', 'expense', 150),
    (new.id, 'Health', 'heart', 'expense', 100),
    (new.id, 'Entertainment', 'film', 'expense', 100),
    (new.id, 'Rent', 'home', 'expense', 1200),
    (new.id, 'Other', 'circle', 'expense', 300);

  insert into public.accounts (user_id, name, type, balance, currency) values
    (new.id, 'Cash', 'cash', 0, coalesce(new.raw_user_meta_data->>'base_currency', 'USD')),
    (new.id, 'Checking', 'checking', 0, coalesce(new.raw_user_meta_data->>'base_currency', 'USD'));

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Balance sync on transaction insert/update/delete
create or replace function public.apply_transaction_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.type = 'income' or (new.type = 'transfer' and new.transfer_direction = 'in') then
      update public.accounts set balance = balance + new.amount where id = new.account_id;
    elsif new.type = 'expense' or (new.type = 'transfer' and new.transfer_direction = 'out') then
      update public.accounts set balance = balance - new.amount where id = new.account_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.type = 'income' or (old.type = 'transfer' and old.transfer_direction = 'in') then
      update public.accounts set balance = balance - old.amount where id = old.account_id;
    elsif old.type = 'expense' or (old.type = 'transfer' and old.transfer_direction = 'out') then
      update public.accounts set balance = balance + old.amount where id = old.account_id;
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    if old.type = 'income' or (old.type = 'transfer' and old.transfer_direction = 'in') then
      update public.accounts set balance = balance - old.amount where id = old.account_id;
    elsif old.type = 'expense' or (old.type = 'transfer' and old.transfer_direction = 'out') then
      update public.accounts set balance = balance + old.amount where id = old.account_id;
    end if;
    if new.type = 'income' or (new.type = 'transfer' and new.transfer_direction = 'in') then
      update public.accounts set balance = balance + new.amount where id = new.account_id;
    elsif new.type = 'expense' or (new.type = 'transfer' and new.transfer_direction = 'out') then
      update public.accounts set balance = balance - new.amount where id = new.account_id;
    end if;
    return new;
  end if;
  return null;
end;
$$;

drop trigger if exists transactions_balance_ai on public.transactions;
create trigger transactions_balance_ai
  after insert on public.transactions
  for each row execute function public.apply_transaction_balance();

drop trigger if exists transactions_balance_au on public.transactions;
create trigger transactions_balance_au
  after update on public.transactions
  for each row execute function public.apply_transaction_balance();

drop trigger if exists transactions_balance_ad on public.transactions;
create trigger transactions_balance_ad
  after delete on public.transactions
  for each row execute function public.apply_transaction_balance();

-- RLS
alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.exchange_rates enable row level security;

-- Profiles policies
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Accounts policies
drop policy if exists "accounts_select_own" on public.accounts;
create policy "accounts_select_own" on public.accounts for select using (auth.uid() = user_id);
drop policy if exists "accounts_insert_own" on public.accounts;
create policy "accounts_insert_own" on public.accounts for insert with check (auth.uid() = user_id);
drop policy if exists "accounts_update_own" on public.accounts;
create policy "accounts_update_own" on public.accounts for update using (auth.uid() = user_id);
drop policy if exists "accounts_delete_own" on public.accounts;
create policy "accounts_delete_own" on public.accounts for delete using (auth.uid() = user_id);

-- Categories policies
drop policy if exists "categories_select_own" on public.categories;
create policy "categories_select_own" on public.categories for select using (auth.uid() = user_id);
drop policy if exists "categories_insert_own" on public.categories;
create policy "categories_insert_own" on public.categories for insert with check (auth.uid() = user_id);
drop policy if exists "categories_update_own" on public.categories;
create policy "categories_update_own" on public.categories for update using (auth.uid() = user_id);
drop policy if exists "categories_delete_own" on public.categories;
create policy "categories_delete_own" on public.categories for delete using (auth.uid() = user_id);

-- Transactions policies
drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own" on public.transactions for select using (auth.uid() = user_id);
drop policy if exists "transactions_insert_own" on public.transactions;
create policy "transactions_insert_own" on public.transactions for insert with check (auth.uid() = user_id);
drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own" on public.transactions for update using (auth.uid() = user_id);
drop policy if exists "transactions_delete_own" on public.transactions;
create policy "transactions_delete_own" on public.transactions for delete using (auth.uid() = user_id);

-- Exchange rates policies
drop policy if exists "exchange_rates_select_own" on public.exchange_rates;
create policy "exchange_rates_select_own" on public.exchange_rates for select using (auth.uid() = user_id);
drop policy if exists "exchange_rates_insert_own" on public.exchange_rates;
create policy "exchange_rates_insert_own" on public.exchange_rates for insert with check (auth.uid() = user_id);
drop policy if exists "exchange_rates_update_own" on public.exchange_rates;
create policy "exchange_rates_update_own" on public.exchange_rates for update using (auth.uid() = user_id);
drop policy if exists "exchange_rates_delete_own" on public.exchange_rates;
create policy "exchange_rates_delete_own" on public.exchange_rates for delete using (auth.uid() = user_id);
