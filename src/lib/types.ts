export type AccountType = "cash" | "checking" | "savings" | "credit";
export type CategoryType = "income" | "expense";
export type TransactionType = "income" | "expense" | "transfer";
export type RecurringFrequency = "weekly" | "monthly" | "yearly";

export interface Profile {
  id: string;
  base_currency: string;
  display_name: string | null;
  created_at: string;
  updated_at: string;
}

export interface Account {
  id: string;
  user_id: string;
  name: string;
  type: AccountType;
  balance: number;
  currency: string;
  created_at: string;
  updated_at: string;
}

export interface Category {
  id: string;
  user_id: string;
  name: string;
  icon: string;
  type: CategoryType;
  monthly_budget: number | null;
  created_at: string;
}

export interface Transaction {
  id: string;
  user_id: string;
  account_id: string;
  category_id: string | null;
  amount: number;
  type: TransactionType;
  date: string;
  merchant: string | null;
  notes: string | null;
  is_recurring: boolean;
  recurring_frequency: RecurringFrequency | null;
  transfer_pair_id: string | null;
  transfer_direction?: "out" | "in" | null;
  created_at: string;
  account?: Account;
  category?: Category | null;
}

export interface ExchangeRate {
  id: string;
  user_id: string;
  from_currency: string;
  to_currency: string;
  rate: number;
  updated_at: string;
}

export interface BudgetProgress {
  category: Category;
  spent: number;
  limit: number;
  ratio: number;
  status: "ok" | "warn" | "over" | "none";
}
