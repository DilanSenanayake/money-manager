"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import {
  exchangeRateSchema,
  profileSchema,
  type ExchangeRateInput,
  type ProfileInput,
} from "@/lib/schemas";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
}

export async function getProfile() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateProfile(input: ProfileInput) {
  const parsed = profileSchema.parse(input);
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("profiles")
    .update(parsed)
    .eq("id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}

export async function getExchangeRates() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("exchange_rates")
    .select("*")
    .eq("user_id", user.id)
    .order("updated_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function upsertExchangeRate(input: ExchangeRateInput) {
  const parsed = exchangeRateSchema.parse(input);
  if (parsed.from_currency === parsed.to_currency) {
    return { error: "Currencies must be different" };
  }
  const { supabase, user } = await requireUser();
  const { error } = await supabase.from("exchange_rates").upsert(
    {
      user_id: user.id,
      ...parsed,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id,from_currency,to_currency" }
  );
  if (error) return { error: error.message };
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}

export async function deleteExchangeRate(id: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("exchange_rates")
    .delete()
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/settings");
  revalidatePath("/dashboard");
  return { success: true };
}
