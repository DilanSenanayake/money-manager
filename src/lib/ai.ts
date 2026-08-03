import { createGoogleGenerativeAI } from "@ai-sdk/google";

/** Free-tier Gemini Flash models only — never use paid/Pro models. */
export const FREE_TIER_MODELS = [
  "gemini-2.5-flash",
  "gemini-1.5-flash",
] as const;

export type FreeTierModel = (typeof FREE_TIER_MODELS)[number];

const google = createGoogleGenerativeAI({
  apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY,
});

export function getFlashModel(preferred: FreeTierModel = "gemini-2.5-flash") {
  return google(preferred);
}

export function getFlashModelFallback() {
  return google("gemini-1.5-flash");
}
