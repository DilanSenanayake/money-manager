using Ledgerly.Api.Helpers;
using Ledgerly.Api.Models;
using Xunit;

namespace Ledgerly.Api.Tests;

public class BudgetHelpersTests
{
    [Theory]
    [InlineData(0, 100, "ok")]
    [InlineData(50, 100, "ok")]
    [InlineData(80, 100, "warn")]
    [InlineData(99.99, 100, "warn")]
    [InlineData(100, 100, "over")]
    [InlineData(150, 100, "over")]
    [InlineData(10, 0, "none")]
    [InlineData(10, -5, "none")]
    public void BudgetStatus_thresholds(decimal spent, decimal limit, string expected)
    {
        Assert.Equal(expected, BudgetHelpers.BudgetStatus(spent, limit));
    }
}

public class CurrencyConverterTests
{
    private static List<ExchangeRate> Rates(params (string from, string to, decimal rate)[] rows) =>
        rows.Select(r => new ExchangeRate
        {
            FromCurrency = r.from,
            ToCurrency = r.to,
            Rate = r.rate,
        }).ToList();

    [Fact]
    public void ConvertToBase_same_currency_is_identity()
    {
        Assert.Equal(42m, CurrencyConverter.ConvertToBase(42m, "USD", "USD", []));
    }

    [Fact]
    public void ConvertToBase_uses_direct_rate()
    {
        var rates = Rates(("EUR", "USD", 1.1m));
        Assert.Equal(110m, CurrencyConverter.ConvertToBase(100m, "EUR", "USD", rates));
    }

    [Fact]
    public void ConvertToBase_uses_inverse_rate()
    {
        var rates = Rates(("USD", "EUR", 2m));
        Assert.Equal(50m, CurrencyConverter.ConvertToBase(100m, "EUR", "USD", rates));
    }

    [Fact]
    public void ConvertToBase_missing_rate_returns_amount()
    {
        Assert.Equal(100m, CurrencyConverter.ConvertToBase(100m, "JPY", "USD", []));
    }

    [Fact]
    public void ComputeNetWorth_subtracts_credit_balances()
    {
        var accounts = new List<Account>
        {
            new() { Balance = 1000m, Currency = "USD", Type = AccountTypes.Checking },
            new() { Balance = 200m, Currency = "USD", Type = AccountTypes.Credit },
        };

        Assert.Equal(800m, CurrencyConverter.ComputeNetWorth(accounts, "USD", []));
    }

    [Fact]
    public void ComputeNetWorth_converts_before_credit_subtract()
    {
        var accounts = new List<Account>
        {
            new() { Balance = 100m, Currency = "EUR", Type = AccountTypes.Cash },
            new() { Balance = 50m, Currency = "EUR", Type = AccountTypes.Credit },
        };
        var rates = Rates(("EUR", "USD", 2m));

        Assert.Equal(100m, CurrencyConverter.ComputeNetWorth(accounts, "USD", rates));
    }
}

public class OwnershipGuardsTests
{
    [Theory]
    [InlineData("2026-09-07", true)]
    [InlineData("2026-9-7", false)]
    [InlineData("07/09/2026", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    [InlineData("not-a-date", false)]
    public void IsValidIsoDate(string? value, bool expected)
    {
        Assert.Equal(expected, OwnershipGuards.IsValidIsoDate(value));
    }

    [Fact]
    public void Clamp_truncates_and_trims()
    {
        Assert.Equal("abc", OwnershipGuards.Clamp("  abcdef  ", 3));
        Assert.Equal("", OwnershipGuards.Clamp("   ", 10));
        Assert.Null(OwnershipGuards.ClampNullable(null, 10));
    }
}
