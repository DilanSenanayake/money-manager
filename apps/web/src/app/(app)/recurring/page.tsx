import { addDays, addMonths, addYears, format, parseISO } from "date-fns";
import { getRecurringTransactions } from "@/app/actions/transactions";
import { getProfile } from "@/app/actions/settings";
import { localDateYYYYMMDD } from "@/lib/dates";
import { transactionTitle } from "@/lib/transaction-description";
import { formatMoney } from "@/lib/utils";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Repeat } from "lucide-react";

function nextDueDate(date: string, frequency: string | null) {
  const base = parseISO(date);
  const today = localDateYYYYMMDD();
  let next = base;

  const advance = () => {
    if (frequency === "weekly") next = addDays(next, 7);
    else if (frequency === "yearly") next = addYears(next, 1);
    else next = addMonths(next, 1);
  };

  let guard = 0;
  while (localDateYYYYMMDD(next) < today && guard < 120) {
    advance();
    guard += 1;
  }
  return format(next, "yyyy-MM-dd");
}

export default async function RecurringPage() {
  const [recurring, profile] = await Promise.all([
    getRecurringTransactions(),
    getProfile(),
  ]);
  const baseCurrency = profile.base_currency ?? "USD";

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
    <div className="page-stack">
      <PageHeader
        title="Recurring"
        description="Subscriptions and predicted upcoming bill dates"
      />

      <Card>
        <CardHeader>
          <CardTitle>Upcoming bills</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1">
          {items.map((tx) => (
            <div
              key={tx.id}
              className="flex items-center justify-between gap-3 rounded-xl px-2 py-3 transition-colors hover:bg-[var(--background)]"
            >
              <div className="min-w-0">
                <p className="truncate font-medium">
                  {transactionTitle(tx)}
                </p>
                <div className="mt-1.5 flex flex-wrap gap-2 text-xs text-[var(--muted)]">
                  <Badge variant="accent" className="capitalize">
                    {tx.recurring_frequency ?? "monthly"}
                  </Badge>
                  <span>Next due {tx.nextDue}</span>
                  {tx.account && <span>{tx.account.name}</span>}
                </div>
              </div>
              <p className="shrink-0 font-semibold tabular-nums text-[var(--danger)]">
                {formatMoney(
                  Number(tx.amount),
                  tx.account?.currency ?? baseCurrency
                )}
              </p>
            </div>
          ))}
          {items.length === 0 && (
            <EmptyState
              icon={Repeat}
              title="No recurring items yet"
              description="Mark a transaction as recurring to predict upcoming dues."
              className="border-0 bg-transparent py-8 shadow-none"
            />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
