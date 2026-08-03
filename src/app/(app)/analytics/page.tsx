import { getAnalyticsData } from "@/app/actions/dashboard";
import { AnalyticsCharts } from "@/components/analytics/analytics-charts";

export default async function AnalyticsPage() {
  const { trend, categorySpend } = await getAnalyticsData();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl tracking-tight">Analytics</h1>
        <p className="text-sm text-slate-500">
          Category breakdown and income vs expense trends
        </p>
      </div>
      <AnalyticsCharts trend={trend} categorySpend={categorySpend} />
    </div>
  );
}
