"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { ClipboardPaste, Upload } from "lucide-react";
import { parseBankSms, parseReceiptImage } from "@/app/actions/ai";
import type { Account, Category } from "@/lib/types";
import type { ReceiptExtraction, SmsExtraction } from "@/lib/schemas";
import { AiReviewModal } from "@/components/ai/ai-review-modal";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export function AiImportPanel({
  accounts,
  categories,
}: {
  accounts: Account[];
  categories: Category[];
}) {
  const [pending, startTransition] = useTransition();
  const [smsText, setSmsText] = useState("");
  const [extraction, setExtraction] = useState<
    ReceiptExtraction | SmsExtraction | null
  >(null);
  const [source, setSource] = useState<"receipt" | "sms" | null>(null);
  const [reviewOpen, setReviewOpen] = useState(false);

  function openReview(
    data: ReceiptExtraction | SmsExtraction,
    kind: "receipt" | "sms"
  ) {
    setExtraction(data);
    setSource(kind);
    setReviewOpen(true);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-3xl tracking-tight">AI Import</h1>
        <p className="text-sm text-slate-500">
          Free-tier Gemini Flash OCR & SMS parsing — always review before save
        </p>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <Upload className="h-4 w-4" />
              Receipt OCR
            </CardTitle>
            <CardDescription>
              Upload a receipt image for structured extraction
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form
              className="space-y-3"
              onSubmit={(e) => {
                e.preventDefault();
                const formData = new FormData(e.currentTarget);
                startTransition(async () => {
                  const result = await parseReceiptImage(formData);
                  if ("error" in result) {
                    toast.error(result.error);
                    return;
                  }
                  openReview(result.data, "receipt");
                });
              }}
            >
              <input
                name="image"
                type="file"
                accept="image/*"
                required
                className="block w-full text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-teal-700 file:px-3 file:py-2 file:text-sm file:font-medium file:text-white"
              />
              <Button type="submit" disabled={pending} className="w-full">
                {pending ? "Parsing…" : "Parse receipt"}
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <ClipboardPaste className="h-4 w-4" />
              Bank SMS parser
            </CardTitle>
            <CardDescription>
              Paste a bank alert or grab it from the clipboard
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Textarea
              placeholder="Paste bank SMS here…"
              value={smsText}
              onChange={(e) => setSmsText(e.target.value)}
              rows={6}
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
                    toast.success("Clipboard pasted");
                  } catch {
                    toast.error(
                      "Clipboard access denied — paste the message manually"
                    );
                  }
                }}
              >
                <ClipboardPaste className="h-4 w-4" />
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
                {pending ? "Parsing…" : "Parse SMS"}
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      <AiReviewModal
        open={reviewOpen}
        onOpenChange={setReviewOpen}
        extraction={extraction}
        accounts={accounts}
        categories={categories}
        source={source}
      />
    </div>
  );
}
