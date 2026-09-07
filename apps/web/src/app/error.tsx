"use client";

import { useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="mx-auto flex min-h-[50vh] max-w-lg flex-col items-center justify-center gap-4 px-4 py-16 text-center">
      <h1 className="font-display text-2xl font-semibold tracking-tight">
        Something went wrong
      </h1>
      <p className="text-sm text-[var(--muted)]">
        We couldn&apos;t load this page. Your money data is safe — try again in
        a moment.
      </p>
      <div className="flex flex-wrap justify-center gap-2">
        <Button type="button" onClick={reset}>
          Try again
        </Button>
        <Button type="button" variant="outline" asChild>
          <Link href="/dashboard">Go to Home</Link>
        </Button>
      </div>
    </main>
  );
}
