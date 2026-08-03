import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const CURRENCY_LOCALES: Record<string, string> = {
  USD: "en-US",
  EUR: "de-DE",
  GBP: "en-GB",
  LKR: "en-LK",
  INR: "en-IN",
  JPY: "ja-JP",
  AUD: "en-AU",
  CAD: "en-CA",
  CHF: "de-CH",
  SGD: "en-SG",
};

export function formatMoney(
  amount: number,
  currency = "USD",
  locale?: string
): string {
  const resolvedLocale = locale ?? CURRENCY_LOCALES[currency] ?? "en-US";
  try {
    return new Intl.NumberFormat(resolvedLocale, {
      style: "currency",
      currency,
      maximumFractionDigits: currency === "JPY" ? 0 : 2,
    }).format(amount);
  } catch {
    return `${Number(amount).toFixed(2)} ${currency}`;
  }
}

export function budgetStatus(spent: number, limit: number) {
  if (limit <= 0) return "none" as const;
  const ratio = spent / limit;
  if (ratio >= 1) return "over" as const;
  if (ratio >= 0.8) return "warn" as const;
  return "ok" as const;
}
