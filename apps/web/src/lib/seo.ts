import type { Metadata } from "next";
import { getSiteUrl } from "@/lib/env";

export const SEO = {
  name: "Smart Money Manager",
  shortName: "Smart Money",
  title: "Smart Money Manager - Your money, made easier",
  description:
    "An AI-assisted personal finance ledger. Record an expense from a line, a bank message, or a receipt. You confirm every save. Free to start. No bank login.",
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
