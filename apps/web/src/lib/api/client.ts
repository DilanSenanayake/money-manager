import { createClient } from "@/lib/supabase/server";

export function getApiBaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "");
  if (!url) {
    throw new Error(
      "NEXT_PUBLIC_API_URL is not set. Point it at Ledgerly.Api (e.g. http://localhost:5080 or http://<vm-host>:8080)."
    );
  }
  return url;
}

async function getAccessToken(): Promise<string> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error("Unauthorized");
  return session.access_token;
}

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

type QueryValue = string | number | boolean | null | undefined;

type ApiOptions = {
  method?: string;
  body?: unknown;
  query?: Record<string, QueryValue>;
};

function errorMessage(json: unknown, status: number): string {
  if (json && typeof json === "object") {
    const obj = json as Record<string, unknown>;
    if (typeof obj.error === "string") return obj.error;
    if (typeof obj.title === "string") return obj.title;
    if (obj.errors && typeof obj.errors === "object") {
      const first = Object.values(obj.errors as Record<string, unknown>)[0];
      if (Array.isArray(first) && typeof first[0] === "string") return first[0];
    }
  }
  return `API error ${status}`;
}

/** Authenticated fetch to Ledgerly.Api (runs on the Next.js server). */
export async function apiRequest<T>(
  path: string,
  options: ApiOptions = {}
): Promise<T> {
  const token = await getAccessToken();
  const base = getApiBaseUrl();
  const url = new URL(path.startsWith("http") ? path : `${base}${path}`);

  if (options.query) {
    for (const [key, value] of Object.entries(options.query)) {
      if (value === undefined || value === null || value === "") continue;
      url.searchParams.set(key, String(value));
    }
  }

  const res = await fetch(url, {
    method: options.method ?? "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...(options.body !== undefined
        ? { "Content-Type": "application/json" }
        : {}),
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    cache: "no-store",
  });

  const text = await res.text();
  let json: unknown = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = null;
    }
  }

  if (!res.ok) {
    throw new ApiError(errorMessage(json, res.status), res.status);
  }

  return json as T;
}

export async function apiMutate(
  path: string,
  options: ApiOptions = {}
): Promise<{ success: true } | { error: string }> {
  try {
    await apiRequest(path, options);
    return { success: true };
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : "Request failed",
    };
  }
}
