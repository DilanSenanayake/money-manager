"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";
import { saveReviewedTransaction } from "@/app/actions/ai";
import type { Account, Category } from "@/lib/types";
import type {
  AiReviewSave,
  QuickTextExtraction,
  ReceiptExtraction,
  SmsExtraction,
} from "@/lib/schemas";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
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

export type AiSource = "receipt" | "sms" | "text" | "manual";
export type Extraction =
  | ReceiptExtraction
  | SmsExtraction
  | QuickTextExtraction
  | null;

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  extraction: Extraction;
  accounts: Account[];
  categories: Category[];
  source: AiSource | null;
  /** Optional pre-built form (e.g. manual quick add) */
  initialForm?: AiReviewSave | null;
};

function matchCategory(
  categories: Category[],
  type: "income" | "expense",
  categoryName?: string | null
) {
  if (!categoryName) return null;
  const needle = categoryName.toLowerCase();
  return (
    categories.find(
      (c) =>
        c.type === type &&
        (c.name.toLowerCase() === needle ||
          c.name.toLowerCase().includes(needle) ||
          needle.includes(c.name.toLowerCase()))
    )?.id ?? null
  );
}

function toReviewForm(
  extraction: Extraction,
  accounts: Account[],
  categories: Category[],
  source: AiSource | null
): AiReviewSave {
  const today = new Date().toISOString().slice(0, 10);

  if (source === "sms" && extraction && "type" in extraction) {
    const sms = extraction as SmsExtraction;
    const type = sms.type === "Credit" ? "income" : "expense";
    let accountId = accounts[0]?.id ?? "";
    if (sms.account_hint) {
      const hint = sms.account_hint.toLowerCase();
      const found = accounts.find(
        (a) =>
          a.name.toLowerCase().includes(hint) ||
          hint.includes(a.name.toLowerCase())
      );
      if (found) accountId = found.id;
    }
    return {
      account_id: accountId,
      category_id: null,
      amount: Number(sms.amount ?? 0),
      type,
      date: sms.date || today,
      merchant: sms.merchant ?? "",
      notes: sms.notes ?? "",
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  if (source === "text" && extraction && "category" in extraction) {
    const text = extraction as QuickTextExtraction;
    return {
      account_id: accounts[0]?.id ?? "",
      category_id: matchCategory(categories, text.type, text.category),
      amount: Number(text.amount ?? 0),
      type: text.type,
      date: text.date || today,
      merchant: text.merchant ?? "",
      notes: text.notes ?? "",
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  const receipt = extraction as ReceiptExtraction | null;
  const type = "expense" as const;
  return {
    account_id: accounts[0]?.id ?? "",
    category_id: matchCategory(categories, type, receipt?.category),
    amount: Number(receipt?.amount ?? 0),
    type,
    date: receipt?.date || today,
    merchant: receipt?.merchant ?? "",
    notes:
      receipt?.notes ||
      (receipt?.line_items?.length
        ? receipt.line_items
            .map((i) => `${i.name}${i.price != null ? ` (${i.price})` : ""}`)
            .join(", ")
        : ""),
    is_recurring: false,
    recurring_frequency: null,
  };
}

export function AiReviewModal({
  open,
  onOpenChange,
  extraction,
  accounts,
  categories,
  source,
  initialForm = null,
}: Props) {
  const [form, setForm] = useState<AiReviewSave | null>(null);
  const [showMore, setShowMore] = useState(false);
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    if (!open) return;
    if (initialForm) {
      setForm(initialForm);
    } else if (extraction) {
      setForm(toReviewForm(extraction, accounts, categories, source));
    }
    setShowMore(false);
  }, [open, extraction, accounts, categories, source, initialForm]);

  if (!form) return null;

  const relevantCategories = categories.filter((c) => c.type === form.type);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Confirm & save</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-slate-500">
          Check the amount and category, then save. Nothing is stored until you
          confirm.
        </p>

        <div className="space-y-4">
          <div className="flex gap-2">
            {(["expense", "income"] as const).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() =>
                  setForm({ ...form, type: t, category_id: null })
                }
                className={cn(
                  "flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium capitalize transition-colors",
                  form.type === t
                    ? t === "expense"
                      ? "border-rose-600 bg-rose-50 text-rose-700"
                      : "border-teal-700 bg-teal-50 text-teal-800"
                    : "border-slate-200 text-slate-600 hover:bg-slate-50"
                )}
              >
                {t}
              </button>
            ))}
          </div>

          <div className="space-y-2">
            <Label htmlFor="review-amount">Amount</Label>
            <Input
              id="review-amount"
              type="number"
              step="0.01"
              min="0"
              autoFocus
              className="h-12 text-2xl font-semibold"
              value={form.amount || ""}
              onChange={(e) =>
                setForm({ ...form, amount: Number(e.target.value) })
              }
            />
          </div>

          <div className="space-y-2">
            <Label>Category</Label>
            <div className="flex flex-wrap gap-2">
              {relevantCategories.map((c) => (
                <button
                  key={c.id}
                  type="button"
                  onClick={() => setForm({ ...form, category_id: c.id })}
                  className={cn(
                    "rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
                    form.category_id === c.id
                      ? "border-teal-700 bg-teal-700 text-white"
                      : "border-slate-200 text-slate-600 hover:border-teal-600/40"
                  )}
                >
                  {c.name}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <Label>Account</Label>
            <Select
              value={form.account_id}
              onValueChange={(v) => setForm({ ...form, account_id: v })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Account" />
              </SelectTrigger>
              <SelectContent>
                {accounts.map((a) => (
                  <SelectItem key={a.id} value={a.id}>
                    {a.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <button
            type="button"
            className="text-xs font-medium text-teal-700 hover:underline"
            onClick={() => setShowMore((v) => !v)}
          >
            {showMore ? "Hide extra fields" : "More (date, merchant, notes)"}
          </button>

          {showMore && (
            <div className="space-y-3 rounded-xl border border-slate-100 p-3 dark:border-slate-800">
              <div className="space-y-2">
                <Label>Date</Label>
                <Input
                  type="date"
                  value={form.date}
                  onChange={(e) => setForm({ ...form, date: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Merchant</Label>
                <Input
                  value={form.merchant ?? ""}
                  onChange={(e) =>
                    setForm({ ...form, merchant: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label>Notes</Label>
                <Textarea
                  value={form.notes ?? ""}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  rows={2}
                />
              </div>
            </div>
          )}
        </div>

        <DialogFooter className="gap-2 sm:gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="lg"
            className="min-w-32 flex-1 sm:flex-none"
            disabled={pending || !form.account_id || !form.amount}
            onClick={() =>
              startTransition(async () => {
                const result = await saveReviewedTransaction(form);
                if (result.error) {
                  toast.error(result.error);
                  return;
                }
                toast.success("Saved");
                onOpenChange(false);
              })
            }
          >
            {pending ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
