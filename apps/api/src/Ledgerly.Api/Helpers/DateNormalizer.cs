using System.Globalization;
using System.Text.RegularExpressions;

namespace Ledgerly.Api.Helpers;

/// <summary>
/// Turns common receipt / SMS / note date strings into YYYY-MM-DD.
/// LLMs often keep the printed order or swap day and month; this repairs that.
/// </summary>
public static partial class DateNormalizer
{
    /// <summary>
    /// Shared instruction for AI prompts: recognize common formats, never swap day/month.
    /// </summary>
    public static string PromptRule(string fallbackIsoDate) =>
        $"""
        Date: read any common printed format and output exactly YYYY-MM-DD. Accept YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, DD.MM.YYYY, YYYY/MM/DD, D Month YYYY, Month D YYYY, compact YYYYMMDD, and the same forms with a time. Never swap day and month. When a numeric date has the year last and both other numbers are ≤ 12, prefer day-month-year (05/11/2026 → 2026-11-05) unless the text clearly uses US month-first wording (e.g. "November 5"). A number above 12 is always the day. Two-digit years are 2000+. If unknown use {fallbackIsoDate}.
        """;

    /// <summary>
    /// Normalize a model or OCR date to YYYY-MM-DD. Falls back to the local calendar day of
    /// <paramref name="referenceNow"/> when the value cannot be understood.
    /// </summary>
    public static string NormalizeToIsoDate(string? value, DateTime? referenceNow = null)
    {
        var today = referenceNow ?? DateTime.Now;
        if (string.IsNullOrWhiteSpace(value))
            return DateHelpers.LocalDateYyyyMmDd(today);

        var raw = value.Trim();
        if (OwnershipGuards.IsValidIsoDate(raw))
            return raw;

        // Keep only the calendar portion when a time or timezone is attached.
        var datePart = StripTime(raw);
        if (OwnershipGuards.IsValidIsoDate(datePart))
            return datePart;

        if (TryParseNamedMonth(datePart, out var named))
            return Format(named);

        if (TryParseCompact(datePart, out var compact))
            return Format(compact);

        if (TryParseNumeric(datePart, today, out var numeric))
            return Format(numeric);

        // Last resort: tolerant parse for odd but unambiguous strings.
        if (DateTime.TryParse(
                datePart,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AllowWhiteSpaces,
                out var loose)
            && loose.Year is >= 1990 and <= 2100)
        {
            return Format(DateOnly.FromDateTime(loose));
        }

        return DateHelpers.LocalDateYyyyMmDd(today);
    }

    private static string Format(DateOnly d) =>
        $"{d.Year:D4}-{d.Month:D2}-{d.Day:D2}";

    private static string StripTime(string value)
    {
        var tIndex = value.IndexOf('T');
        if (tIndex > 0)
            value = value[..tIndex];

        // "26/11/2026 14:30", "26/11/2026 2:30 PM", "26/11/2026, 14:30"
        var m = TimeSuffixRegex().Match(value);
        if (m.Success)
            value = value[..m.Index].Trim().TrimEnd(',');

        return value.Trim();
    }

