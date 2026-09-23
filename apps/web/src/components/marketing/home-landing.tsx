"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  ArrowLeftRight,
  Camera,
  ClipboardPaste,
  Globe,
  LayoutDashboard,
  Lock,
  MessageSquareText,
  PiggyBank,
  Plus,
  ShieldCheck,
  Sparkles,
  Wallet,
} from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { CURRENCIES } from "@/lib/schemas";
import { formatMoney, cn } from "@/lib/utils";
import { trackEvent } from "@/lib/analytics";
import { BrandMark } from "@/components/brand/brand-mark";
import {
  CategoryBadge,
  CategoryIcon,
} from "@/components/categories/category-icon";
import { SiteFooter } from "@/components/layout/site-footer";

type CaptureMode = "text" | "sms" | "receipt";
type DemoCurrency = (typeof CURRENCIES)[number];

type DemoTx = {
  merchant: string;
  amount: number;
  category: string;
  account: string;
  type: "expense" | "income";
};

const DEMO_CURRENCIES: DemoCurrency[] = ["USD", "EUR", "GBP", "INR", "LKR"];

const STARTER: DemoTx[] = [
  {
    merchant: "City Market",
    amount: 86,
    category: "Groceries",
    account: "Main wallet",
    type: "expense",
  },
  {
    merchant: "Monthly pay",
    amount: 3200,
    category: "Salary",
    account: "Main wallet",
    type: "income",
  },
  {
    merchant: "Phone bill",
    amount: 39,
    category: "Utilities",
    account: "Main wallet",
    type: "expense",
  },
];

function samples(
  currency: DemoCurrency
): Record<CaptureMode, { label: string; value: string }[]> {
  return {
    text: [
      { label: "Coffee 4.50", value: "Coffee 4.50" },
      { label: "Taxi 12", value: "Taxi 12" },
      { label: "Rent 950", value: "Rent 950" },
    ],
    sms: [
      {
        label: "Grocery debit",
        value: `${currency} 24.00 debited from A/C **4521 at CITY MARKET on 17 Sep. Avl bal 1,210.00`,
      },
      {
        label: "Pay credit",
        value: `${currency} 3,200.00 credited to A/C **4521 from PAYROLL on 01 Sep. Avl bal 4,410.00`,
      },
    ],
    receipt: [
      { label: "Cafe receipt", value: "receipt-cafe" },
      { label: "Grocery bill", value: "receipt-grocery" },
    ],
  };
}

function parseDemo(mode: CaptureMode, raw: string): DemoTx | null {
  if (mode === "receipt") {
    if (raw === "receipt-grocery") {
      return {
        merchant: "City Market",
        amount: 24,
        category: "Groceries",
        account: "Main wallet",
        type: "expense",
      };
    }
    return {
      merchant: "Neighbourhood Cafe",
      amount: 8.9,
      category: "Dining",
      account: "Main wallet",
      type: "expense",
    };
  }

  const text = raw.trim();
  if (!text) return null;
  const amountMatch = text.replace(/,/g, "").match(/(\d+(?:\.\d{1,2})?)/);
  const amount = amountMatch ? Number(amountMatch[1]) : 0;
  if (!amount) return null;

  const isIncome = /credit|salary|payroll|pay|deposited|received/i.test(text);
  const merchantSource = text
    .replace(/lkr|usd|eur|gbp|inr|jpy|aud|cad|chf|sgd|rs\.?/gi, " ")
    .replace(amountMatch?.[0] ?? "", " ")
    .replace(/debited|credited|from|at|on|a\/c|\*+/gi, " ")
    .replace(/\s+/g, " ")
    .trim();

  const lower = text.toLowerCase();
  let category = "Other";
  if (/coffee|cafe|lunch|dinner|restaurant/i.test(lower)) category = "Dining";
  else if (/grocery|market|food/i.test(lower)) category = "Groceries";
  else if (/taxi|uber|ride|fuel|bus/i.test(lower)) category = "Transport";
  else if (/rent|lease/i.test(lower)) category = "Housing";
  else if (/salary|payroll|pay/i.test(lower)) category = "Salary";
  else if (/phone|utility|bill/i.test(lower)) category = "Utilities";

  return {
    merchant:
      merchantSource.split(" ").slice(0, 4).join(" ") ||
      (isIncome ? "Incoming" : "Expense"),
    amount,
    category,
    account: "Main wallet",
    type: isIncome || /salary|credit/i.test(lower) ? "income" : "expense",
  };
}

