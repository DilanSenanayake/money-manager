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
  return parseAi<ReceiptExtraction>("/v1/ai/parse-receipt", {
    ocr_text: ocrText,
  });
}

export async function parseBankSms(
  text: string
): Promise<{ data: SmsExtraction } | { error: string }> {
  return parseAi<SmsExtraction>("/v1/ai/parse-sms", { text });
}

export async function parseQuickText(
  text: string
): Promise<{ data: QuickTextExtraction } | { error: string }> {
  return parseAi<QuickTextExtraction>("/v1/ai/parse-text", { text });
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
