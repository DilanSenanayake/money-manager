"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { createTransaction } from "@/app/actions/transactions";
import { CategoryIcon } from "@/components/categories/category-icon";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { DateQuickPick } from "@/components/ui/date-quick-pick";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { trackEvent } from "@/lib/analytics";
import { localDateYYYYMMDD } from "@/lib/dates";
import { canonicalMoney } from "@/lib/money";
import { toMerchantAndNotes } from "@/lib/transaction-description";
import type { Account, FrequentRecord } from "@/lib/types";
import { formatMoney } from "@/lib/utils";

export function FrequentQuickAdd({
  records,
  accounts,
}: {
  records: FrequentRecord[];
  accounts: Account[];
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [record, setRecord] = useState<FrequentRecord | null>(null);
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [date, setDate] = useState(localDateYYYYMMDD());
  const [saving, setSaving] = useState(false);

  if (records.length === 0) return null;

  const currency =
    accounts.find((account) => account.id === accountId)?.currency ??
    accounts[0]?.currency ??
    "USD";

  function openRecord(next: FrequentRecord) {
    const account =
      accounts.find((item) => item.id === next.accountId)?.id ??
      accounts[0]?.id ??
      "";
    setRecord(next);
    setAmount(next.amount.toFixed(2));
    setAccountId(account);
    setDate(localDateYYYYMMDD());
    setOpen(true);
  }

  async function save() {
    if (!record || saving) return;
    const canonical = canonicalMoney(amount);
    if (!canonical) {
      toast.error("Enter an amount");
      return;
    }
    if (!accountId) {
      toast.error("Add an account first");
      return;
    }

    setSaving(true);
    try {
      const result = await createTransaction({
        account_id: accountId,
        category_id: record.categoryId,
        amount: canonical,
        type: record.type,
        date,
        ...toMerchantAndNotes(record.label),
        is_recurring: false,
        recurring_frequency: null,
        transfer_to_account_id: null,
      });
      if (result.error) {
        toast.error(result.error);
        return;
      }
      trackEvent("add_transaction", {
        type: record.type,
        method: "frequent",
      });
      toast.success("Saved");
      setOpen(false);
      router.refresh();
    } catch {
      toast.error("Something went wrong. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <Card>
        <CardHeader className="space-y-0">
          <CardTitle>Add again</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2 overflow-x-auto pb-1">
            {records.map((item) => {
              const itemCurrency =
                accounts.find((account) => account.id === item.accountId)
                  ?.currency ?? "USD";
              return (
                <button
                  key={`${item.type}|${item.label}|${item.categoryId ?? ""}|${item.count}`}
                  type="button"
                  onClick={() => openRecord(item)}
                  className="flex w-[10.5rem] shrink-0 flex-col gap-2 rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 py-2.5 text-left transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface)]"
                  aria-label={`Add ${item.label} again${
                    item.category?.name ? `, ${item.category.name}` : ""
                  }`}
                >
                  <span className="flex min-w-0 items-center gap-2">
                    <CategoryIcon
                      icon={item.category?.icon}
                      name={item.category?.name ?? item.label}
                      framed
                      className="h-8 w-8"
                    />
                    <span className="truncate text-sm font-medium">
                      {item.label}
                    </span>
                  </span>
                  <span className="flex items-baseline justify-between gap-2">
                    <span className="truncate text-xs text-[var(--muted)]">
                      {item.category?.name ??
                        (item.type === "income" ? "Income" : "Expense")}
                    </span>
                    <span className="shrink-0 text-sm font-semibold tabular-nums">
                      {formatMoney(item.amount, itemCurrency)}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </CardContent>
      </Card>

      <Dialog
        open={open}
        onOpenChange={(next) => {
          if (!saving) setOpen(next);
        }}
      >
        <DialogContent className="gap-0 p-0 sm:max-w-md sm:p-0">
          <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
            <DialogTitle>{record?.label ?? "Add again"}</DialogTitle>
            <DialogDescription>
              Today&apos;s date, last amount, and the category saved on this
              record.
            </DialogDescription>
          </DialogHeader>
          {record && (
            <div className="space-y-4 px-5 py-4 sm:px-6">
              <div className="space-y-2">
                <Label>Saved category</Label>
                {record.category ? (
                  <div className="flex items-center gap-2 rounded-xl border border-[var(--border)] px-3 py-2">
                    <CategoryIcon
                      icon={record.category.icon}
                      name={record.category.name}
                      framed
                      className="h-8 w-8"
                    />
                    <span className="text-sm font-medium">
                      {record.category.name}
                    </span>
                  </div>
                ) : (
                  <p className="text-sm text-[var(--muted)]">
                    No category on this record
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label htmlFor="frequent-amount">Amount ({currency})</Label>
                <Input
                  id="frequent-amount"
                  type="number"
                  step="0.01"
                  min="0"
                  inputMode="decimal"
                  className="h-12 text-2xl font-semibold"
                  value={amount}
                  disabled={saving}
                  autoFocus
                  onChange={(event) => setAmount(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") void save();
                  }}
                />
              </div>
              <div className="space-y-2">
                <Label>Account</Label>
                {accounts.length === 0 || !accountId ? (
                  <p className="text-sm text-rose-600">
                    Add an account first in More → Accounts.
                  </p>
                ) : (
                  <Select
                    value={accountId}
                    onValueChange={setAccountId}
                    disabled={saving}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select account" />
                    </SelectTrigger>
                    <SelectContent>
                      {accounts.map((account) => (
                        <SelectItem key={account.id} value={account.id}>
                          {account.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
              <DateQuickPick
                id="frequent-date"
                value={date}
                onChange={setDate}
                disabled={saving}
              />
              <Button
                size="lg"
                className="w-full"
                disabled={saving || !amount || !accountId}
                onClick={() => void save()}
              >
                {saving ? "Saving…" : "Save"}
              </Button>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