export function HomeLanding() {
  const [mode, setMode] = useState<CaptureMode>("text");
  const [currency, setCurrency] = useState<DemoCurrency>("USD");
  const [input, setInput] = useState("Coffee 4.50");
  const [busy, setBusy] = useState(false);
  const [draft, setDraft] = useState<DemoTx | null>(null);
  const [ledger, setLedger] = useState<DemoTx[]>(STARTER);
  const demoSamples = samples(currency);

  const income = useMemo(
    () => ledger.filter((t) => t.type === "income").reduce((s, t) => s + t.amount, 0),
    [ledger]
  );
  const expense = useMemo(
    () => ledger.filter((t) => t.type === "expense").reduce((s, t) => s + t.amount, 0),
    [ledger]
  );
  const grocerySpend = useMemo(
    () =>
      ledger
        .filter((t) => t.category === "Groceries" && t.type === "expense")
        .reduce((s, t) => s + t.amount, 0),
    [ledger]
  );

  async function runParse(value = input) {
    const next = value.trim();
    if (!next || busy) return;
    setInput(next);
    setBusy(true);
    setDraft(null);
    await new Promise((r) => setTimeout(r, 650));
    const parsed = parseDemo(mode, next);
    setBusy(false);
    if (!parsed) {
      toast.error("Try a short note with an amount, like Coffee 4.50");
      return;
    }
    setDraft(parsed);
  }

  function confirmDraft() {
    if (!draft) return;
    setLedger((rows) => [draft, ...rows].slice(0, 6));
    setDraft(null);
    toast.success("Saved in the demo. In the app, you confirm the same way.");
  }

  return (
    <main className="auth-shell">
      <header className="sticky top-0 z-20 border-b border-[var(--border)]/80 bg-[var(--background)]/80 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-3 px-4 sm:h-16 sm:px-6">
          <Link href="/" aria-label="Smart Money Manager home">
            <BrandMark size="sm" priority />
          </Link>
          <nav className="hidden items-center gap-6 text-sm font-medium text-[var(--muted)] md:flex">
            <a href="#demo" className="hover:text-[var(--foreground)]">
              Try it
            </a>
            <a href="#why" className="hover:text-[var(--foreground)]">
              Why it helps
            </a>
            <a href="#app" className="hover:text-[var(--foreground)]">
              The app
            </a>
          </nav>
          <div className="flex items-center gap-1 sm:gap-2">
            <Button asChild variant="ghost" size="sm">
              <Link href="/login">Sign in</Link>
            </Button>
            <Button asChild size="sm">
              <Link
                href="/signup"
                onClick={() =>
                  trackEvent("select_content", {
                    content_type: "cta",
                    item_id: "start_free_header",
                  })
                }
              >
                Start free
              </Link>
            </Button>
          </div>
        </div>
      </header>

      <section className="mx-auto grid max-w-6xl items-center gap-8 px-4 py-10 sm:px-6 sm:py-14 md:grid-cols-[1.08fr_0.92fr] md:gap-10 md:py-20">
        <div className="stagger max-w-xl">
          <h1 className="font-display text-[2rem] leading-[1.12] tracking-tight text-[var(--foreground)] sm:text-4xl md:text-[3.15rem] md:leading-[1.08]">
            Take control of your money.
          </h1>
          <p className="mt-4 max-w-lg text-[15px] leading-relaxed text-[var(--muted)] sm:text-base md:text-lg">
            See where it goes. Add a purchase in seconds. Nothing is saved until
            you say yes.
          </p>
          <div className="mt-7 flex w-full flex-col items-stretch gap-3 sm:flex-row sm:items-center">
            <Button asChild size="lg" className="w-full shadow-[var(--shadow-md)] sm:w-auto">
              <Link
                href="/signup"
                onClick={() =>
                  trackEvent("select_content", {
                    content_type: "cta",
                    item_id: "start_free_hero",
                  })
                }
              >
                Start free
              </Link>
            </Button>
            <a
              href="#demo"
              className="inline-flex min-h-11 items-center justify-center px-1 text-center text-sm font-semibold text-[var(--accent-hover)] underline-offset-4 hover:underline"
            >
              Try a live demo
            </a>
          </div>
          <ul className="mt-5 flex flex-col gap-2 text-xs leading-snug text-[var(--muted-fg)] sm:text-[13px]">
            <li className="flex items-start gap-2">
              <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--accent-hover)]" />
              Free to start. No card. No bank login.
            </li>
            <li className="flex items-start gap-2">
              <ShieldCheck className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--accent-hover)]" />
              Your data stays private - only you confirm what is saved.
            </li>
            <li className="flex items-start gap-2">
              <Globe className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--accent-hover)]" />
              Works in your currency. Choose it when you sign up.
            </li>
          </ul>
          <div className="mt-4 flex flex-wrap items-center gap-1.5">
            <span className="text-[11px] font-medium text-[var(--muted-fg)]">
              Preview
            </span>
            {DEMO_CURRENCIES.map((code) => (
              <button
                key={code}
                type="button"
                onClick={() => setCurrency(code)}
                className={cn(
                  "rounded-full border px-2 py-0.5 text-[11px] font-semibold tabular-nums transition-colors",
                  currency === code
                    ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent-hover)]"
                    : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--border-strong)] hover:text-[var(--foreground)]"
                )}
                aria-pressed={currency === code}
              >
                {code}
              </button>
            ))}
            <span className="text-[11px] text-[var(--muted-fg)]">+ more</span>
          </div>
        </div>

        <div className="relative min-w-0">
          <AppPreview
            ledger={ledger}
            income={income}
            expense={expense}
            grocerySpend={grocerySpend}
            currency={currency}
          />
          <p className="mt-2 text-center text-[11px] text-[var(--muted-fg)] md:text-left">
            Sample amounts in {currency}. You set your own when you join.
          </p>
        </div>
      </section>

      <section id="why" className="mx-auto max-w-6xl px-4 pb-4 sm:px-6 sm:pb-6">
        <p className="mb-3 max-w-2xl text-sm text-[var(--muted)]">
          Built to feel calm - help without taking over.
        </p>
        <div className="grid gap-3 md:grid-cols-3">
          {[
            {
              icon: ShieldCheck,
              title: "You stay in control",
              body: "AI can fill the form. You always confirm. Nothing is saved without you.",
            },
            {
              icon: ClipboardPaste,
              title: "Capture life as it happens",
              body: "A photo, a bank message, or one short line - so logging money takes seconds, not a chore.",
            },
            {
              icon: Wallet,
              title: "See the full picture",
              body: "Wallets, budgets, and trends in one place, so you know where you stand.",
            },
          ].map(({ icon: Icon, title, body }) => (
            <div key={title} className="surface p-5">
              <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
                <Icon className="h-5 w-5" />
              </span>
              <h2 className="font-semibold tracking-tight">{title}</h2>
              <p className="mt-2 text-sm leading-relaxed text-[var(--muted)]">
                {body}
              </p>
            </div>
          ))}
        </div>
      </section>

      <section id="demo" className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-14">
        <div className="mb-6 max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--accent-hover)]">
            Interactive demo
          </p>
          <h2 className="mt-2 font-display text-2xl tracking-tight sm:text-3xl">
            Try it before you sign up
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)] sm:text-base">
            No account needed. Confirm a sample and watch the home screen update.
          </p>
        </div>

        <div className="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="surface p-5 sm:p-6">
            <div className="flex flex-wrap gap-2">
              {(
                [
                  ["text", "Describe it", MessageSquareText],
                  ["sms", "Paste SMS", ClipboardPaste],
                  ["receipt", "Scan receipt", Camera],
                ] as const
              ).map(([id, label, Icon]) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => {
                    setMode(id);
                    setDraft(null);
                    setInput(demoSamples[id][0].value);
                  }}
                  className={cn(
                    "inline-flex min-h-10 items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors",
                    mode === id
                      ? "border-[var(--accent)] bg-[var(--accent-soft)] text-[var(--accent-hover)]"
                      : "border-[var(--border)] text-[var(--muted)] hover:border-[var(--border-strong)]"
                  )}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {label}
                </button>
              ))}
            </div>

            <div className="mt-5 space-y-3">
              {mode === "receipt" ? (
                <button
                  type="button"
                  onClick={() => void runParse(input)}
                  className="w-full rounded-[12px] border border-dashed border-[var(--border-strong)] bg-[var(--background)] p-4 text-left"
                >
                  <p className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">
                    Sample receipt
                  </p>
                  <p className="mt-2 font-semibold">
                    {input === "receipt-grocery"
                      ? "City Market"
                      : "Neighbourhood Cafe"}
                  </p>
                  <p className="text-sm tabular-nums text-[var(--muted)]">
                    {formatMoney(
                      input === "receipt-grocery" ? 24 : 8.9,
                      currency
                    )}
                  </p>
                  <p className="mt-3 text-xs text-[var(--accent-hover)]">
                    Tap to read. In the app, this is your camera.
                  </p>
                </button>
              ) : (
                <Input
                  value={input.startsWith("receipt-") ? "" : input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      void runParse();
                    }
                  }}
                  placeholder={
                    mode === "sms"
                      ? "Paste a bank message…"
                      : "Coffee 4.50"
                  }
                />
              )}

              <div className="flex flex-wrap gap-2">
                {demoSamples[mode].map((sample) => (
                  <button
                    key={sample.label}
                    type="button"
                    className="rounded-full border border-[var(--border)] px-3 py-1.5 text-xs text-[var(--muted)] hover:border-[var(--border-strong)] hover:text-[var(--foreground)]"
                    onClick={() => {
                      setInput(sample.value);
                      void runParse(sample.value);
                    }}
                  >
                    {sample.label}
                  </button>
                ))}
              </div>

              {mode !== "receipt" && (
                <Button
                  className="w-full sm:w-auto"
                  disabled={busy}
                  onClick={() => void runParse()}
                >
                  <Sparkles className="h-4 w-4" />
                  {busy ? "Reading…" : "Fill the form"}
                </Button>
              )}
            </div>
          </div>

          <div className="surface flex flex-col p-5 sm:p-6">
            <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
              Review before save
            </p>
            {busy ? (
              <p className="mt-6 text-sm text-[var(--muted)]">
                Finding the amount and details…
              </p>
            ) : draft ? (
              <div className="mt-4 space-y-4">
                <div>
                  <p className="font-display text-3xl tabular-nums">
                    {formatMoney(draft.amount, currency)}
                  </p>
                  <p className="mt-1 font-semibold">{draft.merchant}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="accent">{draft.category}</Badge>
                  <Badge>{draft.account}</Badge>
                  <Badge variant={draft.type === "income" ? "success" : "default"}>
                    {draft.type}
                  </Badge>
                </div>
                <p className="text-xs leading-relaxed text-[var(--muted)]">
                  This is the confirm step. Nothing is saved until you agree.
                </p>
                <div className="flex flex-col gap-2 sm:flex-row">
                  <Button className="w-full sm:w-auto" onClick={confirmDraft}>
                    Confirm &amp; add
                  </Button>
                  <Button
                    variant="outline"
                    className="w-full sm:w-auto"
                    onClick={() => setDraft(null)}
                  >
                    Discard
                  </Button>
                </div>
              </div>
            ) : (
              <p className="mt-6 text-sm leading-relaxed text-[var(--muted)]">
                Try a sample. You will see a draft, then confirm it into the
                preview.
              </p>
            )}
          </div>
        </div>
      </section>

      <section id="app" className="mx-auto max-w-6xl px-4 pb-14 sm:px-6 sm:pb-16">
        <div className="mb-6 max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--accent-hover)]">
            How the app feels
          </p>
          <h2 className="mt-2 font-display text-2xl tracking-tight sm:text-3xl">
            Built for everyday use
          </h2>
          <p className="mt-2 text-sm text-[var(--muted)] sm:text-base">
            After you confirm, it is a calm home for balances, budgets, and bills.
          </p>
        </div>
        <AppPreview
          ledger={ledger}
          income={income}
          expense={expense}
          grocerySpend={grocerySpend}
          currency={currency}
          large
        />

        <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {[
            [
              "Several wallets",
              "Keep cash, bank, and cards together so balances stay in view.",
            ],
            [
              "Budget alerts",
              "A gentle warning as a category fills up - before it runs out.",
            ],
            [
              "Clear trends",
              "See spending by category over time, so patterns are easy to spot.",
            ],
            [
              "Repeating bills",
              "Mark what comes back each month, in any currency you use.",
            ],
          ].map(([title, body]) => (
            <div key={title} className="surface p-4">
              <p className="font-semibold">{title}</p>
              <p className="mt-1 text-sm leading-relaxed text-[var(--muted)]">
                {body}
              </p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-[var(--border)]">
        <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-6 px-4 py-12 sm:px-6 sm:py-14 md:flex-row md:items-center">
          <div className="max-w-lg">
            <h2 className="font-display text-2xl tracking-tight sm:text-3xl">
              Ready to feel in control?
            </h2>
            <p className="mt-2 text-sm text-[var(--muted)] sm:text-base">
              Create a free account, choose your currency, and add your first
              purchase when you are ready.
            </p>
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              No credit card. No bank login. Your data stays private.
            </p>
          </div>
          <div className="flex w-full flex-col items-stretch gap-3 sm:w-auto">
            <Button asChild size="lg" className="w-full shadow-[var(--shadow-md)]">
              <Link
                href="/signup"
                onClick={() =>
                  trackEvent("select_content", {
                    content_type: "cta",
                    item_id: "start_free_footer",
                  })
                }
              >
                Start free
              </Link>
            </Button>
            <Link
              href="/login"
              className="text-center text-sm font-semibold text-[var(--muted)] underline-offset-4 hover:text-[var(--foreground)] hover:underline"
            >
              I already have an account
            </Link>
          </div>
        </div>
      </section>
      <SiteFooter />
    </main>
  );
}

function AppPreview({
  ledger,
  income,
  expense,
  grocerySpend,
  currency,
  large = false,
}: {
  ledger: DemoTx[];
  income: number;
  expense: number;
  grocerySpend: number;
  currency: DemoCurrency;
  large?: boolean;
}) {
  const groceryLimit = 120;
  const groceryRatio = Math.min(1, grocerySpend / groceryLimit);

  return (
    <div
      className={cn(
        "overflow-hidden rounded-[20px] border border-[var(--border)] bg-[var(--surface)] shadow-[var(--shadow-lg)]",
        !large && "md:rotate-[0.4deg]"
      )}
    >
      <div className="flex items-center gap-1.5 border-b border-[var(--border)] bg-[var(--background)] px-3 py-2">
        <span className="h-2 w-2 rounded-full bg-[#f43f5e]/80" />
        <span className="h-2 w-2 rounded-full bg-[#f59e0b]/80" />
        <span className="h-2 w-2 rounded-full bg-[#10b981]/80" />
        <span className="ml-2 truncate text-[11px] text-[var(--muted-fg)]">
          Home · Smart Money Manager
        </span>
        <span className="ml-auto shrink-0 rounded-full bg-[var(--accent-soft)] px-2 py-0.5 text-[10px] font-semibold tabular-nums text-[var(--accent-hover)]">
          {currency}
        </span>
      </div>
      <div className="flex min-h-[240px] sm:min-h-[280px]">
        <aside className="hidden w-40 shrink-0 border-r border-[var(--border)] p-3 md:block">
          <p className="mb-3 px-2 text-[11px] font-semibold text-[var(--muted-fg)]">
            Menu
          </p>
          {(
            [
              { Icon: LayoutDashboard, label: "Home", active: true },
              { Icon: Plus, label: "Add", active: false },
              { Icon: ArrowLeftRight, label: "Activity", active: false },
              { Icon: Wallet, label: "Accounts", active: false },
              { Icon: PiggyBank, label: "Budgets", active: false },
            ] as const
          ).map(({ Icon, label, active }) => (
            <div
              key={label}
              className={cn(
                "mb-1 flex items-center gap-2 rounded-lg px-2 py-1.5 text-xs font-medium",
                active
                  ? "bg-[var(--accent-soft)] text-[var(--accent-hover)]"
                  : "text-[var(--muted)]"
              )}
            >
              <Icon className="h-3.5 w-3.5" />
              {label}
            </div>
          ))}
        </aside>
        <div className="min-w-0 flex-1 space-y-3 bg-[var(--background)] p-4">
          <div>
            <p className="text-xs text-[var(--muted)]">This month</p>
            <p className="font-display text-lg tracking-tight">Welcome back</p>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <div className="surface p-3">
              <p className="text-[10px] uppercase tracking-wide text-[var(--muted)]">
                Income
              </p>
              <p className="mt-1 text-sm font-semibold tabular-nums text-[var(--success)]">
                {formatMoney(income, currency)}
              </p>
            </div>
            <div className="surface p-3">
              <p className="text-[10px] uppercase tracking-wide text-[var(--muted)]">
                Spent
              </p>
              <p className="mt-1 text-sm font-semibold tabular-nums">
                {formatMoney(expense, currency)}
              </p>
            </div>
          </div>
          <div className="surface p-3">
            <div className="flex items-center justify-between gap-2 text-xs">
              <span className="font-medium">Groceries</span>
              <span className="shrink-0 tabular-nums text-[var(--muted)]">
                {formatMoney(grocerySpend, currency)} /{" "}
                {formatMoney(groceryLimit, currency)}
              </span>
            </div>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-[var(--border)]">
              <div
                className="h-full rounded-full bg-[var(--accent)] transition-[width] duration-500"
                style={{ width: `${groceryRatio * 100}%` }}
              />
            </div>
          </div>
          <div className="space-y-2">
            {ledger.slice(0, large ? 4 : 3).map((tx, i) => (
              <div
                key={`${tx.merchant}-${tx.amount}-${i}`}
                className="flex items-center justify-between gap-2 text-sm"
              >
                <div className="flex min-w-0 items-center gap-2">
                  <CategoryIcon
                    icon={null}
                    name={tx.category}
                    framed
                    className="h-7 w-7 rounded-md"
                  />
                  <div className="min-w-0">
                    <p className="truncate font-medium">{tx.merchant}</p>
                    <div className="mt-0.5">
                      <CategoryBadge name={tx.category} />
                    </div>
                  </div>
                </div>
                <p
                  className={cn(
                    "shrink-0 tabular-nums font-semibold",
                    tx.type === "income" && "text-[var(--success)]"
                  )}
                >
                  {tx.type === "income" ? "+" : "−"}
                  {formatMoney(tx.amount, currency)}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
