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
    <main className="app-grid flex min-h-screen items-center justify-center px-4 py-10">
      <Card className="w-full max-w-md">
        <CardHeader>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-teal-700">
            Ledgerly
          </p>
          <CardTitle className="font-display text-2xl">Create account</CardTitle>
          <CardDescription>
            Start tracking wallets, budgets, and AI-parsed expenses
          </CardDescription>
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
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                {CURRENCIES.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
              <p className="text-xs text-slate-500">
                Used for your wallets, budgets, and totals. You can change it later in Settings.
              </p>
            </div>
            {error && (
              <p className="text-sm text-rose-600" role="alert">
                {error}
              </p>
            )}
            {message && (
              <p className="text-sm text-teal-800" role="status">
                {message}{" "}
                <Link href="/login" className="font-medium underline">
                  Sign in
                </Link>
              </p>
            )}
            <Button className="w-full" disabled={pending || Boolean(message)}>
              {pending ? "Creating…" : "Create account"}
            </Button>
          </form>
          <p className="mt-4 text-center text-sm text-slate-500">
            Already have an account?{" "}
            <Link href="/login" className="font-medium text-teal-700 hover:underline">
              Sign in
            </Link>
          </p>
        </CardContent>
      </Card>
    </main>
  );
}
