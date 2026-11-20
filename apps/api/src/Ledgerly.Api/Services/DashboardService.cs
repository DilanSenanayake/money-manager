using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface IDashboardService
{
    Task<DashboardResponse> GetDashboardAsync(CancellationToken ct = default);
    Task<AnalyticsResponse> GetAnalyticsAsync(CancellationToken ct = default);
    Task<List<BudgetProgress>> GetBudgetsAsync(CancellationToken ct = default);
}

public sealed class DashboardService(ISupabaseRestClient supabase, ICurrentUser user) : IDashboardService
{
    public async Task<DashboardResponse> GetDashboardAsync(CancellationToken ct = default)
    {
        var profileTask = supabase.GetSingleAsync<Profile>(
            "profiles", $"id=eq.{user.UserId}", ct);
        var accountsTask = supabase.GetListAsync<Account>(
            "accounts", $"user_id=eq.{user.UserId}", ct);
        var categoriesTask = supabase.GetListAsync<Category>(
            "categories", $"user_id=eq.{user.UserId}", ct);
        var ratesTask = supabase.GetListAsync<ExchangeRate>(
            "exchange_rates", $"user_id=eq.{user.UserId}", ct);

        await Task.WhenAll(profileTask, accountsTask, categoriesTask, ratesTask);

        var profile = await profileTask;
        var accounts = await accountsTask;
        var categories = await categoriesTask;
        var rates = await ratesTask;

        var monthStart = DateHelpers.LocalMonthStartYyyyMmDd();
        var monthEnd = DateHelpers.LocalMonthEndYyyyMmDd();

        var monthTx = await supabase.GetListAsync<Transaction>(
            "transactions",
            $"user_id=eq.{user.UserId}&date=gte.{monthStart}&date=lte.{monthEnd}&order=date.desc&limit=2000",
            ct);

        var recent = await supabase.GetListAsync<Transaction>(
            "transactions",
            $"select={Uri.EscapeDataString("*,account:accounts(*),category:categories(*)")}&user_id=eq.{user.UserId}&order=date.desc,created_at.desc&limit=8",
            ct);

        var baseCurrency = profile?.BaseCurrency ?? "USD";
        var currencyByAccount = CurrencyConverter.AccountCurrencyMap(accounts);
        var netWorth = CurrencyConverter.ComputeNetWorth(accounts, baseCurrency, rates);

        string CurrencyOf(Transaction t) =>
            currencyByAccount.GetValueOrDefault(t.AccountId, baseCurrency);

        decimal? SumType(string type)
        {
            decimal sum = 0;
            foreach (var transaction in monthTx.Where(t => t.Type == type))
            {
                if (!CurrencyConverter.TryConvertToBase(
                        transaction.Amount, CurrencyOf(transaction), baseCurrency, rates, out var converted))
                    return null;
                sum += converted;
            }

            return sum;
        }

        var budgets = categories
            .Where(c =>
                c.Type == CategoryTypes.Expense &&
                c.MonthlyBudget is > 0)
            .Select(category =>
            {
                var limit = category.MonthlyBudget ?? 0;
                decimal spent = 0;
                var missing = new List<string>();
                foreach (var transaction in monthTx.Where(t =>
                             t.Type == TransactionTypes.Expense &&
                             t.CategoryId == category.Id))
                {
                    var currency = CurrencyOf(transaction);
                    if (!CurrencyConverter.TryConvertToBase(
                            transaction.Amount, currency, baseCurrency, rates, out var converted))
                    {
                        if (!missing.Contains(currency)) missing.Add(currency);
                    }
                    else
                    {
                        spent += converted;
                    }
                }

                if (missing.Count > 0)
                {
                    return new BudgetProgress
                    {
                        Category = category,
                        Spent = 0,
                        Limit = limit,
                        Ratio = 0,
                        Status = "incomplete",
                        MissingRateCurrencies = missing,
                    };
                }

                var ratio = limit > 0 ? spent / limit : 0;
                return new BudgetProgress
                {
                    Category = category,
                    Spent = spent,
                    Limit = limit,
                    Ratio = ratio,
                    Status = BudgetHelpers.BudgetStatus(spent, limit),
                };
            })
            .OrderByDescending(b => b.Status == "incomplete")
            .ThenByDescending(b => b.Ratio)
            .ToList();

        var missingRateCurrencies = CurrencyConverter.MissingCurrencies(
            accounts.Select(a => a.Currency).Concat(monthTx.Select(CurrencyOf)),
            baseCurrency,
            rates);

        return new DashboardResponse
        {
            Profile = profile,
            Accounts = accounts,
            Rates = rates,
            NetWorth = netWorth,
            Income = SumType(TransactionTypes.Income),
            Expense = SumType(TransactionTypes.Expense),
            MissingRateCurrencies = missingRateCurrencies,
            Budgets = budgets,
            Recent = recent,
            BaseCurrency = baseCurrency,
            MonthStart = monthStart,
            MonthEnd = monthEnd,
        };
    }

