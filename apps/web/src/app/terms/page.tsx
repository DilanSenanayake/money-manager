import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/legal/legal-page";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Terms of Use",
  robots: { index: false, follow: false },
};

const toc = [
  { id: "agreement", label: "Agreement" },
  { id: "definitions", label: "Definitions" },
  { id: "eligibility", label: "Eligibility" },
  { id: "accounts", label: "Accounts" },
  { id: "service", label: "The service" },
  { id: "paid", label: "Paid plans" },
  { id: "acceptable-use", label: "Acceptable use" },
  { id: "ip", label: "Intellectual property" },
  { id: "not-advice", label: "Not advice" },
  { id: "disclaimers", label: "Disclaimers" },
  { id: "liability", label: "Liability" },
  { id: "termination", label: "Termination" },
  { id: "changes", label: "Changes" },
  { id: "law", label: "Law and disputes" },
  { id: "contact", label: "Contact" },
];

export default function TermsPage() {
  return (
    <LegalPage
      title="Terms of Use"
      description={`These terms explain how you may use ${LEGAL.productName}. They are a binding agreement between you and the operator of the Service.`}
      toc={toc}
    >
      <LegalSection id="agreement" title="1. Purpose and acceptance">
        <p>
          {LEGAL.productName} (the “Service”) is a personal budgeting and money
          tracking tool. It helps you record income and spending, set category
          limits, and review your own numbers. It is provided by the person who
          operates the Service (the “Operator”).
        </p>
        <p>
          By creating an account, checking the agreement box at sign-up, or
          using the Service, you accept these Terms of Use (the “Terms”). If you
          do not agree, do not use the Service.
        </p>
      </LegalSection>

      <LegalSection id="definitions" title="2. Definitions">
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong>You</strong> means the person who uses the Service.
          </li>
          <li>
            <strong>Content</strong> means information you enter or upload,
            including display name, wallets, transactions, budgets, notes,
            receipt photos you choose, and text you paste (such as a bank
            message).
          </li>
          <li>
            <strong>Smart Add</strong> means optional helpers that suggest
            fields from a receipt photo, pasted text, or a short description.
            Suggestions are not saved until you confirm.
          </li>
        </ul>
      </LegalSection>

      <LegalSection id="eligibility" title="3. Eligibility">
        <p>
          You must be at least {LEGAL.minAge} years old to use the Service. If
          you are under the age of majority where you live, you may use the
          Service only with the consent of a parent or guardian who also agrees
          to these Terms. You may not use the Service if you are not allowed to
          form a contract where you live.
        </p>
      </LegalSection>

      <LegalSection id="accounts" title="4. Accounts and your responsibilities">
        <p>
          You must provide a working email address, a password, and other
          details the sign-up form asks for (such as a display name and base
          currency). Keep that information accurate. You are responsible for
          activity on your account and for keeping your password secret. Tell
          the Operator promptly if you think someone else used your account.
        </p>
        <p>
          Do not share your login. Do not use another person’s account. The
          Operator may refuse, suspend, or close an account that is incomplete,
          misleading, or used in a way that breaks these Terms.
        </p>
      </LegalSection>

      <LegalSection id="service" title="5. Description of the service">
        <p>When you have an account, the Service may let you:</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>Create wallets and record income, spending, and transfers.</li>
          <li>Set budgets, recurring items, and exchange rates you enter.</li>
          <li>View summaries and charts based on data you saved.</li>
          <li>
            Use Smart Add: take or choose a receipt photo (text is read on your
            device when possible), paste a bank message yourself, or type one
            line. The Service may suggest fields. You review and confirm before
            a record is stored.
          </li>
        </ul>
        <p>
          The Service does not open or connect to your bank. It does not read
          your SMS inbox on its own. It does not move money, issue cards, or
          hold deposits.
        </p>
        <p>
          Features can change as the project grows. The Operator may add, pause,
          or remove functions, including Smart Add, when models, hosting, or
          costs require it.
        </p>
      </LegalSection>

      <LegalSection id="paid" title="6. Payment, renewal, cancellation, and refunds">
        <p>
          The Service is currently offered free of charge. You do not need a
          payment method to create an account.
        </p>
        <p>
          If the Operator later offers paid plans (for example a monthly or
          yearly Plus plan), the price, currency, billing period, and included
          features will be shown in the app or at checkout before you pay. Paid
          plans are billed in advance and renew automatically at the then-current
          price until you cancel. You can cancel at any time in account settings
          (when that control exists) or by emailing the Operator from the address
          on your account. Cancellation stops the next renewal. You keep access
          until the end of the period you already paid for.
        </p>
        <p>
          Fees paid for the current period are not refunded, including unused
          time, unless a law where you live requires a refund. The Operator does
          not give credits for partial months. Taxes, if any, are extra unless
          the checkout page says they are included. Failed payments may lead to
          loss of paid features after a short grace period.
        </p>
        <p>
          Price changes apply from the next renewal. The Operator will give
          reasonable notice (for example in the app or by email) before a
          renewal at a new price.
        </p>
      </LegalSection>

      <LegalSection id="acceptable-use" title="7. Acceptable use">
        <p>You agree not to:</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>
            Use the Service for fraud, money laundering, or any other illegal
            purpose.
          </li>
          <li>
            Try to break, overload, or probe the Service, or bypass security.
          </li>
          <li>
            Copy, reverse engineer, or resell the software except as the law
            allows.
          </li>
          <li>
            Upload malware, scrape other users’ data, or interfere with anyone
            else’s use.
          </li>
          <li>
            Submit content you do not have the right to use, or content that is
            hateful, sexual involving minors, or otherwise unlawful.
          </li>
        </ul>
        <p>
          The Operator may investigate suspected abuse and cooperate with lawful
          requests from authorities.
        </p>
      </LegalSection>

      <LegalSection id="ip" title="8. Intellectual property and your content">
        <p>
          The Operator and licensors own the Service: software, design, name,
          and logos. These Terms do not transfer that ownership. You receive a
          limited, personal, non-exclusive right to use the Service for your own
          household or personal bookkeeping.
        </p>
        <p>
          You keep the rights you already have in your Content. You grant the
          Operator a limited licence to host, process, and display that Content
          only as needed to run the Service for you (including sending text you
          submit to the AI processor when you use Smart Add). That licence ends
          when your Content is deleted from the live systems, except for copies
          that remain briefly in backups or that the Operator must keep by law.
        </p>
      </LegalSection>

      <LegalSection id="not-advice" title="9. Not a bank, advisor, or investment service">
        <p>
          {LEGAL.productName} is a record-keeping and budgeting aid. It is not a
          bank, payment institution, credit provider, tax agent, broker, or
          licensed financial adviser. Nothing in the Service is legal, tax, or
          investment advice. Smart Add suggestions can be wrong. You are
          responsible for checking every draft and for decisions you make with
          your money. If you need professional advice, speak to a qualified
          person in your country.
        </p>
      </LegalSection>

      <LegalSection id="disclaimers" title="10. Disclaimer of warranties">
        <p>
          The Service is provided “as is” and “as available.” To the fullest
          extent the law allows, the Operator disclaims all warranties, whether
          express or implied, including fitness for a particular purpose,
          merchantability, and non-infringement. The Operator does not promise
          that the Service will be uninterrupted, error-free, or free of harmful
          components, or that totals, charts, or AI suggestions will be complete
          or correct.
        </p>
      </LegalSection>

      <LegalSection id="liability" title="11. Limitation of liability">
        <p>
          To the fullest extent the law allows, the Operator is not liable for
          lost profits, lost data, or indirect, incidental, special,
          consequential, or punitive damages arising from the Service or these
          Terms, even if told they were possible.
        </p>
        <p>
          The Operator’s total liability for all claims relating to the Service
          is limited to the greater of (a) the amount you paid the Operator for
          the Service in the three months before the claim, or (b) twenty US
          dollars (or the equivalent in your currency). Some places do not allow
          certain limits. In those places, the limit applies only as far as the
          law permits. Nothing in these Terms limits liability that cannot be
          limited, such as liability for death or personal injury caused by
          negligence where that cannot be excluded, or for fraud.
        </p>
      </LegalSection>

      <LegalSection id="termination" title="12. Termination">
        <p>
          You may stop using the Service at any time. You may ask the Operator
          to close your account using the contact details in these Terms or any
          in-app delete control if one is provided.
        </p>
        <p>
          The Operator may suspend or end your access at any time if you break
          these Terms, if the Service cannot be run safely, or if the personal
          project is shut down. Where reasonable, the Operator will try to give
          notice. After closure, your right to use the Service ends. Sections
          that should survive (including intellectual property, disclaimers,
          liability limits, and governing law) remain in effect.
        </p>
      </LegalSection>

      <LegalSection id="changes" title="13. Changes to these Terms">
        <p>
          The Operator may update these Terms. The “Last updated” date at the
          top will change. For material changes, the Operator will give notice
          in the app or by email to the address on your account when practical.
          If you continue to use the Service after the updated Terms take
          effect, you accept the new Terms. If you do not agree, stop using the
          Service and request account closure.
        </p>
      </LegalSection>

      <LegalSection id="law" title="14. Governing law and disputes">
        <p>
          These Terms are governed by the laws of {LEGAL.jurisdiction}, without
          regard to conflict-of-law rules. That choice does not take away
          consumer protections that cannot be waived in the country where you
          live.
        </p>
        <p>
          If a dispute arises, you and the Operator will first try to resolve it
          in good faith by email for at least 30 days. If that fails, either
          side may bring a claim in {LEGAL.courts}, except that you may bring a
          qualifying consumer claim in the courts of your place of residence
          when the law gives you that right.
        </p>
      </LegalSection>

      <LegalSection id="contact" title="15. Contact">
        <p>
          Questions about these Terms:{" "}
          <a
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href={`mailto:${LEGAL.contactEmail}`}
          >
            {LEGAL.contactEmail}
          </a>
          . Please write from the email on your account when you can, so the
          Operator can find your records.
        </p>
        <p>
          Related:{" "}
          <Link
            className="font-medium text-[var(--accent-hover)] hover:underline"
            href="/privacy"
          >
            Privacy Policy
          </Link>
          .
        </p>
      </LegalSection>
    </LegalPage>
  );
}
