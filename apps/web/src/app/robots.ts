import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/seo";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: [
        "/terms",
        "/privacy",
        "/dashboard",
        "/add",
        "/transactions",
        "/accounts",
        "/budgets",
        "/analytics",
        "/recurring",
        "/settings",
        "/more",
        "/import",
      ],
    },
    sitemap: absoluteUrl("/sitemap.xml"),
    host: absoluteUrl("/"),
  };
}
