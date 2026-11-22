using System.Text.RegularExpressions;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// Reads the currency printed on a receipt. The model often copies the wallet
/// currency and leaves the raw total, which makes Check &amp; Save look converted.
/// </summary>
public static partial class ReceiptCurrencyDetector
{
    /// <summary>
    /// Currency the total is printed in, before it is converted into <paramref name="targetCurrency"/>.
    /// A wallet-currency hit does not replace a foreign code that is actually printed.
    /// </summary>
    public static string Resolve(string? modelCurrency, string? ocrText, string targetCurrency)
    {
        var model = Known(modelCurrency);
        var target = Known(targetCurrency);
        var hits = Filtered(ocrText);

        // An explicit wallet total (LKR, USD, … printed on the total line) is the
        // amount to save. "Rs" or "$" alone is not explicit and must not hide a
        // foreign currency the model read.
        if (ExplicitOnTotal(hits, target))
        {
            var foreignOnTotal = SingleForeign(
                hits.Where(h => h.OnTotal && !Same(h.Code, target)));
            if (foreignOnTotal is null)
                return target;
            return foreignOnTotal;
        }

        var foreign = SingleForeign(hits.Where(h => !Same(h.Code, target)));
        if (foreign is not null)
            return foreign;

        if (model.Length > 0 && !Same(model, target))
            return model;

        var detected = Choose(hits)?.Code;
        if (detected is not null)
            return detected;

        if (model.Length > 0)
            return model;

        return target.Length > 0 ? target : "USD";
    }

    public static string? Detect(string? ocrText)
    {
        var hits = Filtered(ocrText);
        return hits.Count == 0 ? null : Choose(hits)?.Code;
    }

    private static List<Hit> Filtered(string? ocrText)
    {
        var hits = Collect(ocrText);
        var explicitInr = hits.Exists(h => h.Code == "INR" && h.IsExplicit);
        var explicitLkr = hits.Exists(h => h.Code == "LKR" && h.IsExplicit);
        if (explicitInr)
            hits.RemoveAll(h => h.Code == "LKR" && !h.IsExplicit);
        if (explicitLkr)
            hits.RemoveAll(h => h.Code == "INR" && !h.IsExplicit);
        return hits;
    }

    private static bool ExplicitOnTotal(List<Hit> hits, string code) =>
        code.Length > 0 && hits.Exists(h =>
            h.OnTotal && !h.InParentheses && h.IsExplicit && Same(h.Code, code));

    /// <summary>One explicit currency in the set, ignoring parentheses and weak tokens.</summary>
    private static string? SingleForeign(IEnumerable<Hit> hits)
    {
        var codes = new List<string>();
        foreach (var hit in hits)
        {
            if (hit.InParentheses || !hit.IsExplicit) continue;
            if (!codes.Contains(hit.Code))
                codes.Add(hit.Code);
        }

        return codes.Count == 1 ? codes[0] : null;
    }

    private static List<Hit> Collect(string? ocrText)
    {
        var hits = new List<Hit>();
        if (string.IsNullOrWhiteSpace(ocrText)) return hits;

        foreach (var rawLine in ocrText.Replace('\u00A0', ' ').Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0) continue;
            var onTotal = TotalLine().IsMatch(line);
            foreach (Match match in Token().Matches(line))
            {
                var code = CodeFor(match.Value);
                if (code is null) continue;
                hits.Add(new Hit(
                    code,
                    onTotal,
                    InParentheses(line, match.Index),
                    Explicit(match.Value)));
            }
        }

