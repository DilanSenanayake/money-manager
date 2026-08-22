import { createGoogleGenerativeAI } from "@ai-sdk/google";

/**
 * Free-tier Gemini Flash models only — never use paid/Pro models.
 * Prefer 2.5 Flash family; 2.0 Flash often reports free_tier limit: 0.
 */
export const FREE_TIER_MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
] as const;

export type FreeTierModel = (typeof FREE_TIER_MODELS)[number];

const google = createGoogleGenerativeAI({
  apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY,
});

export function getFlashModel(preferred: FreeTierModel = "gemini-2.5-flash") {
  return google(preferred);
}

export function getFlashModelFallback() {
  return google("gemini-2.5-flash-lite");
}

export function isQuotaError(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return /quota|rate.?limit|resource.?exhausted|429/i.test(msg);
}

export function formatAiError(err: unknown, fallback: string): string {
  if (isQuotaError(err)) {
    return "We’re a bit busy right now. Please wait a minute and try again.";
  }
  const msg = err instanceof Error ? err.message : "";
  // Hide raw API / model errors from users
  if (/api|quota|model|gemini|generate|unauthorized|429|403/i.test(msg)) {
    return fallback;
  }
  return msg || fallback;
}
