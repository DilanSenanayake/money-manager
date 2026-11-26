"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { toast } from "sonner";
import { createQuickAdd, deleteQuickAdd } from "@/app/actions/quick-adds";
import { createTransaction } from "@/app/actions/transactions";
import {
  CategoryChip,
  CategoryIcon,
} from "@/components/categories/category-icon";
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
import { Textarea } from "@/components/ui/textarea";
import { trackEvent } from "@/lib/analytics";
import { localDateYYYYMMDD } from "@/lib/dates";
import { canonicalMoney } from "@/lib/money";
import { entryDescriptions } from "@/lib/transaction-description";
import type {
  Account,
  Category,
  FrequentRecord,
  QuickShortcut,
} from "@/lib/types";
import { formatMoney } from "@/lib/utils";

const chipClass =
  "flex w-[10.5rem] shrink-0 flex-col gap-2 rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 py-2.5 text-left transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface)]";

export function FrequentQuickAdd({
  records,
  shortcuts,
  accounts,
  categories,
  baseCurrency,
}: {
  records: FrequentRecord[];
  shortcuts: QuickShortcut[];
  accounts: Account[];
  categories: Category[];
  baseCurrency: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [record, setRecord] = useState<FrequentRecord | null>(null);
  const [shortcutId, setShortcutId] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const [amount, setAmount] = useState("");
  const [description, setDescription] = useState("");
  const [detail, setDetail] = useState("");
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [accountId, setAccountId] = useState("");
  const [date, setDate] = useState(localDateYYYYMMDD());
  const [saving, setSaving] = useState(false);
  const [composerOpen, setComposerOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [draftName, setDraftName] = useState("");
  const [draftDetail, setDraftDetail] = useState("");
  const [draftType, setDraftType] = useState<"income" | "expense">("expense");
  const [draftCategoryId, setDraftCategoryId] = useState<string | null>(null);
  const [draftAmount, setDraftAmount] = useState("");

  const currency =
    accounts.find((account) => account.id === accountId)?.currency ??
    accounts[0]?.currency ??
    baseCurrency;

  function openTarget(next: FrequentRecord, savedId: string | null) {
    const account =
      accounts.find((item) => item.id === next.accountId)?.id ??
      accounts[0]?.id ??
      "";
    setRecord(next);
    setShortcutId(savedId);
    setConfirmRemove(false);
    setDescription(next.label);
    setDetail(next.notes ?? "");
    setCategoryId(next.categoryId);
    setAmount(next.amount.toFixed(2));
    setAccountId(account);
    setDate(localDateYYYYMMDD());
    setOpen(true);
  }

  function openComposer() {
    setDraftName("");
    setDraftDetail("");
    setDraftType("expense");
    setDraftCategoryId(null);
    setDraftAmount("");
    setComposerOpen(true);
  }

  function chooseDraftType(next: "income" | "expense") {
    setDraftType(next);
    setDraftCategoryId((current) => {
      const category = categories.find((item) => item.id === current);
      return category?.type === next ? current : null;
    });
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
      const descriptions = entryDescriptions(description, detail);
      const result = await createTransaction({
        account_id: accountId,
        category_id: categoryId,
        amount: canonical,
        type: record.type,
        date,
        ...descriptions,
        is_recurring: false,
        recurring_frequency: null,
        transfer_to_account_id: null,
        proposed_merchant: record.label,
        proposed_category_id: record.categoryId,
        proposed_account_id: record.accountId || null,
      });
      if (result.error) {
        toast.error(result.error);
        return;
      }
      trackEvent("add_transaction", {
        type: record.type,
        method: shortcutId ? "shortcut" : "frequent",
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

  async function saveShortcut() {
    if (creating) return;
    const canonical = canonicalMoney(draftAmount);
    if (!draftName.trim()) {
      toast.error("Enter a description");
      return;
    }
    if (!draftCategoryId) {
      toast.error("Choose a category");
      return;
    }
    if (!canonical) {
      toast.error("Enter an amount");
      return;
    }

    setCreating(true);
    try {
      const descriptions = entryDescriptions(draftName, draftDetail);
      const result = await createQuickAdd({
        merchant: descriptions.merchant ?? "",
        notes: descriptions.notes,
        category_id: draftCategoryId,
        amount: canonical,
      });
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Quick add saved");
      setComposerOpen(false);
      router.refresh();
    } catch {
      toast.error("Something went wrong. Please try again.");
    } finally {
      setCreating(false);
    }
  }

  async function removeShortcut() {
    if (!shortcutId || saving) return;
    if (!confirmRemove) {
      setConfirmRemove(true);
      return;
    }
    setSaving(true);
    try {
      const result = await deleteQuickAdd(shortcutId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Quick add removed");
      setOpen(false);
      router.refresh();
    } catch {
      toast.error("Something went wrong. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  const draftCategories = categories.filter(
    (category) => category.type === draftType
  );

  return (
    <>
      <Card>
        <CardHeader className="space-y-0">
          <CardTitle>Add again</CardTitle>
        </CardHeader>
        <CardContent>
          {records.length === 0 && shortcuts.length === 0 ? (
            <p className="mb-3 text-sm text-[var(--muted)]">
              Save a description, category, and amount, then add it in one tap.
            </p>
          ) : null}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {records.map((item) => {
              const itemCurrency =
                accounts.find((account) => account.id === item.accountId)
                  ?.currency ?? baseCurrency;
              return (
                <QuickChip
                  key={`${item.type}|${item.label}|${item.categoryId ?? ""}|${item.count}`}
                  label={item.label}
                  notes={item.notes}
                  categoryName={
                    item.category?.name ??
                    (item.type === "income" ? "Income" : "Expense")
                  }
                  categoryIcon={item.category?.icon}
                  amountLabel={formatMoney(item.amount, itemCurrency)}
                  onClick={() => openTarget(item, null)}
                />
              );
            })}
            {shortcuts.map((item) => (
              <QuickChip
                key={item.id}
                label={item.label}
                notes={item.notes}
                categoryName={
                  item.category?.name ??
                  (item.type === "income" ? "Income" : "Expense")
                }
                categoryIcon={item.category?.icon}
                amountLabel={formatMoney(item.amount, baseCurrency)}
                onClick={() =>
                  openTarget(
                    {
                      label: item.label,
                      notes: item.notes,
                      type: item.type,
                      amount: item.amount,
                      accountId: accounts[0]?.id ?? "",
                      categoryId: item.categoryId,
                      category: item.category,
                      count: 0,
                    },
                    item.id
                  )
                }
              />
            ))}
            <button
              type="button"
              onClick={openComposer}
              className="flex w-[10.5rem] shrink-0 flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-[var(--border)] bg-[var(--background)] px-3 py-2.5 text-[var(--muted)] transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface)] hover:text-[var(--foreground)]"
              aria-label="Add a quick add"
            >
              <Plus className="h-5 w-5" />
              <span className="text-sm font-medium">Add quick add</span>
            </button>
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
                <Label htmlFor="frequent-description">Description</Label>
                <Input
                  id="frequent-description"
                  maxLength={200}
                  value={description}
                  disabled={saving}
                  autoFocus
                  onChange={(event) => setDescription(event.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="frequent-detail">Long description</Label>
                <Textarea
                  id="frequent-detail"
                  rows={2}
                  maxLength={1000}
                  placeholder="Optional details"
                  value={detail}
                  disabled={saving}
                  onChange={(event) => setDetail(event.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label>Category</Label>
                <div className="flex flex-wrap gap-2">
                  {categories
                    .filter((category) => category.type === record.type)
                    .map((category) => (
                      <CategoryChip
                        key={category.id}
                        icon={category.icon}
                        name={category.name}
                        selected={categoryId === category.id}
                        disabled={saving}
                        onClick={() => setCategoryId(category.id)}
                      />
                    ))}
                </div>
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
              {shortcutId ? (
                <Button
                  type="button"
                  variant="ghost"
                  className="w-full text-rose-600"
                  disabled={saving}
                  onClick={() => void removeShortcut()}
                >
                  {confirmRemove ? "Remove this shortcut" : "Remove quick add"}
                </Button>
              ) : null}
            </div>
          )}
        </DialogContent>
      </Dialog>

      <Dialog
        open={composerOpen}
        onOpenChange={(next) => {
          if (!creating) setComposerOpen(next);
        }}
      >
        <DialogContent className="gap-0 p-0 sm:max-w-md sm:p-0">
          <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
            <DialogTitle>New quick add</DialogTitle>
            <DialogDescription>
              Choose the description, category, and amount. It stays on home
              so you can add it again.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 px-5 py-4 sm:px-6">
            <div className="space-y-2">
              <Label htmlFor="shortcut-description">Description</Label>
              <Input
                id="shortcut-description"
                maxLength={200}
                value={draftName}
                disabled={creating}
                autoFocus
                onChange={(event) => setDraftName(event.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="shortcut-detail">Long description</Label>
              <Textarea
                id="shortcut-detail"
                rows={2}
                maxLength={1000}
                placeholder="Optional details"
                value={draftDetail}
                disabled={creating}
                onChange={(event) => setDraftDetail(event.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Category</Label>
              <div className="flex gap-2">
                <Button
                  type="button"
                  size="sm"
                  variant={draftType === "expense" ? "default" : "outline"}
                  disabled={creating}
                  onClick={() => chooseDraftType("expense")}
                >
                  Expense
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant={draftType === "income" ? "default" : "outline"}
                  disabled={creating}
                  onClick={() => chooseDraftType("income")}
                >
                  Income
                </Button>
              </div>
              {draftCategories.length === 0 ? (
                <p className="text-sm text-[var(--muted)]">
                  Add a category on Budgets first.
                </p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {draftCategories.map((category) => (
                    <CategoryChip
                      key={category.id}
                      icon={category.icon}
                      name={category.name}
                      selected={draftCategoryId === category.id}
                      disabled={creating}
                      onClick={() => setDraftCategoryId(category.id)}
                    />
                  ))}
                </div>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="shortcut-amount">Amount ({baseCurrency})</Label>
              <Input
                id="shortcut-amount"
                type="number"
                step="0.01"
                min="0"
                inputMode="decimal"
                className="h-12 text-2xl font-semibold"
                value={draftAmount}
                disabled={creating}
                onChange={(event) => setDraftAmount(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") void saveShortcut();
                }}
              />
            </div>
            <Button
              size="lg"
              className="w-full"
              disabled={creating}
              onClick={() => void saveShortcut()}
            >
              {creating ? "Saving…" : "Save quick add"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

function QuickChip({
  label,
  notes,
  categoryName,
  categoryIcon,
  amountLabel,
  onClick,
}: {
  label: string;
  notes?: string | null;
  categoryName: string;
  categoryIcon?: string | null;
  amountLabel: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={chipClass}
      aria-label={`Add ${label} again, ${categoryName}`}
    >
      <span className="flex min-w-0 items-center gap-2">
        <CategoryIcon
          icon={categoryIcon}
          name={categoryName}
          framed
          className="h-8 w-8"
        />
        <span className="min-w-0">
          <span className="block truncate text-sm font-semibold">{label}</span>
          {notes ? (
            <span className="block truncate text-xs text-[var(--muted)]">
              {notes}
            </span>
          ) : null}
        </span>
      </span>
      <span className="flex items-baseline justify-between gap-2">
        <span className="truncate text-xs text-[var(--muted)]">
          {categoryName}
        </span>
        <span className="shrink-0 text-xs font-medium tabular-nums text-[var(--muted)] opacity-60">
          {amountLabel}
        </span>
      </span>
    </button>
  );
}
