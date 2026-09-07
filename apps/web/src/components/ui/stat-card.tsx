import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function StatCard({
  label,
  value,
  hint,
  tone = "default",
  className,
}: {
  label: string;
  value: ReactNode;
  hint?: string;
  tone?: "default" | "positive" | "negative";
  className?: string;
}) {
  return (
    <div
      className={cn(
        "surface flex flex-col gap-3 p-5",
        className
      )}
    >
      <p className="text-xs font-medium uppercase tracking-[0.08em] text-[var(--muted)]">
        {label}
      </p>
      <p
        className={cn(
          "font-display text-xl leading-tight tracking-tight tabular-nums break-all sm:text-[1.75rem] md:text-[2rem] md:leading-none",
          tone === "positive" && "text-[var(--success)]",
          tone === "negative" && "text-[var(--danger)]"
        )}
      >
        {value}
      </p>
      {hint ? (
        <p className="text-xs text-[var(--muted-fg)]">{hint}</p>
      ) : null}
    </div>
  );
}
