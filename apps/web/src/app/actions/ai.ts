"use server";

import { generateObject } from "ai";
import { revalidatePath } from "next/cache";
import {
  FREE_TIER_MODELS,
  formatAiError,
  getFlashModel,
  isQuotaError,
  type FreeTierModel,
} from "@/lib/ai";
import { matchCategoryId } from "@/lib/category-match";
import { localDateYYYYMMDD } from "@/lib/dates";
import {
  aiReviewSaveSchema,
  quickTextExtractionSchema,
  receiptExtractionSchema,
  smsExtractionSchema,
  type AiReviewSave,
  type QuickTextExtraction,
  type ReceiptExtraction,
  type SmsExtraction,
} from "@/lib/schemas";
import { requireUser } from "@/lib/supabase/auth";

/** Try Flash models in order; avoid burning retries on quota errors. */
async function generateWithFallback<T>(
  run: (model: ReturnType<typeof getFlashModel>) => Promise<T>
): Promise<T> {
  let lastError: unknown;

  for (const name of FREE_TIER_MODELS) {
    try {
      return await run(getFlashModel(name as FreeTierModel));
    } catch (err) {
      lastError = err;
      // Quota is usually project-wide — switching models rarely helps, but try lite once.
      if (isQuotaError(err) && name !== "gemini-2.5-flash-lite") {
        continue;
      }
      if (isQuotaError(err)) break;
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error("All Gemini Flash models failed");
}

export async function parseReceiptText(ocrText: string): Promise<
  | { data: ReceiptExtraction }
  | { error: string }
> {
  const { supabase, user } = await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return {
      error: "Smart add isn’t set up yet. You can still add expenses manually.",
    };
  }

  const trimmed = ocrText.replace(/\r/g, "").trim();
  if (trimmed.length < 8) {
    return {
      error:
        "We couldn’t read enough from that photo. Try a clearer picture, or add it manually.",
    };
  }

  // Cap payload size so we don't blow token limits on noisy OCR
  const text = trimmed.length > 8000 ? trimmed.slice(0, 8000) : trimmed;

  const { data: categories } = await supabase
    .from("categories")
    .select("name")
    .eq("user_id", user.id)
    .eq("type", "expense");
  const categoryNames =
    (categories ?? []).map((c) => c.name).join(", ") ||
    "Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other";

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: receiptExtractionSchema,
        maxRetries: 0,
        prompt: `You are given plain text extracted from a purchase receipt by OCR (may contain typos or junk lines). Extract structured purchase fields. Amount must be the TOTAL paid (not tax-only or unit prices). Date must be YYYY-MM-DD; if unknown use ${localDateYYYYMMDD()}.
Pick category as ONE of these exact names when possible: ${categoryNames}.

OCR text:
"""
${text}
"""`,
      });
      return object;
    });

    const notes =
      result.notes?.trim() ||
      (text.length > 0
        ? `From receipt: ${text.slice(0, 240)}${text.length > 240 ? "…" : ""}`
        : "");

    return { data: { ...result, notes } };
  } catch (err) {
    return {
      error: formatAiError(err, "We couldn’t understand that receipt. Please try again."),
    };
  }
}

export async function parseBankSms(text: string): Promise<
  | { data: SmsExtraction }
  | { error: string }
> {
  await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return {
      error: "Smart add isn’t set up yet. You can still add expenses manually.",
    };
  }

  const trimmed = text.trim();
  if (!trimmed) return { error: "Paste a bank message first" };

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: smsExtractionSchema,
        maxRetries: 0,
        prompt: `Parse this bank SMS / alert into structured transaction fields. Credit = money received, Debit = money spent.\n\nMessage:\n${trimmed}`,
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return { error: formatAiError(err, "We couldn’t read that message. Please try again.") };
  }
}

export async function parseQuickText(text: string): Promise<
  | { data: QuickTextExtraction }
  | { error: string }
> {
  const { supabase, user } = await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return { error: "Smart add isn’t set up yet. You can still add expenses manually." };
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return { error: "Type something like “Coffee 450 at Starbucks”" };
  }

  const [{ data: expenseCats }, { data: incomeCats }] = await Promise.all([
    supabase
      .from("categories")
      .select("name")
      .eq("user_id", user.id)
      .eq("type", "expense"),
    supabase
      .from("categories")
      .select("name")
      .eq("user_id", user.id)
      .eq("type", "income"),
  ]);
  const expenseNames = (expenseCats ?? []).map((c) => c.name).join(", ");
  const incomeNames = (incomeCats ?? []).map((c) => c.name).join(", ");

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: quickTextExtractionSchema,
        maxRetries: 0,
        prompt: `Parse this short personal finance note into a single income or expense transaction. Prefer expense unless the text clearly means income (salary, refund, received, paid me, etc.). Date YYYY-MM-DD; if unknown use ${localDateYYYYMMDD()}.
For expense category use ONE of: ${expenseNames || "Groceries, Dining, Transport, Shopping, Utilities, Health, Entertainment, Rent, Other"}.
For income category use ONE of: ${incomeNames || "Salary, Freelance, Investments"}.

Note:
${trimmed}`,
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return { error: formatAiError(err, "We couldn’t understand that. Please try again.") };
  }
}

function revalidateMoneyPaths() {
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
}

/** Persist only after human review confirmation */
export async function saveReviewedTransaction(input: AiReviewSave) {
  const parsed = aiReviewSaveSchema.parse(input);
  const { supabase, user } = await requireUser();

  let categoryId = parsed.category_id ?? null;
  if (parsed.type === "expense" || parsed.type === "income") {
    const { data: categories } = await supabase
      .from("categories")
      .select("*")
      .eq("user_id", user.id)
      .eq("type", parsed.type);

    const resolved = matchCategoryId(
      categories ?? [],
      parsed.type,
      // Prefer existing id's category name if present
      categoryId
        ? (categories ?? []).find((c) => c.id === categoryId)?.name
        : null,
      parsed.merchant,
      parsed.notes
    );

    // Keep explicit selection when valid; otherwise use resolved match
    if (categoryId) {
      const stillValid = (categories ?? []).some((c) => c.id === categoryId);
      if (!stillValid) categoryId = resolved;
    } else {
      categoryId = resolved;
    }
  }

  const { error } = await supabase.from("transactions").insert({
    user_id: user.id,
    account_id: parsed.account_id,
    category_id: categoryId,
    amount: parsed.amount,
    type: parsed.type,
    date: parsed.date || localDateYYYYMMDD(),
    merchant: parsed.merchant,
    notes: parsed.notes,
    is_recurring: parsed.is_recurring,
    recurring_frequency: parsed.is_recurring
      ? parsed.recurring_frequency ?? "monthly"
      : null,
  });

  if (error) return { error: error.message };

  revalidateMoneyPaths();
  return { success: true, category_id: categoryId };
}
