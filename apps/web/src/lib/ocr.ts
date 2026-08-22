"use client";

import { createWorker } from "tesseract.js";

export type OcrProgress = {
  status: string;
  progress: number;
};

/**
 * Browser-side OCR. Returns cleaned plain text for structuring.
 */
export async function extractTextFromImage(
  file: File | Blob,
  onProgress?: (info: OcrProgress) => void
): Promise<{ text: string } | { error: string }> {
  let worker: Awaited<ReturnType<typeof createWorker>> | null = null;

  try {
    onProgress?.({ status: "Getting ready…", progress: 0 });

    worker = await createWorker("eng", 1, {
      logger: (m) => {
        if (typeof m.progress === "number") {
          onProgress?.({
            status:
              m.status === "recognizing text"
                ? "Reading your receipt…"
                : "Getting ready…",
            progress: m.progress,
          });
        }
      },
    });

    const {
      data: { text },
    } = await worker.recognize(file);

    const cleaned = text.replace(/\r/g, "").replace(/[ \t]+\n/g, "\n").trim();

    if (cleaned.length < 8) {
      return {
        error:
          "We couldn’t read that photo clearly. Try again with better lighting, or add it manually.",
      };
    }

    return { text: cleaned };
  } catch {
    return {
      error: "We couldn’t read that photo. Try another one, or add it manually.",
    };
  } finally {
    if (worker) {
      await worker.terminate().catch(() => undefined);
    }
  }
}
