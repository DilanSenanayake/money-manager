import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/login", "/signup"],
      disallow: [
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
  };
}
