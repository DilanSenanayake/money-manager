using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface IAccountsService
{
    Task<List<Account>> GetAllAsync(CancellationToken ct = default);
    Task<Result> CreateAsync(CreateAccountRequest request, CancellationToken ct = default);
    Task<Result> UpdateAsync(Guid id, UpdateAccountRequest request, CancellationToken ct = default);
    Task<Result> DeleteAsync(Guid id, CancellationToken ct = default);
}

public sealed class AccountsService(ISupabaseRestClient supabase, ICurrentUser user) : IAccountsService
{
    public Task<List<Account>> GetAllAsync(CancellationToken ct = default) =>
        supabase.GetListAsync<Account>(
            "accounts",
            $"user_id=eq.{user.UserId}&order=created_at.asc",
            ct);

    public async Task<Result> CreateAsync(CreateAccountRequest request, CancellationToken ct = default)
    {
        if (!AccountTypes.All.Contains(request.Type))
            return Result.Fail("Invalid account type");
        if (!Currencies.All.Contains(request.Currency))
            return Result.Fail("Invalid currency");

        try
        {
            await supabase.InsertAsync<Account>("accounts", new
            {
                user_id = user.UserId,
                name = request.Name.Trim(),
                type = request.Type,
                balance = request.Balance,
                currency = request.Currency,
            }, ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> UpdateAsync(Guid id, UpdateAccountRequest request, CancellationToken ct = default)
    {
        if (!AccountTypes.All.Contains(request.Type))
            return Result.Fail("Invalid account type");
        if (!Currencies.All.Contains(request.Currency))
            return Result.Fail("Invalid currency");

        try
        {
            var existing = await supabase.GetSingleAsync<Account>(
                "accounts",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                ct);
            if (existing is null)
                return Result.Fail("Account not found");
            if (existing.Currency != request.Currency && existing.Balance != 0)
            {
                return Result.Fail(
                    "Change currency only when the balance is zero, or transfer funds out first");
            }

            // Never overwrite live balance — DB triggers keep it in sync
            await supabase.UpdateAsync(
                "accounts",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                new
                {
                    name = request.Name.Trim(),
                    type = request.Type,
                    currency = request.Currency,
                },
                ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> DeleteAsync(Guid id, CancellationToken ct = default)
    {
        try
        {
            await supabase.DeleteAsync("accounts", $"id=eq.{id}&user_id=eq.{user.UserId}", ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }
}

public interface ICategoriesService
{
    Task<List<Category>> GetAllAsync(CancellationToken ct = default);
    Task<Result> CreateAsync(CreateCategoryRequest request, CancellationToken ct = default);
    Task<Result> UpdateAsync(Guid id, CreateCategoryRequest request, CancellationToken ct = default);
    Task<Result> DeleteAsync(Guid id, CancellationToken ct = default);
}

public sealed class CategoriesService(ISupabaseRestClient supabase, ICurrentUser user) : ICategoriesService
{
    public Task<List<Category>> GetAllAsync(CancellationToken ct = default) =>
        supabase.GetListAsync<Category>(
            "categories",
            $"user_id=eq.{user.UserId}&order=type.asc,name.asc",
            ct);

    public async Task<Result> CreateAsync(CreateCategoryRequest request, CancellationToken ct = default)
    {
        if (!CategoryTypes.All.Contains(request.Type))
            return Result.Fail("Invalid category type");

        try
        {
            await supabase.InsertAsync<Category>("categories", new
            {
                user_id = user.UserId,
                name = request.Name.Trim(),
                icon = string.IsNullOrWhiteSpace(request.Icon) ? "circle" : request.Icon,
                type = request.Type,
                monthly_budget = request.MonthlyBudget,
            }, ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> UpdateAsync(Guid id, CreateCategoryRequest request, CancellationToken ct = default)
    {
        if (!CategoryTypes.All.Contains(request.Type))
            return Result.Fail("Invalid category type");

        try
        {
            await supabase.UpdateAsync(
                "categories",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                new
                {
                    name = request.Name.Trim(),
                    icon = string.IsNullOrWhiteSpace(request.Icon) ? "circle" : request.Icon,
                    type = request.Type,
                    monthly_budget = request.MonthlyBudget,
                },
                ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> DeleteAsync(Guid id, CancellationToken ct = default)
    {
        try
        {
            await supabase.DeleteAsync("categories", $"id=eq.{id}&user_id=eq.{user.UserId}", ct);
            return Result.Ok();
        }
        catch (Exception)
        {
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }
}

public readonly record struct Result(bool Success, string? Error)
{
    public static Result Ok() => new(true, null);
    public static Result Fail(string error) => new(false, error);
}

public readonly record struct Result<T>(bool Success, T? Value, string? Error)
{
    public static Result<T> Ok(T value) => new(true, value, null);
    public static Result<T> Fail(string error) => new(false, default, error);
}
