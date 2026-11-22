using System.Net;
using System.Text;
using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure;
using Ledgerly.Api.Infrastructure.Fx;
using Ledgerly.Api.Models;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace Ledgerly.Api.Tests;

public class ReceiptCurrencyConversionTests
{
    [Fact]
    public async Task Same_currency_does_not_call_the_rate_provider()
    {
        var rates = new CountingRates();
        var receipt = Receipt(42m, "USD", 3m);

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "USD", rates);

        Assert.Equal(0, rates.Calls);
        Assert.Equal(42m, receipt.Amount);
        Assert.Equal("USD", receipt.Currency);
        Assert.Null(receipt.SourceAmount);
        Assert.Null(receipt.SourceCurrency);
        Assert.Null(receipt.ExchangeRate);
        Assert.Null(receipt.ConversionWarning);
        Assert.Equal(3m, receipt.LineItems[0].Price);
    }

    [Fact]
    public async Task Different_currency_converts_total_and_line_prices_with_one_rate_call()
    {
        var rates = new CountingRates { Rate = 1.25m };
        var receipt = Receipt(10m, "EUR", 4m);
        receipt.LineItems.Add(new ReceiptLineItem { Name = "Tip", Price = null });

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "usd", rates);

        Assert.Equal(1, rates.Calls);
        Assert.Equal("EUR", rates.LastFrom);
        Assert.Equal("USD", rates.LastTo);
        Assert.Equal(12.50m, receipt.Amount);
        Assert.Equal("USD", receipt.Currency);
        Assert.Equal(10m, receipt.SourceAmount);
        Assert.Equal("EUR", receipt.SourceCurrency);
        Assert.Equal(1.25m, receipt.ExchangeRate);
        Assert.Null(receipt.ConversionWarning);
        Assert.Equal(5m, receipt.LineItems[0].Price);
        Assert.Null(receipt.LineItems[1].Price);
    }

    [Fact]
    public async Task Jpy_target_rounds_to_a_whole_number()
    {
        var rates = new CountingRates { Rate = 150.4m };
        var receipt = Receipt(1.2m, "USD");

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "JPY", rates);

        Assert.Equal(180m, receipt.Amount);
    }

    [Fact]
    public async Task Missing_rate_leaves_the_receipt_amount_unchanged()
    {
        var rates = new CountingRates { Rate = null };
        var receipt = Receipt(80m, "GBP");

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal(1, rates.Calls);
        Assert.Equal(80m, receipt.Amount);
        Assert.Equal("GBP", receipt.Currency);
        Assert.Null(receipt.SourceAmount);
        Assert.Contains("GBP", receipt.ConversionWarning);
        Assert.Contains("LKR", receipt.ConversionWarning);
    }

    [Fact]
    public void Resolve_account_prefers_the_chosen_wallet()
    {
        var chosen = Guid.NewGuid();
        var older = Guid.NewGuid();
        var accounts = new List<Account>
        {
            new() { Id = older, Currency = "USD" },
            new() { Id = chosen, Currency = "LKR" },
        };

        Assert.True(ReceiptCurrencyConversion.TryResolveAccount(
            chosen.ToString(), accounts, "USD", out var currency, out var accountId));
        Assert.Equal("LKR", currency);
        Assert.Equal(chosen.ToString(), accountId);
    }

    [Fact]
    public void Resolve_account_uses_the_oldest_wallet_when_none_is_chosen()
    {
        var first = Guid.NewGuid();
        var accounts = new List<Account>
        {
            new() { Id = first, Currency = "EUR" },
            new() { Id = Guid.NewGuid(), Currency = "USD" },
        };

        Assert.True(ReceiptCurrencyConversion.TryResolveAccount(
            null, accounts, null, out var currency, out var accountId));
        Assert.Equal("EUR", currency);
        Assert.Equal(first.ToString(), accountId);
    }

    [Fact]
    public void Resolve_account_prefers_the_base_currency_wallet()
    {
        var usd = Guid.NewGuid();
        var lkr = Guid.NewGuid();
        var accounts = new List<Account>
        {
            new() { Id = usd, Currency = "USD" },
            new() { Id = lkr, Currency = "LKR" },
        };

        Assert.True(ReceiptCurrencyConversion.TryResolveAccount(
            null, accounts, "LKR", out var currency, out var accountId));
        Assert.Equal("LKR", currency);
        Assert.Equal(lkr.ToString(), accountId);
    }

    [Theory]
    [InlineData("Cafe\nTOTAL EUR 18.00", "EUR")]
    [InlineData("TOTAL € 12.50", "EUR")]
    [InlineData("TOTAL EURO 18.00", "EUR")]
    [InlineData("TOTAL EUROS 10.00", "EUR")]
    [InlineData("Amount due\n18.00 pounds", "GBP")]
    [InlineData("Amount due\nGBP 9.99", "GBP")]
    [InlineData("Rs. 1,500.00\nThank you", "LKR")]
    [InlineData("TOTAL INR 200.00", "INR")]
    [InlineData("TOTAL LKR 500.00 (USD 1.50)", "LKR")]
    [InlineData("TOTAL $ 24.00", "USD")]
    public void Detects_the_currency_printed_on_the_receipt(string text, string expected)
    {
        Assert.Equal(expected, ReceiptCurrencyDetector.Detect(text));
    }

    [Fact]
    public void Parenthetical_usd_does_not_replace_a_printed_lkr_total()
    {
        Assert.Equal(
            "LKR",
            ReceiptCurrencyDetector.Resolve("USD", "TOTAL LKR 500.00 (USD 1.50)", "LKR"));
    }

    [Fact]
    public void Ignores_a_currency_word_inside_another_word()
    {
        Assert.Null(ReceiptCurrencyDetector.Detect("EUROPE MARKET\nTOTAL 12.00"));
    }

    [Fact]
    public async Task Printed_eur_total_converts_even_when_the_model_says_usd()
    {
        var receipt = Receipt(18m, "USD");
        receipt.Currency = ReceiptCurrencyDetector.Resolve(
            "USD",
            "Cafe Roma\nTOTAL EUR 18.00\nThank you",
            "LKR");
        var rates = new CountingRates { Rate = 320m };

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal(1, rates.Calls);
        Assert.Equal(5760m, receipt.Amount);
        Assert.Equal("LKR", receipt.Currency);
        Assert.Equal("EUR", receipt.SourceCurrency);
        Assert.Equal(18m, receipt.SourceAmount);
    }

    [Fact]
    public async Task Same_printed_currency_does_not_call_the_rate_provider()
    {
        var receipt = Receipt(18m, "USD");
        receipt.Currency = ReceiptCurrencyDetector.Resolve("USD", "TOTAL LKR 18.00", "LKR");
        var rates = new CountingRates();

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal(0, rates.Calls);
        Assert.Equal(18m, receipt.Amount);
        Assert.Equal("LKR", receipt.Currency);
    }

    [Fact]
    public async Task Printed_euro_is_kept_when_the_wallet_currency_is_also_on_the_page()
    {
        var receipt = Receipt(18m, "EUR");
        receipt.Currency = ReceiptCurrencyDetector.Resolve(
            "EUR",
            "Cafe Roma\nTOTAL EUR 18.00\nRs. 5760",
            "LKR");
        var rates = new CountingRates { Rate = 320m };

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal(1, rates.Calls);
        Assert.Equal(5760m, receipt.Amount);
        Assert.Equal("LKR", receipt.Currency);
        Assert.Equal("EUR", receipt.SourceCurrency);
    }

    [Fact]
    public async Task Rs_token_does_not_hide_a_foreign_model_currency()
    {
        var receipt = Receipt(18m, "EUR");
        receipt.Currency = ReceiptCurrencyDetector.Resolve(
            "EUR",
            "Cafe Roma\nRs. 18.00\nThank you",
            "LKR");
        var rates = new CountingRates { Rate = 320m };

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal("EUR", receipt.SourceCurrency);
        Assert.Equal(1, rates.Calls);
        Assert.Equal(5760m, receipt.Amount);
        Assert.Equal("LKR", receipt.Currency);
    }

    [Fact]
    public async Task Wallet_currency_from_the_model_converts_when_the_total_says_euro()
    {
        var receipt = Receipt(18m, "LKR");
        receipt.Currency = ReceiptCurrencyDetector.Resolve(
            "LKR",
            "Cafe Roma\nTOTAL EURO 18.00",
            "LKR");
        var rates = new CountingRates { Rate = 320m };

        await ReceiptCurrencyConversion.ApplyLiveRateAsync(receipt, "LKR", rates);

        Assert.Equal(1, rates.Calls);
        Assert.Equal(5760m, receipt.Amount);
        Assert.Equal("EUR", receipt.SourceCurrency);
        Assert.Equal("LKR", receipt.Currency);
    }

    private static ReceiptExtraction Receipt(decimal amount, string currency, decimal? linePrice = null)
    {
        var receipt = new ReceiptExtraction
        {
            Amount = amount,
            Currency = currency,
            SourceAmount = 1m,
            SourceCurrency = "XXX",
            ExchangeRate = 9m,
            ConversionWarning = "stale",
        };
        if (linePrice is not null)
        {
            receipt.LineItems.Add(new ReceiptLineItem { Name = "Item", Price = linePrice });
        }

        return receipt;
    }

    private sealed class CountingRates : ILiveRateProvider
    {
        public int Calls { get; private set; }
        public decimal? Rate { get; set; } = 1m;
        public string? LastFrom { get; private set; }
        public string? LastTo { get; private set; }

        public Task<decimal?> GetRateAsync(string fromCurrency, string toCurrency, CancellationToken ct = default)
        {
            Calls++;
            LastFrom = fromCurrency;
            LastTo = toCurrency;
            return Task.FromResult(Rate);
        }
    }
}

