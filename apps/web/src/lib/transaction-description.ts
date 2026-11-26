/** Short name plus optional longer detail, stored in separate columns. */
export function entryDescriptions(
  merchant?: string | null,
  notes?: string | null
): { merchant: string | null; notes: string | null } {
  const name = (merchant ?? "").trim();
  const detail = (notes ?? "").trim();
  return {
    merchant: name ? name.slice(0, 200) : null,
    notes: detail ? detail.slice(0, 1000) : null,
  };
}

/** Longer detail for a list row, when it adds something beyond the short name. */
export function transactionDetail(tx: {
  merchant?: string | null;
  notes?: string | null;
}): string | null {
  const name = (tx.merchant ?? "").trim();
  const detail = (tx.notes ?? "").trim();
  if (!detail || detail.toLowerCase() === name.toLowerCase()) return null;
  return detail;
}

/** Short name for a list row, then the long description, then the category. */
export function transactionTitle(tx: {
  merchant?: string | null;
  notes?: string | null;
  category?: { name: string } | null;
  type?: string;
}): string {
  const name = (tx.merchant ?? "").trim().split("\n")[0]?.trim() ?? "";
  if (name) return name;
  const detail = (tx.notes ?? "").trim().split("\n")[0]?.trim() ?? "";
  return detail || tx.category?.name || tx.type || "Transaction";
}
