"use client";

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

export function AnalyticsCharts({
  trend,
  categorySpend,
  currency,
}: {
  trend: { month: string; income: number; expense: number }[];
  categorySpend: { name: string; value: number }[];
  currency: string;
}) {
  const money = (value: number) => formatMoney(value, currency);

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card className="lg:col-span-2">
        <CardHeader>
          <CardTitle className="text-base">Income vs expense (6 months)</CardTitle>
        </CardHeader>
        <CardContent className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={trend}>
              <CartesianGrid strokeDasharray="3 3" stroke="#cbd5e1" />
              <XAxis dataKey="month" />
              <YAxis tickFormatter={(v) => money(Number(v))} width={80} />
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

      <Card className="lg:col-span-2">
        <CardHeader>
          <CardTitle className="text-base">
            Category spending (this month)
          </CardTitle>
        </CardHeader>
        <CardContent className="h-80">
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
                  outerRadius={110}
                  label={({ name, value }) =>
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
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
