"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";
import {
  createAccount,
  deleteAccount,
  updateAccount,
} from "@/app/actions/accounts";
import type { Account } from "@/lib/types";
import { formatMoney } from "@/lib/utils";
import { CURRENCIES, type AccountInput } from "@/lib/schemas";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export function AccountsManager({
  accounts,
  defaultCurrency = "USD",
}: {
  accounts: Account[];
  defaultCurrency?: string;
}) {
  const blank = (): AccountInput => ({
    name: "",
    type: "checking",
    balance: 0,
    currency: (CURRENCIES.includes(defaultCurrency as (typeof CURRENCIES)[number])
      ? defaultCurrency
      : "USD") as AccountInput["currency"],
  });

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Account | null>(null);
  const [form, setForm] = useState<AccountInput>(blank);
  const [pending, startTransition] = useTransition();

  function openCreate() {
    setEditing(null);
    setForm(blank());
    setOpen(true);
  }

  function openEdit(account: Account) {
    setEditing(account);
    setForm({
      name: account.name,
      type: account.type,
      balance: Number(account.balance),
      currency: account.currency as AccountInput["currency"],
    });
    setOpen(true);
  }

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (!next) setEditing(null);
  }

  function submit() {
    startTransition(async () => {
      const result = editing
        ? await updateAccount(editing.id, form)
        : await createAccount(form);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(editing ? "Account updated" : "Account created");
      setOpen(false);
      setEditing(null);
    });
  }

  return (
    <div className="page-stack">
      <PageHeader
        title="Accounts"
        description="Cash, checking, savings, and credit cards"
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" />
            Add account
          </Button>
        }
      />

      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent className="gap-0 overflow-hidden p-0 sm:p-0">
          <div className="flex max-h-[min(92dvh,100svh)] min-h-0 flex-col sm:max-h-[min(84vh,720px)]">
            <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
              <DialogTitle>
                {editing ? "Edit account" : "New account"}
              </DialogTitle>
            </DialogHeader>
            <div className="min-h-0 flex-1 space-y-3 overflow-y-auto overscroll-contain px-5 py-4 sm:px-6">
              <div className="space-y-2">
                <Label>Name</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Type</Label>
                <Select
                  value={form.type}
                  onValueChange={(v) =>
                    setForm({ ...form, type: v as AccountInput["type"] })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="cash">Cash</SelectItem>
                    <SelectItem value="checking">Checking</SelectItem>
                    <SelectItem value="savings">Savings</SelectItem>
                    <SelectItem value="credit">Credit Card</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label>
                    {editing ? "Current balance" : "Starting balance"}
                  </Label>
                  <Input
                    type="number"
                    step="0.01"
                    value={form.balance}
                    disabled={Boolean(editing)}
                    onChange={(e) =>
                      setForm({ ...form, balance: Number(e.target.value) })
                    }
                  />
                  {editing && (
                    <p className="text-xs text-[var(--muted)]">
                      Balance updates automatically when you add transactions
                    </p>
                  )}
                </div>
                <div className="space-y-2">
                  <Label>Currency</Label>
                  <Select
                    value={form.currency}
                    onValueChange={(v) =>
                      setForm({
                        ...form,
                        currency: v as AccountInput["currency"],
                      })
                    }
                  >
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
              </div>
            </div>
            <DialogFooter className="shrink-0 border-t border-[var(--border)] px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:px-6 sm:pb-4">
              <Button
                className="w-full sm:w-auto"
                onClick={submit}
                disabled={pending}
              >
                {pending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>

      <div className="grid gap-3 sm:grid-cols-2">
        {accounts.map((account) => (
          <Card key={account.id}>
            <CardHeader className="flex flex-row items-start justify-between space-y-0">
              <div>
                <CardTitle>{account.name}</CardTitle>
                <Badge className="mt-2 capitalize" variant="accent">
                  {account.type}
                </Badge>
              </div>
              <div className="flex shrink-0 gap-1">
                <Button variant="outline" onClick={() => openEdit(account)}>
                  Edit
                </Button>
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label={`Delete ${account.name}`}
                  onClick={() =>
                    startTransition(async () => {
                      const result = await deleteAccount(account.id);
                      if (result.error) toast.error(result.error);
                      else toast.success("Account deleted");
                    })
                  }
                >
                  <Trash2 className="h-4 w-4 text-rose-600" />
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              <p className="font-display text-xl tabular-nums break-all sm:text-[1.75rem]">
                {formatMoney(Number(account.balance), account.currency)}
              </p>
            </CardContent>
          </Card>
        ))}
        {accounts.length === 0 && (
          <p className="text-sm text-[var(--muted)] sm:col-span-2">
            No accounts yet.
          </p>
        )}
      </div>
    </div>
  );
}
