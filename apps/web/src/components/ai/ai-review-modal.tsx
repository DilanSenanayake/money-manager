"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  convertCurrencyAmount,
  saveReviewedTransaction,
} from "@/app/actions/ai";
import { trackEvent } from "@/lib/analytics";
import type { Account, Category } from "@/lib/types";
import type {
  AiReviewSave,
  QuickTextExtraction,
  ReceiptExtraction,
  SmsExtraction,
} from "@/lib/schemas";
import { matchCategoryId, sanitizeOcrForCategoryHints } from "@/lib/category-match";
import { localDateYYYYMMDD } from "@/lib/dates";
import { asMoneyInput } from "@/lib/money";
import {
  mentionsCurrency,
  receiptMoneyFrom,
  type ReceiptMoney,
} from "@/lib/receipt-currency";
import {
  fromMerchantAndNotes,
  toMerchantAndNotes,
} from "@/lib/transaction-description";
import { cn, formatMoney } from "@/lib/utils";
import { CategoryChip } from "@/components/categories/category-icon";
import { Button } from "@/components/ui/button";
import { DateQuickPick } from "@/components/ui/date-quick-pick";
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
  /** Raw OCR text from the receipt photo — used to resolve Dining etc. */
  ocrText?: string | null;
};

function ownedAccountId(
  accounts: Account[],
  accountId: string | null | undefined,
  fallback: string
) {
  if (accountId && accounts.some((a) => a.id === accountId)) return accountId;
  return fallback;
}

function ownedCategoryId(
  categories: Category[],
  type: "income" | "expense",
  categoryId: string | null | undefined,
  ...hints: (string | null | undefined)[]
) {
  if (
    categoryId &&
    categories.some((c) => c.id === categoryId && c.type === type)
  ) {
    return categoryId;
  }
  return matchCategoryId(categories, type, ...hints);
}

function payeeKeyOf(extraction: Extraction): string | null {
  if (!extraction || !("payee_key" in extraction)) return null;
  const key = extraction.payee_key;
  return typeof key === "string" && key.trim() ? key.trim() : null;
}

function formatRate(rate: number) {
  return new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 6,
  }).format(rate);
}

function sameCurrency(a?: string | null, b?: string | null) {
  return (a ?? "").trim().toUpperCase() === (b ?? "").trim().toUpperCase();
}

function reviewMoney(
  extraction: Extraction,
  source: AiSource | null,
  ocrText: string | null,
  accountCurrency: string
): ReceiptMoney | null {
  if (
    !extraction ||
    (source !== "receipt" && source !== "text" && source !== "sms") ||
    !("amount" in extraction) ||
    !("currency" in extraction)
  ) {
    return null;
  }

  const noted = mentionsCurrency(ocrText);
  const alreadyConverted = Boolean(
    extraction.source_currency &&
      extraction.exchange_rate &&
      sameCurrency(extraction.currency, accountCurrency)
  );
  const currency =
    source === "receipt" || alreadyConverted || noted
      ? extraction.currency
      : accountCurrency;

  return receiptMoneyFrom(
    { ...extraction, currency },
    source === "receipt" || noted ? ocrText : null,
    accountCurrency
  );
}

type FillBaseline = {
  account_id: string;
  category_id: string | null;
  merchant: string | null;
  payee_key: string | null;
};

