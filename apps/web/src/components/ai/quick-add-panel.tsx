"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { PageHeader } from "@/components/layout/page-header";
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
import { localDateYYYYMMDD } from "@/lib/dates";
import { toMerchantAndNotes } from "@/lib/transaction-description";
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
import { CategoryChip } from "@/components/categories/category-icon";
import { Button } from "@/components/ui/button";
import { DateQuickPick } from "@/components/ui/date-quick-pick";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { LoadingOverlay } from "@/components/ui/loading-overlay";

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
  const [busy, setBusy] = useState(false);
  const [busyTitle, setBusyTitle] = useState("Just a moment");
  const [busyMessage, setBusyMessage] = useState("Please wait…");
  const [busyProgress, setBusyProgress] = useState<number | null>(null);
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
  const [manualDate, setManualDate] = useState(localDateYYYYMMDD());
  const [manualDescription, setManualDescription] = useState("");

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

  function startBusy(
    title: string,
    message: string,
    progress: number | null = null
  ) {
    setBusyTitle(title);
    setBusyMessage(message);
    setBusyProgress(progress);
    setBusy(true);
  }

  function stopBusy() {
    setBusy(false);
    setBusyProgress(null);
    setBusyMessage("Please wait…");
  }

  function openReview(
    data: ReceiptExtraction | SmsExtraction | QuickTextExtraction,
    kind: AiSource
  ) {
    stopBusy();
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
      stopBusy();
    }
  }

  async function handleReceiptFile(file: File) {
    startBusy("Reading receipt", "Looking at your photo…", 0);
    try {
      const ocr = await extractTextFromImage(file, (info) => {
        setBusyProgress(info.progress);
        setBusyMessage(info.status);
      });

      if ("error" in ocr) {
        stopBusy();
        toast.error(ocr.error);
        return;
      }

      startBusy("Almost done", "Filling in the details…", null);
      const result = await parseReceiptText(ocr.text);
      if ("error" in result) {
        stopBusy();
        toast.error(result.error);
        return;
      }
      openReview(result.data, "receipt");
    } catch {
      stopBusy();
      toast.error("Something went wrong. Please try again.");
    }
  }

  async function runSmsParse() {
    if (!smsText.trim() || busy) return;
    startBusy("Reading message", "Picking out the amount and details…");
    try {
      const result = await parseBankSms(smsText);
      if ("error" in result) {
        stopBusy();
        toast.error(result.error);
        return;
      }
      openReview(result.data, "sms");
    } catch {
      stopBusy();
      toast.error("Something went wrong. Please try again.");
    }
  }

  async function runTextParse() {
    if (!quickText.trim() || busy) return;
    startBusy("Understanding", "Filling in the details…");
    try {
      const result = await parseQuickText(quickText);
      if ("error" in result) {
        stopBusy();
        toast.error(result.error);
        return;
      }
      openReview(result.data, "text");
    } catch {
      stopBusy();
      toast.error("Something went wrong. Please try again.");
    }
  }

  async function runManualSave() {
    const amount = Number(manualAmount);
    if (!amount || amount <= 0) {
      toast.error("Enter an amount");
      return;
    }
    if (!accounts[0] || busy) return;

    startBusy("Saving", "Adding to your money tracker…");
    try {
      const result = await createTransaction({
        account_id: accounts[0].id,
        category_id: manualCategoryId,
        amount,
        type: manualType,
        date: manualDate,
        ...toMerchantAndNotes(manualDescription),
        is_recurring: false,
        recurring_frequency: null,
        transfer_to_account_id: null,
      });
      if (result.error) {
        stopBusy();
        toast.error(result.error);
        return;
      }
      toast.success("Saved");
      setManualAmount("");
      setManualCategoryId(null);
      setManualDate(localDateYYYYMMDD());
      setManualDescription("");
      stopBusy();
      router.push("/dashboard");
      router.refresh();
    } catch {
      stopBusy();
      toast.error("Something went wrong. Please try again.");
    }
  }

  return (
    <div className="page-stack">
      <PageHeader
        title="Add"
        description="Log income or an expense in about 30 seconds"
      />

      <div className="stagger grid gap-3 sm:grid-cols-3">
        <button
          type="button"
          disabled={busy}
          onClick={() => {
            setActive("receipt");
            fileRef.current?.click();
          }}
          className="surface surface-interactive pressable p-4 text-left disabled:opacity-60"
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
            <Camera className="h-5 w-5" />
          </span>
          <p className="font-semibold">Scan receipt</p>
          <p className="mt-1 text-xs text-[var(--muted)]">
            Photo → check → save
          </p>
        </button>

        <button
          type="button"
          onClick={() => setActive("sms")}
          className={cn(
            "surface surface-interactive pressable p-4 text-left",
            active === "sms" &&
              "border-[var(--accent)] ring-2 ring-[var(--accent-ring)]"
          )}
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
            <ClipboardPaste className="h-5 w-5" />
          </span>
          <p className="font-semibold">Paste bank SMS</p>
          <p className="mt-1 text-xs text-[var(--muted)]">
            Clipboard or type → confirm
          </p>
        </button>

        <button
          type="button"
          onClick={() => setActive("text")}
          className={cn(
            "surface surface-interactive pressable p-4 text-left",
            active === "text" &&
              "border-[var(--accent)] ring-2 ring-[var(--accent-ring)]"
          )}
        >
          <span className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--accent-soft)] text-[var(--accent-hover)]">
            <MessageSquareText className="h-5 w-5" />
          </span>
          <p className="font-semibold">Describe it</p>
          <p className="mt-1 text-xs text-[var(--muted)]">
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
              Bank message
            </CardTitle>
            <CardDescription>
              Paste a bank alert — we’ll fill in the details for you
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Textarea
              placeholder="Paste your bank message here…"
              value={smsText}
              onChange={(e) => setSmsText(e.target.value)}
              rows={4}
              autoFocus
            />
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                disabled={busy}
                onClick={async () => {
                  try {
                    const text = await navigator.clipboard.readText();
                    if (!text.trim()) {
                      toast.error("Nothing to paste from the clipboard");
                      return;
                    }
                    setSmsText(text);
                    toast.success("Pasted");
                  } catch {
                    toast.error("Couldn’t read the clipboard — paste it yourself");
                  }
                }}
              >
                Paste from clipboard
              </Button>
              <Button
                disabled={busy || !smsText.trim()}
                onClick={() => void runSmsParse()}
              >
                <Sparkles className="h-4 w-4" />
                Continue
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
              Describe it
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
                if (e.key === "Enter" && quickText.trim() && !busy) {
                  e.preventDefault();
                  void runTextParse();
                }
              }}
            />
            <Button
              className="w-full sm:w-auto"
              disabled={busy || !quickText.trim()}
              onClick={() => void runTextParse()}
            >
              <Sparkles className="h-4 w-4" />
              Continue
            </Button>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base">Add manually</CardTitle>
          <CardDescription>
            Amount, description, category, and save
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-2">
            {(["expense", "income"] as const).map((t) => (
              <button
                key={t}
                type="button"
                disabled={busy}
                onClick={() => {
                  setManualType(t);
                  setManualCategoryId(null);
                }}
                className={cn(
                  "flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium capitalize transition-[color,background-color,border-color,transform] duration-200 active:scale-[0.98] disabled:opacity-60",
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
            placeholder={`Amount (${accounts[0]?.currency ?? "USD"})`}
            className="h-12 text-2xl font-semibold"
            value={manualAmount}
            disabled={busy}
            onChange={(e) => setManualAmount(e.target.value)}
          />
          <Textarea
            placeholder="What was this for? (optional)"
            rows={2}
            maxLength={1000}
            value={manualDescription}
            disabled={busy}
            onChange={(e) => setManualDescription(e.target.value)}
          />
          <DateQuickPick
            value={manualDate}
            onChange={setManualDate}
            disabled={busy}
          />
          <div className="flex flex-wrap gap-2">
            {manualCategories.map((c) => (
              <CategoryChip
                key={c.id}
                icon={c.icon}
                name={c.name}
                selected={manualCategoryId === c.id}
                disabled={busy}
                onClick={() => setManualCategoryId(c.id)}
              />
            ))}
          </div>
          <Button
            size="lg"
            className="w-full"
            disabled={busy || !manualAmount || !accounts[0]}
            onClick={() => void runManualSave()}
          >
            Save
          </Button>
          {accounts.length === 0 && (
            <p className="text-xs text-rose-600">
              Add an account first in More → Accounts.
            </p>
          )}
        </CardContent>
      </Card>

      <LoadingOverlay
        open={busy}
        title={busyTitle}
        message={busyMessage}
        progress={busyProgress}
      />

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
