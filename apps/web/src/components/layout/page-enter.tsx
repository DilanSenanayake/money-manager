import { cn } from "@/lib/utils";

/** Subtle enter animation on first mount only — no remount on route change. */
export function PageEnter({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={cn("page-enter", className)}>{children}</div>;
}
