using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Llm;
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
        Assert.True(CurrencyConverter.TryConvertToBase(42m, "USD", "USD", [], out var converted));
        Assert.Equal(42m, converted);
    }

    [Fact]
    public void ConvertToBase_uses_direct_rate()
    {
        var rates = Rates(("EUR", "USD", 1.1m));
        Assert.True(CurrencyConverter.TryConvertToBase(100m, "EUR", "USD", rates, out var converted));
        Assert.Equal(110m, converted);
    }

    [Fact]
    public void ConvertToBase_uses_inverse_rate()
    {
        var rates = Rates(("USD", "EUR", 2m));
        Assert.True(CurrencyConverter.TryConvertToBase(100m, "EUR", "USD", rates, out var converted));
        Assert.Equal(50m, converted);
    }

    [Fact]
    public void ConvertToBase_missing_rate_does_not_assume_parity()
    {
        Assert.False(CurrencyConverter.TryConvertToBase(100_000m, "LKR", "USD", [], out _));
        Assert.Equal(["LKR"], CurrencyConverter.MissingCurrencies(["LKR", "USD"], "USD", []));
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

    [Fact]
    public void ComputeNetWorth_is_hidden_when_any_rate_is_missing()
    {
        var accounts = new List<Account>
        {
            new() { Balance = 500m, Currency = "USD", Type = AccountTypes.Checking },
            new() { Balance = 100_000m, Currency = "LKR", Type = AccountTypes.Cash },
        };

        Assert.Null(CurrencyConverter.ComputeNetWorth(accounts, "USD", []));
    }
}

public class DateNormalizerTests
{
    private static readonly DateTime Today = new(2026, 11, 26, 12, 0, 0);

    [Theory]
    [InlineData("2026-09-07", "2026-09-07")]
    [InlineData("07/09/2026", "2026-09-07")]
    [InlineData("7/9/2026", "2026-09-07")]
    [InlineData("07-09-2026", "2026-09-07")]
    [InlineData("07.09.2026", "2026-09-07")]
    [InlineData("2026/09/07", "2026-09-07")]
    [InlineData("20260907", "2026-09-07")]
    [InlineData("07/09/26", "2026-09-07")]
    [InlineData("09/25/2026", "2026-09-25")]
    [InlineData("25/09/2026", "2026-09-25")]
    [InlineData("2026-25-09", "2026-09-25")]
    [InlineData("25-09-2026", "2026-09-25")]
    [InlineData("09-25-2026", "2026-09-25")]
    [InlineData("7 September 2026", "2026-09-07")]
    [InlineData("7th September 2026", "2026-09-07")]
    [InlineData("September 7, 2026", "2026-09-07")]
    [InlineData("Sep 7 2026", "2026-09-07")]
    [InlineData("07-Sep-2026", "2026-09-07")]
    [InlineData("2026-09-07T14:30:00", "2026-09-07")]
    [InlineData("07/09/2026 14:30", "2026-09-07")]
    [InlineData("07/09/2026 2:30 PM", "2026-09-07")]
    public void NormalizeToIsoDate_common_formats(string input, string expected)
    {
        Assert.Equal(expected, DateNormalizer.NormalizeToIsoDate(input, Today));
    }

    [Fact]
    public void NormalizeToIsoDate_ambiguous_numeric_prefers_day_month_year()
    {
        // 05/11/2026 → 5 Nov 2026 (DMY), not 11 May 2026 (MDY).
        Assert.Equal("2026-11-05", DateNormalizer.NormalizeToIsoDate("05/11/2026", Today));
    }

    [Fact]
    public void NormalizeToIsoDate_unknown_falls_back_to_today()
    {
        Assert.Equal("2026-11-26", DateNormalizer.NormalizeToIsoDate("not-a-date", Today));
        Assert.Equal("2026-11-26", DateNormalizer.NormalizeToIsoDate("", Today));
        Assert.Equal("2026-11-26", DateNormalizer.NormalizeToIsoDate(null, Today));
    }

