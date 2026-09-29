import { describe, expect, it } from "vitest";
import { canonicalMoney, canonicalRate } from "@/lib/money";

describe("canonicalMoney", () => {
  it("keeps cents from the typed text", () => {
    expect(canonicalMoney("10.10")).toBe("10.10");
    expect(canonicalMoney("10")).toBe("10.00");
    expect(canonicalMoney("0")).toBeNull();
    expect(canonicalMoney("0", { allowZero: true })).toBe("0.00");
  });

  it("keeps rate precision", () => {
    expect(canonicalRate("1.2500")).toBe("1.25");
    expect(canonicalRate("0")).toBeNull();
  });
});
