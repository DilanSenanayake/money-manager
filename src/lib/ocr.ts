"use client";

import { createWorker } from "tesseract.js";

export type OcrProgress = {
  status: string;
  progress: number;
};

/**
 * Browser-side OCR with Tesseract.js (free, no API key).
 * Returns cleaned plain text for Gemini structured parsing.
 */
export async function extractTextFromImage(
  file: File | Blob,
  onProgress?: (info: OcrProgress) => void
): Promise<{ text: string } | { error: string }> {
  let worker: Awaited<ReturnType<typeof createWorker>> | null = null;

  try {
    onProgress?.({ status: "Loading OCR engine…", progress: 0 });

    worker = await createWorker("eng", 1, {
      logger: (m) => {
        if (typeof m.progress === "number") {
          onProgress?.({
            status:
              m.status === "recognizing text"
                ? "Reading receipt…"
                : "Preparing OCR…",
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
          "Couldn’t read enough text from this image. Try a clearer, well-lit photo.",
      };
    }

    return { text: cleaned };
  } catch (err) {
    return {
      error:
        err instanceof Error
          ? err.message
          : "OCR failed — try another photo or add manually",
    };
  } finally {
    if (worker) {
      await worker.terminate().catch(() => undefined);
    }
  }
}
