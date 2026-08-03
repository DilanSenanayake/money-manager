"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";
import { saveReviewedTransaction } from "@/app/actions/ai";
import type { Account, Category } from "@/lib/types";
import type { AiReviewSave, ReceiptExtraction, SmsExtraction } from "@/lib/schemas";
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

type Extraction = ReceiptExtraction | SmsExtraction | null;

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  extraction: Extraction;
  accounts: Account[];
  categories: Category[];
  source: "receipt" | "sms" | null;
};

function toReviewForm(
  extraction: Extraction,
  accounts: Account[],
  categories: Category[],
  source: "receipt" | "sms" | null
): AiReviewSave {
  const isSms = source === "sms" && extraction && "type" in extraction;
  const sms = isSms ? (extraction as SmsExtraction) : null;
  const receipt = !isSms ? (extraction as ReceiptExtraction | null) : null;

  const type =
    sms?.type === "Credit"
      ? "income"
      : ("expense" as "income" | "expense");

  const categoryName = receipt?.category?.toLowerCase() ?? "";
  const matched = categories.find(
    (c) =>
      c.type === type &&
      (c.name.toLowerCase() === categoryName ||
        c.name.toLowerCase().includes(categoryName) ||
        categoryName.includes(c.name.toLowerCase()))
  );

  let accountId = accounts[0]?.id ?? "";
  if (sms?.account_hint) {
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
    category_id: matched?.id ?? null,
    amount: Number(extraction?.amount ?? 0),
    type,
    date: extraction?.date ?? new Date().toISOString().slice(0, 10),
    merchant: extraction?.merchant ?? "",
    notes:
      ("notes" in (extraction ?? {}) && extraction?.notes) ||
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
}: Props) {
  const [form, setForm] = useState<AiReviewSave | null>(null);
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    if (open && extraction) {
      setForm(toReviewForm(extraction, accounts, categories, source));
    }
  }, [open, extraction, accounts, categories, source]);

  if (!form) return null;

  const relevantCategories = categories.filter((c) => c.type === form.type);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Review AI extraction</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-slate-500">
          Verify these fields before saving to your ledger. Nothing is stored
          until you confirm.
        </p>
        <div className="space-y-3">
          <div className="space-y-2">
            <Label>Type</Label>
            <Select
              value={form.type}
              onValueChange={(v) =>
                setForm({ ...form, type: v as AiReviewSave["type"], category_id: null })
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="expense">Expense (Debit)</SelectItem>
                <SelectItem value="income">Income (Credit)</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label>Account</Label>
            <Select
              value={form.account_id}
              onValueChange={(v) => setForm({ ...form, account_id: v })}
            >
              <SelectTrigger>
                <SelectValue />
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
          <div className="space-y-2">
            <Label>Category</Label>
            <Select
              value={form.category_id ?? undefined}
              onValueChange={(v) => setForm({ ...form, category_id: v })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                {relevantCategories.map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Amount</Label>
              <Input
                type="number"
                step="0.01"
                value={form.amount}
                onChange={(e) =>
                  setForm({ ...form, amount: Number(e.target.value) })
                }
              />
            </div>
            <div className="space-y-2">
              <Label>Date</Label>
              <Input
                type="date"
                value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })}
              />
            </div>
          </div>
          <div className="space-y-2">
            <Label>Merchant</Label>
            <Input
              value={form.merchant ?? ""}
              onChange={(e) => setForm({ ...form, merchant: e.target.value })}
            />
          </div>
          <div className="space-y-2">
            <Label>Notes</Label>
            <Textarea
              value={form.notes ?? ""}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Discard
          </Button>
          <Button
            disabled={pending}
            onClick={() =>
              startTransition(async () => {
                const result = await saveReviewedTransaction(form);
                if (result.error) {
                  toast.error(result.error);
                  return;
                }
                toast.success("Transaction saved");
                onOpenChange(false);
              })
            }
          >
            {pending ? "Saving…" : "Confirm & save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