public class OpenExchangeRateProviderTests
{
    [Fact]
    public async Task Same_currency_does_not_call_the_external_provider()
    {
        var handler = new CountingHandler();
        var provider = Create(handler);

        var rate = await provider.GetRateAsync("usd", "USD");

        Assert.Equal(1m, rate);
        Assert.Equal(0, handler.Calls);
    }

    [Fact]
    public async Task Unknown_code_does_not_call_the_external_provider()
    {
        var handler = new CountingHandler();
        var provider = Create(handler);

        var rate = await provider.GetRateAsync("EURO", "USD");

        Assert.Null(rate);
        Assert.Equal(0, handler.Calls);
    }

    [Fact]
    public async Task Different_currency_fetches_once_and_reuses_the_table()
    {
        var handler = new CountingHandler();
        var provider = Create(handler);

        var usd = await provider.GetRateAsync("EUR", "USD");
        var lkr = await provider.GetRateAsync("EUR", "LKR");

        Assert.Equal(1.1m, usd);
        Assert.Equal(320.5m, lkr);
        Assert.Equal(1, handler.Calls);
        Assert.Equal("https://fx.test/latest/EUR", handler.LastUrl);
    }

    private static OpenExchangeRateProvider Create(CountingHandler handler)
    {
        var client = new HttpClient(handler);
        return new OpenExchangeRateProvider(
            new SingleClientFactory(client),
            new MemoryCache(new MemoryCacheOptions()),
            Options.Create(new FxOptions { BaseUrl = "https://fx.test" }),
            NullLogger<OpenExchangeRateProvider>.Instance);
    }

    private sealed class SingleClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class CountingHandler : HttpMessageHandler
    {
        public int Calls { get; private set; }
        public string? LastUrl { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Calls++;
            LastUrl = request.RequestUri?.ToString();
            var json = """{"result":"success","rates":{"USD":1.1,"LKR":320.5,"EUR":1}}""";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            });
        }
    }
}
