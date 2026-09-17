import Link from "next/link";
import type { ComponentType } from "react";
import { cn } from "@/lib/utils";

export type ActionTile = {
  key: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  href?: string;
  onClick?: () => void;
  active?: boolean;
  disabled?: boolean;
};

export function ActionTiles({ tiles }: { tiles: ActionTile[] }) {
  return (
    <div className="stagger grid grid-cols-4 gap-2">
      {tiles.map((tile) => {
        const Icon = tile.icon;
        const className = cn(
          "surface surface-interactive pressable flex min-h-[4.75rem] flex-col items-center justify-center gap-1.5 px-1 py-2.5 text-center",
          tile.active &&
            "border-[var(--accent)] bg-[var(--accent-soft)] ring-2 ring-[var(--accent-ring)]"
        );
        const inner = (
          <>
            <span
              className={cn(
                "flex h-8 w-8 items-center justify-center rounded-lg",
                tile.active
                  ? "bg-[var(--accent)] text-[var(--accent-fg)]"
                  : "bg-[var(--accent-soft)] text-[var(--accent-hover)]"
              )}
            >
              <Icon className="h-4 w-4" />
            </span>
            <span className="text-[11px] font-semibold leading-tight sm:text-xs">
              {tile.label}
            </span>
          </>
        );

        if (tile.href) {
          return (
            <Link key={tile.key} href={tile.href} className={className}>
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
            className={cn(className, "disabled:opacity-60")}
          >
            {inner}
          </button>
        );
      })}
    </div>
  );
}
