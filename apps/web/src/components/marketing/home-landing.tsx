"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  ArrowLeftRight,
  Camera,
  ClipboardPaste,
  LayoutDashboard,
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
import { formatMoney, cn } from "@/lib/utils";
import { BrandMark } from "@/components/brand/brand-mark";

type CaptureMode = "text" | "sms" | "receipt";

type DemoTx = {
  merchant: string;
  amount: number;
  category: string;
  account: string;
  type: "expense" | "income";
};

const STARTER: DemoTx[] = [
  {
    merchant: "Keells Super",
    amount: 4200,
    category: "Groceries",
    account: "Checking",
    type: "expense",
  },
  {
    merchant: "Monthly salary",
    amount: 185000,
    category: "Salary",
    account: "Checking",
    type: "income",
  },
  {
    merchant: "Dialog",
    amount: 1990,
    category: "Utilities",
    account: "Checking",
    type: "expense",
  },
];

const SAMPLES: Record<CaptureMode, { label: string; value: string }[]> = {
  text: [
    { label: "Coffee 450", value: "Coffee 450" },
    { label: "Uber 1,200", value: "Uber 1200" },
    { label: "Rent 85,000", value: "Rent 85000" },
  ],
  sms: [
    {
      label: "Keells debit",
      value:
        "LKR 2,400.00 debited from A/C **4521 at KEELLS SUPER on 17 Sep. Avl bal 48,210.00",
    },
    {
      label: "Salary credit",
      value:
        "LKR 185,000.00 credited to A/C **4521 from ACME PAYROLL on 01 Sep. Avl bal 233,410.00",
    },
  ],
  receipt: [
    { label: "Cafe receipt", value: "receipt-cafe" },
    { label: "Grocery bill", value: "receipt-grocery" },
  ],
};

function parseDemo(mode: CaptureMode, raw: string): DemoTx | null {
  if (mode === "receipt") {
    if (raw === "receipt-grocery") {
      return {
        merchant: "Keells Super",
        amount: 2400,
        category: "Groceries",
        account: "Checking",
        type: "expense",
      };
    }
    return {
      merchant: "The Coffee Bean",
      amount: 890,
      category: "Dining",
      account: "Checking",
      type: "expense",
    };
  }

  const text = raw.trim();
  if (!text) return null;
  const amountMatch = text.replace(/,/g, "").match(/(\d+(?:\.\d{1,2})?)/);
  const amount = amountMatch ? Number(amountMatch[1]) : 0;
  if (!amount) return null;

  const isIncome = /credit|salary|payroll|deposited|received/i.test(text);
  const merchantSource = text
    .replace(/lkr|usd|rs\.?/gi, " ")
    .replace(amountMatch?.[0] ?? "", " ")
    .replace(/debited|credited|from|at|on|a\/c|\*+/gi, " ")
    .replace(/\s+/g, " ")
    .trim();

  const lower = text.toLowerCase();
  let category = "Other";
  if (/coffee|cafe|lunch|dinner|restaurant|bean/i.test(lower)) category = "Dining";
  else if (/keells|grocery|food city|keels/i.test(lower)) category = "Groceries";
  else if (/uber|pickme|taxi|fuel|petrol/i.test(lower)) category = "Transport";
  else if (/rent|lease/i.test(lower)) category = "Housing";
  else if (/salary|payroll/i.test(lower)) category = "Salary";
  else if (/dialog|utility|bill/i.test(lower)) category = "Utilities";

  return {
    merchant:
      merchantSource.split(" ").slice(0, 4).join(" ") ||
      (isIncome ? "Incoming" : "Expense"),
    amount,
    category,
    account: "Checking",
    type: isIncome || /salary|credit/i.test(lower) ? "income" : "expense",
  };
}

