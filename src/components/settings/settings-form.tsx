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
  const [from, setFrom] = useState("USD");
  const [to, setTo] = useState("LKR");
  const [rate, setRate] = useState(300);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl tracking-tight">Settings</h1>
        <p className="text-sm text-slate-500">
          Base currency and manual exchange rates
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Profile</CardTitle>
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
          <CardTitle className="text-base">Exchange rates</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-4">
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
                className="flex items-center justify-between rounded-xl border border-slate-200/80 px-3 py-2 text-sm dark:border-slate-800"
              >
                <span>
                  1 {r.from_currency} = {Number(r.rate)} {r.to_currency}
                </span>
                <Button
                  size="sm"
                  variant="ghost"
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
