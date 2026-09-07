using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Gemini;
using Ledgerly.Api.Infrastructure.Supabase;
using Ledgerly.Api.Models;

namespace Ledgerly.Api.Services;

public interface IAiService
{
    Task<Result<ReceiptExtraction>> ParseReceiptAsync(string ocrText, CancellationToken ct = default);
    Task<Result<SmsExtraction>> ParseSmsAsync(string text, CancellationToken ct = default);
    Task<Result<QuickTextExtraction>> ParseQuickTextAsync(string text, CancellationToken ct = default);
    Task<Result<Guid?>> SaveReviewedAsync(AiReviewSaveRequest request, CancellationToken ct = default);
}

public sealed class AiService(
    IGeminiService gemini,
    ISupabaseRestClient supabase,
    ICurrentUser user,
    ICategoriesService categories) : IAiService
{
    private const string NotConfigured =
        "Smart add isn't set up yet. You can still add expenses manually.";

    public async Task<Result<ReceiptExtraction>> ParseReceiptAsync(
        string ocrText,
        CancellationToken ct = default)
    {
        if (!gemini.IsConfigured)
            return Result<ReceiptExtraction>.Fail(NotConfigured);

        var trimmed = ocrText.Replace("\r", "").Trim();
        if (trimmed.Length < 8)
        {
            return Result<ReceiptExtraction>.Fail(
                "We couldn't read enough from that photo. Try a clearer picture, or add it manually.");
        }

        var text = trimmed.Length > 8000 ? trimmed[..8000] : trimmed;
        var expenseCats = (await categories.GetAllAsync(ct))
            .Where(c => c.Type == CategoryTypes.Expense)
            .Select(c => c.Name)
            .ToList();
        var categoryNames = expenseCats.Count > 0
            ? string.Join(", ", expenseCats)
            : "Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other";

        try
        {
            var prompt =
                $"""
                You are given plain text extracted from a purchase receipt by OCR (may contain typos or junk lines). Extract structured purchase fields. Amount must be the TOTAL paid (not tax-only or unit prices). Date must be YYYY-MM-DD; if unknown use {DateHelpers.LocalDateYyyyMmDd()}.
                Pick category as ONE of these exact names when possible: {categoryNames}.

                OCR text:
                """
                + text
                + "\"\"\"";

            var schema =
                """
                {"merchant":"string","amount":number,"currency":"USD|EUR|GBP|LKR|INR|JPY|AUD|CAD|CHF|SGD","date":"YYYY-MM-DD","category":"string","line_items":[{"name":"string","quantity":number|null,"price":number|null}],"notes":"string|null"}
                """;

            var result = await gemini.GenerateObjectAsync<ReceiptExtraction>(prompt, schema, ct);
            var notes = string.IsNullOrWhiteSpace(result.Notes)
                ? $"From receipt: {text[..Math.Min(240, text.Length)]}{(text.Length > 240 ? "…" : "")}"
                : result.Notes.Trim();

            result.Notes = notes;
            return Result<ReceiptExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<ReceiptExtraction>.Fail(
                GeminiService.FormatAiError(ex, "We couldn't understand that receipt. Please try again."));
        }
    }

    public async Task<Result<SmsExtraction>> ParseSmsAsync(string text, CancellationToken ct = default)
    {
        if (!gemini.IsConfigured)
            return Result<SmsExtraction>.Fail(NotConfigured);

        var trimmed = text.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
            return Result<SmsExtraction>.Fail("Paste a bank message first");

        try
        {
            var prompt =
                $"""
                Parse this bank SMS / alert into structured transaction fields.
                Credit = money received (income). Debit = money spent (expense).
                Amount must be a positive number (no currency symbols).
                Date must be YYYY-MM-DD; if unknown use {DateHelpers.LocalDateYyyyMmDd()}.
                Merchant = payee/merchant/counterparty name (or "Unknown" if missing).
                type must be exactly "Credit" or "Debit".

                Message:
                {trimmed}
                """;
            var schema =
                """
                {"amount":number,"type":"Credit|Debit","merchant":"string","date":"YYYY-MM-DD","currency":"string|null","account_hint":"string|null","notes":"string|null"}
                """;

            var result = await gemini.GenerateObjectAsync<SmsExtraction>(prompt, schema, ct);
            NormalizeSms(result);
            return Result<SmsExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<SmsExtraction>.Fail(
                GeminiService.FormatAiError(ex, "We couldn't read that message. Please try again."));
        }
    }

    public async Task<Result<QuickTextExtraction>> ParseQuickTextAsync(
        string text,
        CancellationToken ct = default)
    {
        if (!gemini.IsConfigured)
            return Result<QuickTextExtraction>.Fail(NotConfigured);

        var trimmed = text.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
            return Result<QuickTextExtraction>.Fail("Type something like \"Coffee 450 at Starbucks\"");

        var cats = await categories.GetAllAsync(ct);
        var expenseNames = string.Join(", ", cats.Where(c => c.Type == CategoryTypes.Expense).Select(c => c.Name));
        var incomeNames = string.Join(", ", cats.Where(c => c.Type == CategoryTypes.Income).Select(c => c.Name));

        try
        {
            var prompt =
                $"""
                Parse this short personal finance note into a single income or expense transaction. Prefer expense unless the text clearly means income (salary, refund, received, paid me, etc.). Date YYYY-MM-DD; if unknown use {DateHelpers.LocalDateYyyyMmDd()}.
                For expense category use ONE of: {expenseNames.IfEmpty("Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other")}.
                For income category use ONE of: {incomeNames.IfEmpty("Salary, Freelance, Investments")}.

                Note:
                {trimmed}
                """;

            var schema =
                """
                {"amount":number,"type":"income|expense","merchant":"string","date":"YYYY-MM-DD","category":"string","currency":"string|null","notes":"string|null"}
                """;

            var result = await gemini.GenerateObjectAsync<QuickTextExtraction>(prompt, schema, ct);
            return Result<QuickTextExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<QuickTextExtraction>.Fail(
                GeminiService.FormatAiError(ex, "We couldn't understand that. Please try again."));
        }
    }

    public async Task<Result<Guid?>> SaveReviewedAsync(
        AiReviewSaveRequest request,
        CancellationToken ct = default)
    {
        if (request.Type is not (TransactionTypes.Income or TransactionTypes.Expense))
            return Result<Guid?>.Fail("Type must be income or expense");
        if (request.Amount <= 0)
            return Result<Guid?>.Fail("Amount must be positive");

        try
        {
            var cats = (await categories.GetAllAsync(ct))
                .Where(c => c.Type == request.Type)
                .ToList();

            Guid? categoryId = request.CategoryId;
            var resolved = CategoryMatcher.MatchCategoryId(
                cats,
                request.Type,
                categoryId is Guid cid
                    ? cats.FirstOrDefault(c => c.Id == cid)?.Name
                    : null,
                request.Merchant,
                request.Notes);

            if (categoryId is Guid selected)
            {
                if (cats.All(c => c.Id != selected))
                    categoryId = resolved;
            }
            else
            {
                categoryId = resolved;
            }

            await supabase.InsertAsync<Transaction>("transactions", new
            {
                user_id = user.UserId,
                account_id = request.AccountId,
                category_id = categoryId,
                amount = request.Amount,
                type = request.Type,
                date = string.IsNullOrWhiteSpace(request.Date)
                    ? DateHelpers.LocalDateYyyyMmDd()
                    : request.Date,
                merchant = request.Merchant,
                notes = request.Notes,
                is_recurring = request.IsRecurring,
                recurring_frequency = request.IsRecurring
                    ? request.RecurringFrequency ?? RecurringFrequencies.Monthly
                    : null,
            }, ct);

            return Result<Guid?>.Ok(categoryId);
        }
        catch (Exception ex)
        {
            return Result<Guid?>.Fail(ex.Message);
        }
    }

    private static void NormalizeSms(SmsExtraction result)
    {
        if (result.Amount < 0) result.Amount = Math.Abs(result.Amount);

        var type = (result.Type ?? "").Trim();
        if (type.Equals("credit", StringComparison.OrdinalIgnoreCase)
            || type.Equals("income", StringComparison.OrdinalIgnoreCase)
            || type.Equals("cr", StringComparison.OrdinalIgnoreCase))
        {
            result.Type = "Credit";
        }
        else
        {
            result.Type = "Debit";
        }

        if (string.IsNullOrWhiteSpace(result.Merchant))
            result.Merchant = "Unknown";

        if (string.IsNullOrWhiteSpace(result.Date))
            result.Date = DateHelpers.LocalDateYyyyMmDd();
    }
}

internal static class StringExtensions
{
    public static string IfEmpty(this string value, string fallback) =>
        string.IsNullOrWhiteSpace(value) ? fallback : value;
}
