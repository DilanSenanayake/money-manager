-- Shortcuts the user saves for one-tap entry. Separate from the
-- computed "most used" list. Another user's rows are never read.

create table if not exists public.quick_adds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  merchant text not null check (char_length(merchant) between 1 and 200),
  notes text check (notes is null or char_length(notes) <= 1000),
  category_id uuid references public.categories (id) on delete set null,
  amount numeric(18, 2) not null check (amount > 0),
  type text not null check (type in ('income', 'expense')),
  created_at timestamptz not null default now()
);

create index if not exists quick_adds_user_id_idx
  on public.quick_adds (user_id, created_at);

alter table public.quick_adds enable row level security;

drop policy if exists "quick_adds_select_own" on public.quick_adds;
create policy "quick_adds_select_own" on public.quick_adds
  for select using (auth.uid() = user_id);

drop policy if exists "quick_adds_insert_own" on public.quick_adds;
create policy "quick_adds_insert_own" on public.quick_adds
  for insert with check (auth.uid() = user_id);

drop policy if exists "quick_adds_update_own" on public.quick_adds;
create policy "quick_adds_update_own" on public.quick_adds
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "quick_adds_delete_own" on public.quick_adds;
create policy "quick_adds_delete_own" on public.quick_adds
  for delete using (auth.uid() = user_id);
