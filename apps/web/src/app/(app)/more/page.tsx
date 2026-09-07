import Link from "next/link";
import {
  Wallet,
  PiggyBank,
  PieChart,
  Repeat,
  Settings,
  ChevronRight,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
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
    <div className="page-stack">
      <PageHeader
        title="More"
        description="Accounts, budgets, analytics, and settings"
      />
      <Card>
        <CardContent className="divide-y divide-[var(--border)] p-0">
          {links.map(({ href, label, description, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="group flex min-h-14 items-center gap-3 px-4 py-3.5 transition-colors hover:bg-[var(--background)] active:bg-[var(--background)]"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
                <Icon className="h-5 w-5" aria-hidden />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-semibold">{label}</span>
                <span className="block text-xs text-[var(--muted)]">
                  {description}
                </span>
              </span>
              <ChevronRight className="h-4 w-4 text-[var(--muted-fg)] transition-transform duration-150 group-hover:translate-x-0.5" />
            </Link>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
