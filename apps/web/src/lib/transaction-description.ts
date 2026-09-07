/** Merge merchant + notes into one user-facing description. */
export function fromMerchantAndNotes(
  merchant?: string | null,
  notes?: string | null
): string {
  const m = merchant?.trim() ?? "";
  const n = notes?.trim() ?? "";
  if (!m) return n;
  if (!n || n === m) return m;
  // Merchant was truncated title of a longer note
  if (n.startsWith(m)) return n;
  return `${m}\n${n}`;
}

/**
 * Split a single description into DB fields:
 * - merchant: short title (≤200) for lists
 * - notes: full text when longer than 200, otherwise unused
 */
export function toMerchantAndNotes(description: string): {
  merchant: string | null;
  notes: string | null;
} {
  const text = description.trim();
  if (!text) return { merchant: null, notes: null };
  if (text.length <= 200) return { merchant: text, notes: null };
  return { merchant: text.slice(0, 200), notes: text.slice(0, 1000) };
}

/** Prefer merchant, fall back to notes — for list row titles. */
export function transactionTitle(tx: {
  merchant?: string | null;
  notes?: string | null;
  category?: { name: string } | null;
  type?: string;
}): string {
  return (
    fromMerchantAndNotes(tx.merchant, tx.notes).split("\n")[0] ||
    tx.category?.name ||
    tx.type ||
    "Transaction"
  );
}
