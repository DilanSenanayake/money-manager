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
    "mcdonalds",
    "kfc",
    "pizza",
    "uber eats",
    "doordash",
    "burger",
    "sushi",
    "bistro",
    "takeaway",
    "takeout",
    "eatery",
  ],
  Groceries: [
    "grocery",
    "groceries",
    "supermarket",
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
};

const INCOME_ALIASES: Record<string, string[]> = {
  Salary: ["salary", "paycheck", "wage", "payroll"],
  Freelance: ["freelance", "contract", "gig", "client"],
  Investments: ["investment", "dividend", "interest", "stock"],
};

const WEAK_LABELS = new Set(["other", "misc", "general", "unknown", "n/a", "na"]);

function normalize(s: string) {
  return s.toLowerCase().trim();
}

function hasWord(haystack: string, needle: string) {
  if (!needle) return false;
  if (haystack === needle) return true;
  const parts = haystack.split(/[^a-z0-9]+/).filter(Boolean);
  return parts.some(
    (p) =>
      p === needle ||
      // Brand stems: "mcdonald" matches "mcdonalds"
      (needle.length >= 5 && p.startsWith(needle))
  );
}

function isWeakLabel(value: string) {
  return WEAK_LABELS.has(normalize(value));
}

function isOtherCategory(name: string) {
  return name.toLowerCase() === "other";
}

/**
 * Resolve a category id from LLM/user labels and optional merchant text.
 * "Other" / misc labels never win early — merchant aliases can still map to Dining, etc.
 */
export function matchCategoryId(
  categories: Category[],
  type: "income" | "expense",
  ...hints: Array<string | null | undefined>
): string | null {
  const pool = categories.filter((c) => c.type === type);
  if (pool.length === 0) return null;

  const other = pool.find((c) => isOtherCategory(c.name));

  const cleaned = hints
    .filter((h): h is string => Boolean(h && String(h).trim()))
    .map((h) => normalize(String(h)))
    // Ignore OCR dumps that pollute alias matching (e.g. "STORE", "BILL")
    .filter((h) => !h.startsWith("from receipt:"));

  const joined = cleaned.join(" ");
  if (!joined || cleaned.every(isWeakLabel)) {
    return other?.id ?? null;
  }

  // Prefer an explicit non-Other category name from any hint (usually the LLM label)
  const byLength = [...pool]
    .filter((c) => !isOtherCategory(c.name))
    .sort((a, b) => b.name.length - a.name.length);

  for (const hint of cleaned) {
    if (isWeakLabel(hint)) continue;
    for (const c of byLength) {
      const name = c.name.toLowerCase();
      if (hint === name || hasWord(hint, name)) {
        return c.id;
      }
    }
  }

  // Then scan the full joined string for non-Other category names
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
        (t) =>
          name === t ||
          (t.length >= 4 && (name.includes(t) || t.includes(name)))
      )
    ) {
      return c.id;
    }
  }

  return other?.id ?? pool[pool.length - 1]?.id ?? null;
}
