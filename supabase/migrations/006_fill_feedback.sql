-- One combination per user and payee: the category and account they kept
-- after editing a smart-add review. Another user's rows are never read.

create table if not exists public.fill_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  payee_key text not null check (char_length(payee_key) between 1 and 80),
  display_name text check (display_name is null or char_length(display_name) <= 200),
  category_id uuid references public.categories (id) on delete set null,
  account_id uuid references public.accounts (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint fill_feedback_user_payee unique (user_id, payee_key)
);

create index if not exists fill_feedback_user_id_idx
  on public.fill_feedback (user_id);

alter table public.fill_feedback enable row level security;

drop policy if exists "fill_feedback_select_own" on public.fill_feedback;
create policy "fill_feedback_select_own" on public.fill_feedback
  for select using (auth.uid() = user_id);

drop policy if exists "fill_feedback_insert_own" on public.fill_feedback;
create policy "fill_feedback_insert_own" on public.fill_feedback
  for insert with check (auth.uid() = user_id);

drop policy if exists "fill_feedback_update_own" on public.fill_feedback;
create policy "fill_feedback_update_own" on public.fill_feedback
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "fill_feedback_delete_own" on public.fill_feedback;
create policy "fill_feedback_delete_own" on public.fill_feedback
  for delete using (auth.uid() = user_id);
