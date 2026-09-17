import { GoogleAnalytics } from "@next/third-parties/google";
import { Analytics } from "@vercel/analytics/next";

function googleMeasurementId(): string | undefined {
  const id = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID?.trim();
  return id && /^G-[A-Z0-9]+$/i.test(id) ? id : undefined;
}

export function SiteAnalytics() {
  const gaId = googleMeasurementId();

  return (
    <>
      <Analytics />
      {gaId ? <GoogleAnalytics gaId={gaId} /> : null}
    </>
  );
}
