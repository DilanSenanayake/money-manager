"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { signIn } from "@/app/actions/auth";
import { trackAfterAction } from "@/lib/analytics";
import { BrandMark } from "@/components/brand/brand-mark";
import { SiteFooter } from "@/components/layout/site-footer";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default function LoginPage() {
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <main className="auth-shell flex min-h-screen flex-col">
      <div className="flex flex-1 items-center justify-center px-4 py-10">
      <Card className="w-full max-w-md shadow-[var(--shadow-md)]">
        <CardHeader className="space-y-3">
          <Link href="/" className="inline-flex">
            <BrandMark size="sm" />
          </Link>
          <div>
            <CardTitle className="font-display text-2xl">Welcome back</CardTitle>
            <CardDescription className="mt-1.5">
              Sign in to spend smarter and save better
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form
            className="space-y-4"
            action={(formData) => {
              startTransition(async () => {
                const result = await trackAfterAction(
                  "login",
                  { method: "email" },
                  () => signIn(formData)
                );
                if (result?.error) setError(result.error);
              });
            }}
          >
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                name="email"
                type="email"
                required
                autoComplete="email"
                placeholder="you@example.com"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                name="password"
                type="password"
                required
                autoComplete="current-password"
                minLength={8}
              />
            </div>
            {error && (
              <p
                className="rounded-lg bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]"
                role="alert"
              >
                {error}
              </p>
            )}
            <Button className="w-full" disabled={pending}>
              {pending ? "Signing in…" : "Sign in"}
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-[var(--muted)]">
            No account?{" "}
            <Link
              href="/signup"
              className="font-semibold text-[var(--accent-hover)] hover:underline"
            >
              Create one
            </Link>
          </p>
        </CardContent>
      </Card>
      </div>
      <SiteFooter />
    </main>
  );
}
