import type { Metadata } from "next";
import { getSiteUrl } from "@/lib/env";

export const SEO = {
  name: "Smart Money Manager",
  shortName: "Smart Money",
  title: "Smart Money Manager - Add an expense in seconds",
  description:
    "Type a line, paste a bank message, or snap a receipt. AI fills the details so it takes a moment. You confirm the save. Free to start. No bank login.",
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
