"use client";

import { useState } from "react";
import Link from "next/link";
import { BarChart3 } from "lucide-react";
import type { MonthlyReport, SpendingReportSummary } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { cn } from "@/lib/utils";
import { StatCard } from "@/components/ui/stat-card";
import { EmptyState } from "@/components/ui/empty-state";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function formatPercent(value: number | null, signed = false) {
  if (value == null) return "—";
  const text = `${Math.abs(value).toFixed(1)}%`;
  if (value < 0) return `-${text}`;
  if (signed && value > 0) return `+${text}`;
  if (value === 0) return "0%";
  return text;
}

function changeHint(value: number | null) {
  if (value == null) return "No earlier month to compare";
  if (value > 0) return `${formatPercent(value, true)} more than the month before`;
  if (value < 0) return `${formatPercent(value, true)} less than the month before`;
  return "Same spend as the month before";
}

export function MonthlyReports({
  months,
  summary,
  currency,
}: {
  months: MonthlyReport[];
  summary: SpendingReportSummary;
  currency: string;
}) {
  const [selectedKey, setSelectedKey] = useState(months[0]?.key ?? "");
  const selected = months.find((month) => month.key === selectedKey) ?? months[0];
  const money = (value: number) => formatMoney(value, currency);

  if (!selected || summary.monthCount === 0) {
    return (
      <EmptyState
        icon={BarChart3}
        title="No spending history yet"
        description="Add income and expenses and each month will show up here, including older activity."
        action={
          <Button asChild>
            <Link href="/add">Add a transaction</Link>
          </Button>
        }
      />
    );
  }

  const maxCategory = selected.categories[0]?.value ?? 0;

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Average monthly spend"
          value={money(summary.averageExpense)}
          hint={`Across ${summary.monthCount} month${summary.monthCount === 1 ? "" : "s"}`}
        />
        <StatCard
          label="Total spent"
          value={money(summary.totalExpense)}
          tone="negative"
          hint="Income and transfers are kept separate"
        />
        <StatCard
          label="Total income"
          value={money(summary.totalIncome)}
          tone="positive"
        />
        <StatCard
          label="Savings rate"
          value={formatPercent(summary.savingsRate)}
          hint={
            summary.highestSpendMonth
              ? `Highest spend: ${summary.highestSpendMonth} (${money(summary.highestSpend)})`
              : undefined
          }
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Every month</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {months.map((month) => {
            const active = month.key === selected.key;
            return (
              <button
                key={month.key}
                type="button"
                aria-pressed={active}
                onClick={() => setSelectedKey(month.key)}
                className={cn(
                  "grid w-full grid-cols-2 gap-x-3 gap-y-1 rounded-[10px] border px-3 py-3 text-left transition-colors sm:grid-cols-5 sm:items-center",
                  active
                    ? "border-[var(--accent)] bg-[var(--accent-soft)]"
                    : "border-[var(--border)] hover:bg-[var(--background)]"
                )}
              >
                <span className="text-sm font-semibold">{month.label}</span>
                <span className="text-sm tabular-nums text-[var(--danger)]">
                  <span className="mr-1 text-xs text-[var(--muted)]">Spent</span>
                  {money(month.expense)}
                </span>
                <span className="text-sm tabular-nums text-[var(--success)]">
                  <span className="mr-1 text-xs text-[var(--muted)]">Income</span>
                  {money(month.income)}
                </span>
                <span className="text-sm tabular-nums">
                  <span className="mr-1 text-xs text-[var(--muted)]">Left</span>
                  {money(month.net)}
                </span>
                <span className="text-xs text-[var(--muted)] sm:text-right">
                  {month.transactionCount} txn
                  {month.expenseChange == null
                    ? ""
                    : ` · ${formatPercent(month.expenseChange, true)}`}
                </span>
              </button>
            );
          })}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              {selected.label} by category
            </CardTitle>
            <p className="text-xs text-[var(--muted)]">
              {changeHint(selected.expenseChange)}
            </p>
          </CardHeader>
          <CardContent className="space-y-3">
            {selected.categories.length === 0 ? (
              <p className="text-sm text-[var(--muted)]">
                No expenses recorded this month.
              </p>
            ) : (
              selected.categories.map((category) => {
                const width =
                  maxCategory > 0
                    ? Math.max(4, (category.value / maxCategory) * 100)
                    : 0;
                return (
                  <div key={category.name} className="space-y-1">
                    <div className="flex items-baseline justify-between gap-3 text-sm">
                      <span className="font-medium">{category.name}</span>
                      <span className="tabular-nums">{money(category.value)}</span>
                    </div>
                    <div className="h-2 overflow-hidden rounded-full bg-[var(--background)]">
                      <div
                        className="h-full rounded-full bg-[var(--accent)]"
                        style={{ width: `${width}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Where it went</CardTitle>
            <p className="text-xs text-[var(--muted)]">
              {selected.savingsRate == null
                ? "No income recorded this month"
                : selected.savingsRate < 0
                  ? `Overspent by ${formatPercent(Math.abs(selected.savingsRate))} of income`
                  : `Kept ${formatPercent(selected.savingsRate)} of income`}
            </p>
          </CardHeader>
          <CardContent>
            {selected.merchants.length === 0 ? (
              <p className="text-sm text-[var(--muted)]">
                Expenses this month have no payee names yet.
              </p>
            ) : (
              <ul className="divide-y divide-[var(--border)]">
                {selected.merchants.map((merchant) => (
                  <li
                    key={merchant.name}
                    className="flex items-center justify-between gap-3 py-2.5 text-sm"
                  >
                    <span>
                      <span className="font-medium">{merchant.name}</span>
                      <span className="ml-2 text-xs text-[var(--muted)]">
                        {merchant.count} {merchant.count === 1 ? "time" : "times"}
                      </span>
                    </span>
                    <span className="tabular-nums">{money(merchant.value)}</span>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
