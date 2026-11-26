using Ledgerly.Api.Helpers;
using Ledgerly.Api.Models;
using Xunit;

namespace Ledgerly.Api.Tests;

public class FrequentRecordsTests
{
    private readonly Guid _cash = Guid.NewGuid();
    private readonly Guid _dining = Guid.NewGuid();
    private readonly Guid _groceries = Guid.NewGuid();
    private readonly Guid _salary = Guid.NewGuid();

    [Fact]
    public void Top_returns_up_to_five_repeats_most_used_first()
    {
        var names = new[] { "Alpha", "Bravo", "Cedar", "Delta", "Eagle", "Frost" };
        var categories = Categories();
        var accounts = Accounts();
        var rows = new List<Transaction>();
        for (var i = 0; i < names.Length; i++)
        {
            for (var n = 0; n < i + 1; n++)
                rows.Add(Tx(names[i], "expense", 10 + i, _dining, $"2026-01-{i + 1:00}"));
        }

        var top = FrequentRecords.Top(rows, categories, accounts);

        Assert.Equal(5, top.Count);
        Assert.Equal("Frost", top[0].Label);
        Assert.Equal(6, top[0].Count);
        Assert.Equal("Bravo", top[4].Label);
        Assert.DoesNotContain(top, record => record.Label == "Alpha");
    }

    [Fact]
    public void Top_uses_latest_amount_and_saved_category()
    {
        var categories = Categories();
        var accounts = Accounts();
        var rows = new List<Transaction>
        {
            Tx("Coffee", "expense", 4, _dining, "2026-03-01"),
            Tx("coffee", "expense", 5.5m, null, "2026-03-02"),
            Tx("Coffee", "expense", 6, _groceries, "2026-03-03"),
        };

        var top = FrequentRecords.Top(rows, categories, accounts);

        var coffee = Assert.Single(top);
        Assert.Equal("Coffee", coffee.Label);
        Assert.Equal(6, coffee.Amount);
        Assert.Equal(_groceries, coffee.CategoryId);
        Assert.Equal("Groceries", coffee.Category?.Name);
        Assert.Equal(3, coffee.Count);
        Assert.Equal(_cash, coffee.AccountId);
    }

    [Fact]
    public void Top_keeps_an_older_category_when_the_latest_row_has_none()
    {
        var rows = new List<Transaction>
        {
            Tx("Bus", "expense", 2, _dining, "2026-04-01"),
            Tx("Bus", "expense", 3, null, "2026-04-02"),
        };

        var top = FrequentRecords.Top(rows, Categories(), Accounts());

        var bus = Assert.Single(top);
        Assert.Equal(3, bus.Amount);
        Assert.Equal(_dining, bus.CategoryId);
    }

    [Fact]
    public void Top_uses_fill_feedback_when_no_row_has_a_category()
    {
        var rows = new List<Transaction>
        {
            Tx("Keells", "expense", 20, null, "2026-05-01"),
            Tx("Keells", "expense", 22, null, "2026-05-02"),
        };
        var feedback = new[]
        {
            new FillFeedbackRow { PayeeKey = "keells", CategoryId = _groceries },
        };

        var top = FrequentRecords.Top(rows, Categories(), Accounts(), feedback);

        Assert.Equal(_groceries, Assert.Single(top).CategoryId);
    }

    [Fact]
    public void Top_ignores_a_saved_category_of_the_wrong_type()
    {
        var rows = new List<Transaction>
        {
            Tx("Bonus", "income", 100, null, "2026-06-01"),
            Tx("Bonus", "income", 120, null, "2026-06-02"),
        };
        var feedback = new[]
        {
            new FillFeedbackRow { PayeeKey = "bonus", CategoryId = _groceries },
        };

        var top = FrequentRecords.Top(rows, Categories(), Accounts(), feedback);

        Assert.Null(Assert.Single(top).CategoryId);
    }

    [Fact]
    public void Top_separates_income_and_expense_and_skips_one_offs()
    {
        var rows = new List<Transaction>
        {
            Tx("Rent", "expense", 50, _dining, "2026-07-01"),
            Tx("Rent", "income", 50, _salary, "2026-07-02"),
            Tx("Rent", "income", 55, _salary, "2026-07-03"),
            Tx("Once", "expense", 9, _dining, "2026-07-04"),
            new()
            {
                Merchant = "Moved",
                Type = "transfer",
                Amount = 10,
                AccountId = _cash,
                Date = "2026-07-05",
            },
            new()
            {
                Merchant = "Moved",
                Type = "transfer",
                Amount = 10,
                AccountId = _cash,
                Date = "2026-07-06",
            },
        };

        var top = FrequentRecords.Top(rows, Categories(), Accounts());

        var rent = Assert.Single(top);
        Assert.Equal("income", rent.Type);
        Assert.Equal(_salary, rent.CategoryId);
        Assert.Equal(2, rent.Count);
    }

    private List<Category> Categories() =>
    [
        new() { Id = _dining, Name = "Dining", Icon = "utensils", Type = "expense" },
        new() { Id = _groceries, Name = "Groceries", Icon = "shopping-cart", Type = "expense" },
        new() { Id = _salary, Name = "Salary", Icon = "wallet", Type = "income" },
    ];

    private List<Account> Accounts() =>
    [
        new() { Id = _cash, Name = "Cash", Currency = "USD", Type = "cash" },
    ];

    private Transaction Tx(
        string merchant,
        string type,
        decimal amount,
        Guid? categoryId,
        string date)
    {
        return new Transaction
        {
            Id = Guid.NewGuid(),
            Merchant = merchant,
            Type = type,
            Amount = amount,
            AccountId = _cash,
            CategoryId = categoryId,
            Date = date,
            CreatedAt = DateTimeOffset.Parse($"{date}T00:00:00Z"),
        };
    }
}
