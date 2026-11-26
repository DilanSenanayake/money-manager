import { z } from "zod";
import { canonicalMoney, canonicalRate } from "@/lib/money";

function moneyString(allowZero = false) {
  return z.union([z.string(), z.number()]).transform((value, ctx) => {
    const text =
      typeof value === "number"
        ? Number.isFinite(value)
          ? value.toFixed(2)
          : ""
        : value;
    const canonical = canonicalMoney(text, { allowZero });
    if (!canonical) {
      ctx.addIssue({ code: "custom", message: "Enter a valid amount" });
      return z.NEVER;
    }
    return canonical;
  });
}

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

export const authCredentialsSchema = z.object({
  email: z.string().trim().email("Enter a valid email"),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(128, "Password is too long"),
});

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
  balance: moneyString(true),
  currency: currencySchema,
});

export const categorySchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().min(1).max(50).default("circle"),
  type: categoryTypeSchema,
  // Don't coerce null/"" to 0 — that broke clearing budgets
  monthly_budget: z
    .union([z.string(), z.number(), z.null()])
    .optional()
    .transform((value, ctx) => {
      if (value === "" || value === null || value === undefined) return null;
      const text = typeof value === "number" ? value.toFixed(2) : value;
      const canonical = canonicalMoney(text, { allowZero: true });
      if (!canonical) {
        ctx.addIssue({ code: "custom", message: "Enter a valid budget" });
        return z.NEVER;
      }
      return canonical;
    }),
});

export const transactionSchema = z.object({
  account_id: z.string().uuid(),
  category_id: z.string().uuid().nullable().optional(),
  amount: moneyString(),
  type: transactionTypeSchema,
  date: z.string().min(1),
  merchant: z.string().max(200).optional().nullable(),
  notes: z.string().max(1000).optional().nullable(),
  is_recurring: z.boolean().default(false),
  recurring_frequency: recurringFrequencySchema.nullable().optional(),
  transfer_to_account_id: z.string().uuid().optional().nullable(),
  proposed_merchant: z.string().max(200).nullable().optional(),
  proposed_category_id: z.string().uuid().nullable().optional(),
  proposed_account_id: z.string().uuid().nullable().optional(),
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
  rate: z.union([z.string(), z.number()]).transform((value, ctx) => {
    const text = typeof value === "number" ? String(value) : value;
    const canonical = canonicalRate(text);
    if (!canonical) {
      ctx.addIssue({ code: "custom", message: "Enter a valid rate" });
      return z.NEVER;
    }
    return canonical;
  }),
});

export const receiptLineItemSchema = z.object({
  name: z.string(),
  quantity: z.number().nullable().optional(),
  price: z
    .number()
    .nullable()
    .optional()
    .describe(
      "Line total for the bought quantity (quantity × unit price), not unit price alone"
    ),
});

/** Shared by Gemini generateObject for receipt text (after Tesseract OCR) */
export const receiptExtractionSchema = z.object({
  merchant: z.string().describe("Short name for the place or purchase"),
  amount: z.number().describe("Total amount paid for the whole document"),
  currency: currencySchema.describe(
    "ISO code printed for the total. If the document shows no currency, use USD"
  ),
  source_amount: z.number().nullable().optional(),
  source_currency: currencySchema.nullable().optional(),
  exchange_rate: z.number().nullable().optional(),
  conversion_warning: z.string().nullable().optional(),
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
    .describe(
      "Individual line items when visible; each price is the amount for the bought quantity"
    )
    .default([]),
  notes: z
    .string()
    .nullable()
    .optional()
    .describe("Optional longer description. Leave null when the short name is enough"),
  category_id: z.string().uuid().nullable().optional(),
  account_id: z.string().uuid().nullable().optional(),
  payee_key: z.string().max(80).nullable().optional(),
});

/** Shared by forms and Gemini generateObject for SMS / bank alert parsing */
export const smsExtractionSchema = z.object({
  amount: z.number().describe("Transaction amount as a positive number"),
  type: z
    .enum(["Credit", "Debit"])
    .describe("Credit = money in, Debit = money out"),
  merchant: z.string().describe("Short name for who was paid or what it was for"),
  date: z
    .string()
    .describe("Transaction date in YYYY-MM-DD; use today if unknown"),
  currency: currencySchema.optional().describe("Currency if mentioned"),
  source_amount: z.number().nullable().optional(),
  source_currency: currencySchema.nullable().optional(),
  exchange_rate: z.number().nullable().optional(),
  conversion_warning: z.string().nullable().optional(),
  account_hint: z
    .string()
    .nullable()
    .optional()
    .describe("Account last-4 or name hint from the message"),
  notes: z
    .string()
    .nullable()
    .optional()
    .describe("Optional longer description. Leave null when the short name is enough"),
  category_id: z.string().uuid().nullable().optional(),
  account_id: z.string().uuid().nullable().optional(),
  payee_key: z.string().max(80).nullable().optional(),
});

/** One-line natural language: "Coffee 450 at Starbucks" / "Salary 120000" */
export const quickTextExtractionSchema = z.object({
  amount: z.number().describe("Transaction amount as a positive number"),
  type: z
    .enum(["income", "expense"])
    .describe("income = money in, expense = money out"),
  merchant: z
    .string()
    .describe("Short name, like Coffee or Rent"),
  date: z
    .string()
    .describe("Transaction date in YYYY-MM-DD; use today if unknown"),
  category: z
    .string()
    .describe(
      "Likely category e.g. Salary, Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other"
    ),
  currency: currencySchema.optional().describe("Currency if mentioned"),
  source_amount: z.number().nullable().optional(),
  source_currency: currencySchema.nullable().optional(),
  exchange_rate: z.number().nullable().optional(),
  conversion_warning: z.string().nullable().optional(),
  notes: z
    .string()
    .nullable()
    .optional()
    .describe("Optional longer description. Leave null when the short name is enough"),
  category_id: z.string().uuid().nullable().optional(),
  account_id: z.string().uuid().nullable().optional(),
  payee_key: z.string().max(80).nullable().optional(),
});

export const aiReviewSaveSchema = z.object({
  account_id: z.string().uuid(),
  category_id: z.string().uuid().nullable().optional(),
  amount: moneyString(),
  type: z.enum(["income", "expense"]),
  date: z.string().min(1),
  merchant: z.string().max(200).optional().nullable(),
  notes: z.string().max(1000).optional().nullable(),
  is_recurring: z.boolean().default(false),
  recurring_frequency: recurringFrequencySchema.nullable().optional(),
  proposed_category_id: z.string().uuid().nullable().optional(),
  proposed_account_id: z.string().uuid().nullable().optional(),
  proposed_merchant: z.string().max(200).nullable().optional(),
  payee_key: z.string().max(80).nullable().optional(),
});

export const quickAddSchema = z.object({
  merchant: z.string().trim().min(1, "Enter a description").max(200),
  notes: z
    .string()
    .max(1000)
    .nullable()
    .optional()
    .transform((value) => {
      const text = value?.trim() ?? "";
      return text ? text : null;
    }),
  category_id: z.string().uuid("Choose a category"),
  amount: moneyString(),
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
export type QuickAddInput = z.infer<typeof quickAddSchema>;
