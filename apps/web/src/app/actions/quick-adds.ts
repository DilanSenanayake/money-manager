"use server";

import { revalidatePath } from "next/cache";
import { ZodError } from "zod";
import { apiMutate } from "@/lib/api/client";
import type { ActionResult } from "@/lib/api/result";
import { quickAddSchema, type QuickAddInput } from "@/lib/schemas";

export async function createQuickAdd(
  input: QuickAddInput
): Promise<ActionResult> {
  try {
    const parsed = quickAddSchema.parse(input);
    const result = await apiMutate("/v1/quick-adds", {
      method: "POST",
      body: parsed,
    });
    if ("error" in result) return result;
    revalidatePath("/dashboard");
    return { success: true };
  } catch (error) {
    if (error instanceof ZodError) {
      return {
        error: error.issues[0]?.message ?? "Check the shortcut and try again.",
      };
    }
    return { error: "Something went wrong. Please try again." };
  }
}

export async function deleteQuickAdd(id: string): Promise<ActionResult> {
  const result = await apiMutate(`/v1/quick-adds/${id}`, { method: "DELETE" });
  if ("error" in result) return result;
  revalidatePath("/dashboard");
  return { success: true };
}
