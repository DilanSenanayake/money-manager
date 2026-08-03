import Link from "next/link";
import {
  Wallet,
  PiggyBank,
  PieChart,
  Repeat,
  Settings,
  ChevronRight,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";

const links = [
  {
    href: "/accounts",
    label: "Accounts",
    description: "Cash, bank, and credit wallets",
    icon: Wallet,
  },
  {
    href: "/budgets",
    label: "Budgets",
    description: "Category limits and progress",
    icon: PiggyBank,
  },
  {
    href: "/analytics",
    label: "Analytics",
    description: "Trends and category charts",
    icon: PieChart,
  },
  {
    href: "/recurring",
    label: "Recurring",
    description: "Bills and repeating payments",
    icon: Repeat,
  },
  {
    href: "/settings",
    label: "Settings",
    description: "Profile, currency, exchange rates",
    icon: Settings,
  },
];

export default function MorePage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl tracking-tight">More</h1>
        <p className="text-sm text-slate-500">
          Accounts, budgets, and other tools
        </p>
      </div>
      <Card>
        <CardContent className="divide-y divide-slate-100 p-0 dark:divide-slate-800">
          {links.map(({ href, label, description, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center gap-3 px-4 py-3.5 transition hover:bg-slate-50 dark:hover:bg-slate-900"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-teal-50 text-teal-800 dark:bg-teal-950 dark:text-teal-300">
                <Icon className="h-5 w-5" />
              </span>
              <span className="flex-1">
                <span className="block text-sm font-medium">{label}</span>
                <span className="block text-xs text-slate-500">
                  {description}
                </span>
              </span>
              <ChevronRight className="h-4 w-4 text-slate-400" />
            </Link>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
