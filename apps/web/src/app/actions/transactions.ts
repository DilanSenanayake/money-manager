"use server";

import { revalidatePath } from "next/cache";
import { apiMutate, apiRequest } from "@/lib/api/client";
import type { ActionResult } from "@/lib/api/result";
import {
  transactionFilterSchema,
  transactionSchema,
  type TransactionFilter,
  type TransactionInput,
} from "@/lib/schemas";
import type { Transaction } from "@/lib/types";

function revalidateMoneyPaths() {
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
}

export async function getTransactions(filters: TransactionFilter = {}) {
  const parsed = transactionFilterSchema.parse(filters);
  return apiRequest<Transaction[]>("/v1/transactions", {
    query: {
      q: parsed.q,
      account_id: parsed.account_id,
      category_id: parsed.category_id,
      type: parsed.type,
      from: parsed.from,
      to: parsed.to,
    },
  });
}

export async function createTransaction(
  input: TransactionInput
): Promise<ActionResult> {
  const parsed = transactionSchema.parse(input);
  const result = await apiMutate("/v1/transactions", {
    method: "POST",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidateMoneyPaths();
  return { success: true };
}

export async function updateTransaction(
  id: string,
  input: TransactionInput
): Promise<ActionResult> {
  const parsed = transactionSchema.parse(input);
  if (parsed.type === "transfer") {
    return { error: "Edit transfers by deleting and recreating them" };
  }

  const result = await apiMutate(`/v1/transactions/${id}`, {
    method: "PATCH",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidateMoneyPaths();
  return { success: true };
}

export async function deleteTransaction(id: string): Promise<ActionResult> {
  const result = await apiMutate(`/v1/transactions/${id}`, {
    method: "DELETE",
  });
  if ("error" in result) return result;
  revalidateMoneyPaths();
  return { success: true };
}

export async function getRecurringTransactions() {
  return apiRequest<Transaction[]>("/v1/transactions/recurring");
}
