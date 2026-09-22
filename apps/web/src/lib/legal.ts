/**
 * Legal copy constants for the public Terms and Privacy pages.
 *
 * Assumptions (edit here when facts change):
 * - Operator is an individual personal project, not a registered company.
 * - Governing law: Sri Lanka (operator locale inferred from the project; change if wrong).
 * - Minimum age: 16.
 * - Core service is free today. Paid-plan language is included so it can apply if subscriptions are added.
 * - Refunds: no refund of the current paid period (digital service), except where required by law.
 * - Account deletion: within 30 days of a verified request, except where law requires longer retention.
 * - Contact inbox: NEXT_PUBLIC_LEGAL_CONTACT_EMAIL, falling back to the address below.
 * - Processors listed in privacy match the current stack: Supabase, Vercel, Groq, optional Google Analytics.
 * - The web app does not auto-read SMS or link bank accounts. Users paste, type, or optionally speak a short description and confirm saves.
 */
export const LEGAL = {
  productName: "Smart Money Manager",
  lastUpdated: "22 September 2026",
  minAge: 16,
  deletionDays: 30,
  jurisdiction: "Sri Lanka",
  courts: "the courts of Sri Lanka",
  contactEmail:
    process.env.NEXT_PUBLIC_LEGAL_CONTACT_EMAIL?.trim() ||
    "diladws@gmail.com",
} as const;

export const PROCESSORS = [
  {
    name: "Supabase",
    role: "Authentication and database",
    purpose:
      "Create and sign in to accounts, and store the money records you save.",
  },
  {
    name: "Vercel",
    role: "Website hosting and product analytics",
    purpose:
      "Serve the web app and measure visits through Vercel Web Analytics.",
  },
  {
    name: "Operator-hosted API",
    role: "Application server",
    purpose:
      "Run app logic and, when you use Smart Add, send text you submit for parsing.",
  },
  {
    name: "Groq",
    role: "AI text processing",
    purpose:
      "Suggest amounts, merchants, and categories from text you choose to submit. You still confirm before anything is saved.",
  },
  {
    name: "Google (optional)",
    role: "Analytics",
    purpose:
      "If a Google Analytics measurement ID is configured, measure how the site is used.",
  },
] as const;
