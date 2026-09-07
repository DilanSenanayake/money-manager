import dynamic from "next/dynamic";
import { getAnalyticsData } from "@/app/actions/dashboard";
import { PageHeader } from "@/components/layout/page-header";

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

export default async function AnalyticsPage() {
  const data = await getAnalyticsData();

  return (
    <div className="page-stack">
      <PageHeader
        title="Analytics"
        description="Trends and category spend in your base currency"
      />
      <AnalyticsCharts
        trend={data.trend}
        categorySpend={data.categorySpend}
        currency={data.baseCurrency}
      />
    </div>
  );
}
