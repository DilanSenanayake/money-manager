namespace Ledgerly.Api.Models;

public static class AccountTypes
{
    public const string Cash = "cash";
    public const string Checking = "checking";
    public const string Savings = "savings";
    public const string Credit = "credit";

    public static readonly HashSet<string> All =
    [
        Cash, Checking, Savings, Credit
    ];
}

public static class CategoryTypes
{
    public const string Income = "income";
    public const string Expense = "expense";

    public static readonly HashSet<string> All = [Income, Expense];
}

public static class TransactionTypes
{
    public const string Income = "income";
    public const string Expense = "expense";
    public const string Transfer = "transfer";

    public static readonly HashSet<string> All = [Income, Expense, Transfer];
}

public static class RecurringFrequencies
{
    public const string Weekly = "weekly";
    public const string Monthly = "monthly";
    public const string Yearly = "yearly";

    public static readonly HashSet<string> All = [Weekly, Monthly, Yearly];
}

public static class Currencies
{
    public static readonly HashSet<string> All =
    [
        "USD", "EUR", "GBP", "LKR", "INR", "JPY", "AUD", "CAD", "CHF", "SGD"
    ];
}
