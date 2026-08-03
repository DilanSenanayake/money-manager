"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ComponentType } from "react";
import {
  LayoutDashboard,
  ArrowLeftRight,
  Plus,
  Menu,
  LogOut,
  Wallet,
  PiggyBank,
  PieChart,
  Repeat,
  Settings,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { signOut } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";

const primary = [
  { href: "/dashboard", label: "Home", icon: LayoutDashboard },
  { href: "/add", label: "Add", icon: Plus },
  { href: "/transactions", label: "Activity", icon: ArrowLeftRight },
];

const secondary = [
  { href: "/accounts", label: "Accounts", icon: Wallet },
  { href: "/budgets", label: "Budgets", icon: PiggyBank },
  { href: "/analytics", label: "Analytics", icon: PieChart },
  { href: "/recurring", label: "Recurring", icon: Repeat },
  { href: "/settings", label: "Settings", icon: Settings },
];

function NavLink({
  href,
  label,
  icon: Icon,
  active,
}: {
  href: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  active: boolean;
}) {
  return (
    <Link
      href={href}
      className={cn(
        "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors",
        active
          ? "bg-teal-700 text-white"
          : "text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-900"
      )}
    >
      <Icon className="h-4 w-4" />
      {label}
    </Link>
  );
}

export function AppSidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-full w-full flex-col border-r border-slate-200/80 bg-white/80 px-3 py-5 backdrop-blur dark:border-slate-800 dark:bg-slate-950/70">
      <div className="mb-6 px-3">
        <p className="font-display text-xl tracking-tight text-teal-800 dark:text-teal-300">
          Ledgerly
        </p>
        <p className="text-xs text-slate-500">Add money in ~30 seconds</p>
      </div>
      <nav className="flex flex-1 flex-col gap-1">
        {primary.map((item) => (
          <NavLink
            key={item.href}
            {...item}
            active={
              pathname === item.href || pathname.startsWith(`${item.href}/`)
            }
          />
        ))}
        <p className="mb-1 mt-5 px-3 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
          More
        </p>
        {secondary.map((item) => (
          <NavLink
            key={item.href}
            {...item}
            active={
              pathname === item.href || pathname.startsWith(`${item.href}/`)
            }
          />
        ))}
      </nav>
      <form action={signOut} className="mt-4 px-1">
        <Button type="submit" variant="ghost" className="w-full justify-start gap-3">
          <LogOut className="h-4 w-4" />
          Sign out
        </Button>
      </form>
    </aside>
  );
}

const mobileTabs = [
  { href: "/dashboard", label: "Home", icon: LayoutDashboard },
  { href: "/transactions", label: "Activity", icon: ArrowLeftRight },
  { href: "/add", label: "Add", icon: Plus, emphasize: true },
  { href: "/more", label: "More", icon: Menu },
];

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex items-end border-t border-slate-200 bg-white/95 px-2 pb-2 pt-1 backdrop-blur md:hidden dark:border-slate-800 dark:bg-slate-950/95">
      {mobileTabs.map(({ href, label, icon: Icon, emphasize }) => {
        const active =
          pathname === href ||
          (href !== "/dashboard" && pathname.startsWith(`${href}/`)) ||
          (href === "/more" &&
            secondary.some(
              (s) => pathname === s.href || pathname.startsWith(`${s.href}/`)
            ));

        if (emphasize) {
          return (
            <Link
              key={href}
              href={href}
              className="flex flex-1 flex-col items-center gap-0.5"
            >
              <span
                className={cn(
                  "-mt-5 flex h-14 w-14 items-center justify-center rounded-full shadow-lg transition",
                  active
                    ? "bg-teal-800 text-white"
                    : "bg-teal-700 text-white hover:bg-teal-800"
                )}
              >
                <Icon className="h-6 w-6" />
              </span>
              <span
                className={cn(
                  "text-[10px] font-semibold",
                  active ? "text-teal-700" : "text-slate-500"
                )}
              >
                {label}
              </span>
            </Link>
          );
        }

        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex flex-1 flex-col items-center gap-1 rounded-lg py-2 text-[10px] font-medium",
              active ? "text-teal-700" : "text-slate-500"
            )}
          >
            <Icon className="h-4 w-4" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
