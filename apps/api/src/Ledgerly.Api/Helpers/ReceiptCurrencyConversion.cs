using Ledgerly.Api.Infrastructure.Fx;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class ReceiptCurrencyConversion
{
    public static bool NeedsLiveRate(string? fromCurrency, string? toCurrency) =>
        !string.Equals(
            (fromCurrency ?? "").Trim(),
            (toCurrency ?? "").Trim(),
            StringComparison.OrdinalIgnoreCase);

    public static decimal RoundMoney(decimal amount, string currency)
    {
        var digits = string.Equals(currency, "JPY", StringComparison.OrdinalIgnoreCase) ? 0 : 2;
        return decimal.Round(amount, digits, MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// Wallet the receipt amount should be expressed in.
    /// Prefers the account already chosen for the receipt, then the oldest wallet.
    /// </summary>
    public static bool TryResolveAccount(
        string? accountId,
        IReadOnlyList<Account> accounts,
        out string currency,
        out string? resolvedAccountId)
    {
        if (Guid.TryParse(accountId, out var id))
        {
            var match = accounts.FirstOrDefault(a =>
                a.Id == id && Currencies.All.Contains(a.Currency));
            if (match is not null)
            {
                currency = match.Currency;
                resolvedAccountId = match.Id.ToString();
                return true;
            }
        }

        var first = accounts.FirstOrDefault(a => Currencies.All.Contains(a.Currency));
        if (first is not null)
        {
            currency = first.Currency;
            resolvedAccountId = first.Id.ToString();
            return true;
        }

        currency = "";
        resolvedAccountId = null;
        return false;
    }

    public static string FallbackCurrency(string? baseCurrency)
    {
        var code = (baseCurrency ?? "").Trim().ToUpperInvariant();
        return Currencies.All.Contains(code) ? code : "USD";
    }

    /// <summary>
    /// Converts the receipt total into <paramref name="targetCurrency"/> using a live rate.
    /// Does not call the provider when the receipt is already in that currency.
    /// </summary>
    public static async Task ApplyLiveRateAsync(
        ReceiptExtraction receipt,
        string targetCurrency,
        ILiveRateProvider rates,
        CancellationToken ct = default)
    {
        receipt.SourceAmount = null;
        receipt.SourceCurrency = null;
        receipt.ExchangeRate = null;
        receipt.ConversionWarning = null;

        var source = (receipt.Currency ?? "").Trim().ToUpperInvariant();
        var target = targetCurrency.Trim().ToUpperInvariant();
        if (!NeedsLiveRate(source, target))
            return;

        decimal? rate;
        try
        {
            rate = await rates.GetRateAsync(source, target, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            rate = null;
        }

        if (rate is null or <= 0)
        {
            receipt.ConversionWarning =
                $"This receipt is in {source}. Today's {source} to {target} rate couldn't be loaded, so the amount is still in {source}.";
            return;
        }

        if (!TryConvert(receipt.Amount, rate.Value, target, out var converted))
        {
            receipt.ConversionWarning =
                $"This receipt is in {source}. It couldn't be converted to {target}, so the amount is still in {source}.";
            return;
        }

        foreach (var item in receipt.LineItems)
        {
            if (item.Price is not decimal price) continue;
            if (TryConvert(price, rate.Value, target, out var lineTotal))
                item.Price = lineTotal;
        }

        receipt.SourceAmount = receipt.Amount;
        receipt.SourceCurrency = source;
        receipt.ExchangeRate = rate;
        receipt.Amount = converted;
        receipt.Currency = target;
    }

    private static bool TryConvert(decimal amount, decimal rate, string target, out decimal converted)
    {
        try
        {
            converted = RoundMoney(amount * rate, target);
            return true;
        }
        catch (OverflowException)
        {
            converted = 0;
            return false;
        }
    }
}
