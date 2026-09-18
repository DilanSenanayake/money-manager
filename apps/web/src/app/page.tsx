import { HomeLanding } from "@/components/marketing/home-landing";
import { HomeJsonLd } from "@/components/seo/home-json-ld";
import { publicMetadata, SEO } from "@/lib/seo";

export const metadata = publicMetadata({
  title: SEO.title,
  description: SEO.description,
  path: "/",
  absoluteTitle: true,
});

export default function HomePage() {
  return (
    <>
      <HomeJsonLd />
      <HomeLanding />
    </>
  );
}
