import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function HomePage() {
  return (
    <main className="app-grid relative min-h-screen overflow-hidden">
      <div className="mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-6 py-16">
        <p className="mb-4 text-sm font-semibold uppercase tracking-[0.2em] text-teal-700">
          Ledgerly
        </p>
        <h1 className="font-display max-w-3xl text-5xl leading-tight tracking-tight text-slate-900 md:text-6xl dark:text-slate-50">
          Money, tracked with clarity.
        </h1>
        <p className="mt-5 max-w-xl text-lg text-slate-600 dark:text-slate-300">
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
    </main>
  );
}
