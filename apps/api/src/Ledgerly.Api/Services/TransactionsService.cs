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
    ICategoriesService categories,
    ILogger<TransactionsService> logger) : ITransactionsService
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
        {
            if (!OwnershipGuards.IsValidIsoDate(filter.From))
                return [];
            parts.Add($"date=gte.{Uri.EscapeDataString(filter.From.Trim())}");
        }
        if (!string.IsNullOrWhiteSpace(filter.To))
        {
            if (!OwnershipGuards.IsValidIsoDate(filter.To))
                return [];
            parts.Add($"date=lte.{Uri.EscapeDataString(filter.To.Trim())}");
        }
        if (!string.IsNullOrWhiteSpace(filter.Q))
        {
            var safe = filter.Q.Replace("%", "").Replace("_", "").Replace(",", "")
                .Replace("(", "").Replace(")", "").Replace(".", "").Trim();
            if (safe.Length > 100) safe = safe[..100];
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
        if (!OwnershipGuards.IsValidIsoDate(request.Date))
            return Result.Fail("Invalid date");
        if (request.IsRecurring
            && request.RecurringFrequency is not null
            && !RecurringFrequencies.All.Contains(request.RecurringFrequency))
            return Result.Fail("Invalid recurring frequency");

        try
        {
            if (request.Type == TransactionTypes.Transfer)
            {
                if (request.TransferToAccountId is null)
                    return Result.Fail("Choose where the money should go");
                if (request.TransferToAccountId == request.AccountId)
                    return Result.Fail("Pick two different accounts for a transfer");

                var accounts = await supabase.GetListAsync<Account>(
                    "accounts",
                    $"user_id=eq.{user.UserId}&or=(id.eq.{request.AccountId},id.eq.{request.TransferToAccountId})",
                    ct);
                var from = accounts.FirstOrDefault(a => a.Id == request.AccountId);
                var to = accounts.FirstOrDefault(a => a.Id == request.TransferToAccountId);
                if (from is null || to is null)
                    return Result.Fail("One of the accounts was not found");
                if (from.Currency != to.Currency)
                    return Result.Fail("Transfers must be between accounts that share the same currency");

                var pairId = Guid.NewGuid();
                var baseRow = new Dictionary<string, object?>
                {
                    ["user_id"] = user.UserId,
                    ["amount"] = request.Amount,
                    ["type"] = TransactionTypes.Transfer,
                    ["date"] = request.Date.Trim(),
                    ["merchant"] = OwnershipGuards.ClampNullable(request.Merchant, 200) ?? "Transfer",
                    ["notes"] = OwnershipGuards.ClampNullable(request.Notes, 1000),
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

            var accountCheck = await OwnershipGuards.EnsureOwnedAccountAsync(
                supabase, user.UserId, request.AccountId, ct);
            if (!accountCheck.Success) return accountCheck;

            var categoryCheck = await OwnershipGuards.EnsureOwnedCategoryAsync(
                supabase, user.UserId, request.CategoryId, ct);
            if (!categoryCheck.Success) return categoryCheck;

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
                date = request.Date.Trim(),
                merchant = OwnershipGuards.ClampNullable(request.Merchant, 200),
                notes = OwnershipGuards.ClampNullable(request.Notes, 1000),
                is_recurring = request.IsRecurring,
                recurring_frequency = request.IsRecurring
                    ? request.RecurringFrequency ?? RecurringFrequencies.Monthly
                    : null,
            }, ct);

            return Result.Ok();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create transaction for user {UserId}", user.UserId);
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }

    public async Task<Result> UpdateAsync(Guid id, CreateTransactionRequest request, CancellationToken ct = default)
    {
        if (request.Type == TransactionTypes.Transfer)
            return Result.Fail("Edit transfers by deleting and recreating them");
        if (!TransactionTypes.All.Contains(request.Type))
            return Result.Fail("Invalid transaction type");
        if (!OwnershipGuards.IsValidIsoDate(request.Date))
            return Result.Fail("Invalid date");

        try
        {
            var accountCheck = await OwnershipGuards.EnsureOwnedAccountAsync(
                supabase, user.UserId, request.AccountId, ct);
            if (!accountCheck.Success) return accountCheck;

            var categoryCheck = await OwnershipGuards.EnsureOwnedCategoryAsync(
                supabase, user.UserId, request.CategoryId, ct);
            if (!categoryCheck.Success) return categoryCheck;

            var existing = await supabase.GetSingleAsync<Transaction>(
                "transactions",
                $"select=id,transfer_pair_id,type&id=eq.{id}&user_id=eq.{user.UserId}",
                ct);
            if (existing is null)
                return Result.Fail("Transaction not found");
            if (existing.TransferPairId is not null || existing.Type == TransactionTypes.Transfer)
                return Result.Fail("Edit transfers by deleting and recreating them");

            await supabase.UpdateAsync(
                "transactions",
                $"id=eq.{id}&user_id=eq.{user.UserId}",
                new
                {
                    account_id = request.AccountId,
                    category_id = request.CategoryId,
                    amount = request.Amount,
                    type = request.Type,
                    date = request.Date.Trim(),
                    merchant = OwnershipGuards.ClampNullable(request.Merchant, 200),
                    notes = OwnershipGuards.ClampNullable(request.Notes, 1000),
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
            logger.LogError(ex, "Failed to update transaction {Id} for user {UserId}", id, user.UserId);
            return Result.Fail(OwnershipGuards.GenericError);
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
            logger.LogError(ex, "Failed to delete transaction {Id} for user {UserId}", id, user.UserId);
            return Result.Fail(OwnershipGuards.GenericError);
        }
    }
}
