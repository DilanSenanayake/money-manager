"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { signUp } from "@/app/actions/auth";
import { CURRENCIES } from "@/lib/schemas";
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

export default function SignupPage() {
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <main className="auth-shell flex min-h-screen items-center justify-center px-4 py-10">
      <Card className="w-full max-w-md shadow-[var(--shadow-md)]">
        <CardHeader className="space-y-3">
          <Link href="/" className="inline-flex items-center gap-2">
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--accent)] text-xs font-bold text-[var(--accent-fg)]">
              S
            </span>
            <span className="text-sm font-semibold">Smart Money Manager</span>
          </Link>
          <div>
            <CardTitle className="font-display text-2xl">Create account</CardTitle>
            <CardDescription className="mt-1.5">
              Start spending smarter — set your currency and you&apos;re in
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form
            className="space-y-4"
            action={(formData) => {
              startTransition(async () => {
                setError(null);
                setMessage(null);
                const result = await signUp(formData);
                if (result?.error) setError(result.error);
                else if (result?.message) setMessage(result.message);
              });
            }}
          >
            <div className="space-y-2">
              <Label htmlFor="display_name">Display name</Label>
              <Input id="display_name" name="display_name" required />
            </div>
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
                autoComplete="new-password"
                minLength={6}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="base_currency">Currency</Label>
              <select
                id="base_currency"
                name="base_currency"
                defaultValue="USD"
                className="flex h-10 w-full rounded-[10px] border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm shadow-[var(--shadow-sm)] focus-visible:border-[var(--accent)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent-ring)]"
              >
                {CURRENCIES.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
              <p className="text-xs text-[var(--muted)]">
                You can change this later in Settings.
              </p>
            </div>
            {error && (
              <p
                className="rounded-lg bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]"
                role="alert"
              >
                {error}
              </p>
            )}
            {message && (
              <p
                className="rounded-lg bg-[var(--success-soft)] px-3 py-2 text-sm text-[var(--success)]"
                role="status"
              >
                {message}{" "}
                <Link href="/login" className="font-semibold underline">
                  Sign in
                </Link>
              </p>
            )}
            <Button className="w-full" disabled={pending || Boolean(message)}>
              {pending ? "Creating…" : "Create account"}
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-[var(--muted)]">
            Already have an account?{" "}
            <Link
              href="/login"
              className="font-semibold text-[var(--accent-hover)] hover:underline"
            >
              Sign in
            </Link>
          </p>
        </CardContent>
      </Card>
    </main>
  );
}
