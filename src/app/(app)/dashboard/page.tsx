import Link from "next/link";
import { formatMoney } from "@/lib/utils";
import { getDashboardData } from "@/app/actions/dashboard";
import { BudgetAlerts, BudgetBars } from "@/components/budgets/budget-bars";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default async function DashboardPage() {
  const data = await getDashboardData();

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl tracking-tight">
            Hello{data.profile?.display_name ? `, ${data.profile.display_name}` : ""}
          </h1>
          <p className="text-sm text-slate-500">
            Net worth and this month&apos;s cash flow
          </p>
        </div>
        <div className="flex gap-2">
          <Button asChild variant="outline">
            <Link href="/import">AI Import</Link>
          </Button>
          <Button asChild>
            <Link href="/transactions">Add transaction</Link>
          </Button>
        </div>
      </div>

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
          <CardHeader>
            <CardTitle className="text-base">Accounts</CardTitle>
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
        <CardHeader>
          <CardTitle className="text-base">Recent transactions</CardTitle>
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
          {data.recent.length === 0 && (
            <p className="text-sm text-slate-500">No transactions yet.</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
