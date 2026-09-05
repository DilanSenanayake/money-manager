using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;

namespace Ledgerly.Api.Models;

public sealed class ErrorResponse
{
    [JsonPropertyName("error")]
    public string Error { get; set; } = "";

    public ErrorResponse() { }

    public ErrorResponse(string error) => Error = error;
}

public sealed class SuccessResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; } = true;

    [JsonPropertyName("category_id")]
    public Guid? CategoryId { get; set; }
}

public sealed class CreateAccountRequest
{
    [Required, MaxLength(100)]
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = AccountTypes.Cash;

    [JsonPropertyName("balance")]
    public decimal Balance { get; set; }

    [Required]
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";
}

public sealed class UpdateAccountRequest
{
    [Required, MaxLength(100)]
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = AccountTypes.Cash;

    [Required]
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";
}

public sealed class CreateCategoryRequest
{
    [Required, MaxLength(100)]
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [MaxLength(50)]
    [JsonPropertyName("icon")]
    public string Icon { get; set; } = "circle";

    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = CategoryTypes.Expense;

    [JsonPropertyName("monthly_budget")]
    public decimal? MonthlyBudget { get; set; }
}

public sealed class CreateTransactionRequest
{
    [Required]
    [JsonPropertyName("account_id")]
    public Guid AccountId { get; set; }

    [JsonPropertyName("category_id")]
    public Guid? CategoryId { get; set; }

    [Range(0.01, double.MaxValue)]
    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = TransactionTypes.Expense;

    [Required]
    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [MaxLength(200)]
    [JsonPropertyName("merchant")]
    public string? Merchant { get; set; }

    [MaxLength(1000)]
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("is_recurring")]
    public bool IsRecurring { get; set; }

    [JsonPropertyName("recurring_frequency")]
    public string? RecurringFrequency { get; set; }

    [JsonPropertyName("transfer_to_account_id")]
    public Guid? TransferToAccountId { get; set; }
}

public sealed class TransactionFilter
{
    // FromQuery Name required — JsonPropertyName does not bind query strings
    [FromQuery(Name = "q")]
    public string? Q { get; set; }

    [FromQuery(Name = "account_id")]
    public Guid? AccountId { get; set; }

    [FromQuery(Name = "category_id")]
    public Guid? CategoryId { get; set; }

    [FromQuery(Name = "type")]
    public string? Type { get; set; }

    [FromQuery(Name = "from")]
    public string? From { get; set; }

    [FromQuery(Name = "to")]
    public string? To { get; set; }
}

public sealed class UpdateProfileRequest
{
    [Required]
    [JsonPropertyName("base_currency")]
    public string BaseCurrency { get; set; } = "USD";

    [MaxLength(100)]
    [JsonPropertyName("display_name")]
    public string? DisplayName { get; set; }
}

public sealed class UpsertExchangeRateRequest
{
    [Required]
    [JsonPropertyName("from_currency")]
    public string FromCurrency { get; set; } = "";

    [Required]
    [JsonPropertyName("to_currency")]
    public string ToCurrency { get; set; } = "";

    [Range(0.0000001, double.MaxValue)]
    [JsonPropertyName("rate")]
    public decimal Rate { get; set; }
}

public sealed class ParseTextRequest
{
    [Required]
    [JsonPropertyName("text")]
    public string Text { get; set; } = "";
}

public sealed class ParseReceiptRequest
{
    [Required]
    [JsonPropertyName("ocr_text")]
    public string OcrText { get; set; } = "";
}

public sealed class AiReviewSaveRequest
{
    [Required]
    [JsonPropertyName("account_id")]
    public Guid AccountId { get; set; }

    [JsonPropertyName("category_id")]
    public Guid? CategoryId { get; set; }

    [Range(0.01, double.MaxValue)]
    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [Required]
    [JsonPropertyName("type")]
    public string Type { get; set; } = TransactionTypes.Expense;

    [Required]
    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [MaxLength(200)]
    [JsonPropertyName("merchant")]
    public string? Merchant { get; set; }

    [MaxLength(1000)]
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("is_recurring")]
    public bool IsRecurring { get; set; }

    [JsonPropertyName("recurring_frequency")]
    public string? RecurringFrequency { get; set; }
}

public sealed class ReceiptExtraction
{
    [JsonPropertyName("merchant")]
    public string Merchant { get; set; } = "";

    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("category")]
    public string Category { get; set; } = "Other";

    [JsonPropertyName("line_items")]
    public List<ReceiptLineItem> LineItems { get; set; } = [];

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

public sealed class ReceiptLineItem
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("quantity")]
    public decimal? Quantity { get; set; }

    [JsonPropertyName("price")]
    public decimal? Price { get; set; }
}

public sealed class SmsExtraction
{
    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = "Debit";

    [JsonPropertyName("merchant")]
    public string Merchant { get; set; } = "";

    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("currency")]
    public string? Currency { get; set; }

    [JsonPropertyName("account_hint")]
    public string? AccountHint { get; set; }

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

public sealed class QuickTextExtraction
{
    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = TransactionTypes.Expense;

    [JsonPropertyName("merchant")]
    public string Merchant { get; set; } = "";

    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("category")]
    public string Category { get; set; } = "Other";

    [JsonPropertyName("currency")]
    public string? Currency { get; set; }

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

public sealed class BudgetProgress
{
    [JsonPropertyName("category")]
    public Category Category { get; set; } = new();

    [JsonPropertyName("spent")]
    public decimal Spent { get; set; }

    [JsonPropertyName("limit")]
    public decimal Limit { get; set; }

    [JsonPropertyName("ratio")]
    public decimal Ratio { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "none";
}

public sealed class DashboardResponse
{
    [JsonPropertyName("profile")]
    public Profile? Profile { get; set; }

    [JsonPropertyName("accounts")]
    public List<Account> Accounts { get; set; } = [];

    [JsonPropertyName("rates")]
    public List<ExchangeRate> Rates { get; set; } = [];

    [JsonPropertyName("netWorth")]
    public decimal NetWorth { get; set; }

    [JsonPropertyName("income")]
    public decimal Income { get; set; }

    [JsonPropertyName("expense")]
    public decimal Expense { get; set; }

    [JsonPropertyName("budgets")]
    public List<BudgetProgress> Budgets { get; set; } = [];

    [JsonPropertyName("recent")]
    public List<Transaction> Recent { get; set; } = [];

    [JsonPropertyName("baseCurrency")]
    public string BaseCurrency { get; set; } = "USD";

    [JsonPropertyName("monthStart")]
    public string MonthStart { get; set; } = "";

    [JsonPropertyName("monthEnd")]
    public string MonthEnd { get; set; } = "";
}

public sealed class AnalyticsResponse
{
    [JsonPropertyName("trend")]
    public List<TrendPoint> Trend { get; set; } = [];

    [JsonPropertyName("categorySpend")]
    public List<CategorySpendPoint> CategorySpend { get; set; } = [];

    [JsonPropertyName("baseCurrency")]
    public string BaseCurrency { get; set; } = "USD";
}

public sealed class TrendPoint
{
    [JsonPropertyName("month")]
    public string Month { get; set; } = "";

    [JsonPropertyName("income")]
    public decimal Income { get; set; }

    [JsonPropertyName("expense")]
    public decimal Expense { get; set; }
}

public sealed class CategorySpendPoint
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("value")]
    public decimal Value { get; set; }
}

public sealed class DataEnvelope<T>
{
    [JsonPropertyName("data")]
    public T Data { get; set; } = default!;

    public DataEnvelope() { }

    public DataEnvelope(T data) => Data = data;
}