    public async Task<AnalyticsResponse> GetAnalyticsAsync(CancellationToken ct = default)
    {
        var now = DateTime.Now;
        var chartMonths = Enumerable.Range(0, 6)
            .Select(i =>
            {
                var d = now.AddMonths(-(5 - i));
                return new
                {
                    Key = $"{d.Year:D4}-{d.Month:D2}",
                    Label = d.ToString("MMM"),
                    From = DateHelpers.LocalMonthStartYyyyMmDd(d),
                    To = DateHelpers.LocalMonthEndYyyyMmDd(d),
                };
            })
            .ToList();

        var txTask = LoadAllTransactionsAsync(ct);
        var categoriesTask = supabase.GetListAsync<Category>(
            "categories",
            $"user_id=eq.{user.UserId}&type=eq.expense",
            ct);
        var accountsTask = supabase.GetListAsync<Account>(
            "accounts",
            $"select=id,currency&user_id=eq.{user.UserId}",
            ct);
        var profileTask = supabase.GetSingleAsync<Profile>(
            "profiles",
            $"select=base_currency&id=eq.{user.UserId}",
            ct);
        var ratesTask = supabase.GetListAsync<ExchangeRate>(
            "exchange_rates",
            $"user_id=eq.{user.UserId}",
            ct);

        await Task.WhenAll(txTask, categoriesTask, accountsTask, profileTask, ratesTask);

        var tx = await txTask;
        var categories = await categoriesTask;
        var accounts = await accountsTask;
        var profile = await profileTask;
        var rates = await ratesTask;

        var baseCurrency = profile?.BaseCurrency ?? "USD";
        var currencyByAccount = CurrencyConverter.AccountCurrencyMap(accounts);
        var missingRateCurrencies = CurrencyConverter.MissingCurrencies(
            tx.Select(t => currencyByAccount.GetValueOrDefault(t.AccountId, baseCurrency)),
            baseCurrency,
            rates);
        if (missingRateCurrencies.Count > 0)
        {
            return new AnalyticsResponse
            {
                BaseCurrency = baseCurrency,
                MissingRateCurrencies = missingRateCurrencies,
            };
        }

        decimal ToBase(Transaction t)
        {
            var from = currencyByAccount.GetValueOrDefault(t.AccountId, baseCurrency);
            return CurrencyConverter.TryConvertToBase(t.Amount, from, baseCurrency, rates, out var converted)
                ? converted
                : 0;
        }

        var trend = chartMonths.Select(m =>
        {
            var inMonth = tx.Where(t => t.Date.CompareTo(m.From) >= 0 && t.Date.CompareTo(m.To) <= 0);
            return new TrendPoint
            {
                Month = m.Label,
                Income = inMonth.Where(t => t.Type == TransactionTypes.Income).Sum(ToBase),
                Expense = inMonth.Where(t => t.Type == TransactionTypes.Expense).Sum(ToBase),
            };
        }).ToList();

        var thisMonth = chartMonths[^1];
        var categorySpend = categories
            .Select(cat =>
            {
                var rows = tx
                    .Where(t =>
                        t.Type == TransactionTypes.Expense &&
                        t.CategoryId == cat.Id &&
                        t.Date.CompareTo(thisMonth.From) >= 0 &&
                        t.Date.CompareTo(thisMonth.To) <= 0)
                    .OrderByDescending(t => t.Date, StringComparer.Ordinal)
                    .ThenBy(t => t.Merchant ?? "", StringComparer.OrdinalIgnoreCase)
                    .ThenBy(t => t.Id)
                    .ToList();
                var expenses = rows
                    .Select(t => new CategoryExpenseItem
                    {
                        Id = t.Id,
                        Date = t.Date,
                        Merchant = string.IsNullOrWhiteSpace(t.Merchant) ? null : t.Merchant.Trim(),
                        Amount = Math.Round(ToBase(t), 2, MidpointRounding.AwayFromZero),
                    })
                    .ToList();
                return new CategorySpendPoint
                {
                    CategoryId = cat.Id,
                    Name = cat.Name,
                    Value = Math.Round(expenses.Sum(e => e.Amount), 2, MidpointRounding.AwayFromZero),
                    Count = expenses.Count,
                    Expenses = expenses,
                };
            })
            .Where(c => c.Value > 0)
            .OrderByDescending(c => c.Value)
            .ToList();

        var categoryNames = categories.ToDictionary(c => c.Id, c => c.Name);
        var (months, summary) = MonthlyReportBuilder.Build(tx, categoryNames, ToBase, now);

        return new AnalyticsResponse
        {
            Trend = trend,
            CategorySpend = categorySpend,
            Months = months,
            Summary = summary,
            BaseCurrency = baseCurrency,
        };
    }

    private async Task<List<Transaction>> LoadAllTransactionsAsync(CancellationToken ct)
    {
        const int pageSize = 1000;
        var all = new List<Transaction>();
        for (var offset = 0; offset < 50_000; offset += pageSize)
        {
            var page = await supabase.GetListAsync<Transaction>(
                "transactions",
                $"select=id,amount,type,date,account_id,category_id,merchant&user_id=eq.{user.UserId}&order=date.asc,id.asc&limit={pageSize}&offset={offset}",
                ct);
            all.AddRange(page);
            if (page.Count < pageSize) break;
        }

        return all;
    }

    public async Task<List<BudgetProgress>> GetBudgetsAsync(CancellationToken ct = default)
    {
        var data = await GetDashboardAsync(ct);
        return data.Budgets;
    }
}
