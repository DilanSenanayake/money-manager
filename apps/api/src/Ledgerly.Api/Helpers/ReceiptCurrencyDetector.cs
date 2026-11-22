using System.Text.RegularExpressions;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// Reads the currency printed on a receipt. The model often copies the wallet
/// currency instead, which skips conversion.
/// </summary>
public static partial class ReceiptCurrencyDetector
{
    public static void UseDetectedCurrency(ReceiptExtraction receipt, string? ocrText)
    {
        var detected = Detect(ocrText);
        if (detected is not null)
            receipt.Currency = detected;
    }

    public static string? Detect(string? ocrText)
    {
        if (string.IsNullOrWhiteSpace(ocrText)) return null;

        var hits = new List<Hit>();
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

        if (hits.Count == 0) return null;

        var explicitInr = hits.Exists(h => h.Code == "INR" && h.IsExplicit);
        var explicitLkr = hits.Exists(h => h.Code == "LKR" && h.IsExplicit);
        if (explicitInr)
            hits.RemoveAll(h => h.Code == "LKR" && !h.IsExplicit);
        if (explicitLkr)
            hits.RemoveAll(h => h.Code == "INR" && !h.IsExplicit);

        return Choose(hits);
    }

    private static string? Choose(List<Hit> hits)
    {
        var onTotal = Distinct(hits.Where(h => h.OnTotal && !h.InParentheses));
        if (onTotal.Count == 1) return onTotal[0];

        var plain = Distinct(hits.Where(h => !h.InParentheses));
        if (plain.Count == 1) return plain[0];

        var anyTotal = Distinct(hits.Where(h => h.OnTotal));
        if (anyTotal.Count == 1) return anyTotal[0];

        var all = Distinct(hits);
        return all.Count == 1 ? all[0] : null;
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
        var value = token.Trim().TrimEnd('.').ToUpperInvariant();
        return value is not ("RS" or "RUPEE" or "RUPEES" or "$");
    }

    private static string? CodeFor(string token)
    {
        var value = token.Trim().TrimEnd('.').ToUpperInvariant();
        return value switch
        {
            "US$" or "USD" => "USD",
            "A$" or "AUD" => "AUD",
            "C$" or "CAD" => "CAD",
            "S$" or "SGD" => "SGD",
            "€" or "EUR" => "EUR",
            "£" or "GBP" => "GBP",
            "¥" or "￥" or "JPY" => "JPY",
            "CHF" => "CHF",
            "LKR" or "SLR" or "රු" => "LKR",
            "₹" or "INR" => "INR",
            "RS" or "RUPEE" or "RUPEES" => "LKR",
            "$" => "USD",
            _ => null,
        };
    }

    private readonly record struct Hit(string Code, bool OnTotal, bool InParentheses, bool IsExplicit);

    [GeneratedRegex(
        @"\b(grand\s+total|amount\s+due|balance\s+due|total\s+due|net\s+amount|amount\s+paid|total|to\s+pay|nett)\b",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex TotalLine();

    [GeneratedRegex(
        @"US\$|\bUSD\b|A\$|\bAUD\b|C\$|\bCAD\b|S\$|\bSGD\b|€|\bEUR\b|£|\bGBP\b|¥|￥|\bJPY\b|\bCHF\b|\bLKR\b|\bSLR\b|රු\.?|₹|\bINR\b|\bRs\.?\b|\bRupees?\b|(?<![A-Za-z])\$(?=\s*\d)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Token();
}
