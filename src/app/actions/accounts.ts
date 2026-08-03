"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { accountSchema, type AccountInput } from "@/lib/schemas";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
}

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
  return { success: true };
}

export async function updateAccount(id: string, input: AccountInput) {
  const parsed = accountSchema.parse(input);
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("accounts")
    .update(parsed)
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
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
