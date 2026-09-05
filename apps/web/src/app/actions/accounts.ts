"use server";

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/supabase/auth";
import { accountSchema, type AccountInput } from "@/lib/schemas";

export async function getAccounts() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("accounts")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function createAccount(input: AccountInput) {
  const parsed = accountSchema.parse(input);
  const { supabase, user } = await requireUser();
  const { error } = await supabase.from("accounts").insert({
    ...parsed,
    user_id: user.id,
  });
  if (error) return { error: error.message };
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  revalidatePath("/transactions");
  return { success: true };
}

export async function updateAccount(id: string, input: AccountInput) {
  const parsed = accountSchema.parse(input);
  const { supabase, user } = await requireUser();

  const { data: existing } = await supabase
    .from("accounts")
    .select("id, currency, balance")
    .eq("id", id)
    .eq("user_id", user.id)
    .single();

  if (!existing) return { error: "Account not found" };
  if (
    existing.currency !== parsed.currency &&
    Number(existing.balance) !== 0
  ) {
    return {
      error:
        "Change currency only when the balance is zero, or transfer funds out first",
    };
  }

  // Never overwrite live balance on edit — triggers keep it in sync with transactions
  const { error } = await supabase
    .from("accounts")
    .update({
      name: parsed.name,
      type: parsed.type,
      currency: parsed.currency,
    })
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  revalidatePath("/add");
  return { success: true };
}

export async function deleteAccount(id: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("accounts")
    .delete()
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
  return { success: true };
}
