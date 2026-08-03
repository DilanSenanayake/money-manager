import { AlertTriangle } from "lucide-react";
import type { BudgetProgress } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { Progress } from "@/components/ui/progress";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function BudgetBars({
  budgets,
  currency,
}: {
  budgets: BudgetProgress[];
  currency: string;
}) {
  if (budgets.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        Set monthly budgets on expense categories to track progress.
      </p>
    );
  }

  return (
    <div className="space-y-4">
      {budgets.map((b) => {
        const pct = Math.min(100, Math.round(b.ratio * 100));
        const indicator =
          b.status === "over"
            ? "bg-rose-600"
            : b.status === "warn"
              ? "bg-amber-500"
              : "bg-teal-600";

        return (
          <div key={b.category.id} className="space-y-2">
            <div className="flex items-center justify-between gap-2 text-sm">
              <span className="font-medium">{b.category.name}</span>
              <span className="text-slate-500">
                {formatMoney(b.spent, currency)} /{" "}
                {formatMoney(b.limit, currency)}
              </span>
            </div>
            <Progress value={pct} indicatorClassName={indicator} />
            {(b.status === "warn" || b.status === "over") && (
              <p
                className={`flex items-center gap-1.5 text-xs ${
                  b.status === "over" ? "text-rose-600" : "text-amber-600"
                }`}
              >
                <AlertTriangle className="h-3.5 w-3.5" />
                {b.status === "over"
                  ? "Budget exceeded (100%+)"
                  : "Approaching limit (80%+)"}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}

export function BudgetAlerts({ budgets }: { budgets: BudgetProgress[] }) {
  const alerts = budgets.filter(
    (b) => b.status === "warn" || b.status === "over"
  );
  if (alerts.length === 0) return null;

  return (
    <Card className="border-amber-200 bg-amber-50/80 dark:border-amber-900 dark:bg-amber-950/30">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base text-amber-800 dark:text-amber-200">
          <AlertTriangle className="h-4 w-4" />
          Budget alerts
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-1 text-sm text-amber-900 dark:text-amber-100">
        {alerts.map((b) => (
          <p key={b.category.id}>
            <strong>{b.category.name}</strong>:{" "}
            {b.status === "over" ? "over budget" : "at 80%+ of limit"} (
            {Math.round(b.ratio * 100)}%)
          </p>
        ))}
      </CardContent>
    </Card>
  );
}
