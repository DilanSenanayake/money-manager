import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/legal/legal-page";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Delete your account",
};

export default function AccountDeletionPage() {
  return (
    <LegalPage
      title="Delete your account"
      description={`You can delete your ${LEGAL.productName} account and the money records stored with it without installing anything new.`}
      toc={[
        { id: "app", label: "In the app" },
        { id: "web", label: "On the website" },
        { id: "email", label: "By email" },
        { id: "what", label: "What is deleted" },
      ]}
    >
      <LegalSection id="app" title="1. In the Android app">
        <p>
          Open Settings, then Delete account. Enter your password. This removes
          the login and the wallets, transactions, budgets, and exchange rates
          tied to that login. It cannot be undone.
        </p>
      </LegalSection>
      <LegalSection id="web" title="2. On this website">
        <p>
          <Link className="font-medium text-[var(--accent-hover)] hover:underline" href="/login">
            Sign in
          </Link>
          , open Settings, and use the delete account control. You will be asked
          for your password.
        </p>
      </LegalSection>
      <LegalSection id="email" title="3. If you cannot sign in">
        <p>
          Email{" "}
          <a
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href={`mailto:${LEGAL.contactEmail}?subject=Delete%20my%20Smart%20Money%20Manager%20account`}
          >
            {LEGAL.contactEmail}
          </a>{" "}
          from the email address on the account. Say that you want the account
          deleted. {LEGAL.operatorName} will verify the request and delete or
          irreversibly anonymise the live records within {LEGAL.deletionDays}{" "}
          days, unless the law requires something to be kept longer.
        </p>
      </LegalSection>
      <LegalSection id="what" title="4. What is deleted">
        <p>
          The account, profile, wallets, transactions, categories, budgets,
          exchange rates, and Smart Add corrections stored for that user. Backup
          copies at the host may remain until they expire. Export a copy from
          Settings before you delete if you still want the records.
        </p>
        <p>
          Related:{" "}
          <Link className="font-medium text-[var(--accent-hover)] hover:underline" href="/privacy">
            Privacy Policy
          </Link>
          .
        </p>
      </LegalSection>
    </LegalPage>
  );
}
