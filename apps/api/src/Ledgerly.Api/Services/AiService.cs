using Ledgerly.Api.Helpers;
using Ledgerly.Api.Infrastructure.Llm;
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
    ILlmService llm,
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
        if (!llm.IsConfigured)
            return Result<ReceiptExtraction>.Fail(NotConfigured);

        var trimmed = ocrText.Replace("\r", "").Trim();
        if (trimmed.Length < 8)
        {
            return Result<ReceiptExtraction>.Fail(
                "We couldn't read enough from that photo. Try a clearer picture, or add it manually.");
        }

        var text = trimmed.Length > 8000 ? trimmed[..8000] : trimmed;
        var expenseCategories = (await categories.GetAllAsync(ct))
            .Where(c => c.Type == CategoryTypes.Expense)
            .ToList();
        var categoryNames = expenseCategories.Count > 0
            ? string.Join(", ", expenseCategories.Select(c => c.Name))
            : "Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other";

        try
        {
            var prompt =
                $"""
                You are given plain text extracted from a purchase receipt by OCR (may contain typos or junk lines). Extract structured purchase fields. Amount must be the TOTAL paid (not tax-only or unit prices). Date must be YYYY-MM-DD; if unknown use {DateHelpers.LocalDateYyyyMmDd()}.
                Pick category as ONE of these exact names when possible: {categoryNames}.
                Prefer Dining for restaurants, cafes, coffee shops, fast food, and takeout. Prefer Groceries for supermarkets. Avoid Other when another listed category fits. Do not put raw OCR into notes — leave notes null unless there is a short useful detail.

                OCR text:
                ---
                {text}
                ---
                """;

            var schema =
                """
                {"merchant":"string","amount":number,"currency":"USD|EUR|GBP|LKR|INR|JPY|AUD|CAD|CHF|SGD","date":"YYYY-MM-DD","category":"string","line_items":[{"name":"string","quantity":number|null,"price":number|null}],"notes":"string|null"}
                """;

            var result = await llm.GenerateObjectAsync<ReceiptExtraction>(prompt, schema, ct);
            if (string.IsNullOrWhiteSpace(result.Notes)
                || result.Notes.Trim().StartsWith("From receipt:", StringComparison.OrdinalIgnoreCase))
            {
                result.Notes = null;
            }
            else
            {
                result.Notes = result.Notes.Trim();
            }

            // Resolve category from merchant / line items when the model returns Other or a vague label
            var lineHints = string.Join(
                " ",
                result.LineItems.Select(i => i.Name).Where(n => !string.IsNullOrWhiteSpace(n)));
            var matchedId = CategoryMatcher.MatchCategoryId(
                expenseCategories,
                CategoryTypes.Expense,
                result.Category,
                result.Merchant,
                lineHints,
                result.Notes,
                CategoryMatcher.SanitizeOcrForCategoryHints(text));
            if (matchedId is Guid id)
            {
                var matchedName = expenseCategories.FirstOrDefault(c => c.Id == id)?.Name;
                if (!string.IsNullOrWhiteSpace(matchedName))
                    result.Category = matchedName;
            }

            return Result<ReceiptExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<ReceiptExtraction>.Fail(
                GroqService.FormatAiError(ex, "We couldn't understand that receipt. Please try again."));
        }
    }

    public async Task<Result<SmsExtraction>> ParseSmsAsync(string text, CancellationToken ct = default)
    {
        if (!llm.IsConfigured)
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

            var result = await llm.GenerateObjectAsync<SmsExtraction>(prompt, schema, ct);
            NormalizeSms(result);
            return Result<SmsExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<SmsExtraction>.Fail(
                GroqService.FormatAiError(ex, "We couldn't read that message. Please try again."));
        }
    }

    public async Task<Result<QuickTextExtraction>> ParseQuickTextAsync(
        string text,
        CancellationToken ct = default)
    {
        if (!llm.IsConfigured)
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

            var result = await llm.GenerateObjectAsync<QuickTextExtraction>(prompt, schema, ct);
            return Result<QuickTextExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            return Result<QuickTextExtraction>.Fail(
                GroqService.FormatAiError(ex, "We couldn't understand that. Please try again."));
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
            var selectedName = categoryId is Guid cid
                ? cats.FirstOrDefault(c => c.Id == cid)?.Name
                : null;
            var resolved = CategoryMatcher.MatchCategoryId(
                cats,
                request.Type,
                selectedName,
                request.Merchant,
                request.Notes);

            if (categoryId is Guid selected && cats.Any(c => c.Id == selected))
            {
                // Keep explicit pick unless it's the weak "Other" fallback and we found better
                var isOther = selectedName?.Equals("Other", StringComparison.OrdinalIgnoreCase) == true;
                if (!isOther || resolved is null || resolved == selected)
                    categoryId = selected;
                else
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
