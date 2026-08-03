"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Camera,
  ClipboardPaste,
  MessageSquareText,
  Sparkles,
} from "lucide-react";
import {
  parseBankSms,
  parseQuickText,
  parseReceiptText,
} from "@/app/actions/ai";
import { createTransaction } from "@/app/actions/transactions";
import { extractTextFromImage } from "@/lib/ocr";
import type { Account, Category } from "@/lib/types";
import type {
  AiReviewSave,
  QuickTextExtraction,
  ReceiptExtraction,
  SmsExtraction,
} from "@/lib/schemas";
import { cn } from "@/lib/utils";
import {
  AiReviewModal,
  type AiSource,
} from "@/components/ai/ai-review-modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

type Props = {
  accounts: Account[];
  categories: Category[];
  initialType?: "income" | "expense";
  initialMode?: "receipt" | "sms" | "text" | "manual";
};

export function QuickAddPanel({
  accounts,
  categories,
  initialType = "expense",
  initialMode,
}: Props) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [pending, startTransition] = useTransition();
  const [ocrStatus, setOcrStatus] = useState<string | null>(null);
  const [active, setActive] = useState<
    "receipt" | "sms" | "text" | "manual" | null
  >(initialMode === "receipt" ? null : (initialMode ?? null));

  const [smsText, setSmsText] = useState("");
  const [quickText, setQuickText] = useState("");
  const [manualType, setManualType] = useState<"income" | "expense">(
    initialType
  );
  const [manualAmount, setManualAmount] = useState("");
  const [manualCategoryId, setManualCategoryId] = useState<string | null>(null);

  const [extraction, setExtraction] = useState<
    ReceiptExtraction | SmsExtraction | QuickTextExtraction | null
  >(null);
  const [source, setSource] = useState<AiSource | null>(null);
  const [initialForm, setInitialForm] = useState<AiReviewSave | null>(null);
  const [reviewOpen, setReviewOpen] = useState(false);

  useEffect(() => {
    if (initialMode === "receipt") {
      fileRef.current?.click();
    }
  }, [initialMode]);

  const manualCategories = categories.filter((c) => c.type === manualType);

  function openReview(
    data: ReceiptExtraction | SmsExtraction | QuickTextExtraction,
    kind: AiSource
  ) {
    setExtraction(data);
    setSource(kind);
    setInitialForm(null);
    setReviewOpen(true);
  }

  function onReviewClose(open: boolean) {
    setReviewOpen(open);
    if (!open) {
      setExtraction(null);
      setInitialForm(null);
      setSource(null);
      router.refresh();
    }
  }

  async function handleReceiptFile(file: File) {
    setOcrStatus("Reading receipt with OCR…");
    const ocr = await extractTextFromImage(file, (info) => {
      const pct = Math.round(info.progress * 100);
      setOcrStatus(
        pct > 0 ? `${info.status} ${pct}%` : info.status
      );
    });

    if ("error" in ocr) {
      setOcrStatus(null);
      toast.error(ocr.error);
      return;
    }

    setOcrStatus("Structuring with Gemini…");
    startTransition(async () => {
      const result = await parseReceiptText(ocr.text);
      setOcrStatus(null);
      if ("error" in result) {
        toast.error(result.error);
        return;
      }
      openReview(result.data, "receipt");
    });
  }

  return (
    <div className="space-y-6">
      <div className="animate-fade-up">
        <h1 className="font-display text-3xl tracking-tight">Add</h1>
        <p className="text-sm text-slate-500">
          Log income or an expense in about 30 seconds — OCR + AI help with
          typing
        </p>
      </div>

      <div className="stagger grid gap-3 sm:grid-cols-3">
        <button
          type="button"
          onClick={() => {
            setActive("receipt");
            fileRef.current?.click();
          }}
          className="pressable rounded-2xl border border-slate-200 bg-white/95 p-4 text-left shadow-sm dark:border-slate-800 dark:bg-slate-950"
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-teal-50 text-teal-700 dark:bg-teal-950 dark:text-teal-300">
            <Camera className="h-5 w-5" />
          </span>
          <p className="font-semibold">Scan receipt</p>
          <p className="mt-1 text-xs text-slate-500">
            OCR → AI → confirm → save
          </p>
        </button>

        <button
          type="button"
          onClick={() => setActive("sms")}
          className={cn(
            "pressable rounded-2xl border bg-white/95 p-4 text-left shadow-sm dark:bg-slate-950",
            active === "sms"
              ? "border-teal-700 ring-2 ring-teal-700/20"
              : "border-slate-200 dark:border-slate-800"
          )}
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-teal-50 text-teal-700 dark:bg-teal-950 dark:text-teal-300">
            <ClipboardPaste className="h-5 w-5" />
          </span>
          <p className="font-semibold">Paste bank SMS</p>
          <p className="mt-1 text-xs text-slate-500">
            Clipboard or type → confirm
          </p>
        </button>

        <button
          type="button"
          onClick={() => setActive("text")}
          className={cn(
            "pressable rounded-2xl border bg-white/95 p-4 text-left shadow-sm dark:bg-slate-950",
            active === "text"
              ? "border-teal-700 ring-2 ring-teal-700/20"
              : "border-slate-200 dark:border-slate-800"
          )}
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-teal-50 text-teal-700 dark:bg-teal-950 dark:text-teal-300">
            <MessageSquareText className="h-5 w-5" />
          </span>
          <p className="font-semibold">Describe it</p>
          <p className="mt-1 text-xs text-slate-500">
            “Coffee 450 at Starbucks”
          </p>
        </button>
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (!file) return;
          void handleReceiptFile(file);
        }}
      />

      {active === "sms" && (
        <Card className="animate-slide-down">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <ClipboardPaste className="h-4 w-4" />
              Bank SMS
            </CardTitle>
            <CardDescription>
              Paste a debit/credit alert — AI fills the fields
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Textarea
              placeholder="Paste bank SMS here…"
              value={smsText}
              onChange={(e) => setSmsText(e.target.value)}
              rows={4}
              autoFocus
            />
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={async () => {
                  try {
                    const text = await navigator.clipboard.readText();
                    if (!text.trim()) {
                      toast.error("Clipboard is empty");
                      return;
                    }
                    setSmsText(text);
                    toast.success("Pasted from clipboard");
                  } catch {
                    toast.error("Clipboard blocked — paste manually");
                  }
                }}
              >
                Read clipboard
              </Button>
              <Button
                disabled={pending || !smsText.trim()}
                onClick={() =>
                  startTransition(async () => {
                    const result = await parseBankSms(smsText);
                    if ("error" in result) {
                      toast.error(result.error);
                      return;
                    }
                    openReview(result.data, "sms");
                  })
                }
              >
                <Sparkles className="h-4 w-4" />
                {pending ? "Parsing…" : "Parse & review"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {active === "text" && (
        <Card className="animate-slide-down">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <MessageSquareText className="h-4 w-4" />
              One-line note
            </CardTitle>
            <CardDescription>
              Examples: “Groceries 3200” · “Salary 150000” · “Uber 850”
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              placeholder="What did you spend or earn?"
              value={quickText}
              onChange={(e) => setQuickText(e.target.value)}
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Enter" && quickText.trim() && !pending) {
                  e.preventDefault();
                  startTransition(async () => {
                    const result = await parseQuickText(quickText);
                    if ("error" in result) {
                      toast.error(result.error);
                      return;
                    }
                    openReview(result.data, "text");
                  });
                }
              }}
            />
            <Button
              className="w-full sm:w-auto"
              disabled={pending || !quickText.trim()}
              onClick={() =>
                startTransition(async () => {
                  const result = await parseQuickText(quickText);
                  if ("error" in result) {
                    toast.error(result.error);
                    return;
                  }
                  openReview(result.data, "text");
                })
              }
            >
              <Sparkles className="h-4 w-4" />
              {pending ? "Parsing…" : "Parse & review"}
            </Button>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base">Quick manual</CardTitle>
          <CardDescription>
            Amount + category + Save — no AI needed
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-2">
            {(["expense", "income"] as const).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => {
                  setManualType(t);
                  setManualCategoryId(null);
                }}
                className={cn(
                  "flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium capitalize transition-[color,background-color,border-color,transform] duration-200 active:scale-[0.98]",
                  manualType === t
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
          <Input
            type="number"
            step="0.01"
            min="0"
            placeholder="Amount"
            className="h-12 text-2xl font-semibold"
            value={manualAmount}
            onChange={(e) => setManualAmount(e.target.value)}
          />
          <div className="flex flex-wrap gap-2">
            {manualCategories.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => setManualCategoryId(c.id)}
                className={cn(
                  "rounded-full border px-3 py-1.5 text-xs font-medium transition-[color,background-color,border-color,transform] duration-200 active:scale-95",
                  manualCategoryId === c.id
                    ? "border-teal-700 bg-teal-700 text-white"
                    : "border-slate-200 text-slate-600 hover:border-teal-600/40"
                )}
              >
                {c.name}
              </button>
            ))}
          </div>
          <Button
            size="lg"
            className="w-full"
            disabled={pending || !manualAmount || !accounts[0]}
            onClick={() => {
              const amount = Number(manualAmount);
              if (!amount || amount <= 0) {
                toast.error("Enter an amount");
                return;
              }
              startTransition(async () => {
                const result = await createTransaction({
                  account_id: accounts[0].id,
                  category_id: manualCategoryId,
                  amount,
                  type: manualType,
                  date: new Date().toISOString().slice(0, 10),
                  merchant: "",
                  notes: "",
                  is_recurring: false,
                  recurring_frequency: null,
                  transfer_to_account_id: null,
                });
                if (result.error) {
                  toast.error(result.error);
                  return;
                }
                toast.success("Saved");
                setManualAmount("");
                setManualCategoryId(null);
                router.refresh();
              });
            }}
          >
            {pending ? "Saving…" : "Save"}
          </Button>
          {accounts.length === 0 && (
            <p className="text-xs text-rose-600">
              Create an account first under More → Accounts.
            </p>
          )}
        </CardContent>
      </Card>

      {(ocrStatus || pending) && (
        <div className="animate-fade-in flex items-center justify-center gap-2 text-sm text-slate-500">
          <span className="spinner" aria-hidden />
          {ocrStatus ?? "Working with Gemini Flash…"}
        </div>
      )}

      <AiReviewModal
        open={reviewOpen}
        onOpenChange={onReviewClose}
        extraction={extraction}
        accounts={accounts}
        categories={categories}
        source={source}
        initialForm={initialForm}
      />
    </div>
  );
}