export function HomeLanding() {
  const [mode, setMode] = useState<CaptureMode>("text");
  const [input, setInput] = useState("Coffee 450");
  const [busy, setBusy] = useState(false);
  const [draft, setDraft] = useState<DemoTx | null>(null);
  const [ledger, setLedger] = useState<DemoTx[]>(STARTER);

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
      toast.error("Try something with an amount, like Coffee 450");
      return;
    }
    setDraft(parsed);
  }

  function confirmDraft() {
    if (!draft) return;
    setLedger((rows) => [draft, ...rows].slice(0, 6));
    setDraft(null);
    toast.success("Saved in the demo — in the real app you confirm the same way.");
  }

  return (
    <main className="auth-shell">
      <header className="sticky top-0 z-20 border-b border-[var(--border)]/80 bg-[var(--background)]/80 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-3 px-4 sm:px-6">
          <Link href="/" aria-label="Smart Money Manager home">
            <BrandMark size="sm" priority />
          </Link>
          <nav className="hidden items-center gap-6 text-sm font-medium text-[var(--muted)] md:flex">
            <a href="#demo" className="hover:text-[var(--foreground)]">
              Try it
            </a>
            <a href="#why" className="hover:text-[var(--foreground)]">
              What’s new
            </a>
            <a href="#app" className="hover:text-[var(--foreground)]">
              The app
            </a>
          </nav>
          <div className="flex items-center gap-2">
            <Button asChild variant="ghost" size="sm">
              <Link href="/login">Sign in</Link>
            </Button>
            <Button asChild size="sm">
              <Link href="/signup">Get started</Link>
            </Button>
          </div>
        </div>
      </header>

      <section className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.05fr_0.95fr] md:py-20">
        <div className="stagger max-w-xl">
          <Badge variant="accent" className="w-fit gap-1.5 px-2.5 py-1">
            <Sparkles className="h-3 w-3" />
            Confirm-first AI capture
          </Badge>
          <h1 className="mt-4 font-display text-4xl leading-[1.08] tracking-tight text-[var(--foreground)] sm:text-5xl md:text-[3.4rem]">
            Spend smarter. Save better. Live better.
          </h1>
          <p className="mt-5 text-base leading-relaxed text-[var(--muted)] md:text-lg">
            Most money apps wait for you to type. This one reads a receipt,
            a bank SMS, or{" "}
            <span className="font-medium text-[var(--foreground)]">
              “Coffee 450”
            </span>{" "}
            — fills the form — then{" "}
            <span className="font-medium text-[var(--foreground)]">
              waits for you to confirm
            </span>
            . AI never auto-saves.
          </p>
          <div className="mt-8 flex w-full flex-col gap-3 sm:flex-row">
            <Button asChild size="lg" className="w-full sm:w-auto">
              <Link href="/signup">Start tracking free</Link>
            </Button>
            <Button asChild variant="outline" size="lg" className="w-full sm:w-auto">
              <a href="#demo">Try a 10-second demo</a>
            </Button>
          </div>
          <p className="mt-4 text-xs text-[var(--muted-fg)]">
            No bank login required. Your data stays in your own Supabase project.
          </p>
        </div>

        <div className="relative">
          <AppPreview
            ledger={ledger}
            income={income}
            expense={expense}
            grocerySpend={grocerySpend}
          />
        </div>
      </section>

      <section id="why" className="mx-auto max-w-6xl px-4 pb-6 sm:px-6">
        <div className="grid gap-3 md:grid-cols-3">
          {[
            {
              icon: ShieldCheck,
              title: "You stay in control",
              body: "The novelty isn’t “AI spends for you.” It’s that capture is instant and saving is always a human yes.",
            },
            {
              icon: ClipboardPaste,
              title: "Built for real-life capture",
              body: "Photo a receipt, paste a bank alert, or type one line. That’s how money actually shows up on your phone.",
            },
            {
              icon: Wallet,
              title: "Then it looks like a ledger",
              body: "Wallets, live balances, 80% budget warnings, recurring bills, and charts — once the entry is confirmed.",
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

      <section id="demo" className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
        <div className="mb-6 max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--accent-hover)]">
            Interactive demo
          </p>
          <h2 className="mt-2 font-display text-3xl tracking-tight">
            Add an expense the new way
          </h2>
          <p className="mt-2 text-[var(--muted)]">
            This runs in your browser — no signup. Confirm it and watch the
            preview ledger on the right update, just like the real app.
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
                    setInput(SAMPLES[id][0].value);
                  }}
                  className={cn(
                    "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors",
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
                      ? "Keells Super"
                      : "The Coffee Bean"}
                  </p>
                  <p className="text-sm text-[var(--muted)]">
                    {input === "receipt-grocery" ? "LKR 2,400.00" : "LKR 890.00"}
                  </p>
                  <p className="mt-3 text-xs text-[var(--accent-hover)]">
                    Tap to read · in the app this is your camera
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
                      ? "Paste a bank SMS…"
                      : "Coffee 450"
                  }
                />
              )}

              <div className="flex flex-wrap gap-2">
                {SAMPLES[mode].map((sample) => (
                  <button
                    key={sample.label}
                    type="button"
                    className="rounded-full border border-[var(--border)] px-3 py-1 text-xs text-[var(--muted)] hover:border-[var(--border-strong)] hover:text-[var(--foreground)]"
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
                Picking out the amount and details…
              </p>
            ) : draft ? (
              <div className="mt-4 space-y-4">
                <div>
                  <p className="font-display text-3xl tabular-nums">
                    {formatMoney(draft.amount, "LKR")}
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
                  This is the confirm step. Nothing hits your real ledger until
                  you say so.
                </p>
                <div className="flex gap-2">
                  <Button onClick={confirmDraft}>Confirm &amp; add</Button>
                  <Button variant="outline" onClick={() => setDraft(null)}>
                    Discard
                  </Button>
                </div>
              </div>
            ) : (
              <div className="mt-6 text-sm leading-relaxed text-[var(--muted)]">
                <p>Try a sample above. You’ll get a draft like the in-app review modal — then confirm it into the live preview.</p>
              </div>
            )}
          </div>
        </div>
      </section>

      <section id="app" className="mx-auto max-w-6xl px-4 pb-16 sm:px-6">
        <div className="mb-6 max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--accent-hover)]">
            How the app feels
          </p>
          <h2 className="mt-2 font-display text-3xl tracking-tight">
            Home, add, activity — built for daily use
          </h2>
          <p className="mt-2 text-[var(--muted)]">
            After confirm, it behaves like a proper money manager: accounts with
            live balances, budget bars, analytics, and recurring bills.
          </p>
        </div>
        <AppPreview
          ledger={ledger}
          income={income}
          expense={expense}
          grocerySpend={grocerySpend}
          large
        />

        <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {[
            ["Multi-account wallets", "Cash, checking, savings, credit — balances stay in sync."],
            ["Budget alerts", "80% warn, 100% over. See it on Home, not a spreadsheet."],
            ["Analytics", "Category spend and income vs expense over six months."],
            ["Recurring & FX", "Mark bills as repeating. Track multiple currencies."],
          ].map(([title, body]) => (
            <div key={title} className="surface p-4">
              <p className="font-semibold">{title}</p>
              <p className="mt-1 text-sm text-[var(--muted)]">{body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-[var(--border)]">
        <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-6 px-4 py-14 sm:px-6 md:flex-row md:items-center">
          <div>
            <h2 className="font-display text-3xl tracking-tight">
              Ready to capture money in seconds?
            </h2>
            <p className="mt-2 max-w-lg text-[var(--muted)]">
              Create an account, add a wallet, then scan, paste, or describe.
              You confirm every AI draft.
            </p>
          </div>
          <div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
            <Button asChild size="lg">
              <Link href="/signup">Get started</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/login">I already have an account</Link>
            </Button>
          </div>
        </div>
      </section>
    </main>
  );
}

function AppPreview({
  ledger,
  income,
  expense,
  grocerySpend,
  large = false,
}: {
  ledger: DemoTx[];
  income: number;
  expense: number;
  grocerySpend: number;
  large?: boolean;
}) {
  const groceryLimit = 15000;
  const groceryRatio = Math.min(1, grocerySpend / groceryLimit);

  return (
    <div
      className={cn(
        "overflow-hidden rounded-[20px] border border-[var(--border)] bg-[var(--surface)] shadow-[var(--shadow-lg)]",
        !large && "rotate-[0.4deg]"
      )}
    >
      <div className="flex items-center gap-1.5 border-b border-[var(--border)] bg-[var(--background)] px-3 py-2">
        <span className="h-2 w-2 rounded-full bg-[#f43f5e]/80" />
        <span className="h-2 w-2 rounded-full bg-[#f59e0b]/80" />
        <span className="h-2 w-2 rounded-full bg-[#10b981]/80" />
        <span className="ml-2 text-[11px] text-[var(--muted-fg)]">
          Home · Smart Money Manager
        </span>
      </div>
      <div className="flex min-h-[280px]">
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
        <div className="flex-1 space-y-3 bg-[var(--background)] p-4">
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
                {formatMoney(income, "LKR")}
              </p>
            </div>
            <div className="surface p-3">
              <p className="text-[10px] uppercase tracking-wide text-[var(--muted)]">
                Spent
              </p>
              <p className="mt-1 text-sm font-semibold tabular-nums">
                {formatMoney(expense, "LKR")}
              </p>
            </div>
          </div>
          <div className="surface p-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-medium">Groceries</span>
              <span className="tabular-nums text-[var(--muted)]">
                {formatMoney(grocerySpend, "LKR")} / {formatMoney(groceryLimit, "LKR")}
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
                <div className="min-w-0">
                  <p className="truncate font-medium">{tx.merchant}</p>
                  <p className="text-[11px] text-[var(--muted)]">{tx.category}</p>
                </div>
                <p
                  className={cn(
                    "shrink-0 tabular-nums font-semibold",
                    tx.type === "income" && "text-[var(--success)]"
                  )}
                >
                  {tx.type === "income" ? "+" : "−"}
                  {formatMoney(tx.amount, "LKR")}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
