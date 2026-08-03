import { z } from "zod";

export const CURRENCIES = [
  "USD",
  "EUR",
  "GBP",
  "LKR",
  "INR",
  "JPY",
  "AUD",
  "CAD",
  "CHF",
  "SGD",
] as const;

export const currencySchema = z.enum(CURRENCIES);

export const accountTypeSchema = z.enum([
  "cash",
  "checking",
  "savings",
  "credit",
]);

export const categoryTypeSchema = z.enum(["income", "expense"]);

export const transactionTypeSchema = z.enum([
  "income",
  "expense",
  "transfer",
]);

export const recurringFrequencySchema = z.enum([
  "weekly",
  "monthly",
  "yearly",
]);

export const profileSchema = z.object({
  base_currency: currencySchema,
  display_name: z.string().min(1).max(100).optional().nullable(),
});

export const accountSchema = z.object({
  name: z.string().min(1).max(100),
  type: accountTypeSchema,
  balance: z.coerce.number(),
  currency: currencySchema,
});

export const categorySchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().min(1).max(50).default("circle"),
  type: categoryTypeSchema,
  monthly_budget: z.coerce.number().min(0).nullable().optional(),
});

export const transactionSchema = z.object({
  account_id: z.string().uuid(),
  category_id: z.string().uuid().nullable().optional(),
  amount: z.coerce.number().positive(),
  type: transactionTypeSchema,
  date: z.string().min(1),
  merchant: z.string().max(200).optional().nullable(),
  notes: z.string().max(1000).optional().nullable(),
  is_recurring: z.boolean().default(false),
  recurring_frequency: recurringFrequencySchema.nullable().optional(),
  transfer_to_account_id: z.string().uuid().optional().nullable(),
});

export const transactionFilterSchema = z.object({
  q: z.string().optional(),
  account_id: z.string().uuid().optional(),
  category_id: z.string().uuid().optional(),
  type: transactionTypeSchema.optional(),
  from: z.string().optional(),
  to: z.string().optional(),
});

export const exchangeRateSchema = z.object({
  from_currency: currencySchema,
  to_currency: currencySchema,
  rate: z.coerce.number().positive(),
});

export const receiptLineItemSchema = z.object({
  name: z.string(),
  quantity: z.number().nullable().optional(),
  price: z.number().nullable().optional(),
});

/** Shared by forms and Gemini generateObject for receipt OCR */
export const receiptExtractionSchema = z.object({
  merchant: z.string().describe("Store or merchant name"),
  amount: z.number().describe("Total amount paid"),
  currency: currencySchema.describe("ISO currency code if detectable, else USD"),
  date: z
    .string()
    .describe("Transaction date in YYYY-MM-DD format; use today if unknown"),
  category: z
    .string()
    .describe(
      "Likely expense category e.g. Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Other"
    ),
  line_items: z
    .array(receiptLineItemSchema)
    .describe("Individual line items when visible")
    .default([]),
  notes: z.string().nullable().optional().describe("Extra notes from the receipt"),
});

/** Shared by forms and Gemini generateObject for SMS / bank alert parsing */
export const smsExtractionSchema = z.object({
  amount: z.number().describe("Transaction amount as a positive number"),
  type: z
    .enum(["Credit", "Debit"])
    .describe("Credit = money in, Debit = money out"),
  merchant: z.string().describe("Merchant, payee, or counterparty"),
  date: z
    .string()
    .describe("Transaction date in YYYY-MM-DD; use today if unknown"),
  currency: currencySchema.optional().describe("Currency if mentioned"),
  account_hint: z
    .string()
    .nullable()
    .optional()
    .describe("Account last-4 or name hint from the message"),
  notes: z.string().nullable().optional(),
});

/** One-line natural language: "Coffee 450 at Starbucks" / "Salary 120000" */
export const quickTextExtractionSchema = z.object({
  amount: z.number().describe("Transaction amount as a positive number"),
  type: z
    .enum(["income", "expense"])
    .describe("income = money in, expense = money out"),
  merchant: z
    .string()
    .describe("Merchant, payee, or short description"),
  date: z
    .string()
    .describe("Transaction date in YYYY-MM-DD; use today if unknown"),
  category: z
    .string()
    .describe(
      "Likely category e.g. Salary, Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other"
    ),
  currency: currencySchema.optional().describe("Currency if mentioned"),
  notes: z.string().nullable().optional(),
});

export const aiReviewSaveSchema = z.object({
  account_id: z.string().uuid(),
  category_id: z.string().uuid().nullable().optional(),
  amount: z.coerce.number().positive(),
  type: z.enum(["income", "expense"]),
  date: z.string().min(1),
  merchant: z.string().max(200).optional().nullable(),
  notes: z.string().max(1000).optional().nullable(),
  is_recurring: z.boolean().default(false),
  recurring_frequency: recurringFrequencySchema.nullable().optional(),
});

export type ProfileInput = z.infer<typeof profileSchema>;
export type AccountInput = z.infer<typeof accountSchema>;
export type CategoryInput = z.infer<typeof categorySchema>;
export type TransactionInput = z.infer<typeof transactionSchema>;
export type TransactionFilter = z.infer<typeof transactionFilterSchema>;
export type ExchangeRateInput = z.infer<typeof exchangeRateSchema>;
export type ReceiptExtraction = z.infer<typeof receiptExtractionSchema>;
export type SmsExtraction = z.infer<typeof smsExtractionSchema>;
export type QuickTextExtraction = z.infer<typeof quickTextExtractionSchema>;
export type AiReviewSave = z.infer<typeof aiReviewSaveSchema>;
