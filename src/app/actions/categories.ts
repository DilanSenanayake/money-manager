"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { categorySchema, type CategoryInput } from "@/lib/schemas";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
}

export async function getCategories() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("categories")
    .select("*")
    .eq("user_id", user.id)
    .order("type")
    .order("name");
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function createCategory(input: CategoryInput) {
  const parsed = categorySchema.parse(input);
  const { supabase, user } = await requireUser();
  const { error } = await supabase.from("categories").insert({
    ...parsed,
    user_id: user.id,
  });
  if (error) return { error: error.message };
  revalidatePath("/budgets");
  revalidatePath("/transactions");
  return { success: true };
}

export async function updateCategory(id: string, input: CategoryInput) {
  const parsed = categorySchema.parse(input);
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("categories")
    .update(parsed)
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/budgets");
  revalidatePath("/dashboard");
  return { success: true };
}

export async function deleteCategory(id: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("categories")
    .delete()
    .eq("id", id)
    .eq("user_id", user.id);
  if (error) return { error: error.message };
  revalidatePath("/budgets");
  return { success: true };
}
