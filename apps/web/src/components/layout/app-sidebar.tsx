"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  useCallback,
  useEffect,
  useId,
  useState,
  type ComponentType,
} from "react";
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
  X,
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
  onNavigate,
}: {
  href: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  active: boolean;
  onNavigate?: () => void;
}) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      onClick={onNavigate}
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
          active
            ? "text-[var(--accent)]"
            : "text-[var(--muted-fg)] group-hover:text-[var(--muted)]"
        )}
      />
      {label}
    </Link>
  );
}

function SidebarNav({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();

  return (
    <>
      <nav className="flex flex-1 flex-col gap-0.5" aria-label="Primary">
        {primary.map((item) => (
          <NavLink
            key={item.href}
            {...item}
            onNavigate={onNavigate}
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
            onNavigate={onNavigate}
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
    </>
  );
}

function BrandMark({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <Link
      href="/dashboard"
      onClick={onNavigate}
      className="inline-flex items-center gap-2.5"
    >
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-[var(--accent)] text-sm font-bold tracking-tight text-[var(--accent-fg)]">
        S
      </span>
      <span>
        <span className="block text-sm font-semibold leading-snug tracking-tight">
          Smart Money Manager
        </span>
        <span className="block text-[11px] text-[var(--muted-fg)]">
          Spend smarter. Save better.
        </span>
      </span>
    </Link>
  );
}

export function AppSidebar() {
  return (
    <aside className="flex h-full w-full flex-col border-r border-[var(--border)] bg-[var(--surface)] px-3 py-5">
      <div className="mb-7 px-3">
        <BrandMark />
      </div>
      <SidebarNav />
    </aside>
  );
}

export function MobileHeader() {
  const [open, setOpen] = useState(false);
  const titleId = useId();
  const pathname = usePathname();

  const close = useCallback(() => setOpen(false), []);

  useEffect(() => {
    close();
  }, [pathname, close]);

  useEffect(() => {
    if (!open) return;

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") close();
    };

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open, close]);

  return (
    <>
      <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-[var(--border)] bg-[var(--surface)] px-3 pb-3 pt-[max(0.75rem,env(safe-area-inset-top))] md:hidden">
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-[var(--accent)] focus:px-3 focus:py-2 focus:text-[var(--accent-fg)]"
        >
          Skip to content
        </a>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-expanded={open}
          aria-controls="mobile-sidebar"
          aria-label={open ? "Close menu" : "Open menu"}
          onClick={() => setOpen(true)}
        >
          <Menu className="h-5 w-5" />
        </Button>
        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-[var(--accent)] text-[11px] font-bold text-[var(--accent-fg)]">
          S
        </span>
        <p className="min-w-0 truncate text-sm font-semibold tracking-tight">
          Smart Money Manager
        </p>
      </header>

      <div
        className={cn(
          "fixed inset-0 z-50 md:hidden",
          open ? "pointer-events-auto" : "pointer-events-none"
        )}
        aria-hidden={!open}
      >
        <button
          type="button"
          tabIndex={open ? 0 : -1}
          aria-label="Close menu"
          className={cn(
            "absolute inset-0 bg-[rgba(12,18,34,0.45)] backdrop-blur-[2px] transition-opacity duration-200",
            open ? "opacity-100" : "opacity-0"
          )}
          onClick={close}
        />
        <aside
          id="mobile-sidebar"
          role="dialog"
          aria-modal="true"
          aria-labelledby={titleId}
          className={cn(
            "absolute inset-y-0 left-0 flex w-[min(20rem,88vw)] flex-col border-r border-[var(--border)] bg-[var(--surface)] px-3 py-5 shadow-[var(--shadow-lg)] transition-transform duration-200 ease-[var(--ease-out)]",
            open ? "translate-x-0" : "-translate-x-full"
          )}
        >
          <div className="mb-6 flex items-start justify-between gap-3 px-3">
            <div id={titleId}>
              <BrandMark onNavigate={close} />
            </div>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label="Close menu"
              onClick={close}
            >
              <X className="h-5 w-5" />
            </Button>
          </div>
          <SidebarNav onNavigate={close} />
        </aside>
      </div>
    </>
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
      className="fixed inset-x-0 bottom-0 z-40 border-t border-[var(--border)] bg-[var(--surface)] px-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-1.5 md:hidden"
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
                    "text-[11px] font-semibold",
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
                "flex min-h-12 flex-1 flex-col items-center justify-center gap-1 rounded-lg py-1.5 text-[11px] font-semibold transition-colors",
                active
                  ? "text-[var(--accent-hover)]"
                  : "text-[var(--muted)]"
              )}
            >
              <Icon className="h-5 w-5" />
              {label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
