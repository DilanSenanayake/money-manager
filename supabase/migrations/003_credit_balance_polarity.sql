-- Credit accounts store a positive "amount owed" (liability).
-- Net worth already subtracts credit balances; balance triggers previously
-- treated credit like asset accounts (charges decreased owed, payments increased it).
-- Invert deltas for type = 'credit' so:
--   expense / transfer out  → owed increases
--   income  / transfer in   → owed decreases (payment)

create or replace function public.balance_delta(
  acct_type text,
  tx_type text,
  transfer_direction text,
  amount numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  signed numeric := 0;
begin
  if tx_type = 'income' or (tx_type = 'transfer' and transfer_direction = 'in') then
    signed := amount;   -- money into account (asset ↑ / liability ↓)
  elsif tx_type = 'expense' or (tx_type = 'transfer' and transfer_direction = 'out') then
    signed := -amount;  -- money out of account (asset ↓ / liability ↑)
  else
    return 0;
  end if;

  -- Credit cards: positive balance = amount owed → invert asset-style deltas
  if acct_type = 'credit' then
    return -signed;
  end if;
  return signed;
end;
$$;

create or replace function public.apply_transaction_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acct_type text;
  delta numeric;
begin
  if tg_op = 'INSERT' then
    select type into acct_type from public.accounts where id = new.account_id;
    delta := public.balance_delta(acct_type, new.type, new.transfer_direction, new.amount);
    if delta <> 0 then
      update public.accounts set balance = balance + delta where id = new.account_id;
    end if;
    return new;

  elsif tg_op = 'DELETE' then
    select type into acct_type from public.accounts where id = old.account_id;
    delta := public.balance_delta(acct_type, old.type, old.transfer_direction, old.amount);
    if delta <> 0 then
      -- reverse the original apply
      update public.accounts set balance = balance - delta where id = old.account_id;
    end if;
    return old;

  elsif tg_op = 'UPDATE' then
    -- reverse old
    select type into acct_type from public.accounts where id = old.account_id;
    delta := public.balance_delta(acct_type, old.type, old.transfer_direction, old.amount);
    if delta <> 0 then
      update public.accounts set balance = balance - delta where id = old.account_id;
    end if;
    -- apply new
    select type into acct_type from public.accounts where id = new.account_id;
    delta := public.balance_delta(acct_type, new.type, new.transfer_direction, new.amount);
    if delta <> 0 then
      update public.accounts set balance = balance + delta where id = new.account_id;
    end if;
    return new;
  end if;
  return null;
end;
$$;
