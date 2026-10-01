using Ledgerly.Api.Helpers;
using Ledgerly.Api.Models;
using Xunit;

namespace Ledgerly.Api.Tests;

public class MonthlyReportBuilderTests
{
    private static readonly DateTime Today = new(2026, 10, 1);

    [Fact]
    public void Build_groups_history_by_month_and_skips_transfers()
    {
        var groceries = Guid.NewGuid();
        var rent = Guid.NewGuid();
        var names = new Dictionary<Guid, string>
        {
            [groceries] = "Groceries",
            [rent] = "Rent",
        };

        var tx = new List<Transaction>
        {
            Row("2026-08-02", "income", 3000, merchant: "Payroll"),
            Row("2026-08-04", "expense", 80, groceries, "Market"),
            Row("2026-08-05", "expense", 40, groceries, "Market"),
            Row("2026-08-10", "transfer", 500),
            Row("2026-09-01", "expense", 1200, rent, "Landlord"),
            Row("2026-09-03", "expense", 25, merchant: "Cafe"),
        };

        var (months, summary) = MonthlyReportBuilder.Build(tx, names, t => t.Amount, Today);

        Assert.Equal(3, months.Count);
        Assert.Equal("2026-10", months[0].Key);
        Assert.Equal(0, months[0].TransactionCount);

        var september = months[1];
        Assert.Equal(1225m, september.Expense);
        Assert.Equal("Rent", september.Categories[0].Name);
        Assert.Equal("Uncategorized", september.Categories[1].Name);
        Assert.Equal("Landlord", september.Merchants[0].Name);

        var august = months[2];
        Assert.Equal(3000m, august.Income);
        Assert.Equal(120m, august.Expense);
        Assert.Equal(2880m, august.Net);
        Assert.Equal(96.0m, august.SavingsRate);
        Assert.Equal(120m, august.Categories[0].Value);
        Assert.Equal(2, august.Merchants[0].Count);
        Assert.Null(august.ExpenseChange);
        Assert.Equal(920.8m, september.ExpenseChange);

        Assert.Equal(2, summary.MonthCount);
        Assert.Equal(1345m, summary.TotalExpense);
        Assert.Equal(3000m, summary.TotalIncome);
        Assert.Equal("September 2026", summary.HighestSpendMonth);
        Assert.Equal(1225m, summary.HighestSpend);
    }

    [Fact]
    public void Build_skips_months_that_have_no_transactions()
    {
        var tx = new List<Transaction>
        {
            Row("2026-01-15", "expense", 40, merchant: "Store"),
        };

        var (months, summary) = MonthlyReportBuilder.Build(
            tx,
            new Dictionary<Guid, string>(),
            t => t.Amount,
            Today);

        Assert.Equal(["2026-10", "2026-01"], months.Select(m => m.Key).ToArray());
        Assert.Equal(1, summary.MonthCount);
        Assert.Equal(40m, summary.AverageExpense);
    }

    [Fact]
    public void Build_returns_empty_when_there_is_no_activity()
    {
        var (months, summary) = MonthlyReportBuilder.Build(
            [],
            new Dictionary<Guid, string>(),
            t => t.Amount,
            Today);

        Assert.Empty(months);
        Assert.Equal(0, summary.MonthCount);
        Assert.Null(summary.HighestSpendMonth);
    }

    private static Transaction Row(
        string date,
        string type,
        decimal amount,
        Guid? category = null,
        string? merchant = null) =>
        new()
        {
            Date = date,
            Type = type,
            Amount = amount,
            CategoryId = category,
            Merchant = merchant,
        };
}
