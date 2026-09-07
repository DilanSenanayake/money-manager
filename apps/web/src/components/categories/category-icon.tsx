import type { LucideIcon } from "lucide-react";
import {
  Briefcase,
  Car,
  Circle,
  Film,
  Heart,
  Home,
  ShoppingBag,
  ShoppingCart,
  TrendingUp,
  Utensils,
  Wallet,
  Zap,
} from "lucide-react";
import { cn } from "@/lib/utils";

/** Lucide icons keyed by category.icon values seeded in the DB. */
const CATEGORY_ICONS: Record<string, LucideIcon> = {
  wallet: Wallet,
  briefcase: Briefcase,
  "trending-up": TrendingUp,
  "shopping-cart": ShoppingCart,
  utensils: Utensils,
  car: Car,
  "shopping-bag": ShoppingBag,
  zap: Zap,
  heart: Heart,
  film: Film,
  home: Home,
  circle: Circle,
};

export type CategoryColor = {
  /** Soft tile background */
  bg: string;
  /** Icon / emphasis text */
  fg: string;
  /** Unselected chip */
  chip: string;
  /** Selected chip */
  chipSelected: string;
};

const CATEGORY_COLORS: Record<string, CategoryColor> = {
  wallet: {
    bg: "bg-teal-100",
    fg: "text-teal-800",
    chip: "border-teal-200 bg-teal-50 text-teal-800",
    chipSelected: "border-teal-700 bg-teal-700 text-white",
  },
  briefcase: {
    bg: "bg-slate-200",
    fg: "text-slate-800",
    chip: "border-slate-300 bg-slate-100 text-slate-800",
    chipSelected: "border-slate-700 bg-slate-700 text-white",
  },
  "trending-up": {
    bg: "bg-emerald-100",
    fg: "text-emerald-800",
    chip: "border-emerald-200 bg-emerald-50 text-emerald-800",
    chipSelected: "border-emerald-700 bg-emerald-700 text-white",
  },
  "shopping-cart": {
    bg: "bg-lime-100",
    fg: "text-lime-800",
    chip: "border-lime-200 bg-lime-50 text-lime-900",
    chipSelected: "border-lime-700 bg-lime-700 text-white",
  },
  utensils: {
    bg: "bg-orange-100",
    fg: "text-orange-800",
    chip: "border-orange-200 bg-orange-50 text-orange-900",
    chipSelected: "border-orange-600 bg-orange-600 text-white",
  },
  car: {
    bg: "bg-sky-100",
    fg: "text-sky-800",
    chip: "border-sky-200 bg-sky-50 text-sky-900",
    chipSelected: "border-sky-700 bg-sky-700 text-white",
  },
  "shopping-bag": {
    bg: "bg-fuchsia-100",
    fg: "text-fuchsia-800",
    chip: "border-fuchsia-200 bg-fuchsia-50 text-fuchsia-900",
    chipSelected: "border-fuchsia-700 bg-fuchsia-700 text-white",
  },
  zap: {
    bg: "bg-amber-100",
    fg: "text-amber-900",
    chip: "border-amber-200 bg-amber-50 text-amber-900",
    chipSelected: "border-amber-600 bg-amber-600 text-white",
  },
  heart: {
    bg: "bg-rose-100",
    fg: "text-rose-800",
    chip: "border-rose-200 bg-rose-50 text-rose-900",
    chipSelected: "border-rose-600 bg-rose-600 text-white",
  },
  film: {
    bg: "bg-violet-100",
    fg: "text-violet-800",
    chip: "border-violet-200 bg-violet-50 text-violet-900",
    chipSelected: "border-violet-700 bg-violet-700 text-white",
  },
  home: {
    bg: "bg-cyan-100",
    fg: "text-cyan-900",
    chip: "border-cyan-200 bg-cyan-50 text-cyan-900",
    chipSelected: "border-cyan-700 bg-cyan-700 text-white",
  },
  circle: {
    bg: "bg-stone-200",
    fg: "text-stone-700",
    chip: "border-stone-300 bg-stone-100 text-stone-800",
    chipSelected: "border-stone-600 bg-stone-600 text-white",
  },
};

