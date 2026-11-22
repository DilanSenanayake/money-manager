namespace Ledgerly.Api.Infrastructure.Fx;

public interface ILiveRateProvider
{
    /// <summary>
    /// Units of <paramref name="toCurrency"/> for 1 unit of <paramref name="fromCurrency"/>.
    /// Returns 1 without a network call when the codes match.
    /// Returns null when a live rate cannot be loaded.
    /// </summary>
    Task<decimal?> GetRateAsync(
        string fromCurrency,
        string toCurrency,
        CancellationToken ct = default);
}
