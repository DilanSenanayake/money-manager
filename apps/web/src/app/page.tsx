import type { Metadata } from "next";
import { HomeLanding } from "@/components/marketing/home-landing";

export const metadata: Metadata = {
  title: {
    absolute:
      "Smart Money Manager — Spend smarter. Save better. Live better.",
  },
  description:
    "Capture spending from receipts, bank SMS, or one line of text. AI fills the form; you always confirm before save. Wallets, budgets, and analytics in one place.",
  robots: { index: true, follow: true },
};

export default function HomePage() {
  return <HomeLanding />;
}
