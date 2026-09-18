import type { Metadata } from "next";
import { getSiteUrl } from "@/lib/env";

export const SEO = {
  name: "Smart Money Manager",
  shortName: "Smart Money",
  title: "Smart Money Manager - Take control of your money",
  description:
    "See where your money goes. Add a purchase in seconds, confirm every save, and budget in your currency. Free to start. No bank login.",
  locale: "en_US",
} as const;

export function absoluteUrl(path = "/"): string {
  const base = getSiteUrl().replace(/\/$/, "");
  if (!path || path === "/") return base;
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}

export function publicMetadata({
  title,
  description,
  path,
  absoluteTitle = false,
}: {
  title: string;
  description: string;
  path: string;
  absoluteTitle?: boolean;
}): Metadata {
  const ogTitle = absoluteTitle ? title : `${title} · ${SEO.name}`;
  return {
    title: absoluteTitle ? { absolute: title } : title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: ogTitle,
      description,
      url: path,
      type: "website",
      locale: SEO.locale,
      siteName: SEO.name,
    },
    twitter: {
      card: "summary_large_image",
      title: ogTitle,
      description,
    },
    robots: { index: true, follow: true },
  };
}
