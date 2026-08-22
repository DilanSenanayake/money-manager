using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface ITransactionsService
{
    Task<List<Transaction>> GetAsync(TransactionFilter filter, CancellationToken ct = default);
    Task<List<Transaction>> GetRecurringAsync(CancellationToken ct = default);
    Task<Result> CreateAsync(CreateTransactionRequest request, CancellationToken ct = default);
    Task<Result> UpdateAsync(Guid id, CreateTransactionRequest request, CancellationToken ct = default);
    Task<Result> DeleteAsync(Guid id, CancellationToken ct = default);
}

public sealed class TransactionsService(
    ISupabaseRestClient supabase,
    ICurrentUser user,
    ICategoriesService categories) : ITransactionsService
{
    private const string SelectWithJoins = "*,account:accounts(*),category:categories(*)";

    public async Task<List<Transaction>> GetAsync(TransactionFilter filter, CancellationToken ct = default)
    {
        var parts = new List<string>
        {
            $"select={Uri.EscapeDataString(SelectWithJoins)}",
            $"user_id=eq.{user.UserId}",
            "order=date.desc,created_at.desc",
            "limit=200",
        };

        if (filter.AccountId is Guid accountId)
            parts.Add($"account_id=eq.{accountId}");
        if (filter.CategoryId is Guid categoryId)
            parts.Add($"category_id=eq.{categoryId}");
        if (!string.IsNullOrWhiteSpace(filter.Type) && TransactionTypes.All.Contains(filter.Type))
            parts.Add($"type=eq.{filter.Type}");
        if (!string.IsNullOrWhiteSpace(filter.From))
            parts.Add($"date=gte.{filter.From}");
        if (!string.IsNullOrWhiteSpace(filter.To))
            parts.Add($"date=lte.{filter.To}");
        if (!string.IsNullOrWhiteSpace(filter.Q))
        {
            var safe = filter.Q.Replace("%", "").Replace("_", "").Replace(",", "").Trim();
            if (!string.IsNullOrWhiteSpace(safe))
            {
                var encoded = Uri.EscapeDataString($"merchant.ilike.%{safe}%,notes.ilike.%{safe}%");
                parts.Add($"or=({encoded})");
            }
        }

        return await supabase.GetListAsync<Transaction>("transactions", string.Join("&", parts), ct);
    }

    public Task<List<Transaction>> GetRecurringAsync(CancellationToken ct = default) =>
        supabase.GetListAsync<Transaction>(
            "transactions",
            $"select={Uri.EscapeDataString(SelectWithJoins)}&user_id=eq.{user.UserId}&is_recurring=eq.true&order=date.desc",
            ct);

    public async Task<Result> CreateAsync(CreateTransactionRequest request, CancellationToken ct = default)
    {
        if (!TransactionTypes.All.Contains(request.Type))
            return Result.Fail("Invalid transaction type");
        if (request.Amount <= 0)
            return Result.Fail("Amount must be positive");

        try
        {
            if (request.Type == TransactionTypes.Transfer)
            {
                if (request.TransferToAccountId is null)
                    return Result.Fail("Choose where the money should go");
                if (request.TransferToAccountId == request.AccountId)
                    return Result.Fail("Pick two different accounts for a transfer");

                var pairId = Guid.NewGuid();
                var baseRow = new Dictionary<string, object?>
                {
                    ["user_id"] = user.UserId,
                    ["amount"] = request.Amount,
                    ["type"] = TransactionTypes.Transfer,
                    ["date"] = request.Date,
                    ["merchant"] = request.Merchant ?? "Transfer",
                    ["notes"] = request.Notes,
                    ["is_recurring"] = false,
                    ["recurring_frequency"] = null,
                    ["transfer_pair_id"] = pairId,
                    ["category_id"] = null,
                };

                var outRow = new Dictionary<string, object?>(baseRow)
                {
                    ["account_id"] = request.AccountId,
                    ["transfer_direction"] = "out",
                };
                var inRow = new Dictionary<string, object?>(baseRow)
                {
                    ["account_id"] = request.TransferToAccountId,
                    ["transfer_direction"] = "in",
                };

                await supabase.InsertManyAsync("transactions", new[] { outRow, inRow }, ct);
                return Result.Ok();
            }

            Guid? categoryId = request.CategoryId;
            if (categoryId is null &&
                (request.Type is TransactionTypes.Expense or TransactionTypes.Income))
            {
                var cats = await categories.GetAllAsync(ct);
                categoryId = CategoryMatcher.MatchCategoryId(
                    cats.Where(c => c.Type == request.Type),
                    request.Type,
                    request.Merchant,
                    request.Notes);
            }

            await supabase.InsertAsync<Transaction>("transactions", new
            {
                user_id = user.UserId,
                account_id = request.AccountId,
                category_id = categoryId,
                amount = request.Amount,
                type = request.Type,
                date = request.Date,
                merchant = request.Merchant,
                notes = request.Notes,
                is_recurring = request.IsRecurring,
                recurring_frequency = request.IsRecurring
                    ? request.RecurringFrequency ?? RecurringFrequencies.Monthly
                    : null,
            }, ct);

            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }

    public async Task<Result> UpdateAsync(Guid id, CreateTransactionRequest request, CancellationToken ct = default)
    {
        if (request.Type == TransactionTypes.Transfer)
            return Result.Fail("Edit transfers by deleting and recreating them");
        if (!TransactionTypes.All.Contains(request.Type))
            return Result.Fail("Invalid transaction type");

        try
        {
            await supabase.UpdateAsync(
                "transactions",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                new
                {
                    account_id = request.AccountId,
                    category_id = request.CategoryId,
                    amount = request.Amount,
                    type = request.Type,
                    date = request.Date,
                    merchant = request.Merchant,
                    notes = request.Notes,
                    is_recurring = request.IsRecurring,
                    recurring_frequency = request.IsRecurring
                        ? request.RecurringFrequency ?? RecurringFrequencies.Monthly
                        : null,
                },
                ct);
            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }

    public async Task<Result> DeleteAsync(Guid id, CancellationToken ct = default)
    {
        try
        {
            var existing = await supabase.GetSingleAsync<Transaction>(
                "transactions",
                $"select=id,transfer_pair_id&id=eq.{id}&user_id=eq.{user.UserId}",
                ct);

            if (existing is null)
                return Result.Fail("Transaction not found");

            if (existing.TransferPairId is Guid pairId)
            {
                await supabase.DeleteAsync(
                    "transactions",
                    $"transfer_pair_id=eq.{pairId}&user_id=eq.{user.UserId}",
                    ct);
            }
            else
            {
                await supabase.DeleteAsync(
                    "transactions",
                    $"id=eq.{id}&user_id=eq.{user.UserId}",
                    ct);
            }

            return Result.Ok();
        }
        catch (Exception ex)
        {
            return Result.Fail(ex.Message);
        }
    }
}
