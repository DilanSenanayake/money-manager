using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface IQuickAddsService
{
    Task<List<QuickShortcut>> ListAsync(CancellationToken ct = default);
    Task<Result> CreateAsync(CreateQuickAddRequest request, CancellationToken ct = default);
    Task<Result> DeleteAsync(Guid id, CancellationToken ct = default);
}

public sealed class QuickAddsService(
    ISupabaseRestClient supabase,
    ICurrentUser user,
    ILogger<QuickAddsService> logger) : IQuickAddsService
{
    public const int Limit = 20;

    public async Task<List<QuickShortcut>> ListAsync(CancellationToken ct = default)
    {
        try
        {
            var select = Uri.EscapeDataString(
                "id,merchant,notes,category_id,amount,type,category:categories(id,user_id,name,icon,type,monthly_budget,created_at)");
            var rows = await supabase.GetListAsync<QuickAdd>(
                "quick_adds",
                $"select={select}&user_id=eq.{user.UserId}&order=created_at.asc&limit={Limit}",
                ct);
            return rows
                .Select(ToShortcut)
                .Where(item => item.Label.Length > 0)
                .ToList();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Quick add lookup skipped for user {UserId}", user.UserId);
            return [];
        }
    }

    public async Task<Result> CreateAsync(CreateQuickAddRequest request, CancellationToken ct = default)
    {
        var merchant = request.Merchant?.Trim() ?? "";
        if (merchant.Length == 0 || merchant.Length > 200)
            return Result.Fail("Enter a description");
        if (request.Amount <= 0)
            return Result.Fail("Enter an amount");
        if (request.CategoryId is not Guid categoryId)
            return Result.Fail("Choose a category");

        var notes = request.Notes?.Trim();
        if (string.IsNullOrEmpty(notes)) notes = null;
        else if (notes.Length > 1000) notes = notes[..1000];

        try
        {
            var existing = await supabase.GetListAsync<QuickAdd>(
                "quick_adds",
                $"select=id&user_id=eq.{user.UserId}&limit={Limit + 1}",
                ct);
            if (existing.Count >= Limit)
                return Result.Fail("You can save up to 20 quick adds.");

            var category = await supabase.GetSingleAsync<Category>(
                "categories",
                $"select=id,type&id=eq.{categoryId}&user_id=eq.{user.UserId}",
                ct);
            if (category is null || category.Type is not (CategoryTypes.Income or CategoryTypes.Expense))
                return Result.Fail("Choose a category");

            await supabase.InsertAsync<QuickAdd>("quick_adds", new
            {
                user_id = user.UserId,
                merchant,
                notes,
                category_id = category.Id,
                amount = request.Amount,
                type = category.Type,
            }, ct);
            return Result.Ok();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create quick add for user {UserId}", user.UserId);
            if (ex.Message.Contains("quick_adds", StringComparison.OrdinalIgnoreCase))
                return Result.Fail("Quick adds need a database update before they can be saved.");
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> DeleteAsync(Guid id, CancellationToken ct = default)
    {
        try
        {
            var existing = await supabase.GetSingleAsync<QuickAdd>(
                "quick_adds",
                $"select=id&id=eq.{id}&user_id=eq.{user.UserId}",
                ct);
            if (existing is null)
                return Result.Fail("Quick add not found");

            await supabase.DeleteAsync("quick_adds", $"id=eq.{id}&user_id=eq.{user.UserId}", ct);
            return Result.Ok();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to delete quick add {Id} for user {UserId}", id, user.UserId);
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    private static QuickShortcut ToShortcut(QuickAdd row)
    {
        var type = row.Category?.Type is CategoryTypes.Income or CategoryTypes.Expense
            ? row.Category.Type
            : row.Type is CategoryTypes.Income or CategoryTypes.Expense
                ? row.Type
                : CategoryTypes.Expense;
        var label = row.Merchant.Trim();
        if (label.Length > 200) label = label[..200];
        var notes = row.Notes?.Trim();
        if (string.IsNullOrEmpty(notes)
            || string.Equals(notes, label, StringComparison.OrdinalIgnoreCase))
            notes = null;
        else if (notes.Length > 1000)
            notes = notes[..1000];

        return new QuickShortcut
        {
            Id = row.Id,
            Label = label,
            Notes = notes,
            Type = type,
            Amount = row.Amount,
            CategoryId = row.Category?.Id ?? row.CategoryId,
            Category = row.Category,
        };
    }
}
