import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/legal/legal-page";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Open-source licenses",
  robots: { index: false, follow: false },
};

const notices = [
  ["Flutter", "BSD-3-Clause", "https://flutter.dev"],
  ["Dart", "BSD-3-Clause", "https://dart.dev"],
  ["Next.js", "MIT", "https://nextjs.org"],
  ["React", "MIT", "https://react.dev"],
  ["Supabase client libraries", "MIT", "https://supabase.com"],
  ["ASP.NET Core", "MIT", "https://dotnet.microsoft.com"],
] as const;

export default function LicensesPage() {
  return (
    <LegalPage
      title="Open-source licenses"
      description={`Major third-party software used to build ${LEGAL.productName}. The Android app also has a full license list in Settings.`}
      toc={[{ id: "notices", label: "Notices" }]}
    >
      <LegalSection id="notices" title="1. Notices">
        <p>
          {LEGAL.productName} includes open-source software. The names and
          license identifiers below are summaries. The Android app’s Settings
          screen lists the packages shipped in that build, including their
          license texts. This page does not replace those texts.
        </p>
        <ul className="list-disc space-y-2 pl-5">
          {notices.map(([name, license, href]) => (
            <li key={name}>
              <a
                className="font-medium text-[var(--accent-hover)] hover:underline"
                href={href}
              >
                {name}
              </a>{" "}
              — {license}
            </li>
          ))}
        </ul>
      </LegalSection>
    </LegalPage>
  );
}
