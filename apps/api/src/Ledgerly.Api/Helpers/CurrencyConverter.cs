using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class CurrencyConverter
{
    public static bool TryConvertToBase(
        decimal amount,
        string fromCurrency,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates,
        out decimal converted)
    {
        if (fromCurrency == baseCurrency)
        {
            converted = amount;
            return true;
        }

        var direct = rates.FirstOrDefault(r =>
            r.FromCurrency == fromCurrency && r.ToCurrency == baseCurrency);
        if (direct is not null)
        {
            converted = amount * direct.Rate;
            return true;
        }

        var inverse = rates.FirstOrDefault(r =>
            r.FromCurrency == baseCurrency && r.ToCurrency == fromCurrency);
        if (inverse is not null && inverse.Rate != 0)
        {
            converted = amount / inverse.Rate;
            return true;
        }

        converted = 0;
        return false;
    }

    public static List<string> MissingCurrencies(
        IEnumerable<string> currencies,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates)
    {
        return currencies
            .Where(currency => !string.IsNullOrWhiteSpace(currency))
            .Distinct(StringComparer.Ordinal)
            .Where(currency => !TryConvertToBase(0, currency, baseCurrency, rates, out _))
            .OrderBy(currency => currency, StringComparer.Ordinal)
            .ToList();
    }

    public static Dictionary<Guid, string> AccountCurrencyMap(IEnumerable<Account> accounts) =>
        accounts.ToDictionary(a => a.Id, a => a.Currency);

    public static bool TryTxAmountInBase(
        decimal amount,
        Guid accountId,
        IReadOnlyDictionary<Guid, string> currencyByAccount,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates,
        out decimal converted)
    {
        var from = currencyByAccount.GetValueOrDefault(accountId, baseCurrency);
        return TryConvertToBase(amount, from, baseCurrency, rates, out converted);
    }

    public static decimal? ComputeNetWorth(
        IEnumerable<Account> accounts,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates)
    {
        decimal sum = 0;
        foreach (var account in accounts)
        {
            if (!TryConvertToBase(account.Balance, account.Currency, baseCurrency, rates, out var converted))
                return null;
            sum += account.Type == AccountTypes.Credit ? -converted : converted;
        }

        return sum;
    }
}

public static class BudgetHelpers
{
    public static string BudgetStatus(decimal spent, decimal limit)
    {
        if (limit <= 0) return "none";
        var ratio = spent / limit;
        if (ratio >= 1) return "over";
        if (ratio >= 0.8m) return "warn";
        return "ok";
    }
}
