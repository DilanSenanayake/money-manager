"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { LEGAL } from "@/lib/legal";

const storageKey = "smm_consent";

type StoredConsent = {
  version?: string;
  acceptedAt?: string;
  analytics?: boolean;
};

function updateAnalytics(granted: boolean) {
  const gtag = (
    window as Window & { gtag?: (...args: unknown[]) => void }
  ).gtag;
  if (!gtag) return;
  gtag("consent", "update", {
    analytics_storage: granted ? "granted" : "denied",
  });
}

export function ConsentBanner() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(storageKey);
      if (!raw) {
        setOpen(true);
        return;
      }
      const parsed = JSON.parse(raw) as StoredConsent;
      if (parsed.version !== LEGAL.consentVersion) {
        setOpen(true);
        return;
      }
      if (parsed.analytics) updateAnalytics(true);
    } catch {
      setOpen(true);
    }
  }, []);

  function save(analytics: boolean) {
    const record: StoredConsent = {
      version: LEGAL.consentVersion,
      acceptedAt: new Date().toISOString(),
      analytics,
    };
    localStorage.setItem(storageKey, JSON.stringify(record));
    updateAnalytics(analytics);
    setOpen(false);
  }

  if (!open) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 border-t border-[var(--border)] bg-[var(--surface)] px-4 py-4 shadow-[var(--shadow-md)]">
      <div className="mx-auto flex max-w-6xl flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <p className="max-w-3xl text-sm text-[var(--muted)]">
          {LEGAL.productName} uses essential storage to keep you signed in.
          Optional analytics stays off unless you allow it. Read the{" "}
          <Link href="/terms" className="font-medium text-[var(--foreground)] underline">
            Terms
          </Link>{" "}
          and{" "}
          <Link href="/privacy" className="font-medium text-[var(--foreground)] underline">
            Privacy Policy
          </Link>
          .
        </p>
        <div className="flex shrink-0 gap-2">
          <button
            type="button"
            className="h-11 rounded-[10px] border border-[var(--border)] px-3 text-sm font-medium"
            onClick={() => save(false)}
          >
            Essential only
          </button>
          <button
            type="button"
            className="h-11 rounded-[10px] bg-[var(--accent)] px-3 text-sm font-medium text-white"
            onClick={() => save(true)}
          >
            Allow analytics
          </button>
        </div>
      </div>
    </div>
  );
}