    [Fact]
    public void PromptRule_mentions_common_formats_and_no_swap()
    {
        var rule = DateNormalizer.PromptRule("2026-11-26");
        Assert.Contains("YYYY-MM-DD", rule);
        Assert.Contains("DD/MM/YYYY", rule);
        Assert.Contains("Never swap day and month", rule);
        Assert.Contains("2026-11-26", rule);
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

public class GroqErrorFormattingTests
{
    [Fact]
    public void FormatAiError_does_not_leak_provider_details()
    {
        var message = GroqService.FormatAiError(
            new InvalidOperationException("Groq HTTP 500: internal stack / secret"),
            "fallback");
        Assert.Equal("fallback", message);
        Assert.DoesNotContain("HTTP 500", message);
        Assert.DoesNotContain("secret", message);
    }

    [Fact]
    public void FormatAiError_maps_rate_limit_to_busy_message()
    {
        var message = GroqService.FormatAiError(
            new InvalidOperationException("Groq rate limit (429): too many requests"),
            "fallback");
        Assert.Equal("We're a bit busy right now. Please wait a minute and try again.", message);
    }
}

public class FillFeedbackTests
{
    [Theory]
    [InlineData("POS-KEELLS SUPER", "keells super")]
    [InlineData("Dialog", "dialog")]
    [InlineData("Rent", "rent")]
    [InlineData("Unknown", null)]
    [InlineData("", null)]
    public void PayeeKey_normalizes_description_words(string description, string? expected)
    {
        Assert.Equal(expected, FillFeedback.PayeeKey(description));
    }

    [Fact]
    public void Match_requires_every_word_and_prefers_the_longer_key()
    {
        var keells = Row("keells");
        var keellsSuper = Row("keells super");
        var dialog = Row("dialog");

        var hit = FillFeedback.Match(
            [dialog, keells, keellsSuper],
            "Keells Super",
            "A/c XX4521 debited LKR 3180 for POS-KEELLS SUPER");

        Assert.Equal("keells super", hit?.PayeeKey);
        Assert.Null(FillFeedback.Match([keells], "Weekly shop"));
    }

    [Fact]
    public void FromReview_skips_an_unchanged_save()
    {
        var category = Guid.NewGuid();
        var account = Guid.NewGuid();
        var change = FillFeedback.FromReview(Input(
            category, account, "Keells",
            category, account, "Keells"));

        Assert.Null(change);
    }

    [Fact]
    public void FromReview_skips_a_description_only_edit()
    {
        var category = Guid.NewGuid();
        var account = Guid.NewGuid();
        var change = FillFeedback.FromReview(Input(
            category, account, "POS-KEELLS SUPER",
            category, account, "Keells"));

        Assert.Null(change);
    }

    [Fact]
    public void FromReview_indexes_by_the_saved_description_when_category_changes()
    {
        var groceries = Guid.NewGuid();
        var household = Guid.NewGuid();
        var account = Guid.NewGuid();

        var change = FillFeedback.FromReview(Input(
            groceries, account, "POS-KEELLS SUPER",
            household, account, "Keells"));

        Assert.NotNull(change);
        Assert.Equal("keells", change!.PayeeKey);
        Assert.Equal("Keells", change.DisplayName);
        Assert.Equal(household, change.CategoryId);
        Assert.Equal(account, change.AccountId);
    }

    [Fact]
    public void FromReview_without_a_baseline_does_not_store()
    {
        var change = FillFeedback.FromReview(new FillFeedbackInput(
            false, null, null, null, "Keells", Guid.NewGuid(), Guid.NewGuid()));

        Assert.Null(change);
    }

    private static FillFeedbackRow Row(string key) => new() { PayeeKey = key };

    private static FillFeedbackInput Input(
        Guid proposedCategory,
        Guid proposedAccount,
        string proposedMerchant,
        Guid savedCategory,
        Guid savedAccount,
        string savedMerchant) =>
        new(
            true,
            proposedMerchant,
            proposedCategory,
            proposedAccount,
            savedMerchant,
            savedCategory,
            savedAccount);
}
