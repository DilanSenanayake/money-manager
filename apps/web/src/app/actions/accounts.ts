"use server";

import { revalidatePath } from "next/cache";
import { apiMutate, apiRequest } from "@/lib/api/client";
import type { ActionResult } from "@/lib/api/result";
import { accountSchema, type AccountInput } from "@/lib/schemas";
import type { Account } from "@/lib/types";

export async function getAccounts() {
  return apiRequest<Account[]>("/v1/accounts");
}

export async function createAccount(input: AccountInput): Promise<ActionResult> {
  const parsed = accountSchema.parse(input);
  const result = await apiMutate("/v1/accounts", {
    method: "POST",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  revalidatePath("/transactions");
  return { success: true };
}

export async function updateAccount(
  id: string,
  input: AccountInput
): Promise<ActionResult> {
  const parsed = accountSchema.parse(input);
  const result = await apiMutate(`/v1/accounts/${id}`, {
    method: "PATCH",
    body: {
      name: parsed.name,
      type: parsed.type,
      currency: parsed.currency,
    },
  });
  if ("error" in result) return result;
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  return { success: true };
}

export async function deleteAccount(id: string): Promise<ActionResult> {
  const result = await apiMutate(`/v1/accounts/${id}`, { method: "DELETE" });
  if ("error" in result) return result;
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  return { success: true };
}
