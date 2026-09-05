using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface ISettingsService
{
    Task<Profile?> GetProfileAsync(CancellationToken ct = default);
    Task<Result> UpdateProfileAsync(UpdateProfileRequest request, CancellationToken ct = default);
    Task<List<ExchangeRate>> GetExchangeRatesAsync(CancellationToken ct = default);
    Task<Result> UpsertExchangeRateAsync(UpsertExchangeRateRequest request, CancellationToken ct = default);
    Task<Result> DeleteExchangeRateAsync(Guid id, CancellationToken ct = default);
}

public sealed class SettingsService(ISupabaseRestClient supabase, ICurrentUser user) : ISettingsService
{
    public Task<Profile?> GetProfileAsync(CancellationToken ct = default) =>
        supabase.GetSingleAsync<Profile>("profiles", $"id=eq.{user.UserId}", ct);

    public async Task<Result> UpdateProfileAsync(UpdateProfileRequest request, CancellationToken ct = default)
    {
        if (!Currencies.All.Contains(request.BaseCurrency))
            return Result.Fail("Invalid currency");

        try
        {
            await supabase.UpdateAsync(
                "profiles",
                $"id=eq.{user.UserId}",
                new
                {
                    base_currency = request.BaseCurrency,
                    display_name = request.DisplayName,
                },
                ct);

            // Do not relabel wallet currencies when base currency changes —
            // that silently reinterpreted balances (e.g. 1000 USD → 1000 EUR).

            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }

    public Task<List<ExchangeRate>> GetExchangeRatesAsync(CancellationToken ct = default) =>
        supabase.GetListAsync<ExchangeRate>(
            "exchange_rates",
            $"user_id=eq.{user.UserId}&order=updated_at.desc",
            ct);

    public async Task<Result> UpsertExchangeRateAsync(
        UpsertExchangeRateRequest request,
        CancellationToken ct = default)
    {
        if (!Currencies.All.Contains(request.FromCurrency) ||
            !Currencies.All.Contains(request.ToCurrency))
            return Result.Fail("Invalid currency");
        if (request.FromCurrency == request.ToCurrency)
            return Result.Fail("Currencies must be different");
        if (request.Rate <= 0)
            return Result.Fail("Rate must be positive");

        try
        {
            await supabase.UpsertAsync(
                "exchange_rates",
                new
                {
                    user_id = user.UserId,
                    from_currency = request.FromCurrency,
                    to_currency = request.ToCurrency,
                    rate = request.Rate,
                    updated_at = DateTimeOffset.UtcNow,
                },
                "user_id,from_currency,to_currency",
                ct);
            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }

    public async Task<Result> DeleteExchangeRateAsync(Guid id, CancellationToken ct = default)
    {
        try
        {
            await supabase.DeleteAsync(
                "exchange_rates",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                ct);
            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }
}
