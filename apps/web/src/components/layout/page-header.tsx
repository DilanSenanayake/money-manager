import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PageHeader({
  title,
  description,
  actions,
  className,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between",
        className
      )}
    >
      <div className="min-w-0 space-y-1">
        <h1 className="font-display text-2xl leading-tight tracking-tight text-[var(--foreground)] sm:text-[1.75rem] md:text-[2rem]">
          {title}
        </h1>
        {description ? (
          <p className="max-w-xl text-sm leading-relaxed text-[var(--muted)]">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? (
        <div className="flex w-full shrink-0 flex-wrap items-center gap-2 sm:w-auto [&>a]:w-full [&>button]:w-full sm:[&>a]:w-auto sm:[&>button]:w-auto">
          {actions}
        </div>
      ) : null}
    </div>
  );
}
