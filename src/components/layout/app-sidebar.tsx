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
      aria-current={active ? "page" : undefined}
      className={cn(
        "group flex items-center gap-2.5 rounded-[10px] px-3 py-2 text-sm font-medium transition-[color,background-color] duration-150",
        active
          ? "bg-[var(--accent-soft)] text-[var(--accent-hover)]"
          : "text-[var(--muted)] hover:bg-[var(--background)] hover:text-[var(--foreground)]"
      )}
    >
      <Icon
        className={cn(
          "h-4 w-4 shrink-0",
          active ? "text-[var(--accent)]" : "text-[var(--muted-fg)] group-hover:text-[var(--muted)]"
        )}
      />
      {label}
    </Link>
  );
}

export function AppSidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-full w-full flex-col border-r border-[var(--border)] bg-[var(--surface)] px-3 py-5">
      <div className="mb-7 px-3">
        <Link href="/dashboard" className="inline-flex items-center gap-2.5">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--accent)] text-[var(--accent-fg)] text-sm font-bold tracking-tight">
            L
          </span>
          <span>
            <span className="block text-sm font-semibold tracking-tight">
              Ledgerly
            </span>
            <span className="block text-[11px] text-[var(--muted-fg)]">
              Money, clarified
            </span>
          </span>
        </Link>
      </div>

      <nav className="flex flex-1 flex-col gap-0.5" aria-label="Primary">
        {primary.map((item) => (
          <NavLink
            key={item.href}
            {...item}
            active={
              pathname === item.href || pathname.startsWith(`${item.href}/`)
            }
          />
        ))}
        <p className="mb-1 mt-6 px-3 text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--muted-fg)]">
          Manage
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

      <form action={signOut} className="mt-4 border-t border-[var(--border)] pt-3">
        <Button
          type="submit"
          variant="ghost"
          className="w-full justify-start gap-2.5 font-medium"
        >
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
    <nav
      aria-label="Mobile"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-[var(--border)] bg-[color-mix(in_oklab,var(--surface)_92%,transparent)] px-2 pb-[max(0.4rem,env(safe-area-inset-bottom))] pt-1.5 backdrop-blur-xl md:hidden"
    >
      <div className="mx-auto flex max-w-lg items-end">
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
                aria-current={active ? "page" : undefined}
                className="flex flex-1 flex-col items-center gap-0.5"
              >
                <span
                  className={cn(
                    "-mt-4 flex h-12 w-12 items-center justify-center rounded-2xl text-[var(--accent-fg)] shadow-[var(--shadow-md)] transition-transform duration-150 active:scale-95",
                    active ? "bg-[var(--accent-hover)]" : "bg-[var(--accent)]"
                  )}
                >
                  <Icon className="h-5 w-5" />
                </span>
                <span
                  className={cn(
                    "text-[10px] font-semibold",
                    active ? "text-[var(--accent-hover)]" : "text-[var(--muted)]"
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
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex min-h-11 flex-1 flex-col items-center justify-center gap-1 rounded-lg py-1.5 text-[10px] font-semibold transition-colors",
                active
                  ? "text-[var(--accent-hover)]"
                  : "text-[var(--muted)]"
              )}
            >
              <Icon className="h-4 w-4" />
              {label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
