import type { HTMLAttributes } from "react";
import { cn } from "@/lib/utils";

function Badge({
  className,
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "inline-flex items-center rounded-md border border-transparent bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700 dark:bg-slate-800 dark:text-slate-200",
        className
      )}
      {...props}
    />
  );
}

export { Badge };
