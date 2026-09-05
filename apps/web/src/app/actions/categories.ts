"use server";

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/supabase/auth";
import { categorySchema, type CategoryInput } from "@/lib/schemas";

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
  revalidatePath("/dashboard");
  revalidatePath("/add");
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
  revalidatePath("/add");
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
  revalidatePath("/dashboard");
  return { success: true };
}
