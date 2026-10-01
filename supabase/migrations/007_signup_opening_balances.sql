-- Opening balances supplied at signup (user metadata). Missing or invalid values stay 0.
-- A savings wallet is created only when its opening balance is greater than zero.

create or replace function public.parse_opening_balance(raw text)
returns numeric
language plpgsql
immutable
as $$
declare
  value numeric;
  cleaned text;
begin
  cleaned := nullif(btrim(coalesce(raw, '')), '');
  if cleaned is null then
    return 0;
  end if;
  if cleaned !~ '^[0-9]+(\.[0-9]{1,2})?$' then
    return 0;
  end if;
  value := cleaned::numeric;
  if value > 999999999.99 then
    return 0;
  end if;
  return value;
exception
  when others then
    return 0;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  currency text;
  cash_balance numeric;
  checking_balance numeric;
  savings_balance numeric;
begin
  currency := coalesce(nullif(new.raw_user_meta_data->>'base_currency', ''), 'USD');
  cash_balance := public.parse_opening_balance(new.raw_user_meta_data->>'cash_balance');
  checking_balance := public.parse_opening_balance(new.raw_user_meta_data->>'checking_balance');
  savings_balance := public.parse_opening_balance(new.raw_user_meta_data->>'savings_balance');

  insert into public.profiles (id, base_currency, display_name)
  values (
    new.id,
    currency,
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
    (new.id, 'Cash', 'cash', cash_balance, currency),
    (new.id, 'Checking', 'checking', checking_balance, currency);

  if savings_balance > 0 then
    insert into public.accounts (user_id, name, type, balance, currency)
    values (new.id, 'Savings', 'savings', savings_balance, currency);
  end if;

  return new;
end;
$$;
