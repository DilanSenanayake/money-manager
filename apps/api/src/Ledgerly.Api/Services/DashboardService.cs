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
            $"user_id=eq.{user.UserId}&date=gte.{monthStart}&date=lte.{monthEnd}",
            ct);

        var recent = await supabase.GetListAsync<Transaction>(
            "transactions",
            $"select={Uri.EscapeDataString("*,account:accounts(*),category:categories(*)")}&user_id=eq.{user.UserId}&order=date.desc,created_at.desc&limit=8",
            ct);

        var baseCurrency = profile?.BaseCurrency ?? "USD";
        var currencyByAccount = CurrencyConverter.AccountCurrencyMap(accounts);
        var netWorth = CurrencyConverter.ComputeNetWorth(accounts, baseCurrency, rates);

        decimal ToBase(Transaction t) =>
            CurrencyConverter.TxAmountInBase(
                t.Amount, t.AccountId, currencyByAccount, baseCurrency, rates);

        var income = monthTx.Where(t => t.Type == TransactionTypes.Income).Sum(ToBase);
        var expense = monthTx.Where(t => t.Type == TransactionTypes.Expense).Sum(ToBase);

        var budgets = categories
            .Where(c =>
                c.Type == CategoryTypes.Expense &&
                c.MonthlyBudget is > 0)
            .Select(category =>
            {
                var spent = monthTx
                    .Where(t =>
                        t.Type == TransactionTypes.Expense &&
                        t.CategoryId == category.Id)
                    .Sum(ToBase);
                var limit = category.MonthlyBudget ?? 0;
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
            .OrderByDescending(b => b.Ratio)
            .ToList();

        return new DashboardResponse
        {
            Profile = profile,
            Accounts = accounts,
            Rates = rates,
            NetWorth = netWorth,
            Income = income,
            Expense = expense,
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
        var months = Enumerable.Range(0, 6)
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

        var rangeFrom = months[0].From;
        var rangeTo = months[^1].To;

        var txTask = supabase.GetListAsync<Transaction>(
            "transactions",
            $"user_id=eq.{user.UserId}&date=gte.{rangeFrom}&date=lte.{rangeTo}",
            ct);
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
        decimal ToBase(Transaction t) =>
            CurrencyConverter.TxAmountInBase(
                t.Amount, t.AccountId, currencyByAccount, baseCurrency, rates);

        var trend = months.Select(m =>
        {
            var inMonth = tx.Where(t => t.Date.CompareTo(m.From) >= 0 && t.Date.CompareTo(m.To) <= 0);
            return new TrendPoint
            {
                Month = m.Label,
                Income = inMonth.Where(t => t.Type == TransactionTypes.Income).Sum(ToBase),
                Expense = inMonth.Where(t => t.Type == TransactionTypes.Expense).Sum(ToBase),
            };
        }).ToList();

        var thisMonth = months[^1];
        var categorySpend = categories
            .Select(cat =>
            {
                var spent = tx
                    .Where(t =>
                        t.Type == TransactionTypes.Expense &&
                        t.CategoryId == cat.Id &&
                        t.Date.CompareTo(thisMonth.From) >= 0 &&
                        t.Date.CompareTo(thisMonth.To) <= 0)
                    .Sum(ToBase);
                return new CategorySpendPoint { Name = cat.Name, Value = spent };
            })
            .Where(c => c.Value > 0)
            .OrderByDescending(c => c.Value)
            .ToList();

        return new AnalyticsResponse
        {
            Trend = trend,
            CategorySpend = categorySpend,
            BaseCurrency = baseCurrency,
        };
    }

    public async Task<List<BudgetProgress>> GetBudgetsAsync(CancellationToken ct = default)
    {
        var data = await GetDashboardAsync(ct);
        return data.Budgets;
    }
}
