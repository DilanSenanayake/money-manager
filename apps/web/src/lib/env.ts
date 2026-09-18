/** Server-only API origin. Prefer API_URL so the host is not inlined into the client bundle. */
export function getApiBaseUrl(): string {
  const url = (process.env.API_URL || process.env.NEXT_PUBLIC_API_URL)?.replace(
    /\/$/,
    ""
  );
  if (!url) {
    throw new Error(
      "API_URL (preferred) or NEXT_PUBLIC_API_URL is not set. Point it at Ledgerly.Api."
    );
  }
  return url;
}

export function getSupabaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!url) {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL is not set.");
  }
  return url;
}

export function getSupabaseAnonKey(): string {
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!key) {
    throw new Error("NEXT_PUBLIC_SUPABASE_ANON_KEY is not set.");
  }
  return key;
}

/** Canonical public origin. Apex `smoneymanager.com` 308s to www. */
export const CANONICAL_SITE_URL = "https://www.smoneymanager.com";

export function getSiteUrl(): string {
  const fromEnv = process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, "");
  if (fromEnv) return fromEnv;
  if (process.env.VERCEL_ENV === "production") return CANONICAL_SITE_URL;
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return "http://localhost:3000";
}
