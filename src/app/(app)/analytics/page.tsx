import { getAnalyticsData } from "@/app/actions/dashboard";
import { AnalyticsCharts } from "@/components/analytics/analytics-charts";
import { PageHeader } from "@/components/layout/page-header";

export default async function AnalyticsPage() {
  const { trend, categorySpend, baseCurrency } = await getAnalyticsData();

  return (
    <div className="page-stack">
      <PageHeader
        title="Analytics"
        description="Category breakdown and income vs expense trends"
      />
      <AnalyticsCharts
        trend={trend}
        categorySpend={categorySpend}
        currency={baseCurrency}
      />
    </div>
  );
}
