"use client";

import { createPortal } from "react-dom";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

type Props = {
  open: boolean;
  title?: string;
  message?: string;
  /** 0–1 when known (OCR); omit for indeterminate */
  progress?: number | null;
};

export function LoadingOverlay({
  open,
  title = "Working on it",
  message,
  progress = null,
}: Props) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!open) {
      document.body.style.overflow = "";
      return;
    }
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev || "";
    };
  }, [open]);

  if (!mounted || !open) return null;

  const pct =
    progress != null && Number.isFinite(progress)
      ? Math.min(100, Math.max(0, Math.round(progress * 100)))
      : null;

  return createPortal(
    <div
      className="loading-overlay fixed inset-0 z-100 flex items-center justify-center p-6"
      role="status"
      aria-live="polite"
      aria-busy="true"
    >
      <div className="absolute inset-0 bg-slate-950/45 backdrop-blur-md dark:bg-slate-950/65" />
      <div
        className="loading-overlay-card relative w-full max-w-sm overflow-hidden rounded-3xl border border-white/40 bg-white/95 p-8 shadow-2xl shadow-teal-900/20 dark:border-slate-700 dark:bg-slate-950/95"
      >
        <div className="pointer-events-none absolute -right-10 -top-10 h-36 w-36 rounded-full bg-teal-400/20 blur-2xl" />
        <div className="pointer-events-none absolute -bottom-12 -left-8 h-32 w-32 rounded-full bg-sky-400/15 blur-2xl" />

        <div className="relative flex flex-col items-center text-center">
          <div className="loading-ring mb-5" aria-hidden>
            <span className="loading-ring-core" />
          </div>

          <p className="font-display text-xl tracking-tight text-slate-900 dark:text-slate-50">
            {title}
          </p>
          {message && (
            <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">
              {message}
            </p>
          )}

          <div className="mt-6 w-full">
            <div className="h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
              <div
                className={cn(
                  "h-full rounded-full bg-linear-to-r from-teal-600 to-teal-400",
                  pct == null ? "loading-bar-indeterminate" : "transition-[width] duration-300 ease-out"
                )}
                style={pct != null ? { width: `${pct}%` } : undefined}
              />
            </div>
            {pct != null && (
              <p className="mt-2 text-xs font-medium tabular-nums text-teal-700 dark:text-teal-300">
                {pct}%
              </p>
            )}
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
}
