/**
 * Heuristic: long bank-style alerts vs short “Coffee 450” notes.
 * User can still correct on the review sheet.
 */
export function looksLikeBankSms(text: string): boolean {
  const value = text.trim();
  if (value.length < 48) return false;

  const signals = [
    /debited|credited|withdrawn|deposited/i,
    /\ba\/c\b|\bacct\b|\baccount\b/i,
    /avl\.?\s*bal|available balance|bal\.?\s*:/i,
    /\b(upi|neft|imps|rtgs|pos)\b/i,
    /\b(txn|transaction|ref\.?\s*no)\b/i,
    /\b(rs\.?|lkr|inr|usd)\s*[\d,]/i,
    /\*{2,}\d{2,}/,
  ];

  let hits = 0;
  for (const re of signals) {
    if (re.test(value)) hits += 1;
  }
  return hits >= 2 || (value.length >= 120 && hits >= 1);
}
