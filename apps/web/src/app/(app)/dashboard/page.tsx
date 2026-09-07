import Link from "next/link";
import { Camera, ClipboardPaste, Plus, Wallet } from "lucide-react";
import { formatMoney } from "@/lib/utils";
import { transactionTitle } from "@/lib/transaction-description";
import { getDashboardData } from "@/app/actions/dashboard";
import { BudgetAlerts, BudgetBars } from "@/components/budgets/budget-bars";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { StatCard } from "@/components/ui/stat-card";

export default async function DashboardPage() {
  const data = await getDashboardData();
  const isEmpty = data.recent.length === 0;
  const firstName = data.profile?.display_name?.split(" ")[0];

  return (
    <div className="page-stack">
      <PageHeader
        title={firstName ? `Welcome back, ${firstName}` : "Welcome back"}
        description="Spend smarter. Save better. Live better."
        actions={
          <Button asChild>
            <Link href="/add">
              <Plus className="h-4 w-4" />
              Add expense
            </Link>
          </Button>
        }
      />

      <div className="stagger grid gap-3 md:grid-cols-3">
        <Link
          href="/add?type=expense"
          className="surface surface-interactive pressable flex items-center gap-3 p-4"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent)] text-[var(--accent-fg)]">
            <Plus className="h-5 w-5" />
          </span>
          <span>
            <span className="block text-sm font-semibold">Quick add</span>
            <span className="block text-xs text-[var(--muted)]">
              Amount, category, done
            </span>
          </span>
        </Link>
        <Link
          href="/add?mode=receipt"
          className="surface surface-interactive pressable flex items-center gap-3 p-4"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
            <Camera className="h-5 w-5" />
          </span>
          <span>
            <span className="block text-sm font-semibold">Scan receipt</span>
            <span className="block text-xs text-[var(--muted)]">
              Photo → review → save
            </span>
          </span>
        </Link>
        <Link
          href="/add?mode=sms"
          className="surface surface-interactive pressable flex items-center gap-3 p-4"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
            <ClipboardPaste className="h-5 w-5" />
          </span>
          <span>
            <span className="block text-sm font-semibold">Paste SMS</span>
            <span className="block text-xs text-[var(--muted)]">
              Bank alert → confirm
            </span>
          </span>
        </Link>
      </div>

      {isEmpty && (
        <EmptyState
          icon={Wallet}
          title="Start with your first expense"
          description="Scan a receipt, paste a bank SMS, type “Coffee 450”, or enter an amount and category."
          action={
            <div className="flex flex-wrap justify-center gap-2">
              <Button asChild>
                <Link href="/add">Open Quick Add</Link>
              </Button>
              <Button asChild variant="outline">
                <Link href="/add?type=income">Log income</Link>
              </Button>
            </div>
          }
        />
      )}

      <BudgetAlerts budgets={data.budgets} />

      <div className="grid gap-3 md:grid-cols-3">
        <StatCard
          label="Net worth"
          value={formatMoney(data.netWorth, data.baseCurrency)}
          hint={`In ${data.baseCurrency}`}
        />
        <StatCard
          label="Income this month"
          value={formatMoney(data.income, data.baseCurrency)}
          tone="positive"
        />
        <StatCard
          label="Spent this month"
          value={formatMoney(data.expense, data.baseCurrency)}
          tone="negative"
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <CardTitle>Accounts</CardTitle>
            <Button asChild variant="ghost" size="sm">
              <Link href="/accounts">Manage</Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-1">
            {data.accounts.map((account) => (
              <div
                key={account.id}
                className="flex items-center justify-between rounded-xl px-2 py-2.5 transition-colors hover:bg-[var(--background)]"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{account.name}</p>
                  <p className="text-xs capitalize text-[var(--muted)]">
                    {account.type}
                  </p>
                </div>
                <p className="shrink-0 text-sm font-semibold tabular-nums">
                  {formatMoney(Number(account.balance), account.currency)}
                </p>
              </div>
            ))}
            {data.accounts.length === 0 && (
              <p className="px-2 py-4 text-sm text-[var(--muted)]">
                No accounts yet.
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <CardTitle>Budgets</CardTitle>
            <Button asChild variant="ghost" size="sm">
              <Link href="/budgets">View all</Link>
            </Button>
          </CardHeader>
          <CardContent>
            <BudgetBars budgets={data.budgets} currency={data.baseCurrency} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0">
          <CardTitle>Recent activity</CardTitle>
          <Button asChild variant="ghost" size="sm">
            <Link href="/transactions">See all</Link>
          </Button>
        </CardHeader>
        <CardContent className="space-y-1">
          {data.recent.map((tx) => {
            const direction = (
              tx as { transfer_direction?: string | null }
            ).transfer_direction;
            const sign =
              tx.type === "income" ||
              (tx.type === "transfer" && direction === "in")
                ? "+"
                : "-";
            return (
            <div
              key={tx.id}
              className="flex items-center justify-between gap-3 rounded-xl px-2 py-2.5 transition-colors hover:bg-[var(--background)]"
            >
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">
                  {transactionTitle(tx)}
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-[var(--muted)]">
                  <span>{tx.date}</span>
                  <Badge
                    variant={
                      tx.type === "income"
                        ? "success"
                        : tx.type === "expense"
                          ? "danger"
                          : "default"
                    }
                    className="capitalize"
                  >
                    {tx.type}
                  </Badge>
                </div>
              </div>
              <p
                className={`shrink-0 text-sm font-semibold tabular-nums ${
                  sign === "+"
                    ? "text-[var(--success)]"
                    : "text-[var(--danger)]"
                }`}
              >
                {sign}
                {formatMoney(
                  Number(tx.amount),
                  tx.account?.currency ?? data.baseCurrency
                )}
              </p>
            </div>
            );
          })}
          {!isEmpty && data.recent.length === 0 && (
            <p className="px-2 py-4 text-sm text-[var(--muted)]">
              No transactions yet.
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
