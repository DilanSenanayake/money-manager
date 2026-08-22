using System.Text.Json.Serialization;

namespace Ledgerly.Api.Models;

public sealed class Profile
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("base_currency")]
    public string BaseCurrency { get; set; } = "USD";

    [JsonPropertyName("display_name")]
    public string? DisplayName { get; set; }

    [JsonPropertyName("created_at")]
    public DateTimeOffset? CreatedAt { get; set; }

    [JsonPropertyName("updated_at")]
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class Account
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("user_id")]
    public Guid UserId { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("type")]
    public string Type { get; set; } = AccountTypes.Cash;

    [JsonPropertyName("balance")]
    public decimal Balance { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    [JsonPropertyName("created_at")]
    public DateTimeOffset? CreatedAt { get; set; }

    [JsonPropertyName("updated_at")]
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class Category
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("user_id")]
    public Guid UserId { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("icon")]
    public string Icon { get; set; } = "circle";

    [JsonPropertyName("type")]
    public string Type { get; set; } = CategoryTypes.Expense;

    [JsonPropertyName("monthly_budget")]
    public decimal? MonthlyBudget { get; set; }

    [JsonPropertyName("created_at")]
    public DateTimeOffset? CreatedAt { get; set; }
}

public sealed class Transaction
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("user_id")]
    public Guid UserId { get; set; }

    [JsonPropertyName("account_id")]
    public Guid AccountId { get; set; }

    [JsonPropertyName("category_id")]
    public Guid? CategoryId { get; set; }

    [JsonPropertyName("amount")]
    public decimal Amount { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = TransactionTypes.Expense;

    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("merchant")]
    public string? Merchant { get; set; }

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("is_recurring")]
    public bool IsRecurring { get; set; }

    [JsonPropertyName("recurring_frequency")]
    public string? RecurringFrequency { get; set; }

    [JsonPropertyName("transfer_pair_id")]
    public Guid? TransferPairId { get; set; }

    [JsonPropertyName("transfer_direction")]
    public string? TransferDirection { get; set; }

    [JsonPropertyName("created_at")]
    public DateTimeOffset? CreatedAt { get; set; }

    [JsonPropertyName("account")]
    public Account? Account { get; set; }

    [JsonPropertyName("category")]
    public Category? Category { get; set; }
}

public sealed class ExchangeRate
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("user_id")]
    public Guid UserId { get; set; }

    [JsonPropertyName("from_currency")]
    public string FromCurrency { get; set; } = "";

    [JsonPropertyName("to_currency")]
    public string ToCurrency { get; set; } = "";

    [JsonPropertyName("rate")]
    public decimal Rate { get; set; }

    [JsonPropertyName("updated_at")]
    public DateTimeOffset? UpdatedAt { get; set; }
}
