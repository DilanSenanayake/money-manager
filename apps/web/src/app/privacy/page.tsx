import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/legal/legal-page";
import { LEGAL, PROCESSORS } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Privacy Policy",
  robots: { index: false, follow: false },
};

const toc = [
  { id: "who", label: "Who we are" },
  { id: "collect", label: "What we collect" },
  { id: "purpose", label: "Why we use it" },
  { id: "bases", label: "Legal bases" },
  { id: "processors", label: "Processors" },
  { id: "transfers", label: "Transfers" },
  { id: "retention", label: "Retention" },
  { id: "rights", label: "Your rights" },
  { id: "cookies", label: "Cookies" },
  { id: "children", label: "Children" },
  { id: "security", label: "Security" },
  { id: "contact", label: "Contact" },
  { id: "changes", label: "Changes" },
];

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      description={`This policy describes how the operator of ${LEGAL.productName} handles information when you use the web app.`}
      toc={toc}
    >
      <LegalSection id="who" title="1. Who we are">
        <p>
          {LEGAL.productName} is provided by the Operator. The Operator decides
          how information is processed and is the controller of that information
          for privacy purposes.
        </p>
        <p>
          Contact:{" "}
          <a
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href={`mailto:${LEGAL.contactEmail}`}
          >
            {LEGAL.contactEmail}
          </a>
          .
        </p>
      </LegalSection>

      <LegalSection id="collect" title="2. What we collect">
        <p>
          We collect only what is needed to run a budgeting app you sign in to.
          We do not auto-read your SMS inbox. We do not connect to your bank.
        </p>
        <p className="font-semibold">Account information</p>
        <p>
          Email address, password (stored as a hash by the authentication
          provider, not as plain text), display name, and the base currency you
          choose.
        </p>
        <p className="font-semibold">Money records you enter</p>
        <p>
          Wallets, balances, transactions, categories, budgets, recurring flags,
          exchange rates you type, and optional notes or merchant names. This is
          information you add or confirm. It can include amounts and dates that
          are sensitive to you.
        </p>
        <p className="font-semibold">Smart Add submissions you choose to send</p>
        <p>
          If you use a receipt photo, text is typically read on your device
          first. Extracted text may be sent to the application server and an AI
          processor so fields can be suggested. If you paste a bank message or
          type a short description, that text is sent the same way. Drafts are
          not stored as saved transactions until you confirm. We do not ask the
          web app for permission to read all messages on your phone.
        </p>
        <p className="font-semibold">Technical and usage data</p>
        <p>
          IP address and basic request logs on hosting systems, browser type,
          pages you open while signed in or on public pages, and approximate
          time of use. Product analytics may record page views. If Google
          Analytics is turned on for the site, Google may also receive device
          and usage signals as described in Google’s own policy.
        </p>
        <p className="font-semibold">Cookies and similar storage</p>
        <p>
          Session and authentication cookies so you can stay signed in. Analytics
          cookies or similar identifiers if analytics tools are enabled. See
          Cookies below.
        </p>
        <p>
          We do not ask for your government ID, full bank login, or card number
          to use the free Service.
        </p>
      </LegalSection>

      <LegalSection id="purpose" title="3. Purpose of collection">
        <ul className="list-disc space-y-2 pl-5">
          <li>Create and secure your account, and sign you in.</li>
          <li>
            Store and show the money records you save, including budgets and
            charts.
          </li>
          <li>
            Run Smart Add when you ask for it, then wait for your confirmation.
          </li>
          <li>Keep the Service reliable, fix errors, and prevent abuse.</li>
          <li>
            Understand which pages are used so the Operator can improve the
            product.
          </li>
          <li>Reply to your requests, including access or deletion requests.</li>
          <li>Meet legal duties if a lawful request or obligation arises.</li>
        </ul>
        <p>
          We do not sell your personal information. We do not use your
          transaction list to advertise third-party financial products.
        </p>
      </LegalSection>

      <LegalSection id="bases" title="4. Legal bases for processing">
        <p>
          Where a consent, contract, and legitimate-interest model applies (for
          example in the European Economic Area and similar frameworks), we rely
          on:
        </p>
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong>Contract.</strong> Running your account and storing the
            records you ask us to keep.
          </li>
          <li>
            <strong>Consent.</strong> Optional Smart Add submissions, and
            non-essential analytics where consent is required. You can avoid
            Smart Add and still enter records by hand. You can also control
            cookies in your browser.
          </li>
          <li>
            <strong>Legitimate interests.</strong> Securing the Service,
            understanding aggregate use, and improving reliability, in ways that
            we believe do not override your rights.
          </li>
          <li>
            <strong>Legal obligation.</strong> Keeping or disclosing information
            when the law requires it.
          </li>
        </ul>
        <p>
          You may withdraw consent for optional processing without affecting
          processing that is still needed to provide an account you choose to
          keep.
        </p>
      </LegalSection>

      <LegalSection id="processors" title="5. Processors and sharing">
        <p>
          The Operator uses other organisations to host and run parts of the
          Service. They may process information only on instructions for those
          tasks, except where they act as independent controllers (for example
          some analytics tools).
        </p>
        <div className="overflow-x-auto rounded-[12px] border border-[var(--border)]">
          <table className="w-full min-w-[32rem] text-left text-sm">
            <thead className="bg-[var(--background)] text-[var(--muted)]">
              <tr>
                <th className="px-3 py-2 font-semibold">Provider</th>
                <th className="px-3 py-2 font-semibold">Role</th>
                <th className="px-3 py-2 font-semibold">Purpose</th>
              </tr>
            </thead>
            <tbody>
              {PROCESSORS.map((row) => (
                <tr key={row.name} className="border-t border-[var(--border)]">
                  <td className="px-3 py-2 font-medium">{row.name}</td>
                  <td className="px-3 py-2">{row.role}</td>
                  <td className="px-3 py-2 text-[var(--muted)]">{row.purpose}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          We may also share information if you ask us to, if we must comply with
          law or a valid legal process, or if the Operator transfers operation
          of this project to a successor who continues to respect this policy.
        </p>
      </LegalSection>

      <LegalSection id="transfers" title="6. International transfers">
        <p>
          You can use the Service from many countries. Hosting, authentication,
          and AI processing often take place in the United States or other
          locations outside your own country, including outside the European
          Economic Area. When information is transferred internationally, the
          Operator relies on the safeguards those providers offer (such as
          standard contractual clauses or an adequacy decision, where they
          apply) and on encryption in transit.
        </p>
        <p>
          By using the Service, you understand that your information may be
          processed in countries with privacy rules that differ from those at
          home.
        </p>
      </LegalSection>

      <LegalSection id="retention" title="7. How long we keep information">
        <p>
          Account and money records are kept while your account stays open, so
          the Service can show your history.
        </p>
        <p>
          If you ask us to delete your account, we will delete or irreversibly
          anonymise personal information in live systems within{" "}
          {LEGAL.deletionDays} days after we verify the request, unless we must
          keep something longer (for example a dispute, security incident, or
          legal duty). Backup copies may persist for a short extra period until
          they cycle out.
        </p>
        <p>
          Server logs and analytics events are kept only as long as needed for
          security and product improvement, then deleted or aggregated.
        </p>
      </LegalSection>

      <LegalSection id="rights" title="8. Your rights">
        <p>
          Depending on where you live, you may have some or all of the following
          rights. The Operator will honour them where they apply to this
          project:
        </p>
        <ul className="list-disc space-y-2 pl-5">
          <li>Access a copy of personal information we hold about you.</li>
          <li>Correct information that is wrong or incomplete.</li>
          <li>Delete your account and associated personal information.</li>
          <li>
            Receive a portable copy of money records you entered, when that is
            practical (for example a common file format).
          </li>
          <li>
            Object to or restrict certain processing, including optional
            analytics.
          </li>
          <li>
            Withdraw consent for optional features such as Smart Add text
            processing.
          </li>
        </ul>
        <p>
          Send requests to{" "}
          <a
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href={`mailto:${LEGAL.contactEmail}`}
          >
            {LEGAL.contactEmail}
          </a>{" "}
          from the email on your account. We may need to confirm it is you. You
          may also have the right to complain to a public authority in your
          country. If you are in California or another place with an “opt out of
          sale” right, we do not sell personal information as that idea is
          commonly defined, and we do not share it for cross-context behavioural
          advertising.
        </p>
      </LegalSection>

      <LegalSection id="cookies" title="9. Cookies and similar technologies">
        <p>
          Essential cookies (or similar browser storage) keep you signed in and
          protect the session. The Service cannot offer an account without them.
        </p>
        <p>
          Analytics tools may set their own cookies or use local storage to
          count visits and page views. Vercel Web Analytics is designed to be
          privacy-sparing. Google Analytics, if enabled, uses Google cookies as
          described by Google.
        </p>
        <p>
          You can block or delete cookies in your browser settings. If you block
          essential cookies, sign-in may fail. Blocking analytics cookies limits
          measurement but not your ability to record money by hand. Where a
          consent prompt is legally required and provided in the interface, we
          will honour the choice you make there.
        </p>
      </LegalSection>

      <LegalSection id="children" title="10. Children">
        <p>
          The Service is not directed at children under {LEGAL.minAge}. The
          Operator does not knowingly collect personal information from children
          under {LEGAL.minAge}. If you believe a child under that age created an
          account, contact us and we will delete it.
        </p>
      </LegalSection>

      <LegalSection id="security" title="11. Security">
        <p>
          The Operator uses reasonable technical and organisational measures
          appropriate to a personal web project: encrypted connections (HTTPS),
          hashed passwords at the authentication provider, access limited to
          systems needed to run the Service, and database rules so one account
          should not read another account’s rows. No method of storage or
          transmission is completely secure. You should use a strong unique
          password and keep your device locked.
        </p>
      </LegalSection>

      <LegalSection id="contact" title="12. Privacy requests">
        <p>
          For access, correction, deletion, or questions about this policy,
          email{" "}
          <a
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href={`mailto:${LEGAL.contactEmail}`}
          >
            {LEGAL.contactEmail}
          </a>
          . We aim to reply within a reasonable time.
        </p>
        <p>
          Related:{" "}
          <Link
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href="/terms"
          >
            Terms of Use
          </Link>
          .
        </p>
      </LegalSection>

      <LegalSection id="changes" title="13. Changes to this policy">
        <p>
          The Operator may update this policy. The “Last updated” date will
          change. Material changes will be announced in the app or by email when
          practical. Continued use after an update means you accept the revised
          policy. If you do not agree, stop using the Service and request
          deletion.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
