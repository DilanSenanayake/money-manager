import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function HomePage() {
  return (
    <main className="auth-shell relative min-h-screen overflow-hidden">
      <div className="relative mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-6 py-16">
        <div className="stagger max-w-2xl">
          <div className="mb-6 inline-flex items-center gap-2.5">
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-[var(--accent)] text-sm font-bold text-[var(--accent-fg)]">
              L
            </span>
            <span className="text-sm font-semibold tracking-tight text-[var(--accent-hover)]">
              Ledgerly
            </span>
          </div>
          <h1 className="font-display text-4xl leading-[1.1] tracking-tight text-[var(--foreground)] md:text-6xl">
            Money, tracked with clarity.
          </h1>
          <p className="mt-5 max-w-xl text-base leading-relaxed text-[var(--muted)] md:text-lg">
            Log spending in about 30 seconds — scan a receipt, paste a bank SMS,
            or type one line. You always confirm before anything hits your ledger.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Button asChild size="lg">
              <Link href="/signup">Get started</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/login">Sign in</Link>
            </Button>
          </div>
        </div>
      </div>
    </main>
  );
}
