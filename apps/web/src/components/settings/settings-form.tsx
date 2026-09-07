"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import {
  deleteExchangeRate,
  updateProfile,
  upsertExchangeRate,
} from "@/app/actions/settings";
import type { ExchangeRate, Profile } from "@/lib/types";
import { CURRENCIES } from "@/lib/schemas";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function SettingsForm({
  profile,
  rates,
}: {
  profile: Profile;
  rates: ExchangeRate[];
}) {
  const [pending, startTransition] = useTransition();
  const [displayName, setDisplayName] = useState(profile.display_name ?? "");
  const [baseCurrency, setBaseCurrency] = useState(profile.base_currency);
  const [from, setFrom] = useState(profile.base_currency);
  const [to, setTo] = useState(
    profile.base_currency === "USD" ? "LKR" : "USD"
  );
  const [rate, setRate] = useState(1);

  return (
    <div className="page-stack">
      <PageHeader
        title="Settings"
        description="Profile, base currency, and exchange rates"
      />

      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="space-y-2">
            <Label>Display name</Label>
            <Input
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Base currency</Label>
            <Select value={baseCurrency} onValueChange={setBaseCurrency}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {CURRENCIES.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-slate-500">
              Totals and budgets use this currency. Saving also updates wallets
              that were in your previous base currency.
            </p>
          </div>
          <Button
            disabled={pending}
            onClick={() =>
              startTransition(async () => {
                const result = await updateProfile({
                  display_name: displayName,
                  base_currency: baseCurrency as (typeof CURRENCIES)[number],
                });
                if (result.error) toast.error(result.error);
                else toast.success("Profile updated");
              })
            }
          >
            Save profile
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Exchange rates</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="space-y-2">
              <Label>From</Label>
              <Select value={from} onValueChange={setFrom}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {CURRENCIES.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>To</Label>
              <Select value={to} onValueChange={setTo}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {CURRENCIES.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Rate</Label>
              <Input
                type="number"
                step="0.0001"
                value={rate}
                onChange={(e) => setRate(Number(e.target.value))}
              />
            </div>
            <div className="flex items-end">
              <Button
                className="w-full"
                disabled={pending}
                onClick={() =>
                  startTransition(async () => {
                    const result = await upsertExchangeRate({
                      from_currency: from as (typeof CURRENCIES)[number],
                      to_currency: to as (typeof CURRENCIES)[number],
                      rate,
                    });
                    if (result.error) toast.error(result.error);
                    else toast.success("Rate saved");
                  })
                }
              >
                Add / update
              </Button>
            </div>
          </div>

          <div className="space-y-2">
            {rates.map((r) => (
              <div
                key={r.id}
                className="flex flex-col items-start gap-2 rounded-xl border border-slate-200/80 px-3 py-3 text-sm sm:flex-row sm:items-center sm:justify-between dark:border-slate-800"
              >
                <span className="min-w-0 break-words">
                  1 {r.from_currency} = {Number(r.rate)} {r.to_currency}
                </span>
                <Button
                  variant="ghost"
                  className="w-full sm:w-auto"
                  onClick={() =>
                    startTransition(async () => {
                      const result = await deleteExchangeRate(r.id);
                      if (result.error) toast.error(result.error);
                      else toast.success("Rate deleted");
                    })
                  }
                >
                  Delete
                </Button>
              </div>
            ))}
            {rates.length === 0 && (
              <p className="text-sm text-slate-500">
                No custom rates yet. Same-currency accounts convert 1:1.
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
