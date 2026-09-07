"use client";

import { useEffect, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatMoney } from "@/lib/utils";
import { getCategoryHex } from "@/components/categories/category-icon";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function useIsNarrow(breakpoint = 640) {
  const [narrow, setNarrow] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${breakpoint - 1}px)`);
    const sync = () => setNarrow(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, [breakpoint]);

  return narrow;
}

function compactMoney(value: number, currency: string) {
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      notation: "compact",
      maximumFractionDigits: 1,
    }).format(value);
  } catch {
    return formatMoney(value, currency);
  }
}

export function AnalyticsCharts({
  trend,
  categorySpend,
  currency,
}: {
  trend: { month: string; income: number; expense: number }[];
  categorySpend: { name: string; value: number }[];
  currency: string;
}) {
  const narrow = useIsNarrow();
  const money = (value: number) => formatMoney(value, currency);
  const axisMoney = (value: number) =>
    narrow ? compactMoney(value, currency) : money(value);

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card className="overflow-hidden lg:col-span-2">
        <CardHeader>
          <CardTitle className="text-base">Income vs expense (6 months)</CardTitle>
        </CardHeader>
        <CardContent className="h-64 overflow-hidden sm:h-72">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart
              data={trend}
              margin={{ top: 8, right: 8, left: 0, bottom: 0 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#cbd5e1" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis
                tickFormatter={(v) => axisMoney(Number(v))}
                width={narrow ? 44 : 72}
                tick={{ fontSize: 11 }}
              />
              <Tooltip formatter={(value) => money(Number(value))} />
              <Legend />
              <Area
                type="monotone"
                dataKey="income"
                stroke="#0f766e"
                fill="#99f6e4"
                name="Income"
              />
              <Area
                type="monotone"
                dataKey="expense"
                stroke="#e11d48"
                fill="#fecdd3"
                name="Expense"
              />
            </AreaChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      <Card className="overflow-hidden lg:col-span-2">
        <CardHeader>
          <CardTitle className="text-base">
            Category spending (this month)
          </CardTitle>
        </CardHeader>
        <CardContent className="h-72 overflow-hidden sm:h-80">
          {categorySpend.length === 0 ? (
            <p className="text-sm text-slate-500">No expense data this month.</p>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={categorySpend}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={narrow ? 72 : 110}
                  label={
                    narrow
                      ? false
                      : ({ name, value }) =>
                          `${name}: ${money(Number(value))}`
                  }
                >
                  {categorySpend.map((entry) => (
                    <Cell
                      key={entry.name}
                      fill={getCategoryHex(null, entry.name)}
                    />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => money(Number(value))} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
