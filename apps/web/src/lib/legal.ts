/**
 * Legal copy constants for the public Terms and Privacy pages.
 *
 * Assumptions (edit here when facts change):
 * - Operator is Dilan Senanayake, an individual, not a registered company.
 * - Governing law: Sri Lanka.
 * - Minimum age: 16.
 * - Core service is free today. Paid-plan language is included so it can apply if subscriptions are added.
 * - Refunds: no refund of the current paid period (digital service), except where required by law.
 * - Account deletion: within 30 days of a verified request, except where law requires longer retention.
 * - Contact inbox: NEXT_PUBLIC_LEGAL_CONTACT_EMAIL, falling back to the address below.
 * - Processors listed in privacy match the current stack: Supabase, Vercel, Groq, optional Google Analytics.
 * - The website and Android app do not auto-read SMS or link bank accounts. Users paste, type, or optionally speak a short description and confirm saves.
 * - Android also uses on-device ML Kit, Google Fonts, and the device speech recognizer.
 */
export const LEGAL = {
  productName: "Smart Money Manager",
  operatorName: "Dilan Senanayake",
  lastUpdated: "29 September 2026",
  consentVersion: "2026-09-29",
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
      "If a Google Analytics measurement ID is configured, measure how the site is used. Analytics storage stays off until you accept it.",
  },
  {
    name: "Google ML Kit",
    role: "On-device receipt text",
    purpose:
      "The Android app reads Latin text from a receipt photo on the phone. The photo is not uploaded. The text may be sent for Smart Add.",
  },
  {
    name: "Google Fonts",
    role: "Typeface",
    purpose:
      "The Android app downloads the Plus Jakarta Sans typeface from Google when it is first needed.",
  },
  {
    name: "Device speech recognizer",
    role: "Voice input",
    purpose:
      "If you use voice entry, the phone’s speech service turns audio into words. On many Android phones that audio is sent to Google. The app does not store a recording.",
  },
] as const;
