using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// A saved review correction: one description key with the category and
/// account the user kept. The parsed description is left as-is on the next
/// fill; only category and account are reused. Amount and date are not part
/// of the combination. Category (and account) selection is the feedback —
/// the row is indexed by the description, not by raw source-text payee words.
/// </summary>
public static class FillFeedback
{
    private static readonly HashSet<string> Noise = new(StringComparer.OrdinalIgnoreCase)
    {
        "pos", "debit", "credit", "the", "and", "for", "from", "unknown",
        "payment", "purchase", "ltd", "pvt", "inc", "llc", "limited", "txn"
    };

    /// <summary>
    /// Normalized words from a description, used as the <c>payee_key</c> index.
    /// </summary>
    public static string? PayeeKey(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var tokens = Tokens(text).ToArray();
        if (tokens.Length == 0) return null;

        var key = string.Join(' ', tokens);
        return key.Length <= 80 ? key : key[..80].TrimEnd();
    }

    /// <summary>
    /// Longest saved key whose words all appear in the new description or source text.
    /// </summary>
    public static FillFeedbackRow? Match(
        IEnumerable<FillFeedbackRow> rows,
        params string?[] texts)
    {
        var haystack = texts
            .SelectMany(Tokens)
            .ToHashSet(StringComparer.Ordinal);

        FillFeedbackRow? best = null;
        var bestLength = -1;
        foreach (var row in rows)
        {
            if (string.IsNullOrWhiteSpace(row.PayeeKey)) continue;
            var keyTokens = row.PayeeKey.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (keyTokens.Length == 0 || keyTokens.Any(t => !haystack.Contains(t))) continue;
            if (row.PayeeKey.Length <= bestLength) continue;
            best = row;
            bestLength = row.PayeeKey.Length;
        }

        return best;
    }

    /// <summary>
    /// When the review changed category or account, return the combination to
    /// store under the saved description. An unchanged save, or a description-only
    /// edit, returns null — selecting category (or account) is the feedback.
    /// </summary>
    public static FillFeedbackChange? FromReview(FillFeedbackInput input)
    {
        if (!input.HasBaseline) return null;

        var categoryChanged = input.ProposedCategoryId is Guid proposedCategory
            && input.SavedCategoryId is Guid savedCategory
            && proposedCategory != savedCategory;
        var accountChanged = input.ProposedAccountId is Guid proposedAccount
            && proposedAccount != input.SavedAccountId;

        if (!categoryChanged && !accountChanged)
            return null;

        // Index by the description the user kept (or the draft description).
        var key = PayeeKey(input.SavedMerchant)
            ?? PayeeKey(input.ProposedMerchant);
        if (key is null) return null;

        var display = input.SavedMerchant?.Trim();
        if (string.IsNullOrEmpty(display)) display = null;
        else if (display.Length > 200) display = display[..200];

        return new FillFeedbackChange(key, display, input.SavedCategoryId, input.SavedAccountId);
    }

    private static IEnumerable<string> Tokens(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) yield break;

        var parts = text.ToLowerInvariant().Split(
            [' ', '\n', '\r', '\t', '-', '_', '/', ',', '.', ';', ':', '|', '&', '+', '\'', '"', '#', '(', ')', '[', ']'],
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        foreach (var token in parts)
        {
            if (token.Length < 3 || token.All(char.IsDigit) || Noise.Contains(token))
                continue;
            yield return token;
        }
    }
}

public sealed record FillFeedbackInput(
    bool HasBaseline,
    string? ProposedMerchant,
    Guid? ProposedCategoryId,
    Guid? ProposedAccountId,
    string? SavedMerchant,
    Guid? SavedCategoryId,
    Guid SavedAccountId);

public sealed record FillFeedbackChange(
    string PayeeKey,
    string? DisplayName,
    Guid? CategoryId,
    Guid AccountId);
