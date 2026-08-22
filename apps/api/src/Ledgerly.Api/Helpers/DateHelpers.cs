namespace Ledgerly.Api.Helpers;

public static class DateHelpers
{
    public static string LocalDateYyyyMmDd(DateTime? d = null)
    {
        var date = d ?? DateTime.Now;
        return $"{date.Year:D4}-{date.Month:D2}-{date.Day:D2}";
    }

    public static string LocalMonthStartYyyyMmDd(DateTime? d = null)
    {
        var date = d ?? DateTime.Now;
        return LocalDateYyyyMmDd(new DateTime(date.Year, date.Month, 1));
    }

    public static string LocalMonthEndYyyyMmDd(DateTime? d = null)
    {
        var date = d ?? DateTime.Now;
        var last = new DateTime(date.Year, date.Month, 1).AddMonths(1).AddDays(-1);
        return LocalDateYyyyMmDd(last);
    }
}
