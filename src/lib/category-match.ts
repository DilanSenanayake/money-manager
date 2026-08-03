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

  // Exact / partial name match
  for (const c of pool) {
    const name = c.name.toLowerCase();
    if (joined === name || joined.includes(name) || name.includes(joined)) {
      return c.id;
    }
  }

  const aliases = type === "expense" ? EXPENSE_ALIASES : INCOME_ALIASES;
  for (const [canonical, words] of Object.entries(aliases)) {
    if (words.some((w) => joined.includes(w))) {
      const found = pool.find(
        (c) => c.name.toLowerCase() === canonical.toLowerCase()
      );
      if (found) return found.id;
    }
  }

  // Token overlap with category names
  const tokens = joined.split(/[^a-z0-9]+/).filter((t) => t.length > 2);
  for (const c of pool) {
    const name = c.name.toLowerCase();
    if (tokens.some((t) => name.includes(t) || t.includes(name))) {
      return c.id;
    }
  }

  const other = pool.find((c) => c.name.toLowerCase() === "other");
  return other?.id ?? pool[pool.length - 1]?.id ?? null;
}
