using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class CurrencyConverter
{
    public static decimal ConvertToBase(
        decimal amount,
        string fromCurrency,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates)
    {
        if (fromCurrency == baseCurrency) return amount;

        var direct = rates.FirstOrDefault(r =>
            r.FromCurrency == fromCurrency && r.ToCurrency == baseCurrency);
        if (direct is not null) return amount * direct.Rate;

        var inverse = rates.FirstOrDefault(r =>
            r.FromCurrency == baseCurrency && r.ToCurrency == fromCurrency);
        if (inverse is not null && inverse.Rate != 0)
            return amount / inverse.Rate;

        return amount;
    }

    public static Dictionary<Guid, string> AccountCurrencyMap(IEnumerable<Account> accounts) =>
        accounts.ToDictionary(a => a.Id, a => a.Currency);

    public static decimal TxAmountInBase(
        decimal amount,
        Guid accountId,
        IReadOnlyDictionary<Guid, string> currencyByAccount,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates)
    {
        var from = currencyByAccount.GetValueOrDefault(accountId, baseCurrency);
        return ConvertToBase(amount, from, baseCurrency, rates);
    }

    public static decimal ComputeNetWorth(
        IEnumerable<Account> accounts,
        string baseCurrency,
        IReadOnlyList<ExchangeRate> rates)
    {
        return accounts.Aggregate(0m, (sum, account) =>
        {
            var converted = ConvertToBase(account.Balance, account.Currency, baseCurrency, rates);
            return account.Type == AccountTypes.Credit ? sum - converted : sum + converted;
        });
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
