import { LEGAL } from "@/lib/legal";
import { SEO, absoluteUrl } from "@/lib/seo";

export function HomeJsonLd() {
  const url = absoluteUrl("/");
  const data = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        name: SEO.name,
        url,
        description: SEO.description,
        inLanguage: "en",
      },
      {
        "@type": "WebApplication",
        name: SEO.name,
        url,
        applicationCategory: "FinanceApplication",
        operatingSystem: "Web",
        description: SEO.description,
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "USD",
        },
        creator: {
          "@type": "Person",
          email: LEGAL.contactEmail,
        },
      },
    ],
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}
