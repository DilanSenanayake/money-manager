/**
 * Google Analytics 4 helpers. Never send money amounts, merchants, emails,
 * or other account data — page path and coarse event names only.
 */

export const GA_MEASUREMENT_ID_PATTERN = /^G-[A-Z0-9]+$/i;

/** Public GA4 web stream for smoneymanager.com. Override with NEXT_PUBLIC_GA_MEASUREMENT_ID. */
export const DEFAULT_GA_MEASUREMENT_ID = "G-YH8936B98F";

const BLOCKED_PARAM_KEY =
  /^(email|e-?mail|password|pass|user.?id|uid|user_id|name|display.?name|amount|value|price|revenue|currency|merchant|note|notes|description|phone|ip|address|token|jwt|session)/i;

type GtagCommand = {
  (
    command: "event",
    eventName: string,
    params?: Record<string, string | number | boolean>
  ): void;
  (command: "config" | "set", ...args: unknown[]): void;
};

declare global {
  interface Window {
    gtag?: GtagCommand;
    dataLayer?: unknown[];
  }
}

export function getGaMeasurementId(
  raw: string | undefined = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID
): string | undefined {
  const id = raw?.trim() || DEFAULT_GA_MEASUREMENT_ID;
  return GA_MEASUREMENT_ID_PATTERN.test(id) ? id : undefined;
}

export function sanitizeEventParams(
  params: Record<string, unknown> | undefined
): Record<string, string | number | boolean> | undefined {
  if (!params) return undefined;
  const out: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(params)) {
    if (BLOCKED_PARAM_KEY.test(key)) continue;
    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean"
    ) {
      out[key] = value;
    }
  }
  return Object.keys(out).length ? out : undefined;
}

export function isNextRedirectError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "digest" in error &&
    typeof (error as { digest: unknown }).digest === "string" &&
    (error as { digest: string }).digest.startsWith("NEXT_REDIRECT")
  );
}

export function trackEvent(
  name: string,
  params?: Record<string, unknown>
): void {
  if (typeof window === "undefined") return;
  if (!getGaMeasurementId()) return;
  const gtag = window.gtag;
  if (typeof gtag !== "function") return;
  gtag("event", name, sanitizeEventParams(params));
}

function actionReturnedError(result: unknown): boolean {
  return (
    typeof result === "object" &&
    result !== null &&
    "error" in result &&
    Boolean((result as { error?: unknown }).error)
  );
}

/** Fire the event on success, including when a Server Action redirects. */
export async function trackAfterAction<T>(
  name: string,
  params: Record<string, unknown> | undefined,
  work: () => Promise<T>
): Promise<T> {
  try {
    const result = await work();
    if (!actionReturnedError(result)) {
      trackEvent(name, params);
    }
    return result;
  } catch (error) {
    if (isNextRedirectError(error)) {
      trackEvent(name, params);
    }
    throw error;
  }
}
