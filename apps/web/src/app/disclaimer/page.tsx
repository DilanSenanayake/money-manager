import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/legal/legal-page";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Financial disclaimer",
  robots: { index: false, follow: false },
};

export default function DisclaimerPage() {
  return (
    <LegalPage
      title="Financial disclaimer"
      description={`${LEGAL.productName} records and budgets the numbers you enter. It does not advise you.`}
      toc={[
        { id: "not-advice", label: "Not advice" },
        { id: "accuracy", label: "Accuracy" },
      ]}
    >
      <LegalSection id="not-advice" title="1. Not financial, tax, or legal advice">
        <p>
          {LEGAL.productName} is a tracking and budgeting tool operated by{" "}
          {LEGAL.operatorName}. It is not a bank, payment service, lender,
          broker, tax agent, or licensed financial adviser. Nothing in the
          website or the Android app is financial, investment, tax, or legal
          advice.
        </p>
      </LegalSection>
      <LegalSection id="accuracy" title="2. Figures can be wrong">
        <p>
          Totals, budgets, charts, exchange rates, and Smart Add suggestions can
          be incomplete or inaccurate. Exchange rates are the ones you type. The
          app does not connect to your bank and does not move money. You are
          responsible for checking every entry before you rely on it.
        </p>
        <p>
          If you need a decision about your money, speak to a qualified person
          in your country. Related:{" "}
          <Link className="font-medium text-[var(--accent-hover)] hover:underline" href="/terms">
            Terms of Use
          </Link>
          .
        </p>
      </LegalSection>
    </LegalPage>
  );
}
