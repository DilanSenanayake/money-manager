using System.Globalization;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class MonthlyReportBuilder
{
    public const int TopCategories = 8;
    public const int TopMerchants = 5;

    public static (List<MonthlyReport> Months, SpendingReportSummary Summary) Build(
        IEnumerable<Transaction> transactions,
        IReadOnlyDictionary<Guid, string> categoryNames,
        Func<Transaction, decimal> toBase,
        DateTime? today = null)
    {
        var buckets = new Dictionary<string, List<Transaction>>(StringComparer.Ordinal);
        foreach (var tx in transactions)
        {
            if (tx.Type != TransactionTypes.Income && tx.Type != TransactionTypes.Expense)
                continue;
            if (!TryMonthKey(tx.Date, out var key))
                continue;
            if (!buckets.TryGetValue(key, out var rows))
            {
                rows = [];
                buckets[key] = rows;
            }
            rows.Add(tx);
        }

        if (buckets.Count == 0)
            return ([], EmptySummary());

        var start = buckets.Keys.Min(StringComparer.Ordinal)!;
        var latest = buckets.Keys.Max(StringComparer.Ordinal)!;
        var now = today ?? DateTime.Now;
        var todayKey = $"{now.Year:D4}-{now.Month:D2}";
        var end = string.CompareOrdinal(latest, todayKey) > 0 ? latest : todayKey;

        var months = new List<MonthlyReport>();
        decimal? previousExpense = null;
        var cursor = DateTime.ParseExact(start + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture);
        var endDate = DateTime.ParseExact(end + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture);

        while (cursor <= endDate)
        {
            var key = $"{cursor:yyyy-MM}";
            var hasActivity = buckets.ContainsKey(key);
            if (!hasActivity && key != todayKey)
            {
                previousExpense = 0;
                cursor = cursor.AddMonths(1);
                continue;
            }

            buckets.TryGetValue(key, out var rows);
            rows ??= [];

            decimal income = 0;
            decimal expense = 0;
            var byCategory = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
            var byMerchant = new Dictionary<string, (decimal Amount, int Count)>(StringComparer.OrdinalIgnoreCase);

            foreach (var tx in rows)
            {
                var amount = Money(toBase(tx));
                if (tx.Type == TransactionTypes.Income)
                {
                    income += amount;
                    continue;
                }

                expense += amount;
                var category = CategoryLabel(tx, categoryNames);
                byCategory[category] = byCategory.GetValueOrDefault(category) + amount;

                var merchant = string.IsNullOrWhiteSpace(tx.Merchant) ? null : tx.Merchant.Trim();
                if (merchant is null) continue;
                var current = byMerchant.GetValueOrDefault(merchant);
                byMerchant[merchant] = (current.Amount + amount, current.Count + 1);
            }

            income = Money(income);
            expense = Money(expense);
            var net = Money(income - expense);
            decimal? change = previousExpense is > 0
                ? Math.Round((expense - previousExpense.Value) / previousExpense.Value * 100m, 1, MidpointRounding.AwayFromZero)
                : null;

            months.Add(new MonthlyReport
            {
                Key = key,
                Label = cursor.ToString("MMMM yyyy", CultureInfo.InvariantCulture),
                Income = income,
                Expense = expense,
                Net = net,
                SavingsRate = income > 0
                    ? Math.Round(net / income * 100m, 1, MidpointRounding.AwayFromZero)
                    : null,
                ExpenseChange = change,
                TransactionCount = rows.Count,
                Categories = byCategory
                    .Select(pair => new CategorySpendPoint { Name = pair.Key, Value = Money(pair.Value) })
                    .Where(point => point.Value > 0)
                    .OrderByDescending(point => point.Value)
                    .ThenBy(point => point.Name, StringComparer.OrdinalIgnoreCase)
                    .Take(TopCategories)
                    .ToList(),
                Merchants = byMerchant
                    .Select(pair => new MerchantSpendPoint
                    {
                        Name = pair.Key,
                        Value = Money(pair.Value.Amount),
                        Count = pair.Value.Count,
                    })
                    .Where(point => point.Value > 0)
                    .OrderByDescending(point => point.Value)
                    .ThenBy(point => point.Name, StringComparer.OrdinalIgnoreCase)
                    .Take(TopMerchants)
                    .ToList(),
            });

            previousExpense = expense;
            cursor = cursor.AddMonths(1);
        }

        var summary = Summarize(months);
        months.Reverse();
        return (months, summary);
    }

    private static SpendingReportSummary Summarize(List<MonthlyReport> months)
    {
        if (months.Count == 0) return EmptySummary();

        var active = months.Where(m => m.TransactionCount > 0).ToList();
        var basis = active.Count == 0 ? months : active;
        var totalIncome = Money(months.Sum(m => m.Income));
        var totalExpense = Money(months.Sum(m => m.Expense));
        MonthlyReport? highest = null;
        foreach (var month in basis)
        {
            if (highest is null || month.Expense >= highest.Expense)
                highest = month;
        }

        return new SpendingReportSummary
        {
            MonthCount = basis.Count,
            AverageExpense = Money(totalExpense / basis.Count),
            TotalIncome = totalIncome,
            TotalExpense = totalExpense,
            SavingsRate = totalIncome > 0
                ? Math.Round((totalIncome - totalExpense) / totalIncome * 100m, 1, MidpointRounding.AwayFromZero)
                : null,
            HighestSpendMonth = highest?.Label,
            HighestSpend = highest?.Expense ?? 0,
        };
    }

    private static SpendingReportSummary EmptySummary() => new();

    private static string CategoryLabel(Transaction tx, IReadOnlyDictionary<Guid, string> categoryNames)
    {
        if (tx.CategoryId is Guid id &&
            categoryNames.TryGetValue(id, out var name) &&
            !string.IsNullOrWhiteSpace(name))
            return name.Trim();
        return "Uncategorized";
    }

    private static bool TryMonthKey(string? date, out string key)
    {
        key = "";
        if (string.IsNullOrEmpty(date) || date.Length < 7) return false;
        var candidate = date[..7];
        if (!DateTime.TryParseExact(
                candidate + "-01",
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out _))
            return false;
        key = candidate;
        return true;
    }

    private static decimal Money(decimal value) =>
        Math.Round(value, 2, MidpointRounding.AwayFromZero);
}