const FALLBACK_COLORS: CategoryColor[] = [
  CATEGORY_COLORS.car,
  CATEGORY_COLORS.utensils,
  CATEGORY_COLORS.heart,
  CATEGORY_COLORS.zap,
  CATEGORY_COLORS["shopping-cart"],
  CATEGORY_COLORS.home,
  CATEGORY_COLORS.film,
  CATEGORY_COLORS.wallet,
];

export const CATEGORY_ICON_OPTIONS = [
  { id: "shopping-cart", label: "Groceries" },
  { id: "utensils", label: "Dining" },
  { id: "car", label: "Transport" },
  { id: "shopping-bag", label: "Shopping" },
  { id: "zap", label: "Utilities" },
  { id: "heart", label: "Health" },
  { id: "film", label: "Entertainment" },
  { id: "home", label: "Home / Rent" },
  { id: "wallet", label: "Salary" },
  { id: "briefcase", label: "Work" },
  { id: "trending-up", label: "Investments" },
  { id: "circle", label: "Other" },
] as const;

export function getCategoryIcon(icon?: string | null): LucideIcon {
  if (!icon) return Circle;
  return CATEGORY_ICONS[icon] ?? Circle;
}

function hashKey(key: string): number {
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) | 0;
  return Math.abs(h);
}

const FALLBACK_HEX = [
  "#0284c7",
  "#ea580c",
  "#e11d48",
  "#d97706",
  "#65a30d",
  "#0e7490",
  "#7c3aed",
  "#0f766e",
];

const CATEGORY_HEX: Record<string, string> = {
  wallet: "#0f766e",
  briefcase: "#334155",
  "trending-up": "#047857",
  "shopping-cart": "#4d7c0f",
  utensils: "#ea580c",
  car: "#0284c7",
  "shopping-bag": "#c026d3",
  zap: "#d97706",
  heart: "#e11d48",
  film: "#7c3aed",
  home: "#0e7490",
  circle: "#57534e",
};

const NAME_TO_ICON: Record<string, string> = {
  salary: "wallet",
  freelance: "briefcase",
  investments: "trending-up",
  groceries: "shopping-cart",
  dining: "utensils",
  transport: "car",
  shopping: "shopping-bag",
  utilities: "zap",
  health: "heart",
  entertainment: "film",
  rent: "home",
  other: "circle",
};

export function getCategoryHex(
  icon?: string | null,
  name?: string | null
): string {
  if (icon && CATEGORY_HEX[icon]) return CATEGORY_HEX[icon];
  const fromName = name ? NAME_TO_ICON[name.toLowerCase()] : undefined;
  if (fromName && CATEGORY_HEX[fromName]) return CATEGORY_HEX[fromName];
  const key = (name || icon || "other").toLowerCase();
  return FALLBACK_HEX[hashKey(key) % FALLBACK_HEX.length];
}

export function getCategoryColor(
  icon?: string | null,
  name?: string | null
): CategoryColor {
  if (icon && CATEGORY_COLORS[icon]) return CATEGORY_COLORS[icon];
  const key = (name || icon || "other").toLowerCase();
  return FALLBACK_COLORS[hashKey(key) % FALLBACK_COLORS.length];
}

type CategoryIconProps = {
  icon?: string | null;
  name?: string | null;
  className?: string;
  /** Soft colored tile behind the glyph */
  framed?: boolean;
};

export function CategoryIcon({
  icon,
  name,
  className,
  framed = false,
}: CategoryIconProps) {
  const Icon = getCategoryIcon(icon);
  const color = getCategoryColor(icon, name);

  if (!framed) {
    return (
      <Icon
        className={cn("h-4 w-4 shrink-0", color.fg, className)}
        aria-hidden
      />
    );
  }

  return (
    <span
      className={cn(
        "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
        color.bg,
        color.fg,
        className
      )}
      aria-hidden
    >
      <Icon className="h-4 w-4" />
    </span>
  );
}

type CategoryChipProps = {
  icon?: string | null;
  name: string;
  selected?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
};

/** Colored category pill for pickers. */
export function CategoryChip({
  icon,
  name,
  selected = false,
  disabled = false,
  onClick,
  className,
}: CategoryChipProps) {
  const color = getCategoryColor(icon, name);

  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95 disabled:opacity-60",
        selected ? color.chipSelected : color.chip,
        className
      )}
    >
      <CategoryIcon icon={icon} name={name} className="h-3.5 w-3.5" />
      {name}
    </button>
  );
}
