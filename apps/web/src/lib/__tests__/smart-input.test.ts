import { describe, expect, it } from "vitest";
import { looksLikeBankSms } from "@/lib/smart-input";

describe("looksLikeBankSms", () => {
  it("treats short notes as text", () => {
    expect(looksLikeBankSms("Coffee 450")).toBe(false);
    expect(looksLikeBankSms("Salary 150000")).toBe(false);
  });

  it("detects typical bank alerts", () => {
    expect(
      looksLikeBankSms(
        "LKR 4,500.00 debited from A/C **4521 at CITY MARKET on 17 Sep. Avl bal 1,210.00"
      )
    ).toBe(true);
  });
});
