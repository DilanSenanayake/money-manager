using System.Globalization;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;
using Ledgerly.Api.Services;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// Shared ownership and input guards for money mutations.
/// </summary>
public static class OwnershipGuards
{
    public static async Task<Result> EnsureOwnedAccountAsync(
        ISupabaseRestClient supabase,
        Guid userId,
        Guid accountId,
        CancellationToken ct = default)
    {
        if (accountId == Guid.Empty)
            return Result.Fail("Choose an account");

        var account = await supabase.GetSingleAsync<Account>(
            "accounts",
            $"select=id&id=eq.{accountId}&user_id=eq.{userId}",
            ct);
        return account is null
            ? Result.Fail("Account not found")
            : Result.Ok();
    }

    public static async Task<Result> EnsureOwnedCategoryAsync(
        ISupabaseRestClient supabase,
        Guid userId,
        Guid? categoryId,
        CancellationToken ct = default)
    {
        if (categoryId is null || categoryId == Guid.Empty)
            return Result.Ok();

        var category = await supabase.GetSingleAsync<Category>(
            "categories",
            $"select=id&id=eq.{categoryId}&user_id=eq.{userId}",
            ct);
        return category is null
            ? Result.Fail("Category not found")
            : Result.Ok();
    }

    public static bool IsValidIsoDate(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && DateOnly.TryParseExact(
            value.Trim(),
            "yyyy-MM-dd",
            CultureInfo.InvariantCulture,
            DateTimeStyles.None,
            out _);

    public static string Clamp(string? value, int max) =>
        string.IsNullOrWhiteSpace(value)
            ? ""
            : (value.Trim().Length <= max ? value.Trim() : value.Trim()[..max]);

    public static string? ClampNullable(string? value, int max)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var trimmed = value.Trim();
        return trimmed.Length <= max ? trimmed : trimmed[..max];
    }

    public const string GenericError = "Something went wrong. Please try again.";
}
