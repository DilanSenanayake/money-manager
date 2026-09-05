"use server";

import { revalidatePath } from "next/cache";
import { apiMutate, apiRequest } from "@/lib/api/client";
import type { ActionResult } from "@/lib/api/result";
import { categorySchema, type CategoryInput } from "@/lib/schemas";
import type { Category } from "@/lib/types";

export async function getCategories() {
  return apiRequest<Category[]>("/v1/categories");
}

export async function createCategory(
  input: CategoryInput
): Promise<ActionResult> {
  const parsed = categorySchema.parse(input);
  const result = await apiMutate("/v1/categories", {
    method: "POST",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidatePath("/budgets");
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  return { success: true };
}

export async function updateCategory(
  id: string,
  input: CategoryInput
): Promise<ActionResult> {
  const parsed = categorySchema.parse(input);
  const result = await apiMutate(`/v1/categories/${id}`, {
    method: "PATCH",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidatePath("/budgets");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  return { success: true };
}

export async function deleteCategory(id: string): Promise<ActionResult> {
  const result = await apiMutate(`/v1/categories/${id}`, { method: "DELETE" });
  if ("error" in result) return result;
  revalidatePath("/budgets");
  revalidatePath("/dashboard");
  return { success: true };
}
