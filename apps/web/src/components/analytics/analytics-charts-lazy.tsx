"use client";

import dynamic from "next/dynamic";

const AnalyticsCharts = dynamic(
  () =>
    import("@/components/analytics/analytics-charts").then(
      (m) => m.AnalyticsCharts
    ),
  {
    loading: () => (
      <div className="grid gap-4 lg:grid-cols-2">
        <div className="h-72 animate-pulse rounded-xl bg-[var(--surface)] lg:col-span-2" />
        <div className="h-72 animate-pulse rounded-xl bg-[var(--surface)]" />
        <div className="h-72 animate-pulse rounded-xl bg-[var(--surface)]" />
      </div>
    ),
    ssr: false,
  }
);

export function AnalyticsChartsLazy({
  trend,
  categorySpend,
  currency,
}: {
  trend: { month: string; income: number; expense: number }[];
  categorySpend: { name: string; value: number }[];
  currency: string;
}) {
  return (
    <AnalyticsCharts
      trend={trend}
      categorySpend={categorySpend}
      currency={currency}
    />
  );
}
