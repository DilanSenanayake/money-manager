import { describe, expect, it } from "vitest";
import { convertToBase, computeNetWorth } from "@/lib/currency";
import { matchCategoryId } from "@/lib/category-match";
import type { Category } from "@/lib/types";

describe("convertToBase", () => {
  it("returns amount when currencies match", () => {
    expect(convertToBase(42, "USD", "USD", [])).toBe(42);
  });

  it("uses a direct rate", () => {
    expect(
      convertToBase(100, "EUR", "USD", [
        {
          id: "1",
          user_id: "u",
          from_currency: "EUR",
          to_currency: "USD",
          rate: 1.1,
          updated_at: "",
        },
      ])
    ).toBeCloseTo(110);
  });

  it("uses an inverse rate", () => {
    expect(
      convertToBase(100, "EUR", "USD", [
        {
          id: "1",
          user_id: "u",
          from_currency: "USD",
          to_currency: "EUR",
          rate: 2,
          updated_at: "",
        },
      ])
    ).toBeCloseTo(50);
  });

  it("falls back to amount when rate is missing", () => {
    expect(convertToBase(100, "JPY", "USD", [])).toBe(100);
  });
});

describe("computeNetWorth", () => {
  it("subtracts credit balances as liabilities", () => {
    expect(
      computeNetWorth(
        [
          { balance: 1000, currency: "USD", type: "checking" },
          { balance: 200, currency: "USD", type: "credit" },
        ],
        "USD",
        []
      )
    ).toBe(800);
  });
});

describe("matchCategoryId", () => {
  const categories: Category[] = [
    {
      id: "dining",
      user_id: "u",
      name: "Dining",
      icon: "utensils",
      type: "expense",
      monthly_budget: null,
      created_at: "",
    },
    {
      id: "other",
      user_id: "u",
      name: "Other",
      icon: "circle",
      type: "expense",
      monthly_budget: null,
      created_at: "",
    },
  ];

  it("matches dining aliases from merchant text", () => {
    expect(
      matchCategoryId(categories, "expense", "Starbucks coffee")
    ).toBe("dining");
  });

  it("falls back to Other when nothing matches", () => {
    expect(matchCategoryId(categories, "expense", "xyzzy")).toBe("other");
  });
});
