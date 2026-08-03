"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { matchCategoryId } from "@/lib/category-match";
import {
  transactionFilterSchema,
  transactionSchema,
  type TransactionFilter,
  type TransactionInput,
} from "@/lib/schemas";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
}

export async function getTransactions(filters: TransactionFilter = {}) {
  const parsed = transactionFilterSchema.parse(filters);
  const { supabase, user } = await requireUser();

  let query = supabase
    .from("transactions")
    .select("*, account:accounts(*), category:categories(*)")
    .eq("user_id", user.id)
    .order("date", { ascending: false })
    .order("created_at", { ascending: false });

  if (parsed.account_id) query = query.eq("account_id", parsed.account_id);
  if (parsed.category_id) query = query.eq("category_id", parsed.category_id);
  if (parsed.type) query = query.eq("type", parsed.type);
  if (parsed.from) query = query.gte("date", parsed.from);
  if (parsed.to) query = query.lte("date", parsed.to);
  if (parsed.q) {
    const safe = parsed.q.replace(/[%_,]/g, "").trim();
    if (safe) {
      query = query.or(`merchant.ilike.%${safe}%,notes.ilike.%${safe}%`);
    }
  }

  const { data, error } = await query.limit(200);
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function createTransaction(input: TransactionInput) {
  const parsed = transactionSchema.parse(input);
  const { supabase, user } = await requireUser();

  if (parsed.type === "transfer") {
    if (!parsed.transfer_to_account_id) {
      return { error: "Choose where the money should go" };
    }
    if (parsed.transfer_to_account_id === parsed.account_id) {
      return { error: "Pick two different accounts for a transfer" };
    }

    const pairId = crypto.randomUUID();
    const base = {
      user_id: user.id,
      amount: parsed.amount,
      type: "transfer" as const,
      date: parsed.date,
      merchant: parsed.merchant ?? "Transfer",
      notes: parsed.notes,
      is_recurring: false,
      recurring_frequency: null,
      transfer_pair_id: pairId,
      category_id: null,
    };

    const { error } = await supabase.from("transactions").insert([
      {
        ...base,
        account_id: parsed.account_id,
        transfer_direction: "out",
      },
      {
        ...base,
        account_id: parsed.transfer_to_account_id,
        transfer_direction: "in",
      },
    ]);

    if (error) return { error: error.message };
  } else {
    let categoryId = parsed.category_id ?? null;
    if (!categoryId && (parsed.type === "expense" || parsed.type === "income")) {
      const { data: categories } = await supabase
        .from("categories")
        .select("*")
        .eq("user_id", user.id)
        .eq("type", parsed.type);
      categoryId = matchCategoryId(
        categories ?? [],
        parsed.type,
        parsed.merchant,
        parsed.notes
      );
    }

    const { error } = await supabase.from("transactions").insert({
      user_id: user.id,
      account_id: parsed.account_id,
      category_id: categoryId,
      amount: parsed.amount,
      type: parsed.type,
      date: parsed.date,
      merchant: parsed.merchant,
      notes: parsed.notes,
      is_recurring: parsed.is_recurring,
      recurring_frequency: parsed.is_recurring
        ? parsed.recurring_frequency ?? "monthly"
        : null,
    });
    if (error) return { error: error.message };
  }

  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
  return { success: true };
}

export async function updateTransaction(id: string, input: TransactionInput) {
  const parsed = transactionSchema.parse(input);
  if (parsed.type === "transfer") {
    return { error: "Edit transfers by deleting and recreating them" };
  }

  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("transactions")
    .update({
      account_id: parsed.account_id,
      category_id: parsed.category_id ?? null,
      amount: parsed.amount,
      type: parsed.type,
      date: parsed.date,
      merchant: parsed.merchant,
      notes: parsed.notes,
      is_recurring: parsed.is_recurring,
      recurring_frequency: parsed.is_recurring
        ? parsed.recurring_frequency ?? "monthly"
        : null,
    })
    .eq("id", id)
    .eq("user_id", user.id);

  if (error) return { error: error.message };
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
  return { success: true };
}

export async function deleteTransaction(id: string) {
  const { supabase, user } = await requireUser();

  const { data: existing } = await supabase
    .from("transactions")
    .select("id, transfer_pair_id")
    .eq("id", id)
    .eq("user_id", user.id)
    .single();

  if (!existing) return { error: "Transaction not found" };

  if (existing.transfer_pair_id) {
    const { error } = await supabase
      .from("transactions")
      .delete()
      .eq("transfer_pair_id", existing.transfer_pair_id)
      .eq("user_id", user.id);
    if (error) return { error: error.message };
  } else {
    const { error } = await supabase
      .from("transactions")
      .delete()
      .eq("id", id)
      .eq("user_id", user.id);
    if (error) return { error: error.message };
  }

  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  revalidatePath("/budgets");
  revalidatePath("/analytics");
  revalidatePath("/add");
  revalidatePath("/recurring");
  revalidatePath("/", "layout");
  return { success: true };
}

export async function getRecurringTransactions() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("transactions")
    .select("*, account:accounts(*), category:categories(*)")
    .eq("user_id", user.id)
    .eq("is_recurring", true)
    .order("date", { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}
