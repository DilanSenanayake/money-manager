"use server";

import { revalidatePath } from "next/cache";
import { apiRequest } from "@/lib/api/client";
import {
  aiReviewSaveSchema,
  type AiReviewSave,
  type QuickTextExtraction,
  type ReceiptExtraction,
  type SmsExtraction,
} from "@/lib/schemas";

type DataEnvelope<T> = { data: T };
type ErrorBody = { error: string };

function revalidateMoneyPaths() {
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
}

async function parseAi<T>(
  path: string,
  body: unknown
): Promise<{ data: T } | { error: string }> {
  try {
    const res = await apiRequest<DataEnvelope<T> | ErrorBody>(path, {
      method: "POST",
      body,
    });
    if (res && typeof res === "object" && "error" in res && !("data" in res)) {
      return { error: (res as ErrorBody).error };
    }
    const data = (res as DataEnvelope<T>).data;
    if (data === undefined || data === null) {
      return { error: "Smart add returned an empty result. Please try again." };
    }
    return { data };
  } catch (err) {
    const message =
      err instanceof Error ? err.message : "Request failed";
    // Never surface raw Next.js / transport payloads in the UI
    if (message.includes(":N") || message.includes('{"a":')) {
      return { error: "Smart add failed. Please try again." };
    }
    return { error: message };
  }
}

export async function parseReceiptText(
  ocrText: string
): Promise<{ data: ReceiptExtraction } | { error: string }> {
  const text = String(ocrText ?? "");
  if (text.trim().length < 8) {
    return {
      error:
        "We couldn't read enough from that photo. Try a clearer picture, or add it manually.",
    };
  }
  return parseAi<ReceiptExtraction>("/v1/ai/parse-receipt", {
    ocr_text: text.slice(0, 8000),
  });
}

export async function parseBankSms(
  text: string
): Promise<{ data: SmsExtraction } | { error: string }> {
  const value = String(text ?? "").trim();
  if (!value) return { error: "Paste a bank message first" };
  if (value.length > 4000) {
    return { error: "That message is too long. Paste a single bank alert." };
  }
  return parseAi<SmsExtraction>("/v1/ai/parse-sms", { text: value });
}

export async function parseQuickText(
  text: string
): Promise<{ data: QuickTextExtraction } | { error: string }> {
  const value = String(text ?? "").trim();
  if (!value) {
    return { error: 'Type something like "Coffee 450 at Starbucks"' };
  }
  if (value.length > 2000) {
    return { error: "That note is too long. Keep it to one short sentence." };
  }
  return parseAi<QuickTextExtraction>("/v1/ai/parse-text", { text: value });
}

/** Persist only after human review confirmation */
export async function saveReviewedTransaction(input: AiReviewSave) {
  const parsed = aiReviewSaveSchema.parse(input);
  try {
    const res = await apiRequest<{ success: true; category_id: string | null }>(
      "/v1/ai/save-reviewed",
      { method: "POST", body: parsed }
    );
    revalidateMoneyPaths();
    return {
      success: true as const,
      category_id: res.category_id ?? null,
    };
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : "Request failed",
    };
  }
}
