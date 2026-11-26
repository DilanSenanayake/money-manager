using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// The descriptions a person logs most often, so home can repeat one
/// with the category already saved on that description.
/// </summary>
public static class FrequentRecords
{
    public const int Limit = 5;
    public const int MinUses = 2;

    public static List<FrequentRecord> Top(
        IEnumerable<Transaction> transactions,
        IReadOnlyList<Category> categories,
        IReadOnlyList<Account> accounts,
        IEnumerable<FillFeedbackRow>? feedback = null,
        string? since = null)
    {
        var categoryById = categories.ToDictionary(c => c.Id);
        var accountIds = accounts.Select(a => a.Id).ToHashSet();
        var feedbackByKey = new Dictionary<string, FillFeedbackRow>(StringComparer.Ordinal);
        if (feedback is not null)
        {
            foreach (var row in feedback)
            {
                if (string.IsNullOrWhiteSpace(row.PayeeKey)) continue;
                feedbackByKey.TryAdd(row.PayeeKey, row);
            }
        }

        var groups = new Dictionary<string, List<Transaction>>(StringComparer.Ordinal);
        foreach (var transaction in transactions)
        {
            if (transaction.Type is not (TransactionTypes.Income or TransactionTypes.Expense))
                continue;
            if (transaction.TransferPairId is not null) continue;
            if (transaction.Amount <= 0) continue;
            if (since is not null && string.CompareOrdinal(transaction.Date, since) < 0)
                continue;

            var text = DisplayText(transaction);
            var key = FillFeedback.PayeeKey(text);
            if (key is null || text is null) continue;

            var groupKey = transaction.Type + "\u001f" + key;
            if (!groups.TryGetValue(groupKey, out var list))
            {
                list = [];
                groups[groupKey] = list;
            }

            list.Add(transaction);
        }

        var ranked = new List<Candidate>();
        foreach (var (groupKey, list) in groups)
        {
            if (list.Count < MinUses) continue;

            var ordered = list
                .OrderByDescending(t => t.Date, StringComparer.Ordinal)
                .ThenByDescending(t => t.CreatedAt ?? DateTimeOffset.MinValue)
                .ToList();
            var template = ordered.FirstOrDefault(t => accountIds.Contains(t.AccountId));
            if (template is null) continue;

            var type = template.Type;
            var separator = groupKey.IndexOf('\u001f');
            var payeeKey = separator < 0 ? groupKey : groupKey[(separator + 1)..];
            var label = DisplayText(template);
            if (label is null) continue;

            var categoryId = PickCategory(ordered, type, categoryById, feedbackByKey, payeeKey);
            Category? category = null;
            if (categoryId is Guid resolved && categoryById.TryGetValue(resolved, out var found))
                category = found;

            ranked.Add(new Candidate(
                new FrequentRecord
                {
                    Label = label,
                    Notes = DetailText(template, label),
                    Type = type,
                    Amount = template.Amount,
                    AccountId = template.AccountId,
                    CategoryId = categoryId,
                    Category = category,
                    Count = list.Count,
                },
                template.Date,
                template.CreatedAt ?? DateTimeOffset.MinValue));
        }

        return ranked
            .OrderByDescending(c => c.Record.Count)
            .ThenByDescending(c => c.LastDate, StringComparer.Ordinal)
            .ThenByDescending(c => c.LastCreated)
            .ThenBy(c => c.Record.Label, StringComparer.OrdinalIgnoreCase)
            .Take(Limit)
            .Select(c => c.Record)
            .ToList();
    }

    private static Guid? PickCategory(
        List<Transaction> newestFirst,
        string type,
        Dictionary<Guid, Category> categoryById,
        Dictionary<string, FillFeedbackRow> feedbackByKey,
        string payeeKey)
    {
        foreach (var transaction in newestFirst)
        {
            if (Matches(transaction.CategoryId, type, categoryById, out var id))
                return id;
        }

        if (feedbackByKey.TryGetValue(payeeKey, out var saved)
            && Matches(saved.CategoryId, type, categoryById, out var savedId))
            return savedId;

        return null;
    }

    private static bool Matches(
        Guid? categoryId,
        string type,
        Dictionary<Guid, Category> categoryById,
        out Guid id)
    {
        id = default;
        if (categoryId is not Guid candidate) return false;
        if (!categoryById.TryGetValue(candidate, out var category)) return false;
        if (!string.Equals(category.Type, type, StringComparison.Ordinal)) return false;
        id = candidate;
        return true;
    }

    private static string? DisplayText(Transaction transaction)
    {
        var text = string.IsNullOrWhiteSpace(transaction.Merchant)
            ? transaction.Notes
            : transaction.Merchant;
        if (string.IsNullOrWhiteSpace(text)) return null;

        var line = text.Trim().Split('\n', 2)[0].Trim();
        if (line.Length == 0) return null;
        return line.Length <= 200 ? line : line[..200];
    }

    private static string? DetailText(Transaction transaction, string label)
    {
        var notes = transaction.Notes?.Trim();
        if (string.IsNullOrEmpty(notes)
            || string.Equals(notes, label, StringComparison.OrdinalIgnoreCase))
            return null;
        return notes.Length <= 1000 ? notes : notes[..1000];
    }

    private sealed record Candidate(FrequentRecord Record, string LastDate, DateTimeOffset LastCreated);
}