    private static bool TryParseCompact(string value, out DateOnly date)
    {
        date = default;
        if (!CompactDateRegex().IsMatch(value))
            return false;

        if (!DateOnly.TryParseExact(
                value,
                "yyyyMMdd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out date))
        {
            return false;
        }

        return date.Year is >= 1990 and <= 2100;
    }

    private static bool TryParseNamedMonth(string value, out DateOnly date)
    {
        date = default;
        var cleaned = value.Replace(",", " ").Trim();
        cleaned = OrdinalSuffixRegex().Replace(cleaned, "$1");
        cleaned = MultiSpaceRegex().Replace(cleaned, " ");

        string[] formats =
        [
            "d MMMM yyyy",
            "dd MMMM yyyy",
            "d MMM yyyy",
            "dd MMM yyyy",
            "MMMM d yyyy",
            "MMMM dd yyyy",
            "MMM d yyyy",
            "MMM dd yyyy",
            "d-MMM-yyyy",
            "dd-MMM-yyyy",
            "d-MMMM-yyyy",
            "dd-MMMM-yyyy",
            "yyyy MMM d",
            "yyyy MMMM d",
            "yyyy-MMM-d",
            "yyyy-MMM-dd",
        ];

        foreach (var format in formats)
        {
            if (DateOnly.TryParseExact(
                    cleaned,
                    format,
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AllowWhiteSpaces,
                    out date)
                && date.Year is >= 1990 and <= 2100)
            {
                return true;
            }
        }

        return false;
    }

    private static bool TryParseNumeric(string value, DateTime today, out DateOnly date)
    {
        date = default;
        var m = NumericDateRegex().Match(value);
        if (!m.Success)
            return false;

        if (!int.TryParse(m.Groups[1].Value, out var a)
            || !int.TryParse(m.Groups[2].Value, out var b)
            || !int.TryParse(m.Groups[3].Value, out var c))
        {
            return false;
        }

        // Year-first: Y-M-D or a swapped Y-D-M the model sometimes emits.
        if (a is >= 1990 and <= 2100)
            return TryResolveYearFirst(a, b, c, out date);

        // Year-last: D-M-Y or M-D-Y (and 2-digit years).
        var year = ExpandYear(c, today.Year);
        if (year is < 1990 or > 2100)
            return false;

        return TryResolveYearLast(a, b, year, today, out date);
    }

    private static bool TryResolveYearFirst(int year, int x, int y, out DateOnly date)
    {
        date = default;

        // Valid Y-M-D as written.
        if (TryCreate(year, x, y, out date))
            return true;

        // Swapped month/day: 2026-26-11 → 2026-11-26.
        if (TryCreate(year, y, x, out date))
            return true;

        return false;
    }

    private static bool TryResolveYearLast(int a, int b, int year, DateTime today, out DateOnly date)
    {
        date = default;

        // a > 12 → must be day → D-M-Y.
        if (a > 12)
            return TryCreate(year, b, a, out date);

        // b > 12 → must be day → M-D-Y.
        if (b > 12)
            return TryCreate(year, a, b, out date);

        // Both ≤ 12: prefer day-month-year (common on LK/IN/UK receipts and bank SMS).
        // If that lands far from "today" while month-day-year is close, prefer the closer one.
        var dmyOk = TryCreate(year, b, a, out var dmy);
        var mdyOk = TryCreate(year, a, b, out var mdy);

        if (dmyOk && !mdyOk)
        {
            date = dmy;
            return true;
        }

        if (mdyOk && !dmyOk)
        {
            date = mdy;
            return true;
        }

        if (!dmyOk)
            return false;

        var refDay = DateOnly.FromDateTime(today);
        var dmyDistance = Math.Abs(dmy.DayNumber - refDay.DayNumber);
        var mdyDistance = Math.Abs(mdy.DayNumber - refDay.DayNumber);

        // Prefer DMY unless MDY is meaningfully closer to today (e.g. recent US-style SMS).
        date = mdyDistance + 14 < dmyDistance ? mdy : dmy;
        return true;
    }

    private static int ExpandYear(int year, int currentYear)
    {
        if (year >= 100)
            return year;

        // 00–99 → 2000–2099, then nudge into a ±50y window around "now".
        var full = 2000 + year;
        if (full > currentYear + 50)
            full -= 100;
        else if (full < currentYear - 50)
            full += 100;
        return full;
    }

    private static bool TryCreate(int year, int month, int day, out DateOnly date)
    {
        date = default;
        if (month is < 1 or > 12 || day is < 1 or > 31)
            return false;
        try
        {
            date = new DateOnly(year, month, day);
            return true;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    [GeneratedRegex(@"\s+\d{1,2}:\d{2}(:\d{2})?(\s*[AaPp][Mm])?\s*$")]
    private static partial Regex TimeSuffixRegex();

    [GeneratedRegex(@"^(\d{1,4})\s*[\/\-.\s]\s*(\d{1,2})\s*[\/\-.\s]\s*(\d{1,4})$")]
    private static partial Regex NumericDateRegex();

    [GeneratedRegex(@"^(\d{4})(\d{2})(\d{2})$")]
    private static partial Regex CompactDateRegex();

    [GeneratedRegex(@"\b(\d{1,2})(st|nd|rd|th)\b", RegexOptions.IgnoreCase)]
    private static partial Regex OrdinalSuffixRegex();

    [GeneratedRegex(@"\s+")]
    private static partial Regex MultiSpaceRegex();
}
