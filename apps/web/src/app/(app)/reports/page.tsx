import Link from "next/link";
import { getAnalyticsData } from "@/app/actions/dashboard";
import { MonthlyReports } from "@/components/reports/monthly-reports";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";

export default async function ReportsPage() {
  const data = await getAnalyticsData();

  return (
    <div className="page-stack">
      <PageHeader
        title="Reports"
        description="Every month of income and spending, so you can see where money went"
        actions={
          <Button asChild variant="outline">
            <Link href="/analytics">Charts</Link>
          </Button>
        }
      />
      <MonthlyReports
        months={data.months ?? []}
        summary={
          data.summary ?? {
            monthCount: 0,
            averageExpense: 0,
            totalIncome: 0,
            totalExpense: 0,
            savingsRate: null,
            highestSpendMonth: null,
            highestSpend: 0,
          }
        }
        currency={data.baseCurrency}
      />
    </div>
  );
}
