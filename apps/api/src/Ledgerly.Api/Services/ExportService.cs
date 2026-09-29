using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface IExportService
{
    Task<string> TransactionsCsvAsync(CancellationToken ct = default);
    Task<string> TransactionsJsonAsync(CancellationToken ct = default);
}

public sealed class ExportService(
    ISupabaseRestClient supabase,
    ICurrentUser user) : IExportService
{
    private const int PageSize = 1000;

    public async Task<string> TransactionsCsvAsync(CancellationToken ct = default)
    {
        var rows = await LoadAsync(ct);
        var builder = new StringBuilder();
        builder.AppendLine("date,type,amount,currency,account,category,merchant,notes,recurring,frequency");
        foreach (var row in rows)
        {
            builder
                .Append(Csv(row.Date)).Append(',')
                .Append(Csv(row.Type)).Append(',')
                .Append(Csv(AmountText(row.Amount, row.Account?.Currency))).Append(',')
                .Append(Csv(row.Account?.Currency)).Append(',')
                .Append(Csv(row.Account?.Name)).Append(',')
                .Append(Csv(row.Category?.Name)).Append(',')
                .Append(Csv(row.Merchant)).Append(',')
                .Append(Csv(row.Notes)).Append(',')
                .Append(row.IsRecurring ? "true" : "false").Append(',')
                .Append(Csv(row.RecurringFrequency))
                .AppendLine();
        }
        return builder.ToString();
    }

    public async Task<string> TransactionsJsonAsync(CancellationToken ct = default)
    {
        var rows = await LoadAsync(ct);
        var payload = rows.Select(row => new ExportTransaction(
            row.Date,
            row.Type,
            AmountText(row.Amount, row.Account?.Currency),
            row.Account?.Currency,
            row.Account?.Name,
            row.Category?.Name,
            row.Merchant,
            row.Notes,
            row.IsRecurring,
            row.RecurringFrequency)).ToList();
        return JsonSerializer.Serialize(payload, JsonOptions);
    }

    private async Task<List<Transaction>> LoadAsync(CancellationToken ct)
    {
        const string select =
            "id,date,type,amount,merchant,notes,is_recurring,recurring_frequency,account:accounts(name,currency),category:categories(name)";
        var rows = new List<Transaction>();
        var offset = 0;
        Guid? previousFirst = null;
        while (offset < 200_000)
        {
            var page = await supabase.GetListAsync<Transaction>(
                "transactions",
                $"select={Uri.EscapeDataString(select)}&user_id=eq.{user.UserId}&order=date.asc,id.asc&limit={PageSize}&offset={offset}",
                ct);
            if (page.Count == 0) break;
            if (previousFirst is not null && page[0].Id == previousFirst) break;
            previousFirst = page[0].Id;
            rows.AddRange(page);
            if (page.Count < PageSize) break;
            offset += page.Count;
        }
        return rows;
    }

    private static string AmountText(decimal amount, string? currency)
    {
        if (string.Equals(currency, "JPY", StringComparison.OrdinalIgnoreCase))
        {
            return decimal.Round(amount, 0, MidpointRounding.AwayFromZero)
                .ToString("0", CultureInfo.InvariantCulture);
        }
        return amount.ToString("0.00", CultureInfo.InvariantCulture);
    }

    private static string Csv(string? value)
    {
        var text = value ?? "";
        if (text.Length > 0 && "=+-@\t\r".Contains(text[0]))
            text = "'" + text;
        if (text.Contains('"') || text.Contains(',') || text.Contains('\n') || text.Contains('\r'))
            return "\"" + text.Replace("\"", "\"\"") + "\"";
        return text;
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private sealed record ExportTransaction(
        [property: JsonPropertyName("date")] string Date,
        [property: JsonPropertyName("type")] string Type,
        [property: JsonPropertyName("amount")] string Amount,
        [property: JsonPropertyName("currency")] string? Currency,
        [property: JsonPropertyName("account")] string? Account,
        [property: JsonPropertyName("category")] string? Category,
        [property: JsonPropertyName("merchant")] string? Merchant,
        [property: JsonPropertyName("notes")] string? Notes,
        [property: JsonPropertyName("recurring")] bool Recurring,
        [property: JsonPropertyName("frequency")] string? Frequency);
}
