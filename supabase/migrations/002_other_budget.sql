-- Give "Other" a default monthly budget so uncategorized-style spend still tracks.
-- Safe to re-run.

update public.categories
set monthly_budget = 300
where type = 'expense'
  and lower(name) = 'other'
  and monthly_budget is null;
