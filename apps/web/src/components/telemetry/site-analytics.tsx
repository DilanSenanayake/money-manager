import Script from "next/script";
import { GoogleAnalytics } from "@next/third-parties/google";
import { Analytics } from "@vercel/analytics/next";
import { getGaMeasurementId } from "@/lib/analytics";

export function SiteAnalytics() {
  const gaId = getGaMeasurementId();

  return (
    <>
      <Analytics />
      {gaId ? (
        <>
          <Script id="ga-privacy-defaults" strategy="beforeInteractive">
            {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('consent','default',{ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied',analytics_storage:'granted'});gtag('set',{anonymize_ip:true,allow_google_signals:false,allow_ad_personalization_signals:false});`}
          </Script>
          <GoogleAnalytics gaId={gaId} />
        </>
      ) : null}
    </>
  );
}
