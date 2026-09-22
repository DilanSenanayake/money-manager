import Link from "next/link";
import type { ComponentType } from "react";
import { cn } from "@/lib/utils";

export type ActionTile = {
  key: string;
  /** Visible label; omit or set hideLabel for icon-only tiles. */
  label?: string;
  /** Screen-reader / title text when label is hidden. */
  ariaLabel: string;
  icon: ComponentType<{ className?: string }>;
  href?: string;
  onClick?: () => void;
  active?: boolean;
  disabled?: boolean;
  hideLabel?: boolean;
};

export function ActionTiles({
  tiles,
  columns,
}: {
  tiles: ActionTile[];
  /** Override grid columns (default 4, or tile count when ≤2). */
  columns?: number;
}) {
  const cols = columns ?? (tiles.length <= 2 ? tiles.length : 4);

  return (
    <div
      className={cn(
        "stagger grid gap-2",
        cols === 2 && "grid-cols-2",
        cols === 3 && "grid-cols-3",
        cols === 4 && "grid-cols-4"
      )}
    >
      {tiles.map((tile) => {
        const Icon = tile.icon;
        const hideLabel = tile.hideLabel || !tile.label;
        const className = cn(
          "surface surface-interactive pressable flex flex-col items-center justify-center text-center",
          hideLabel
            ? "min-h-[3.5rem] px-2 py-3"
            : "min-h-[4.75rem] gap-1.5 px-1 py-2.5",
          tile.active &&
            "border-[var(--accent)] bg-[var(--accent-soft)] ring-2 ring-[var(--accent-ring)]"
        );
        const inner = (
          <>
            <span
              className={cn(
                "flex h-9 w-9 items-center justify-center rounded-lg",
                tile.active
                  ? "bg-[var(--accent)] text-[var(--accent-fg)]"
                  : "bg-[var(--accent-soft)] text-[var(--accent-hover)]"
              )}
            >
              <Icon className="h-5 w-5" />
            </span>
            {!hideLabel && tile.label ? (
              <span className="text-[11px] font-semibold leading-tight sm:text-xs">
                {tile.label}
              </span>
            ) : null}
          </>
        );

        if (tile.href) {
          return (
            <Link
              key={tile.key}
              href={tile.href}
              className={className}
              aria-label={tile.ariaLabel}
              title={tile.ariaLabel}
            >
              {inner}
            </Link>
          );
        }

        return (
          <button
            key={tile.key}
            type="button"
            disabled={tile.disabled}
            onClick={tile.onClick}
            aria-label={tile.ariaLabel}
            title={tile.ariaLabel}
            className={cn(className, "disabled:opacity-60")}
          >
            {inner}
          </button>
        );
      })}
    </div>
  );
}

/** Plain + for enter-details path. */
export function PlusTileIcon({ className }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.25"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      <path d="M5 12h14" />
      <path d="M12 5v14" />
    </svg>
  );
}