        return hits;
    }

    private static Detection? Choose(List<Hit> hits)
    {
        return One(hits.Where(h => h.OnTotal && !h.InParentheses))
            ?? One(hits.Where(h => !h.InParentheses))
            ?? One(hits.Where(h => h.OnTotal))
            ?? One(hits);
    }

    private static Detection? One(IEnumerable<Hit> hits)
    {
        var list = hits.ToList();
        var codes = Distinct(list);
        if (codes.Count != 1) return null;
        return new Detection(codes[0], list.Exists(h => h.IsExplicit));
    }

    private static List<string> Distinct(IEnumerable<Hit> hits)
    {
        var codes = new List<string>();
        foreach (var hit in hits)
        {
            if (!codes.Contains(hit.Code))
                codes.Add(hit.Code);
        }

        return codes;
    }

    private static bool InParentheses(string line, int index)
    {
        var open = line.LastIndexOf('(', index);
        if (open < 0) return false;
        var close = line.IndexOf(')', index);
        return close > index;
    }

    private static bool Explicit(string token)
    {
        var value = NormalizeToken(token);
        return value is not ("RS" or "RUPEE" or "RUPEES" or "$");
    }

    private static string? CodeFor(string token)
    {
        var value = NormalizeToken(token);
        return value switch
        {
            "US$" or "USD" or "US DOLLAR" or "US DOLLARS" or "DOLLAR" or "DOLLARS" => "USD",
            "A$" or "AUD" or "AUSTRALIAN DOLLAR" or "AUSTRALIAN DOLLARS" => "AUD",
            "C$" or "CAD" or "CANADIAN DOLLAR" or "CANADIAN DOLLARS" => "CAD",
            "S$" or "SGD" or "SINGAPORE DOLLAR" or "SINGAPORE DOLLARS" => "SGD",
            "€" or "EUR" or "EURO" or "EUROS" => "EUR",
            "£" or "GBP" or "POUND" or "POUNDS" or "STERLING" or "BRITISH POUND" or "BRITISH POUNDS" or "POUND STERLING" => "GBP",
            "¥" or "￥" or "JPY" or "YEN" or "JAPANESE YEN" => "JPY",
            "CHF" or "FRANC" or "FRANCS" or "SWISS FRANC" or "SWISS FRANCS" => "CHF",
            "LKR" or "SLR" or "රු" or "SRI LANKA RUPEE" or "SRI LANKA RUPEES" or "SRI LANKAN RUPEE" or "SRI LANKAN RUPEES" => "LKR",
            "₹" or "INR" or "INDIAN RUPEE" or "INDIAN RUPEES" => "INR",
            "RS" or "RUPEE" or "RUPEES" => "LKR",
            "$" => "USD",
            _ => null,
        };
    }

    private static string NormalizeToken(string token)
    {
        var value = token.Trim().TrimEnd('.').ToUpperInvariant();
        return Whitespace().Replace(value, " ");
    }

    private static string Known(string? currency)
    {
        var code = (currency ?? "").Trim().ToUpperInvariant();
        return Currencies.All.Contains(code) ? code : "";
    }

    private static bool Same(string? a, string? b) =>
        string.Equals(a, b, StringComparison.OrdinalIgnoreCase);

    private readonly record struct Hit(string Code, bool OnTotal, bool InParentheses, bool IsExplicit);

    private readonly record struct Detection(string Code, bool Explicit);

    [GeneratedRegex(
        @"\b(grand\s+total|amount\s+due|balance\s+due|total\s+due|net\s+amount|amount\s+paid|total|to\s+pay|nett)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex TotalLine();

    [GeneratedRegex(
        @"\b(?:sri\s+lankan?\s+rupees?|indian\s+rupees?|us\s+dollars?|australian\s+dollars?|canadian\s+dollars?|singapore\s+dollars?|swiss\s+francs?|british\s+pounds?|pound\s+sterling|japanese\s+yen)\b|US\$|\bUSD\b|\bDOLLARS?\b|A\$|\bAUD\b|C\$|\bCAD\b|S\$|\bSGD\b|€|\bEUR(?:O(?:S)?|S)?\b|£|\bGBP\b|\bPOUNDS?\b|\bSTERLING\b|¥|￥|\bJPY\b|\bYEN\b|\bCHF\b|\bFRANCS?\b|\bLKR\b|\bSLR\b|රු\.?|₹|\bINR\b|\bRs\.?\b|\bRupees?\b|(?<![A-Za-z])\$(?=\s*\d)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Token();

    [GeneratedRegex(@"\s+", RegexOptions.CultureInvariant)]
    private static partial Regex Whitespace();
}