function toReviewForm(
  extraction: Extraction,
  accounts: Account[],
  categories: Category[],
  source: AiSource | null,
  ocrText?: string | null
): AiReviewSave {
  const today = localDateYYYYMMDD();
  const defaultAccount = accounts[0]?.id ?? "";

  if (source === "text" && extraction) {
    const text = extraction as QuickTextExtraction;
    const type = text.type === "income" ? "income" : "expense";
    return {
      account_id: ownedAccountId(accounts, text.account_id, defaultAccount),
      category_id: ownedCategoryId(
        categories,
        type,
        text.category_id,
        text.category,
        text.merchant,
        text.notes
      ),
      amount: asMoneyInput(text.amount),
      type,
      date: text.date || today,
      merchant: fromMerchantAndNotes(text.merchant, text.notes),
      notes: null,
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  if (source === "sms" && extraction) {
    const sms = extraction as SmsExtraction;
    const type = sms.type === "Credit" ? "income" : "expense";
    let accountId = ownedAccountId(accounts, sms.account_id, defaultAccount);
    if (!sms.account_id && sms.account_hint) {
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
      category_id: ownedCategoryId(
        categories,
        type,
        sms.category_id,
        sms.merchant,
        sms.notes
      ),
      amount: asMoneyInput(sms.amount),
      type,
      date: sms.date || today,
      merchant: fromMerchantAndNotes(sms.merchant, sms.notes),
      notes: null,
      is_recurring: false,
      recurring_frequency: null,
    };
  }

  const receipt = extraction as ReceiptExtraction | null;
  const type = "expense" as const;
  const lineNames =
    receipt?.line_items?.length
      ? receipt.line_items.map((i) => i.name).filter(Boolean).join(" ")
      : "";
  const lineNotes =
    receipt?.line_items?.length
      ? receipt.line_items
          .map((i) => `${i.name}${i.price != null ? ` (${i.price})` : ""}`)
          .join(", ")
      : "";
  const receiptNotes =
    receipt?.notes?.trim().toLowerCase().startsWith("from receipt:")
      ? null
      : receipt?.notes;
  const ocrHint = sanitizeOcrForCategoryHints(ocrText);
  return {
    account_id: ownedAccountId(accounts, receipt?.account_id, defaultAccount),
    category_id: ownedCategoryId(
      categories,
      type,
      receipt?.category_id,
      receipt?.category,
      receipt?.merchant,
      lineNames,
      receiptNotes,
      ocrHint
    ),
    amount: asMoneyInput(receipt?.amount),
    type,
    date: receipt?.date || today,
    merchant: fromMerchantAndNotes(
      receipt?.merchant,
      receiptNotes || lineNotes || null
    ),
    notes: null,
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
  ocrText = null,
}: Props) {
  const router = useRouter();
  const [form, setForm] = useState<AiReviewSave | null>(null);
  const [saving, setSaving] = useState(false);
  const [receiptMoney, setReceiptMoney] = useState<ReceiptMoney | null>(null);
  const [converting, setConverting] = useState(false);
  const baselineRef = useRef<FillBaseline | null>(null);
  const convertSeq = useRef(0);
  const autoConvertKey = useRef<string | null>(null);
  const preparedKey = useRef<string | null>(null);

  useEffect(() => {
    if (!open) {
      baselineRef.current = null;
      convertSeq.current += 1;
      autoConvertKey.current = null;
      preparedKey.current = null;
      setForm(null);
      setReceiptMoney(null);
      setConverting(false);
      return;
    }
    const accountKey = accounts.map((a) => `${a.id}:${a.currency}`).join(",");
    const categoryKey = categories.map((c) => c.id).join(",");
    const key = `${source ?? ""}|${ocrText ?? ""}|${
      extraction ? JSON.stringify(extraction) : ""
    }|${initialForm ? JSON.stringify(initialForm) : ""}|${accountKey}|${categoryKey}`;
    if (preparedKey.current === key) return;
    preparedKey.current = key;
    autoConvertKey.current = null;

    const next = initialForm
      ? {
          ...initialForm,
          merchant: fromMerchantAndNotes(
            initialForm.merchant,
            initialForm.notes
          ),
          notes: null,
        }
      : extraction
        ? toReviewForm(extraction, accounts, categories, source, ocrText)
        : null;
    if (next) {
      const proposed = toMerchantAndNotes(next.merchant ?? "");
      baselineRef.current = {
        account_id: next.account_id,
        category_id: next.category_id ?? null,
        merchant: proposed.merchant,
        payee_key: payeeKeyOf(extraction),
      };
    }
    const accountCurrency =
      accounts.find((a) => a.id === next?.account_id)?.currency ??
      accounts[0]?.currency ??
      "USD";
    const money = reviewMoney(extraction, source, ocrText, accountCurrency);
    const needsConvert = Boolean(
      money && !sameCurrency(money.amountCurrency, accountCurrency)
    );
    setForm(
      next && needsConvert ? { ...next, amount: "" } : next
    );
    setReceiptMoney(money);
    setConverting(needsConvert);
  }, [open, extraction, accounts, categories, source, initialForm, ocrText]);

  const relevantCategories = form
    ? categories.filter((c) => c.type === form.type)
    : [];

  const selectedAccountCurrency =
    accounts.find((a) => a.id === form?.account_id)?.currency ??
    accounts[0]?.currency ??
    "USD";
  const amountLabelCurrency = converting
    ? selectedAccountCurrency
    : (receiptMoney?.amountCurrency ?? selectedAccountCurrency);
  const amountMatchesAccount =
    !receiptMoney ||
    sameCurrency(receiptMoney.amountCurrency, selectedAccountCurrency);

  async function changeAccount(accountId: string) {
    const nextCurrency = accounts.find((a) => a.id === accountId)?.currency;
    if (!nextCurrency) return;
    const seq = ++convertSeq.current;
    const money = receiptMoney;

    if (!money || sameCurrency(nextCurrency, money.amountCurrency)) {
      setConverting(false);
      setForm((current) =>
        current ? { ...current, account_id: accountId } : current
      );
      return;
    }

    if (sameCurrency(nextCurrency, money.sourceCurrency)) {
      setConverting(false);
      setForm((current) =>
        current
          ? {
              ...current,
              account_id: accountId,
              amount: asMoneyInput(money.sourceAmount),
            }
          : current
      );
      setReceiptMoney({
        ...money,
        amountCurrency: nextCurrency,
        rate: null,
        warning: null,
      });
      return;
    }

    const previousId = form?.account_id ?? "";
    setForm((current) =>
      current ? { ...current, account_id: accountId } : current
    );
    setConverting(true);
    try {
      const result = await convertCurrencyAmount({
        amount: money.sourceAmount,
        from_currency: money.sourceCurrency,
        to_currency: nextCurrency,
      });
      if (seq !== convertSeq.current) return;
      if ("error" in result) {
        toast.error(result.error);
        setForm((current) =>
          current && current.account_id === accountId
            ? {
                ...current,
                account_id: previousId,
                amount: current.amount || asMoneyInput(money.sourceAmount),
              }
            : current
        );
        return;
      }
      setForm((current) =>
        current
          ? {
              ...current,
              account_id: accountId,
              amount: asMoneyInput(result.data.amount),
            }
          : current
      );
      setReceiptMoney({
        ...money,
        amountCurrency: result.data.currency,
        rate: result.data.rate,
        warning: null,
      });
    } catch {
      if (seq === convertSeq.current) {
        toast.error("Couldn't convert that amount. Please try again.");
        setForm((current) =>
          current && current.account_id === accountId
            ? {
                ...current,
                account_id: previousId,
                amount: current.amount || asMoneyInput(money.sourceAmount),
              }
            : current
        );
      }
    } finally {
      if (seq === convertSeq.current) setConverting(false);
    }
  }

  useEffect(() => {
    if (!open) return;
    if (!form?.account_id || !receiptMoney) return;
    if (sameCurrency(receiptMoney.amountCurrency, selectedAccountCurrency)) {
      return;
    }
    const key = `${form.account_id}|${receiptMoney.sourceCurrency}|${receiptMoney.amountCurrency}|${receiptMoney.sourceAmount}`;
    if (autoConvertKey.current === key) return;
    autoConvertKey.current = key;
    void changeAccount(form.account_id);
  }, [open, form?.account_id, receiptMoney, selectedAccountCurrency]);

  function acceptUnconverted() {
    if (!receiptMoney) return;
    setReceiptMoney({
      ...receiptMoney,
      amountCurrency: selectedAccountCurrency,
      rate: null,
      warning: null,
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="gap-0 overflow-hidden p-0 pb-0 sm:max-w-md sm:p-0 sm:pb-0">
        <div className="flex max-h-[min(92dvh,100svh)] min-h-0 flex-col sm:max-h-[min(84vh,720px)]">
          <DialogHeader className="shrink-0 border-b border-[var(--border)] px-5 py-4 pr-12 sm:px-6">
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
              <div className="min-h-0 flex-1 space-y-4 overflow-y-auto overscroll-contain px-5 py-4 sm:px-6">
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
                    Amount ({amountLabelCurrency})
                  </Label>
                  <Input
                    id="review-amount"
                    type="number"
                    inputMode="decimal"
                    step="0.01"
                    min="0"
                    className="h-12 text-2xl font-semibold"
                    value={form.amount}
                    disabled={converting}
                    onChange={(e) =>
                      setForm({ ...form, amount: e.target.value })
                    }
                  />
                  {receiptMoney &&
                  receiptMoney.rate != null &&
                  !sameCurrency(
                    receiptMoney.sourceCurrency,
                    amountLabelCurrency
                  ) ? (
                    <p className="text-xs text-[var(--muted)]">
                      {source === "receipt" ? "Receipt total" : "Original amount"}{" "}
                      {formatMoney(
                        receiptMoney.sourceAmount,
                        receiptMoney.sourceCurrency
                      )}{" "}
                      converted at today&apos;s rate (1{" "}
                      {receiptMoney.sourceCurrency} ={" "}
                      {formatRate(receiptMoney.rate)} {amountLabelCurrency}).
                    </p>
                  ) : null}
                  {converting ? (
                    <p className="text-xs text-[var(--muted)]">
                      Converting to {selectedAccountCurrency}…
                    </p>
                  ) : null}
                  {receiptMoney?.warning ? (
                    <p className="text-xs text-amber-800">
                      {receiptMoney.warning}
                    </p>
                  ) : null}
                  {receiptMoney && !amountMatchesAccount && !converting ? (
                    <div className="space-y-2">
                      <p className="text-xs text-[var(--muted)]">
                        Save stays off until this amount is in{" "}
                        {selectedAccountCurrency}.
                      </p>
                      <div className="flex flex-wrap gap-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          disabled={converting}
                          onClick={() => void changeAccount(form.account_id)}
                        >
                          {converting
                            ? "Converting…"
                            : `Convert to ${selectedAccountCurrency}`}
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          disabled={converting}
                          onClick={acceptUnconverted}
                        >
                          Use this number as {selectedAccountCurrency}
                        </Button>
                      </div>
                    </div>
                  ) : null}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="review-description">Description</Label>
                  <Textarea
                    id="review-description"
                    value={form.merchant ?? ""}
                    placeholder="What was this for?"
                    rows={2}
                    maxLength={1000}
                    onChange={(e) =>
                      setForm({ ...form, merchant: e.target.value })
                    }
                  />
                </div>

                <DateQuickPick
                  id="review-date"
                  value={form.date}
                  onChange={(date) => setForm({ ...form, date })}
                />
                <div className="space-y-2">
                  <Label>Account</Label>
                  <Select
                    value={form.account_id}
                    disabled={converting}
                    onValueChange={(v) => void changeAccount(v)}
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

                <div className="space-y-2">
                  <Label>Category</Label>
                  <div className="flex flex-wrap gap-2">
                    {relevantCategories.map((c) => (
                      <CategoryChip
                        key={c.id}
                        icon={c.icon}
                        name={c.name}
                        selected={form.category_id === c.id}
                        onClick={() =>
                          setForm({ ...form, category_id: c.id })
                        }
                      />
                    ))}
                  </div>
                </div>
              </div>

              <DialogFooter className="shrink-0 gap-2 border-t border-[var(--border)] px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:gap-2 sm:px-6 sm:pb-4">
                <Button
                  variant="outline"
                  size="lg"
                  className="h-11 w-full sm:w-auto"
                  onClick={() => onOpenChange(false)}
                >
                  Cancel
                </Button>
                <Button
                  size="lg"
                  className="h-11 w-full min-w-32 sm:w-auto"
                  disabled={
                    saving ||
                    converting ||
                    !form.account_id ||
                    !form.amount ||
                    !amountMatchesAccount
                  }
                  onClick={async () => {
                    setSaving(true);
                    try {
                      const { merchant, notes } = toMerchantAndNotes(
                        form.merchant ?? ""
                      );
                      const categoryId =
                        form.category_id ??
                        matchCategoryId(
                          categories,
                          form.type,
                          merchant,
                          notes,
                          sanitizeOcrForCategoryHints(ocrText)
                        );
                      const baseline = baselineRef.current;
                      const result = await saveReviewedTransaction({
                        ...form,
                        category_id: categoryId,
                        merchant,
                        notes,
                        proposed_category_id: baseline?.category_id ?? null,
                        proposed_account_id: baseline?.account_id || null,
                        proposed_merchant: baseline?.merchant ?? null,
                        payee_key: baseline?.payee_key ?? null,
                      });
                      if (result.error) {
                        toast.error(result.error);
                        setSaving(false);
                        return;
                      }
                      trackEvent("add_transaction", {
                        type: form.type,
                        method: source ?? "text",
                      });
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
