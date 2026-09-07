using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class CategoryMatcher
{
    private static readonly HashSet<string> WeakLabels = new(StringComparer.OrdinalIgnoreCase)
    {
        "other", "misc", "general", "unknown", "n/a", "na"
    };

    private static readonly Dictionary<string, string[]> ExpenseAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Dining"] =
        [
            "dining", "restaurant", "cafe", "coffee", "starbucks", "food", "lunch", "dinner",
            "breakfast", "mcdonald", "mcdonalds", "kfc", "pizza", "uber eats", "doordash", "burger", "sushi",
            "bistro", "takeaway", "takeout", "eatery"
        ],
        ["Groceries"] =
        [
            "grocery", "groceries", "supermarket", "walmart", "costco", "whole foods",
            "trader joe"
        ],
        ["Transport"] =
        [
            "transport", "uber", "lyft", "taxi", "fuel", "gas", "petrol", "parking", "metro",
            "bus", "train", "grab"
        ],
        ["Shopping"] =
        [
            "shopping", "amazon", "mall", "clothing", "apparel", "retail"
        ],
        ["Utilities"] =
        [
            "utility", "utilities", "electric", "water", "internet", "wifi", "phone",
            "gas bill"
        ],
        ["Health"] =
        [
            "health", "pharmacy", "medical", "doctor", "hospital", "dental", "clinic"
        ],
        ["Entertainment"] =
        [
            "entertainment", "movie", "netflix", "spotify", "game", "cinema", "concert"
        ],
        ["Rent"] = ["rent", "mortgage", "housing", "lease"],
    };

    private static readonly Dictionary<string, string[]> IncomeAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Salary"] = ["salary", "paycheck", "wage", "payroll"],
        ["Freelance"] = ["freelance", "contract", "gig", "client"],
        ["Investments"] = ["investment", "dividend", "interest", "stock"],
    };

    public static Guid? MatchCategoryId(
        IEnumerable<Category> categories,
        string type,
        params string?[] hints)
    {
        var pool = categories.Where(c => c.Type == type).ToList();
        if (pool.Count == 0) return null;

        var other = pool.FirstOrDefault(c =>
            c.Name.Equals("Other", StringComparison.OrdinalIgnoreCase));

        var cleaned = hints
            .Where(h => !string.IsNullOrWhiteSpace(h))
            .Select(h => h!.Trim().ToLowerInvariant())
            .Where(h => !h.StartsWith("from receipt:", StringComparison.Ordinal))
            .ToList();

        var joined = string.Join(" ", cleaned);
        if (string.IsNullOrWhiteSpace(joined) || cleaned.All(IsWeakLabel))
            return other?.Id;

        var byLength = pool
            .Where(c => !c.Name.Equals("Other", StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(c => c.Name.Length)
            .ToList();

        // Prefer an explicit non-Other category name from any single hint (LLM label)
        foreach (var hint in cleaned)
        {
            if (IsWeakLabel(hint)) continue;
            foreach (var c in byLength)
            {
                var name = c.Name.ToLowerInvariant();
                if (hint == name || HasWord(hint, name))
                    return c.Id;
            }
        }

        foreach (var c in byLength)
        {
            var name = c.Name.ToLowerInvariant();
            if (joined == name || HasWord(joined, name))
                return c.Id;
        }

        var aliases = type == CategoryTypes.Expense ? ExpenseAliases : IncomeAliases;
        var ranked = aliases
            .SelectMany(kv => kv.Value.Select(w => (Canonical: kv.Key, Word: w)))
            .OrderByDescending(x => x.Word.Length);

        foreach (var (canonical, word) in ranked)
        {
            if (word.Contains(' '))
            {
                if (!joined.Contains(word, StringComparison.Ordinal)) continue;
            }
            else if (!HasWord(joined, word))
            {
                continue;
            }

            var found = pool.FirstOrDefault(c =>
                c.Name.Equals(canonical, StringComparison.OrdinalIgnoreCase));
            if (found is not null) return found.Id;
        }

        var tokens = joined.Split(
                [' ', '-', '_', '/', ',', '.', ';', ':', '|', '&', '+', '\'', '"'],
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(t => t.Length > 2)
            .ToArray();

        foreach (var c in byLength)
        {
            var name = c.Name.ToLowerInvariant();
            if (tokens.Any(t => name == t || (t.Length >= 4 && (name.Contains(t) || t.Contains(name)))))
                return c.Id;
        }

        return other?.Id ?? pool[^1].Id;
    }

    private static bool IsWeakLabel(string value) => WeakLabels.Contains(value);

    private static bool HasWord(string haystack, string needle)
    {
        if (string.IsNullOrEmpty(needle)) return false;
        if (haystack == needle) return true;
        var parts = haystack.Split(
            [' ', '-', '_', '/', ',', '.', ';', ':', '|', '&', '+', '\'', '"'],
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Any(p =>
            p == needle ||
            (needle.Length >= 5 && p.StartsWith(needle, StringComparison.Ordinal)));
    }
}
