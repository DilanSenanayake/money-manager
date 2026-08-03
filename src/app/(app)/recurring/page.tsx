import { addDays, addMonths, addYears, format, parseISO } from "date-fns";
import { getRecurringTransactions } from "@/app/actions/transactions";
import { formatMoney } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function nextDueDate(date: string, frequency: string | null) {
  const base = parseISO(date);
  const today = new Date();
  let next = base;

  const advance = () => {
    if (frequency === "weekly") next = addDays(next, 7);
    else if (frequency === "yearly") next = addYears(next, 1);
    else next = addMonths(next, 1);
  };

  // Walk forward until upcoming (or today)
  let guard = 0;
  while (next < today && guard < 120) {
    advance();
    guard += 1;
  }
  return format(next, "yyyy-MM-dd");
}

export default async function RecurringPage() {
  const recurring = await getRecurringTransactions();

  // Deduplicate by merchant+amount+frequency (show latest occurrence)
  const unique = new Map<string, (typeof recurring)[number]>();
  for (const tx of recurring) {
    const key = `${tx.merchant}-${tx.amount}-${tx.recurring_frequency}-${tx.category_id}`;
    if (!unique.has(key)) unique.set(key, tx);
  }
  const items = Array.from(unique.values()).map((tx) => ({
    ...tx,
    nextDue: nextDueDate(tx.date, tx.recurring_frequency),
  }));

  items.sort((a, b) => a.nextDue.localeCompare(b.nextDue));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl tracking-tight">Recurring</h1>
        <p className="text-sm text-slate-500">
          Subscriptions and predicted upcoming bill dates
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Upcoming bills</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {items.map((tx) => (
            <div
              key={tx.id}
              className="flex items-center justify-between gap-3 rounded-xl border border-slate-200/80 px-3 py-3 dark:border-slate-800"
            >
              <div>
                <p className="font-medium">
                  {tx.merchant || tx.category?.name || "Recurring"}
                </p>
                <div className="mt-1 flex flex-wrap gap-2 text-xs text-slate-500">
                  <Badge className="capitalize">
                    {tx.recurring_frequency ?? "monthly"}
                  </Badge>
                  <span>Next due {tx.nextDue}</span>
                  {tx.account && <span>{tx.account.name}</span>}
                </div>
              </div>
              <p className="font-semibold text-rose-600">
                {formatMoney(
                  Number(tx.amount),
                  tx.account?.currency ?? "USD"
                )}
              </p>
            </div>
          ))}
          {items.length === 0 && (
            <p className="text-sm text-slate-500">
              Mark transactions as recurring to predict upcoming dues.
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
