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

export function getSiteUrl(): string {
  return (
    process.env.NEXT_PUBLIC_SITE_URL ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null) ||
    "http://localhost:3000"
  );
}
