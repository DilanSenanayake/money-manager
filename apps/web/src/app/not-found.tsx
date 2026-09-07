import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-[50vh] max-w-lg flex-col items-center justify-center gap-4 px-4 py-16 text-center">
      <h1 className="font-display text-2xl font-semibold tracking-tight">
        Page not found
      </h1>
      <p className="text-sm text-[var(--muted)]">
        That link doesn&apos;t exist. Head back to your dashboard.
      </p>
      <Button asChild>
        <Link href="/dashboard">Go to Home</Link>
      </Button>
    </main>
  );
}
