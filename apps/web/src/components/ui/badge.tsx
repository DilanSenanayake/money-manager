import type { HTMLAttributes } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold tracking-wide",
  {
    variants: {
      variant: {
        default:
          "bg-[var(--background)] text-[var(--muted)] border border-[var(--border)]",
        accent:
          "bg-[var(--accent-soft)] text-[var(--accent-hover)] border border-transparent",
        danger:
          "bg-[var(--danger-soft)] text-[var(--danger)] border border-transparent",
        warn:
          "bg-[var(--warn-soft)] text-[var(--warn)] border border-transparent",
        success:
          "bg-[var(--success-soft)] text-[var(--success)] border border-transparent",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
);

function Badge({
  className,
  variant,
  ...props
}: HTMLAttributes<HTMLDivElement> & VariantProps<typeof badgeVariants>) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  );
}

export { Badge, badgeVariants };
