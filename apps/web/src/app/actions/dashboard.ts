"use server";

import { format, subMonths } from "date-fns";
import { requireUser } from "@/lib/supabase/auth";
import {
  accountCurrencyMap,
  computeNetWorth,
  txAmountInBase,
} from "@/lib/currency";
import {
  localMonthEndYYYYMMDD,
  localMonthStartYYYYMMDD,
} from "@/lib/dates";
import { budgetStatus } from "@/lib/utils";
import type { BudgetProgress } from "@/lib/types";

export async function getDashboardData() {
  const { supabase, user } = await requireUser();

  const [{ data: profile }, { data: accounts }, { data: categories }, { data: rates }] =
    await Promise.all([
      supabase.from("profiles").select("*").eq("id", user.id).single(),
      supabase.from("accounts").select("*").eq("user_id", user.id),
      supabase.from("categories").select("*").eq("user_id", user.id),
      supabase.from("exchange_rates").select("*").eq("user_id", user.id),
    ]);

  const monthStart = localMonthStartYYYYMMDD();
  const monthEnd = localMonthEndYYYYMMDD();

  const { data: monthTx } = await supabase
    .from("transactions")
    .select("*")
    .eq("user_id", user.id)
    .gte("date", monthStart)
    .lte("date", monthEnd);

  const { data: recent } = await supabase
    .from("transactions")
    .select("*, account:accounts(*), category:categories(*)")
    .eq("user_id", user.id)
    .order("date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(8);

  const baseCurrency = profile?.base_currency ?? "USD";
  const rateList = rates ?? [];
  const currencyByAccount = accountCurrencyMap(accounts ?? []);
  const netWorth = computeNetWorth(accounts ?? [], baseCurrency, rateList);

  const toBase = (t: { amount: number | string; account_id: string }) =>
    txAmountInBase(
      Number(t.amount),
      t.account_id,
      currencyByAccount,
      baseCurrency,
      rateList
    );

  const income = (monthTx ?? [])
    .filter((t) => t.type === "income")
    .reduce((s, t) => s + toBase(t), 0);
  const expense = (monthTx ?? [])
    .filter((t) => t.type === "expense")
    .reduce((s, t) => s + toBase(t), 0);

  const budgets: BudgetProgress[] = (categories ?? [])
    .filter(
      (c) =>
        c.type === "expense" &&
        c.monthly_budget != null &&
        Number(c.monthly_budget) > 0
    )
    .map((category) => {
      const spent = (monthTx ?? [])
        .filter(
          (t) =>
            t.type === "expense" &&
            t.category_id != null &&
            String(t.category_id) === String(category.id)
        )
        .reduce((s, t) => s + toBase(t), 0);
      const limit = Number(category.monthly_budget) || 0;
      const ratio = limit > 0 ? spent / limit : 0;
      return {
        category,
        spent,
        limit,
        ratio,
        status: budgetStatus(spent, limit),
      };
    })
    .sort((a, b) => b.ratio - a.ratio);

  return {
    profile,
    accounts: accounts ?? [],
    rates: rateList,
    netWorth,
    income,
    expense,
    budgets,
    recent: recent ?? [],
    baseCurrency,
    monthStart,
    monthEnd,
  };
}

export async function getAnalyticsData() {
  const { supabase, user } = await requireUser();

  const months = Array.from({ length: 6 }, (_, i) => {
    const d = subMonths(new Date(), 5 - i);
    return {
      key: format(d, "yyyy-MM"),
      label: format(d, "MMM"),
      from: localMonthStartYYYYMMDD(d),
      to: localMonthEndYYYYMMDD(d),
    };
  });

  const rangeFrom = months[0].from;
  const rangeTo = months[months.length - 1].to;

  const [{ data: tx }, { data: categories }, { data: accounts }, { data: profile }, { data: rates }] =
    await Promise.all([
      supabase
        .from("transactions")
        .select("*")
        .eq("user_id", user.id)
        .gte("date", rangeFrom)
        .lte("date", rangeTo),
      supabase
        .from("categories")
        .select("*")
        .eq("user_id", user.id)
        .eq("type", "expense"),
      supabase.from("accounts").select("id, currency").eq("user_id", user.id),
      supabase.from("profiles").select("base_currency").eq("id", user.id).single(),
      supabase.from("exchange_rates").select("*").eq("user_id", user.id),
    ]);

  const baseCurrency = profile?.base_currency ?? "USD";
  const rateList = rates ?? [];
  const currencyByAccount = accountCurrencyMap(accounts ?? []);
  const toBase = (t: { amount: number | string; account_id: string }) =>
    txAmountInBase(
      Number(t.amount),
      t.account_id,
      currencyByAccount,
      baseCurrency,
      rateList
    );

  const trend = months.map((m) => {
    const inMonth = (tx ?? []).filter(
      (t) => t.date >= m.from && t.date <= m.to
    );
    return {
      month: m.label,
      income: inMonth
        .filter((t) => t.type === "income")
        .reduce((s, t) => s + toBase(t), 0),
      expense: inMonth
        .filter((t) => t.type === "expense")
        .reduce((s, t) => s + toBase(t), 0),
    };
  });

  const thisMonth = months[months.length - 1];
  const categorySpend = (categories ?? [])
    .map((cat) => {
      const spent = (tx ?? [])
        .filter(
          (t) =>
            t.type === "expense" &&
            t.category_id != null &&
            String(t.category_id) === String(cat.id) &&
            t.date >= thisMonth.from &&
            t.date <= thisMonth.to
        )
        .reduce((s, t) => s + toBase(t), 0);
      return { name: cat.name, value: spent };
    })
    .filter((c) => c.value > 0)
    .sort((a, b) => b.value - a.value);

  return { trend, categorySpend, baseCurrency };
}

export async function getBudgetProgress() {
  const data = await getDashboardData();
  return data.budgets;
}
