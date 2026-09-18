import type { Metadata } from "next";
import { HomeLanding } from "@/components/marketing/home-landing";

export const metadata: Metadata = {
  title: {
    absolute: "Smart Money Manager - Take control of your money",
  },
  description:
    "See where your money goes. Add a purchase in seconds, confirm every save, and budget in your currency. Free to start. No bank login.",
  robots: { index: true, follow: true },
};

export default function HomePage() {
  return <HomeLanding />;
}
