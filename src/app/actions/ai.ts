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
import { createClient } from "@/lib/supabase/server";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
}

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
  await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return { error: "GOOGLE_GENERATIVE_AI_API_KEY is not configured" };
  }

  const trimmed = ocrText.replace(/\r/g, "").trim();
  if (trimmed.length < 8) {
    return {
      error:
        "OCR text is too short. Try a clearer receipt photo, or add the expense manually.",
    };
  }

  // Cap payload size so we don't blow token limits on noisy OCR
  const text = trimmed.length > 8000 ? trimmed.slice(0, 8000) : trimmed;

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: receiptExtractionSchema,
        maxRetries: 0,
        prompt: `You are given plain text extracted from a purchase receipt by OCR (may contain typos or junk lines). Extract structured purchase fields. Amount must be the TOTAL paid (not tax-only or unit prices). Date must be YYYY-MM-DD; use today's date if unknown. Prefer a sensible expense category.

OCR text:
"""
${text}
"""`,
      });
      return object;
    });

    const notes =
      result.notes?.trim() ||
      `OCR: ${text.slice(0, 240)}${text.length > 240 ? "…" : ""}`;

    return { data: { ...result, notes } };
  } catch (err) {
    return { error: formatAiError(err, "Failed to parse receipt text") };
  }
}

export async function parseBankSms(text: string): Promise<
  | { data: SmsExtraction }
  | { error: string }
> {
  await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return { error: "GOOGLE_GENERATIVE_AI_API_KEY is not configured" };
  }

  const trimmed = text.trim();
  if (!trimmed) return { error: "Clipboard text is empty" };

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
    return { error: formatAiError(err, "Failed to parse SMS") };
  }
}

export async function parseQuickText(text: string): Promise<
  | { data: QuickTextExtraction }
  | { error: string }
> {
  await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return { error: "GOOGLE_GENERATIVE_AI_API_KEY is not configured" };
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return { error: "Type something like “Coffee 450 at Starbucks”" };
  }

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: quickTextExtractionSchema,
        maxRetries: 0,
        prompt: `Parse this short personal finance note into a single income or expense transaction. Prefer expense unless the text clearly means income (salary, refund, received, paid me, etc.). Date YYYY-MM-DD; use today if unknown.\n\nNote:\n${trimmed}`,
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return { error: formatAiError(err, "Failed to parse text") };
  }
}

function revalidateMoneyPaths() {
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
}

/** Persist only after human review confirmation */
export async function saveReviewedTransaction(input: AiReviewSave) {
  const parsed = aiReviewSaveSchema.parse(input);
  const { supabase, user } = await requireUser();

  const { error } = await supabase.from("transactions").insert({
    user_id: user.id,
    account_id: parsed.account_id,
    category_id: parsed.category_id ?? null,
    amount: parsed.amount,
    type: parsed.type,
    date: parsed.date,
    merchant: parsed.merchant,
    notes: parsed.notes,
    is_recurring: parsed.is_recurring,
    recurring_frequency: parsed.is_recurring
      ? parsed.recurring_frequency ?? "monthly"
      : null,
  });

  if (error) return { error: error.message };

  revalidateMoneyPaths();
  return { success: true };
}
