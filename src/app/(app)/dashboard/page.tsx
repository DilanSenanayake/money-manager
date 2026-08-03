import Link from "next/link";
import { Camera, ClipboardPaste, Plus } from "lucide-react";
import { formatMoney } from "@/lib/utils";
import { getDashboardData } from "@/app/actions/dashboard";
import { BudgetAlerts, BudgetBars } from "@/components/budgets/budget-bars";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default async function DashboardPage() {
  const data = await getDashboardData();
  const isEmpty = data.recent.length === 0;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl tracking-tight">
            Hello{data.profile?.display_name ? `, ${data.profile.display_name}` : ""}
          </h1>
          <p className="text-sm text-slate-500">
            Add an expense in about 30 seconds
          </p>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <Button asChild size="lg" className="h-auto flex-col gap-1 py-4">
          <Link href="/add?type=expense">
            <Plus className="h-5 w-5" />
            <span>Add expense</span>
          </Link>
        </Button>
        <Button
          asChild
          size="lg"
          variant="outline"
          className="h-auto flex-col gap-1 py-4"
        >
          <Link href="/add?mode=receipt">
            <Camera className="h-5 w-5" />
            <span>Scan receipt</span>
          </Link>
        </Button>
        <Button
          asChild
          size="lg"
          variant="outline"
          className="h-auto flex-col gap-1 py-4"
        >
          <Link href="/add?mode=sms">
            <ClipboardPaste className="h-5 w-5" />
            <span>Paste SMS</span>
          </Link>
        </Button>
      </div>

      {isEmpty && (
        <Card className="border-teal-200 bg-teal-50/50 dark:border-teal-900 dark:bg-teal-950/30">
          <CardContent className="space-y-3 pt-6">
            <p className="font-display text-xl text-teal-900 dark:text-teal-200">
              Add your first expense in under 30 seconds
            </p>
            <p className="text-sm text-slate-600 dark:text-slate-300">
              Scan a receipt, paste a bank SMS, type one line like “Coffee 450”,
              or tap amount + category.
            </p>
            <div className="flex flex-wrap gap-2">
              <Button asChild>
                <Link href="/add">Open Quick Add</Link>
              </Button>
              <Button asChild variant="outline">
                <Link href="/add?type=income">Log income</Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <BudgetAlerts budgets={data.budgets} />

      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-slate-500">
              Net worth
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="font-display text-3xl">
              {formatMoney(data.netWorth, data.baseCurrency)}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-slate-500">
              Income (month)
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="font-display text-3xl text-teal-700">
              {formatMoney(data.income, data.baseCurrency)}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-slate-500">
              Expenses (month)
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="font-display text-3xl text-rose-600">
              {formatMoney(data.expense, data.baseCurrency)}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">Accounts</CardTitle>
            <Button asChild variant="ghost" size="sm">
              <Link href="/accounts">Manage</Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            {data.accounts.map((account) => (
              <div
                key={account.id}
                className="flex items-center justify-between text-sm"
              >
                <div>
                  <p className="font-medium">{account.name}</p>
                  <p className="capitalize text-slate-500">{account.type}</p>
                </div>
                <p className="font-semibold">
                  {formatMoney(Number(account.balance), account.currency)}
                </p>
              </div>
            ))}
            {data.accounts.length === 0 && (
              <p className="text-sm text-slate-500">No accounts yet.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Budget progress</CardTitle>
          </CardHeader>
          <CardContent>
            <BudgetBars budgets={data.budgets.slice(0, 5)} currency={data.baseCurrency} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base">Recent activity</CardTitle>
          <Button asChild variant="ghost" size="sm">
            <Link href="/transactions">See all</Link>
          </Button>
        </CardHeader>
        <CardContent className="space-y-2">
          {data.recent.map((tx) => (
            <div
              key={tx.id}
              className="flex items-center justify-between gap-3 rounded-xl border border-slate-100 px-3 py-2 dark:border-slate-800"
            >
              <div>
                <p className="text-sm font-medium">
                  {tx.merchant || tx.category?.name || tx.type}
                </p>
                <div className="mt-1 flex gap-2 text-xs text-slate-500">
                  <span>{tx.date}</span>
                  <Badge className="capitalize">{tx.type}</Badge>
                </div>
              </div>
              <p
                className={`text-sm font-semibold ${
                  tx.type === "income" ? "text-teal-700" : "text-rose-600"
                }`}
              >
                {tx.type === "income" ? "+" : "-"}
                {formatMoney(
                  Number(tx.amount),
                  tx.account?.currency ?? data.baseCurrency
                )}
              </p>
            </div>
          ))}
          {!isEmpty && data.recent.length === 0 && (
            <p className="text-sm text-slate-500">No transactions yet.</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
