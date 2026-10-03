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
    ICategoriesService categories,
    ILogger<AiService> logger) : IAiService
{
    private const string NotConfigured =
        "Smart add isn't set up yet. You can still add expenses manually.";
    private const int MaxSmsTextLength = 4000;
    private const int MaxQuickTextLength = 2000;
    private const int MaxReceiptOcrLength = 8000;

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

        var text = trimmed.Length > MaxReceiptOcrLength ? trimmed[..MaxReceiptOcrLength] : trimmed;
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
                You are given plain text extracted by OCR from a photo of a bill, receipt, bus ticket, invoice, fare stub, or similar purchase document (may contain typos or junk lines). Accept any of these document types and extract structured purchase fields.
                Amount must be the TOTAL paid for the whole document (not tax-only or a single unit price).
                For each line_items entry, price must be the amount charged for the bought quantity on that line (line total = quantity × unit price when both appear). Do not use unit price alone when a line total is available or can be computed.
                Date must be YYYY-MM-DD; if unknown use {DateHelpers.LocalDateYyyyMmDd()}.
                Pick category as ONE of these exact names when possible: {categoryNames}.
                Prefer Dining for restaurants, cafes, coffee shops, fast food, and takeout. Prefer Groceries for supermarkets. Prefer Transport for bus, train, taxi, ride-hail, and similar tickets. Avoid Other when another listed category fits. Do not put raw OCR into notes — leave notes null unless there is a short useful detail.

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
            SanitizeReceipt(result);

            if (string.IsNullOrWhiteSpace(result.Notes)
                || result.Notes.Trim().StartsWith("From receipt:", StringComparison.OrdinalIgnoreCase))
            {
                result.Notes = null;
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

            await ApplySavedFeedbackAsync(
                result.Merchant,
                text,
                CategoryTypes.Expense,
                name => result.Category = name,
                categoryId => result.CategoryId = categoryId,
                accountId => result.AccountId = accountId,
                name => result.Merchant = name,
                key => result.PayeeKey = key,
                ct);

            return Result<ReceiptExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Receipt parse failed for user {UserId}", user.UserId);
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
        if (trimmed.Length > MaxSmsTextLength)
            return Result<SmsExtraction>.Fail("That message is too long. Paste a single bank alert.");

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
            await ApplySavedFeedbackAsync(
                result.Merchant,
                trimmed,
                result.Type == "Credit" ? CategoryTypes.Income : CategoryTypes.Expense,
                _ => { },
                categoryId => result.CategoryId = categoryId,
                accountId => result.AccountId = accountId,
                name => result.Merchant = name,
                key => result.PayeeKey = key,
                ct);
            return Result<SmsExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "SMS parse failed for user {UserId}", user.UserId);
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
        if (trimmed.Length > MaxQuickTextLength)
            return Result<QuickTextExtraction>.Fail("That note is too long. Keep it to one short sentence.");

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
            SanitizeQuickText(result);
            await ApplySavedFeedbackAsync(
                result.Merchant,
                trimmed,
                result.Type,
                name => result.Category = name,
                categoryId => result.CategoryId = categoryId,
                accountId => result.AccountId = accountId,
                name => result.Merchant = name,
                key => result.PayeeKey = key,
                ct);
            return Result<QuickTextExtraction>.Ok(result);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Quick-text parse failed for user {UserId}", user.UserId);
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
        if (!OwnershipGuards.IsValidIsoDate(request.Date) && !string.IsNullOrWhiteSpace(request.Date))
            return Result<Guid?>.Fail("Invalid date");

        try
        {
            var accountCheck = await OwnershipGuards.EnsureOwnedAccountAsync(
                supabase, user.UserId, request.AccountId, ct);
            if (!accountCheck.Success)
                return Result<Guid?>.Fail(accountCheck.Error!);

            var categoryCheck = await OwnershipGuards.EnsureOwnedCategoryAsync(
                supabase, user.UserId, request.CategoryId, ct);
            if (!categoryCheck.Success)
                return Result<Guid?>.Fail(categoryCheck.Error!);

            var cats = (await categories.GetAllAsync(ct))
                .Where(c => c.Type == request.Type)
                .ToList();

            Guid? categoryId = request.CategoryId;
            if (categoryId is not Guid selected || cats.All(c => c.Id != selected))
            {
                var selectedName = categoryId is Guid cid
                    ? cats.FirstOrDefault(c => c.Id == cid)?.Name
                    : null;
                categoryId = CategoryMatcher.MatchCategoryId(
                    cats,
                    request.Type,
                    selectedName,
                    request.Merchant,
                    request.Notes);
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
                    : request.Date.Trim(),
                merchant = OwnershipGuards.ClampNullable(request.Merchant, 200),
                notes = OwnershipGuards.ClampNullable(request.Notes, 1000),
                is_recurring = request.IsRecurring,
                recurring_frequency = request.IsRecurring
                    ? request.RecurringFrequency ?? RecurringFrequencies.Monthly
                    : null,
            }, ct);

            await RememberFillFeedbackAsync(request, categoryId, ct);
            return Result<Guid?>.Ok(categoryId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "AI save-reviewed failed for user {UserId}", user.UserId);
            return Result<Guid?>.Fail(OwnershipGuards.GenericError);
        }
    }

    private async Task ApplySavedFeedbackAsync(
        string? merchant,
        string sourceText,
        string categoryType,
        Action<string> setCategoryName,
        Action<string?> setCategoryId,
        Action<string?> setAccountId,
        Action<string> setMerchant,
        Action<string?> setPayeeKey,
        CancellationToken ct)
    {
        setPayeeKey(FillFeedback.PayeeKey(merchant));
        try
        {
            var rows = await supabase.GetListAsync<FillFeedbackRow>(
                "fill_feedback",
                $"select=payee_key,display_name,category_id,account_id&user_id=eq.{user.UserId}",
                ct);
            var hit = FillFeedback.Match(rows, sourceText, merchant);
            if (hit is null) return;

            setPayeeKey(hit.PayeeKey);
            if (!string.IsNullOrWhiteSpace(hit.DisplayName))
                setMerchant(hit.DisplayName);
            if (hit.AccountId is Guid accountId)
                setAccountId(accountId.ToString());
            if (hit.CategoryId is not Guid categoryId) return;

            var category = (await categories.GetAllAsync(ct))
                .FirstOrDefault(c => c.Id == categoryId && c.Type == categoryType);
            if (category is null) return;

            setCategoryName(category.Name);
            setCategoryId(category.Id.ToString());
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Fill feedback lookup skipped for user {UserId}", user.UserId);
        }
    }

    private async Task RememberFillFeedbackAsync(
        AiReviewSaveRequest request,
        Guid? savedCategoryId,
        CancellationToken ct)
    {
        var hasBaseline = request.ProposedMerchant is not null
            || request.ProposedCategoryId is not null
            || request.ProposedAccountId is not null;
        var change = FillFeedback.FromReview(new FillFeedbackInput(
            hasBaseline,
            request.PayeeKey,
            request.ProposedMerchant,
            request.ProposedCategoryId,
            request.ProposedAccountId,
            request.Merchant,
            savedCategoryId,
            request.AccountId));
        if (change is null) return;

        try
        {
            await supabase.UpsertAsync(
                "fill_feedback",
                new
                {
                    user_id = user.UserId,
                    payee_key = change.PayeeKey,
                    display_name = change.DisplayName,
                    category_id = change.CategoryId,
                    account_id = change.AccountId,
                    updated_at = DateTimeOffset.UtcNow,
                },
                "user_id,payee_key",
                ct,
                includeNulls: true);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Fill feedback was not saved for user {UserId}", user.UserId);
        }
    }

    private static void SanitizeReceipt(ReceiptExtraction result)
    {
        if (result.Amount < 0) result.Amount = Math.Abs(result.Amount);
        result.Merchant = OwnershipGuards.Clamp(result.Merchant, 200);
        result.Category = OwnershipGuards.Clamp(result.Category, 100);
        result.Notes = OwnershipGuards.ClampNullable(result.Notes, 1000);
        result.Currency = Currencies.All.Contains(result.Currency ?? "")
            ? result.Currency!
            : "USD";
        if (!OwnershipGuards.IsValidIsoDate(result.Date))
            result.Date = DateHelpers.LocalDateYyyyMmDd();
        foreach (var item in result.LineItems)
        {
            item.Name = OwnershipGuards.Clamp(item.Name, 200);
        }
        if (result.LineItems.Count > 50)
            result.LineItems = result.LineItems.Take(50).ToList();
    }

    private static void SanitizeQuickText(QuickTextExtraction result)
    {
        if (result.Amount < 0) result.Amount = Math.Abs(result.Amount);
        result.Merchant = OwnershipGuards.Clamp(result.Merchant, 200);
        result.Category = OwnershipGuards.Clamp(result.Category, 100);
        result.Notes = OwnershipGuards.ClampNullable(result.Notes, 1000);
        var type = (result.Type ?? "").Trim().ToLowerInvariant();
        result.Type = type == TransactionTypes.Income
            ? TransactionTypes.Income
            : TransactionTypes.Expense;
        if (!OwnershipGuards.IsValidIsoDate(result.Date))
            result.Date = DateHelpers.LocalDateYyyyMmDd();
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

        result.Merchant = string.IsNullOrWhiteSpace(result.Merchant)
            ? "Unknown"
            : OwnershipGuards.Clamp(result.Merchant, 200);
        result.Notes = OwnershipGuards.ClampNullable(result.Notes, 1000);
        result.AccountHint = OwnershipGuards.ClampNullable(result.AccountHint, 100);

        if (!OwnershipGuards.IsValidIsoDate(result.Date))
            result.Date = DateHelpers.LocalDateYyyyMmDd();
    }
}

internal static class StringExtensions
{
    public static string IfEmpty(this string value, string fallback) =>
        string.IsNullOrWhiteSpace(value) ? fallback : value;
}
