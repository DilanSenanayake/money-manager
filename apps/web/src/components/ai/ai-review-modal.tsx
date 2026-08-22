"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { saveReviewedTransaction } from "@/app/actions/ai";
import type { Account, Category } from "@/lib/types";
import type {
  AiReviewSave,
  QuickTextExtraction,
  ReceiptExtraction,
  SmsExtraction,
} from "@/lib/schemas";
import { matchCategoryId } from "@/lib/category-match";
import { localDateYYYYMMDD } from "@/lib/dates";
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
import { LoadingOverlay } from "@/components/ui/loading-overlay";

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
  initialForm?: AiReviewSave | null;
};

function toReviewForm(
  extraction: Extraction,
  accounts: Account[],
  categories: Category[],
  source: AiSource | null
): AiReviewSave {
  const today = localDateYYYYMMDD();
  const defaultAccount = accounts[0]?.id ?? "";

  if (source === "text" && extraction) {
    const text = extraction as QuickTextExtraction;
    const type = text.type === "income" ? "income" : "expense";
    return {
      account_id: defaultAccount,
      category_id: matchCategoryId(
        categories,
        type,
        text.category,
        text.merchant,
        text.notes
      ),
      amount: Number(text.amount ?? 0),
      type,
      date: text.date || today,
      merchant: text.merchant ?? "",
      notes: text.notes ?? "",
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  if (source === "sms" && extraction) {
    const sms = extraction as SmsExtraction;
    const type = sms.type === "Credit" ? "income" : "expense";
    let accountId = defaultAccount;
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
      category_id: matchCategoryId(
        categories,
        type,
        sms.merchant,
        sms.notes
      ),
      amount: Number(sms.amount ?? 0),
      type,
      date: sms.date || today,
      merchant: sms.merchant ?? "",
      notes: sms.notes ?? "",
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  const receipt = extraction as ReceiptExtraction | null;
  const type = "expense" as const;
  return {
    account_id: defaultAccount,
    category_id: matchCategoryId(
      categories,
      type,
      receipt?.category,
      receipt?.merchant,
      receipt?.notes
    ),
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
  const router = useRouter();
  const [form, setForm] = useState<AiReviewSave | null>(null);
  const [showMore, setShowMore] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) {
      setForm(null);
      setShowMore(false);
      return;
    }
    if (initialForm) {
      setForm(initialForm);
    } else if (extraction) {
      setForm(toReviewForm(extraction, accounts, categories, source));
    }
    setShowMore(false);
  }, [open, extraction, accounts, categories, source, initialForm]);

  const relevantCategories = form
    ? categories.filter((c) => c.type === form.type)
    : [];

  const selectedAccountCurrency =
    accounts.find((a) => a.id === form?.account_id)?.currency ??
    accounts[0]?.currency ??
    "USD";

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="gap-0 overflow-hidden p-0 sm:max-w-md">
        <div className="flex max-h-[inherit] min-h-0 flex-col">
          <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 pb-3 pt-5 pr-12">
            <DialogTitle>Check & save</DialogTitle>
            <p className="text-sm text-[var(--muted)]">
              We filled this in for you — change anything you need, then save.
            </p>
          </DialogHeader>

          {!form ? (
            <div className="px-5 py-8 text-center text-sm text-slate-500">
              Preparing…
            </div>
          ) : (
            <>
              <div className="min-h-0 flex-1 space-y-4 overflow-y-auto overscroll-contain px-5 py-4">
                <div className="flex gap-2">
                  {(["expense", "income"] as const).map((t) => (
                    <button
                      key={t}
                      type="button"
                      onClick={() =>
                        setForm({ ...form, type: t, category_id: null })
                      }
                      className={cn(
                        "flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium capitalize transition-[color,background-color,border-color,transform] duration-200 active:scale-[0.98]",
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
                  <Label htmlFor="review-amount">
                    Amount ({selectedAccountCurrency})
                  </Label>
                  <Input
                    id="review-amount"
                    type="number"
                    inputMode="decimal"
                    step="0.01"
                    min="0"
                    className="h-12 text-2xl font-semibold"
                    value={form.amount || ""}
                    onChange={(e) =>
                      setForm({ ...form, amount: Number(e.target.value) })
                    }
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="review-merchant">Merchant / description</Label>
                  <Input
                    id="review-merchant"
                    value={form.merchant ?? ""}
                    placeholder="Where or what"
                    onChange={(e) =>
                      setForm({ ...form, merchant: e.target.value })
                    }
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <Label htmlFor="review-date">Date</Label>
                    <Input
                      id="review-date"
                      type="date"
                      value={form.date}
                      onChange={(e) =>
                        setForm({ ...form, date: e.target.value })
                      }
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Account</Label>
                    <Select
                      value={form.account_id}
                      onValueChange={(v) =>
                        setForm({ ...form, account_id: v })
                      }
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
                </div>

                <div className="space-y-2">
                  <Label>Category</Label>
                  <div className="flex flex-wrap gap-2">
                    {relevantCategories.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        onClick={() =>
                          setForm({ ...form, category_id: c.id })
                        }
                        className={cn(
                          "rounded-full border px-3 py-1.5 text-xs font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95",
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

                <button
                  type="button"
                  className="text-xs font-medium text-teal-700 hover:underline"
                  onClick={() => setShowMore((v) => !v)}
                >
                  {showMore ? "Hide notes" : "Add notes"}
                </button>

                {showMore && (
                  <div className="space-y-2">
                    <Label>Notes</Label>
                    <Textarea
                      value={form.notes ?? ""}
                      onChange={(e) =>
                        setForm({ ...form, notes: e.target.value })
                      }
                      rows={2}
                    />
                  </div>
                )}
              </div>

              <DialogFooter className="shrink-0 gap-2 border-t border-[var(--border)] px-5 py-4 sm:gap-2">
                <Button variant="outline" onClick={() => onOpenChange(false)}>
                  Cancel
                </Button>
                <Button
                  size="lg"
                  className="min-w-32 flex-1 sm:flex-none"
                  disabled={saving || !form.account_id || !form.amount}
                  onClick={async () => {
                    setSaving(true);
                    try {
                      const result = await saveReviewedTransaction(form);
                      if (result.error) {
                        toast.error(result.error);
                        setSaving(false);
                        return;
                      }
                      toast.success("Saved");
                      onOpenChange(false);
                      setSaving(false);
                      router.push("/dashboard");
                      router.refresh();
                    } catch {
                      setSaving(false);
                      toast.error("Something went wrong. Please try again.");
                    }
                  }}
                >
                  {saving ? "Saving…" : "Save"}
                </Button>
              </DialogFooter>
            </>
          )}
        </div>
      </DialogContent>
      <LoadingOverlay
        open={saving}
        title="Saving"
        message="Adding to your money tracker…"
      />
    </Dialog>
  );
}
