"use client";

import Link from "next/link";
import type { ExchangeRate } from "@/lib/types";

function formatRateDate(value: string) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

export function RateGap({ currencies }: { currencies: string[] }) {
  if (currencies.length === 0) return null;
  const list = currencies.join(", ");
  return (
    <div className="rounded-[var(--radius-lg)] border border-[color-mix(in_oklab,var(--warn)_35%,var(--border))] bg-[var(--warn-soft)] px-4 py-3 text-sm leading-relaxed">
      <p>
        Add an exchange rate for {list} before a combined total can include
        that money. Until then, those amounts stay in their own currency.
      </p>
      <Link
        href="/settings"
        className="mt-2 inline-flex font-semibold text-[var(--accent-hover)] underline-offset-4 hover:underline"
      >
        Add a rate
      </Link>
    </div>
  );
}

export function RateStamp({ rates }: { rates: ExchangeRate[] }) {
  if (rates.length === 0) return null;
  return (
    <ul className="space-y-1 text-xs leading-relaxed text-[var(--muted)]">
      {rates.map((rate) => {
        const date = formatRateDate(rate.updated_at);
        return (
          <li key={rate.id}>
            Using your rate 1 {rate.from_currency} = {Number(rate.rate)}{" "}
            {rate.to_currency}
            {date ? `, entered ${date}` : ""}.
          </li>
        );
      })}
    </ul>
  );
}
