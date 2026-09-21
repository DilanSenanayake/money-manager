import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import {
  DEFAULT_GA_MEASUREMENT_ID,
  getGaMeasurementId,
  sanitizeEventParams,
  isNextRedirectError,
  trackAfterAction,
  trackEvent,
} from "@/lib/analytics";

describe("getGaMeasurementId", () => {
  it("accepts a GA4 measurement ID", () => {
    expect(getGaMeasurementId("G-ABC12DEF34")).toBe("G-ABC12DEF34");
  });

  it("trims whitespace", () => {
    expect(getGaMeasurementId("  G-XYZ9  ")).toBe("G-XYZ9");
  });

  it("falls back to the product measurement ID", () => {
    expect(getGaMeasurementId(undefined)).toBe(DEFAULT_GA_MEASUREMENT_ID);
    expect(getGaMeasurementId("")).toBe(DEFAULT_GA_MEASUREMENT_ID);
  });

  it("rejects UA or malformed values", () => {
    expect(getGaMeasurementId("UA-123456-1")).toBeUndefined();
    expect(getGaMeasurementId("not-an-id")).toBeUndefined();
  });
});

describe("sanitizeEventParams", () => {
  it("keeps coarse product fields", () => {
    expect(
      sanitizeEventParams({
        method: "email",
        type: "expense",
        content_type: "cta",
        item_id: "start_free_hero",
      })
    ).toEqual({
      method: "email",
      type: "expense",
      content_type: "cta",
      item_id: "start_free_hero",
    });
  });

  it("drops money, identity, and free-text fields", () => {
    expect(
      sanitizeEventParams({
        amount: 42.5,
        value: 42.5,
        currency: "USD",
        email: "you@example.com",
        merchant: "Cafe",
        notes: "lunch",
        method: "manual",
      })
    ).toEqual({ method: "manual" });
  });

  it("returns undefined when nothing safe remains", () => {
    expect(sanitizeEventParams({ amount: 10, email: "a@b.c" })).toBeUndefined();
    expect(sanitizeEventParams(undefined)).toBeUndefined();
  });
});

describe("isNextRedirectError", () => {
  it("detects the App Router redirect digest", () => {
    expect(
      isNextRedirectError({ digest: "NEXT_REDIRECT;replace;/dashboard;303;" })
    ).toBe(true);
  });

  it("ignores ordinary errors", () => {
    expect(isNextRedirectError(new Error("nope"))).toBe(false);
    expect(isNextRedirectError(null)).toBe(false);
  });
});

describe("trackEvent", () => {
  beforeEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("no-ops when gtag is missing", () => {
    expect(() => trackEvent("login", { method: "email" })).not.toThrow();
  });

  it("sends sanitized events through gtag when configured", () => {
    const gtag = vi.fn();
    vi.stubEnv("NEXT_PUBLIC_GA_MEASUREMENT_ID", "G-TESTID1");
    vi.stubGlobal("window", { gtag });
    trackEvent("login", { method: "email", amount: 99 });
    expect(gtag).toHaveBeenCalledWith("event", "login", { method: "email" });
  });
});

describe("trackAfterAction", () => {
  beforeEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.stubEnv("NEXT_PUBLIC_GA_MEASUREMENT_ID", "G-TESTID1");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("does not track failed actions", async () => {
    const gtag = vi.fn();
    vi.stubGlobal("window", { gtag });
    const result = await trackAfterAction("login", { method: "email" }, async () => ({
      error: "Invalid email or password",
    }));
    expect(result).toEqual({ error: "Invalid email or password" });
    expect(gtag).not.toHaveBeenCalled();
  });

  it("tracks successful actions that return a message", async () => {
    const gtag = vi.fn();
    vi.stubGlobal("window", { gtag });
    await trackAfterAction("sign_up", { method: "email" }, async () => ({
      message: "Check your email",
    }));
    expect(gtag).toHaveBeenCalledWith("event", "sign_up", { method: "email" });
  });

  it("tracks Server Action redirects", async () => {
    const gtag = vi.fn();
    vi.stubGlobal("window", { gtag });
    const redirect = Object.assign(new Error("NEXT_REDIRECT"), {
      digest: "NEXT_REDIRECT;replace;/dashboard;303;",
    });
    await expect(
      trackAfterAction("login", { method: "email" }, async () => {
        throw redirect;
      })
    ).rejects.toBe(redirect);
    expect(gtag).toHaveBeenCalledWith("event", "login", { method: "email" });
  });
});
