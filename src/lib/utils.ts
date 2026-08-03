import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatMoney(
  amount: number,
  currency = "USD",
  locale = "en-US"
): string {
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function budgetStatus(spent: number, limit: number) {
  if (limit <= 0) return "none" as const;
  const ratio = spent / limit;
  if (ratio >= 1) return "over" as const;
  if (ratio >= 0.8) return "warn" as const;
  return "ok" as const;
}
