"use client";

export type OcrProgress = {
  status: string;
  progress: number;
};

const MAX_EDGE = 1600;

/**
 * Camera photos are often too large for Tesseract in the browser and crash
 * right after capture. Downscale to a JPEG first.
 */
export async function prepareImageForOcr(file: File | Blob): Promise<Blob> {
  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      bitmap.close();
      return file;
    }
    ctx.drawImage(bitmap, 0, 0, width, height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob((b) => resolve(b), "image/jpeg", 0.82)
    );
    return blob ?? file;
  } catch {
    return file;
  }
}

/**
 * Browser-side OCR. Returns cleaned plain text for structuring.
 * Tesseract is loaded on demand so it doesn't slow down other pages.
 */
export async function extractTextFromImage(
  file: File | Blob,
  onProgress?: (info: OcrProgress) => void
): Promise<{ text: string } | { error: string }> {
  const { createWorker } = await import("tesseract.js");
  let worker: Awaited<ReturnType<typeof createWorker>> | null = null;

  try {
    onProgress?.({ status: "Getting ready…", progress: 0 });
    const image = await prepareImageForOcr(file);

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
    } = await worker.recognize(image);

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
