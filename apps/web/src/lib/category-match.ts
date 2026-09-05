import type { Category } from "@/lib/types";

/** Keywords → seeded category names (expense). */
const EXPENSE_ALIASES: Record<string, string[]> = {
  Dining: [
    "dining",
    "restaurant",
    "cafe",
    "coffee",
    "starbucks",
    "food",
    "lunch",
    "dinner",
    "breakfast",
    "mcdonald",
    "kfc",
    "pizza",
    "uber eats",
    "doordash",
  ],
  Groceries: [
    "grocery",
    "groceries",
    "supermarket",
    "market",
    "walmart",
    "costco",
    "whole foods",
    "trader joe",
  ],
  Transport: [
    "transport",
    "uber",
    "lyft",
    "taxi",
    "fuel",
    "gas",
    "petrol",
    "parking",
    "metro",
    "bus",
    "train",
    "grab",
  ],
  Shopping: [
    "shopping",
    "amazon",
    "mall",
    "clothing",
    "apparel",
    "store",
    "retail",
  ],
  Utilities: [
    "utility",
    "utilities",
    "electric",
    "water",
    "internet",
    "wifi",
    "phone",
    "bill",
    "gas bill",
  ],
  Health: [
    "health",
    "pharmacy",
    "medical",
    "doctor",
    "hospital",
    "dental",
    "clinic",
  ],
  Entertainment: [
    "entertainment",
    "movie",
    "netflix",
    "spotify",
    "game",
    "cinema",
    "concert",
  ],
  Rent: ["rent", "mortgage", "housing", "lease"],
  Other: ["other", "misc", "general"],
};

const INCOME_ALIASES: Record<string, string[]> = {
  Salary: ["salary", "paycheck", "wage", "payroll"],
  Freelance: ["freelance", "contract", "gig", "client"],
  Investments: ["investment", "dividend", "interest", "stock"],
};

function normalize(s: string) {
  return s.toLowerCase().trim();
}

function hasWord(haystack: string, needle: string) {
  if (!needle) return false;
  if (haystack === needle) return true;
  const parts = haystack.split(/[^a-z0-9]+/).filter(Boolean);
  return parts.includes(needle);
}

/**
 * Resolve a category id from LLM/user labels and optional merchant text.
 */
export function matchCategoryId(
  categories: Category[],
  type: "income" | "expense",
  ...hints: Array<string | null | undefined>
): string | null {
  const pool = categories.filter((c) => c.type === type);
  if (pool.length === 0) return null;

  const joined = hints
    .filter(Boolean)
    .map((h) => normalize(String(h)))
    .join(" ");
  if (!joined) {
    const other = pool.find((c) => c.name.toLowerCase() === "other");
    return other?.id ?? null;
  }

  // Longer names first so "other" does not match inside "mother"
  const byLength = [...pool].sort((a, b) => b.name.length - a.name.length);
  for (const c of byLength) {
    const name = c.name.toLowerCase();
    if (joined === name || hasWord(joined, name)) {
      return c.id;
    }
  }

  const aliases = type === "expense" ? EXPENSE_ALIASES : INCOME_ALIASES;
  const ranked = Object.entries(aliases)
    .flatMap(([canonical, words]) =>
      words.map((word) => ({ canonical, word }))
    )
    .sort((a, b) => b.word.length - a.word.length);

  for (const { canonical, word } of ranked) {
    const matched = word.includes(" ")
      ? joined.includes(word)
      : hasWord(joined, word);
    if (!matched) continue;
    const found = pool.find(
      (c) => c.name.toLowerCase() === canonical.toLowerCase()
    );
    if (found) return found.id;
  }

  const tokens = joined.split(/[^a-z0-9]+/).filter((t) => t.length > 2);
  for (const c of byLength) {
    const name = c.name.toLowerCase();
    if (
      tokens.some(
        (t) => name === t || (t.length >= 4 && (name.includes(t) || t.includes(name)))
      )
    ) {
      return c.id;
    }
  }

  const other = pool.find((c) => c.name.toLowerCase() === "other");
  return other?.id ?? pool[pool.length - 1]?.id ?? null;
}
