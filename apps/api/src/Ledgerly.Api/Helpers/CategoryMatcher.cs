using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

public static class CategoryMatcher
{
    private static readonly Dictionary<string, string[]> ExpenseAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Dining"] =
        [
            "dining", "restaurant", "cafe", "coffee", "starbucks", "food", "lunch", "dinner",
            "breakfast", "mcdonald", "kfc", "pizza", "uber eats", "doordash"
        ],
        ["Groceries"] =
        [
            "grocery", "groceries", "supermarket", "market", "walmart", "costco", "whole foods",
            "trader joe"
        ],
        ["Transport"] =
        [
            "transport", "uber", "lyft", "taxi", "fuel", "gas", "petrol", "parking", "metro",
            "bus", "train", "grab"
        ],
        ["Shopping"] =
        [
            "shopping", "amazon", "mall", "clothing", "apparel", "store", "retail"
        ],
        ["Utilities"] =
        [
            "utility", "utilities", "electric", "water", "internet", "wifi", "phone", "bill",
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
        ["Other"] = ["other", "misc", "general"],
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

        var joined = string.Join(
            " ",
            hints.Where(h => !string.IsNullOrWhiteSpace(h)).Select(h => h!.Trim().ToLowerInvariant()));

        if (string.IsNullOrWhiteSpace(joined))
        {
            return pool.FirstOrDefault(c => c.Name.Equals("Other", StringComparison.OrdinalIgnoreCase))?.Id;
        }

        // Prefer longer / exact category names first to avoid "other" matching inside "mother"
        foreach (var c in pool.OrderByDescending(c => c.Name.Length))
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
            if (!HasWord(joined, word) && !joined.Contains(word, StringComparison.Ordinal))
                continue;
            // Prefer multi-word / longer aliases: require Contains for phrases, word for singles
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
                [' ', '-', '_', '/', ',', '.', ';', ':', '|', '&', '+'],
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(t => t.Length > 2)
            .ToArray();

        foreach (var c in pool.OrderByDescending(c => c.Name.Length))
        {
            var name = c.Name.ToLowerInvariant();
            if (tokens.Any(t => name == t || (t.Length >= 4 && (name.Contains(t) || t.Contains(name)))))
                return c.Id;
        }

        return pool.FirstOrDefault(c => c.Name.Equals("Other", StringComparison.OrdinalIgnoreCase))?.Id
               ?? pool[^1].Id;
    }

    private static bool HasWord(string haystack, string needle)
    {
        if (string.IsNullOrEmpty(needle)) return false;
        if (haystack == needle) return true;
        var parts = haystack.Split(
            [' ', '-', '_', '/', ',', '.', ';', ':', '|', '&', '+'],
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Any(p => p == needle);
    }
}
