import { AlertTriangle } from "lucide-react";
import type { BudgetProgress } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { CategoryIcon } from "@/components/categories/category-icon";
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
      <p className="text-sm text-[var(--muted)]">
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
            ? "bg-[var(--danger)]"
            : b.status === "warn"
              ? "bg-[var(--warn)]"
              : "bg-[var(--accent)]";

        return (
          <div key={b.category.id} className="space-y-2">
            <div className="flex items-center justify-between gap-2 text-sm">
              <span className="flex min-w-0 items-center gap-2 font-medium">
                <CategoryIcon icon={b.category.icon} name={b.category.name} framed />
                <span className="truncate">{b.category.name}</span>
              </span>
              <span className="shrink-0 tabular-nums text-[var(--muted)]">
                {formatMoney(b.spent, currency)} /{" "}
                {formatMoney(b.limit, currency)}
              </span>
            </div>
            <Progress value={pct} indicatorClassName={indicator} />
            {(b.status === "warn" || b.status === "over") && (
              <p
                className={`flex items-center gap-1.5 text-xs ${
                  b.status === "over"
                    ? "text-[var(--danger)]"
                    : "text-[var(--warn)]"
                }`}
              >
                <AlertTriangle className="h-3.5 w-3.5" />
                {b.status === "over"
                  ? "Over budget"
                  : "Nearing limit (80%+)"}
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
    <Card className="border-[color-mix(in_oklab,var(--warn)_35%,var(--border))] bg-[var(--warn-soft)]">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-[var(--warn)]">
          <AlertTriangle className="h-4 w-4" />
          Budget alerts
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-1 text-sm text-[var(--foreground)]">
        {alerts.map((b) => (
          <p key={b.category.id} className="flex items-center gap-2">
            <CategoryIcon
              icon={b.category.icon}
              name={b.category.name}
            />
            <span>
              <strong>{b.category.name}</strong>:{" "}
              {b.status === "over" ? "over budget" : "at 80%+ of limit"} (
              {Math.round(b.ratio * 100)}%)
            </span>
          </p>
        ))}
      </CardContent>
    </Card>
  );
}
