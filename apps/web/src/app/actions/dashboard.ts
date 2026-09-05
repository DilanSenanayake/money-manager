"use server";

import { apiRequest } from "@/lib/api/client";
import type {
  Account,
  BudgetProgress,
  ExchangeRate,
  Profile,
  Transaction,
} from "@/lib/types";

type DashboardResponse = {
  profile: Profile | null;
  accounts: Account[];
  rates: ExchangeRate[];
  netWorth: number;
  income: number;
  expense: number;
  budgets: BudgetProgress[];
  recent: Transaction[];
  baseCurrency: string;
  monthStart: string;
  monthEnd: string;
};

type AnalyticsResponse = {
  trend: { month: string; income: number; expense: number }[];
  categorySpend: { name: string; value: number }[];
  baseCurrency: string;
};

export async function getDashboardData() {
  return apiRequest<DashboardResponse>("/v1/dashboard");
}

export async function getAnalyticsData() {
  return apiRequest<AnalyticsResponse>("/v1/dashboard/analytics");
}

export async function getBudgetProgress() {
  return apiRequest<BudgetProgress[]>("/v1/dashboard/budgets");
}
