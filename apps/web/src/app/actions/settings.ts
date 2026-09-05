"use server";

import { revalidatePath } from "next/cache";
import { apiMutate, apiRequest } from "@/lib/api/client";
import type { ActionResult } from "@/lib/api/result";
import {
  exchangeRateSchema,
  profileSchema,
  type ExchangeRateInput,
  type ProfileInput,
} from "@/lib/schemas";
import type { ExchangeRate, Profile } from "@/lib/types";

export async function getProfile() {
  return apiRequest<Profile>("/v1/settings/profile");
}

export async function updateProfile(input: ProfileInput): Promise<ActionResult> {
  const parsed = profileSchema.parse(input);
  const result = await apiMutate("/v1/settings/profile", {
    method: "PATCH",
    body: parsed,
  });
  if ("error" in result) return result;

  revalidatePath("/settings");
  revalidatePath("/dashboard");
  revalidatePath("/accounts");
  revalidatePath("/transactions");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
  return { success: true };
}

export async function getExchangeRates() {
  return apiRequest<ExchangeRate[]>("/v1/settings/exchange-rates");
}

export async function upsertExchangeRate(
  input: ExchangeRateInput
): Promise<ActionResult> {
  const parsed = exchangeRateSchema.parse(input);
  if (parsed.from_currency === parsed.to_currency) {
    return { error: "Currencies must be different" };
  }
  const result = await apiMutate("/v1/settings/exchange-rates", {
    method: "PUT",
    body: parsed,
  });
  if ("error" in result) return result;
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}

export async function deleteExchangeRate(id: string): Promise<ActionResult> {
  const result = await apiMutate(`/v1/settings/exchange-rates/${id}`, {
    method: "DELETE",
  });
  if ("error" in result) return result;
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}
