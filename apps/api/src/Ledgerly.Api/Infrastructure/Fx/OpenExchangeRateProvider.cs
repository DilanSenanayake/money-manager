using System.Text.Json;
using System.Text.Json.Serialization;
using Ledgerly.Api.Infrastructure;
using Ledgerly.Api.Models;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace Ledgerly.Api.Infrastructure.Fx;

/// <summary>
/// Current mid-market rates from ExchangeRate-API's open endpoint.
/// The HTTP call runs only when the two currencies differ.
/// </summary>
public sealed class OpenExchangeRateProvider(
    IHttpClientFactory httpClientFactory,
    IMemoryCache cache,
    IOptions<FxOptions> options,
    ILogger<OpenExchangeRateProvider> logger) : ILiveRateProvider
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(1);
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public async Task<decimal?> GetRateAsync(
        string fromCurrency,
        string toCurrency,
        CancellationToken ct = default)
    {
        var from = Normalize(fromCurrency);
        var to = Normalize(toCurrency);
        if (from is null || to is null) return null;
        if (from == to) return 1m;

        var table = await GetTableAsync(from, ct);
        if (table is null) return null;
        return table.TryGetValue(to, out var rate) && rate > 0 ? rate : null;
    }

    private async Task<IReadOnlyDictionary<string, decimal>?> GetTableAsync(
        string from,
        CancellationToken ct)
    {
        var cacheKey = $"fx:{from}";
        if (cache.TryGetValue(cacheKey, out IReadOnlyDictionary<string, decimal>? cached)
            && cached is not null)
        {
            return cached;
        }

        var baseUrl = options.Value.BaseUrl.TrimEnd('/');
        if (string.IsNullOrWhiteSpace(baseUrl))
            baseUrl = "https://open.er-api.com/v6";
        if (!baseUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogWarning("FX provider base URL must be https");
            return null;
        }

        try
        {
            var client = httpClientFactory.CreateClient("fx");
            using var response = await client.GetAsync($"{baseUrl}/latest/{from}", ct);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "FX provider returned {Status} for {Currency}",
                    (int)response.StatusCode,
                    from);
                return null;
            }

            var payload = await response.Content.ReadFromJsonAsync<LatestRates>(JsonOptions, ct);
            if (payload?.Rates is null || payload.Rates.Count == 0)
                return null;
            if (payload.Result is not null
                && !payload.Result.Equals("success", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            var table = new Dictionary<string, decimal>(StringComparer.Ordinal);
            foreach (var (code, rate) in payload.Rates)
            {
                var normalized = Normalize(code);
                if (normalized is not null && rate > 0)
                    table[normalized] = rate;
            }

            if (table.Count == 0) return null;
            cache.Set(cacheKey, table, CacheTtl);
            return table;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(ex, "FX provider request failed for {Currency}", from);
            return null;
        }
    }

    private static string? Normalize(string? code)
    {
        var value = (code ?? "").Trim().ToUpperInvariant();
        return value.Length == 3 && Currencies.All.Contains(value) ? value : null;
    }

    private sealed class LatestRates
    {
        [JsonPropertyName("result")]
        public string? Result { get; set; }

        [JsonPropertyName("rates")]
        public Dictionary<string, decimal>? Rates { get; set; }
    }
}
