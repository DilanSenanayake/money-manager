"use server";

import { generateObject } from "ai";
import { revalidatePath } from "next/cache";
import { getFlashModel, getFlashModelFallback } from "@/lib/ai";
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

async function generateWithFallback<T>(
  run: (model: ReturnType<typeof getFlashModel>) => Promise<T>
): Promise<T> {
  try {
    return await run(getFlashModel("gemini-2.5-flash"));
  } catch {
    return await run(getFlashModelFallback());
  }
}

export async function parseReceiptImage(formData: FormData): Promise<
  | { data: ReceiptExtraction }
  | { error: string }
> {
  await requireUser();

  if (!process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
    return { error: "GOOGLE_GENERATIVE_AI_API_KEY is not configured" };
  }

  const file = formData.get("image");
  if (!(file instanceof File) || file.size === 0) {
    return { error: "Please upload a receipt image" };
  }

  const bytes = await file.arrayBuffer();
  const mediaType = file.type || "image/jpeg";

  try {
    const result = await generateWithFallback(async (model) => {
      const { object } = await generateObject({
        model,
        schema: receiptExtractionSchema,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: "Extract structured purchase data from this receipt image. Use ISO currency codes. Date must be YYYY-MM-DD.",
              },
              {
                type: "image",
                image: new Uint8Array(bytes),
                mediaType,
              },
            ],
          },
        ],
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return {
      error:
        err instanceof Error ? err.message : "Failed to parse receipt image",
    };
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
        prompt: `Parse this bank SMS / alert into structured transaction fields. Credit = money received, Debit = money spent.\n\nMessage:\n${trimmed}`,
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : "Failed to parse SMS",
    };
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
        prompt: `Parse this short personal finance note into a single income or expense transaction. Prefer expense unless the text clearly means income (salary, refund, received, paid me, etc.). Date YYYY-MM-DD; use today if unknown.\n\nNote:\n${trimmed}`,
      });
      return object;
    });

    return { data: result };
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : "Failed to parse text",
    };
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
