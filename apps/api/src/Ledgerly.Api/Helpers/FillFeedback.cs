using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// A saved review correction: one payee key with the category and account
/// the user kept. Amount and date are not part of the combination.
/// </summary>
public static class FillFeedback
{
    private static readonly HashSet<string> Noise = new(StringComparer.OrdinalIgnoreCase)
    {
        "pos", "debit", "credit", "the", "and", "for", "from", "unknown",
        "payment", "purchase", "ltd", "pvt", "inc", "llc", "limited", "txn"
    };

    public static string? PayeeKey(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var tokens = Tokens(text).ToArray();
        if (tokens.Length == 0) return null;

        var key = string.Join(' ', tokens);
        return key.Length <= 80 ? key : key[..80].TrimEnd();
    }

    /// <summary>
    /// Longest saved key whose words all appear in the new text or merchant.
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
    /// When the review changed payee, category, or account, return the full
    /// combination to store. An unchanged save returns null.
    /// </summary>
    public static FillFeedbackChange? FromReview(FillFeedbackInput input)
    {
        if (!input.HasBaseline) return null;

        var categoryChanged = input.ProposedCategoryId is Guid proposedCategory
            && input.SavedCategoryId is Guid savedCategory
            && proposedCategory != savedCategory;
        var accountChanged = input.ProposedAccountId is Guid proposedAccount
            && proposedAccount != input.SavedAccountId;
        var merchantChanged = MerchantChanged(input.ProposedMerchant, input.SavedMerchant);

        if (!categoryChanged && !accountChanged && !merchantChanged)
            return null;

        var key = PayeeKey(input.PayeeKey)
            ?? PayeeKey(input.ProposedMerchant)
            ?? PayeeKey(input.SavedMerchant);
        if (key is null) return null;

        var display = input.SavedMerchant?.Trim();
        if (string.IsNullOrEmpty(display)) display = null;
        else if (display.Length > 200) display = display[..200];

        return new FillFeedbackChange(key, display, input.SavedCategoryId, input.SavedAccountId);
    }

    private static bool MerchantChanged(string? proposed, string? saved)
    {
        if (proposed is null) return false;
        var left = proposed.Trim();
        var right = (saved ?? "").Trim();
        if (left.Length == 0 && right.Length == 0) return false;
        return !string.Equals(left, right, StringComparison.OrdinalIgnoreCase);
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
    string? PayeeKey,
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
