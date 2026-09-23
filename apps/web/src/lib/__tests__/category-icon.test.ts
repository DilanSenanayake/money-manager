import { describe, expect, it } from "vitest";
import {
  getCategoryColor,
  getCategoryHex,
  getCategoryIcon,
  resolveCategoryIconKey,
} from "@/components/categories/category-icon";

describe("category visuals", () => {
  it("resolves seeded icon keys", () => {
    expect(resolveCategoryIconKey("utensils")).toBe("utensils");
    expect(resolveCategoryIconKey("shopping-cart", "Groceries")).toBe(
      "shopping-cart"
    );
  });

  it("maps common category names when icon is missing", () => {
    expect(resolveCategoryIconKey(null, "Dining")).toBe("utensils");
    expect(resolveCategoryIconKey(undefined, "Transport")).toBe("car");
  });

  it("returns distinct colors per category icon", () => {
    const dining = getCategoryColor("utensils", "Dining");
    const transport = getCategoryColor("car", "Transport");
    expect(dining.chip).not.toBe(transport.chip);
    expect(dining.fg).toContain("orange");
    expect(transport.fg).toContain("sky");
  });

  it("returns hex colors for charts", () => {
    expect(getCategoryHex("heart", "Health")).toBe("#e11d48");
    expect(getCategoryHex(null, "Groceries")).toBe("#4d7c0f");
  });

  it("returns a lucide icon component", () => {
    const Icon = getCategoryIcon("film", "Entertainment");
    expect(Icon).toBeTruthy();
    expect(Icon.displayName || Icon.name || "Film").toBeTruthy();
  });
});
