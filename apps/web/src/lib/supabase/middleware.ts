import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getSupabaseAnonKey, getSupabaseUrl } from "@/lib/env";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    getSupabaseUrl(),
    getSupabaseAnonKey(),
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const path = request.nextUrl.pathname;
  const isAuthRoute =
    path.startsWith("/login") || path.startsWith("/signup");
  const isPublic =
    isAuthRoute ||
    path === "/" ||
    path.startsWith("/manifest") ||
    path === "/sw.js" ||
    path.startsWith("/brand/") ||
    path.startsWith("/icons/") ||
    path === "/favicon.ico" ||
    path === "/favicon.png" ||
    path === "/robots.txt" ||
    path === "/sitemap.xml" ||
    path.startsWith("/opengraph-image") ||
    path.startsWith("/twitter-image") ||
    path === "/terms" ||
    path === "/privacy";

  // Validate the JWT with Supabase Auth (do not trust cookie-only getSession()).
  let user = null;
  try {
    const result = await Promise.race([
      supabase.auth.getUser(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("Supabase auth timeout")), 8000)
      ),
    ]);
    user = result.data.user ?? null;
  } catch {
    if (!isPublic && !path.startsWith("/_next")) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }
    return supabaseResponse;
  }

  if (!user && !isPublic && !path.startsWith("/_next")) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/dashboard";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
