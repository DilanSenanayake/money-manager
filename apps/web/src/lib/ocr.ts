"use client";

export type OcrProgress = {
  status: string;
  progress: number;
};

const MAX_EDGE = 1600;
const UNREADABLE =
  "We couldn’t read that photo. Try a clearer JPEG or PNG, or add it manually.";

/**
 * Gallery photos are often HEIC, huge, or sideways. Decode and redraw as a
 * JPEG so Tesseract gets a format it can actually read.
 */
export async function prepareImageForOcr(file: File | Blob): Promise<Blob> {
  const source = await decodeImage(file);
  const scale = Math.min(1, MAX_EDGE / Math.max(source.width, source.height));
  const width = Math.max(1, Math.round(source.width * scale));
  const height = Math.max(1, Math.round(source.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    source.close();
    throw new Error("decode");
  }
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, width, height);
  ctx.drawImage(source.image, 0, 0, width, height);
  source.close();
  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob((b) => resolve(b), "image/jpeg", 0.85)
  );
  if (!blob) throw new Error("decode");
  return blob;
}

type Decoded = {
  image: CanvasImageSource;
  width: number;
  height: number;
  close: () => void;
};

async function decodeImage(file: File | Blob): Promise<Decoded> {
  try {
    const bitmap = await createImageBitmap(file);
    return {
      image: bitmap,
      width: bitmap.width,
      height: bitmap.height,
      close: () => bitmap.close(),
    };
  } catch {
    // createImageBitmap often fails on HEIC / some Android gallery files.
  }

  const url = URL.createObjectURL(file);
  try {
    const img = await loadHtmlImage(url);
    return {
      image: img,
      width: img.naturalWidth || img.width,
      height: img.naturalHeight || img.height,
      close: () => URL.revokeObjectURL(url),
    };
  } catch (error) {
    URL.revokeObjectURL(url);
    throw error;
  }
}

function loadHtmlImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      if (!img.naturalWidth) {
        reject(new Error("decode"));
        return;
      }
      resolve(img);
    };
    img.onerror = () => reject(new Error("decode"));
    img.src = src;
  });
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
    let image: Blob;
    try {
      image = await prepareImageForOcr(file);
    } catch {
      return {
        error:
          "This photo format isn’t supported. Take a new photo, or pick a JPEG/PNG.",
      };
    }

    worker = await createWorker("eng", 1, {
      workerPath: `${window.location.origin}/tesseract/worker.min.js`,
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
    } = await worker.recognize(image, { rotateAuto: true });

    const cleaned = text.replace(/\r/g, "").replace(/[ \t]+\n/g, "\n").trim();

    if (cleaned.length < 8) {
      return { error: UNREADABLE };
    }

    return { text: cleaned };
  } catch (error) {
    console.error("Receipt OCR failed", error);
    return { error: UNREADABLE };
  } finally {
    if (worker) {
      await worker.terminate().catch(() => undefined);
    }
  }
}
