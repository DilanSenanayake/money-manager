import Link from "next/link";
import { getAnalyticsData } from "@/app/actions/dashboard";
import { AnalyticsChartsLazy } from "@/components/analytics/analytics-charts-lazy";
import { RateGap } from "@/components/money/rate-notice";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";

export default async function AnalyticsPage() {
  const data = await getAnalyticsData();

  return (
    <div className="page-stack">
      <PageHeader
        title="Analytics"
        description="Trends and category spend in your base currency"
        actions={
          <Button asChild variant="outline">
            <Link href="/reports">Monthly reports</Link>
          </Button>
        }
      />
      <RateGap currencies={data.missingRateCurrencies ?? []} />
      {(data.missingRateCurrencies ?? []).length === 0 && (
      <AnalyticsChartsLazy
        trend={data.trend}
        categorySpend={data.categorySpend}
        currency={data.baseCurrency}
      />
      )}
    </div>
  );
}
