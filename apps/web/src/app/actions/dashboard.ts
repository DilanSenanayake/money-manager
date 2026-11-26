"use server";

import { apiRequest } from "@/lib/api/client";
import type {
  Account,
  BudgetProgress,
  CategorySpendPoint,
  ExchangeRate,
  FrequentRecord,
  MonthlyReport,
  Profile,
  SpendingReportSummary,
  Transaction,
} from "@/lib/types";

type DashboardResponse = {
  profile: Profile | null;
  accounts: Account[];
  rates: ExchangeRate[];
  netWorth: number | null;
  income: number | null;
  expense: number | null;
  missingRateCurrencies?: string[];
  budgets: BudgetProgress[];
  recent: Transaction[];
  frequent?: FrequentRecord[];
  baseCurrency: string;
  monthStart: string;
  monthEnd: string;
};

type AnalyticsResponse = {
  trend: { month: string; income: number; expense: number }[];
  categorySpend: CategorySpendPoint[];
  months: MonthlyReport[];
  summary: SpendingReportSummary;
  baseCurrency: string;
  missingRateCurrencies?: string[];
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
