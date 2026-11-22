import { CURRENCIES, type ReceiptExtraction } from "@/lib/schemas";

const KNOWN = new Set<string>(CURRENCIES);

const totalLine =
  /\b(grand\s+total|amount\s+due|balance\s+due|total\s+due|net\s+amount|amount\s+paid|total|to\s+pay|nett)\b/i;

function tokenPattern() {
  return new RegExp(
    String.raw`\b(?:sri\s+lankan?\s+rupees?|indian\s+rupees?|us\s+dollars?|australian\s+dollars?|canadian\s+dollars?|singapore\s+dollars?|swiss\s+francs?|british\s+pounds?|pound\s+sterling|japanese\s+yen)\b|US\$|\bUSD\b|\bDOLLARS?\b|A\$|\bAUD\b|C\$|\bCAD\b|S\$|\bSGD\b|€|\bEUR(?:O(?:S)?|S)?\b|£|\bGBP\b|\bPOUNDS?\b|\bSTERLING\b|¥|￥|\bJPY\b|\bYEN\b|\bCHF\b|\bFRANCS?\b|\bLKR\b|\bSLR\b|රු\.?|₹|\bINR\b|\bRs\.?\b|\bRupees?\b|(?<![A-Za-z])\$(?=\s*\d)`,
    "gi"
  );
}

type Hit = {
  code: string;
  onTotal: boolean;
  inParentheses: boolean;
  explicit: boolean;
};

function known(currency?: string | null) {
  const code = (currency ?? "").trim().toUpperCase();
  return KNOWN.has(code) ? code : "";
}

function same(a?: string | null, b?: string | null) {
  return (a ?? "").toUpperCase() === (b ?? "").toUpperCase();
}

function normalizeToken(token: string) {
  return token.trim().replace(/\.$/, "").replace(/\s+/g, " ").toUpperCase();
}

function explicitToken(token: string) {
  const value = normalizeToken(token);
  return value !== "RS" && value !== "RUPEE" && value !== "RUPEES" && value !== "$";
}

function codeFor(token: string) {
  switch (normalizeToken(token)) {
    case "US$":
    case "USD":
    case "US DOLLAR":
    case "US DOLLARS":
    case "DOLLAR":
    case "DOLLARS":
    case "$":
      return "USD";
    case "A$":
    case "AUD":
    case "AUSTRALIAN DOLLAR":
    case "AUSTRALIAN DOLLARS":
      return "AUD";
    case "C$":
    case "CAD":
    case "CANADIAN DOLLAR":
    case "CANADIAN DOLLARS":
      return "CAD";
    case "S$":
    case "SGD":
    case "SINGAPORE DOLLAR":
    case "SINGAPORE DOLLARS":
      return "SGD";
    case "€":
    case "EUR":
    case "EURO":
    case "EUROS":
      return "EUR";
    case "£":
    case "GBP":
    case "POUND":
    case "POUNDS":
    case "STERLING":
    case "BRITISH POUND":
    case "BRITISH POUNDS":
    case "POUND STERLING":
      return "GBP";
    case "¥":
    case "￥":
    case "JPY":
    case "YEN":
    case "JAPANESE YEN":
      return "JPY";
    case "CHF":
    case "FRANC":
    case "FRANCS":
    case "SWISS FRANC":
    case "SWISS FRANCS":
      return "CHF";
    case "LKR":
    case "SLR":
    case "රු":
    case "SRI LANKA RUPEE":
    case "SRI LANKA RUPEES":
    case "SRI LANKAN RUPEE":
    case "SRI LANKAN RUPEES":
    case "RS":
    case "RUPEE":
    case "RUPEES":
      return "LKR";
    case "₹":
    case "INR":
    case "INDIAN RUPEE":
    case "INDIAN RUPEES":
      return "INR";
    default:
      return null;
  }
}

function inParentheses(line: string, index: number) {
  const open = line.lastIndexOf("(", index);
  if (open < 0) return false;
  const close = line.indexOf(")", index);
  return close > index;
}

function collect(ocrText?: string | null): Hit[] {
  if (!ocrText?.trim()) return [];
  const hits: Hit[] = [];
  for (const rawLine of ocrText.replaceAll("\u00A0", " ").split("\n")) {
    const line = rawLine.trim();
    if (!line) continue;
    const onTotal = totalLine.test(line);
    const tokens = tokenPattern();
    for (const match of line.matchAll(tokens)) {
      const code = codeFor(match[0]);
      if (!code) continue;
      hits.push({
        code,
        onTotal,
        inParentheses: inParentheses(line, match.index ?? 0),
        explicit: explicitToken(match[0]),
      });
    }
  }
  return hits;
}

function distinct(hits: Hit[]) {
  const codes: string[] = [];
  for (const hit of hits) {
    if (!codes.includes(hit.code)) codes.push(hit.code);
  }
  return codes;
}

function one(hits: Hit[]) {
  const codes = distinct(hits);
  if (codes.length !== 1) return null;
  return codes[0];
}

/** Currency printed on the receipt, or null when it is ambiguous. */
export function detectReceiptCurrency(ocrText?: string | null) {
  const hits = collect(ocrText);
  if (hits.length === 0) return null;
  const explicitInr = hits.some((h) => h.code === "INR" && h.explicit);
  const explicitLkr = hits.some((h) => h.code === "LKR" && h.explicit);
  const filtered = hits.filter((h) => {
    if (explicitInr && h.code === "LKR" && !h.explicit) return false;
    if (explicitLkr && h.code === "INR" && !h.explicit) return false;
    return true;
  });
  return (
    one(filtered.filter((h) => h.onTotal && !h.inParentheses)) ??
    one(filtered.filter((h) => !h.inParentheses)) ??
    one(filtered.filter((h) => h.onTotal)) ??
    one(filtered)
  );
}

function containsExplicit(ocrText: string | null | undefined, code: string) {
  return collect(ocrText).some(
    (hit) => !hit.inParentheses && hit.explicit && same(hit.code, code)
  );
}

/**
 * Printed currency of the total. A home-currency token does not replace a
 * foreign code that is actually printed. When the model copied the wallet
 * currency, a different currency on the receipt is used instead.
 */
export function resolveReceiptCurrency(
  modelCurrency: string | null | undefined,
  ocrText: string | null | undefined,
  targetCurrency: string
) {
  const model = known(modelCurrency);
  const target = known(targetCurrency);
  const detected = detectReceiptCurrency(ocrText);

  if (detected && !same(detected, target)) return detected;
  if (model && !same(model, target) && containsExplicit(ocrText, model)) {
    return model;
  }
  if (detected) return detected;
  if (model) return model;
  return target || "USD";
}

export type ReceiptMoney = {
  sourceAmount: number;
  sourceCurrency: string;
  amountCurrency: string;
  rate: number | null;
  warning: string | null;
};

/** Money shown on Check & Save. Keeps a live conversion the API already did. */
export function receiptMoneyFrom(
  receipt: ReceiptExtraction,
  ocrText: string | null | undefined,
  accountCurrency: string
): ReceiptMoney {
  const target = known(accountCurrency) || "USD";
  const rate =
    receipt.exchange_rate != null &&
    Number.isFinite(receipt.exchange_rate) &&
    receipt.exchange_rate > 0
      ? receipt.exchange_rate
      : null;
  const sourceAmount =
    receipt.source_amount != null && Number.isFinite(receipt.source_amount)
      ? receipt.source_amount
      : receipt.amount;

  if (receipt.source_currency && rate && same(receipt.currency, target)) {
    return {
      sourceAmount,
      sourceCurrency: receipt.source_currency.toUpperCase(),
      amountCurrency: target,
      rate,
      warning: null,
    };
  }

  const printed = resolveReceiptCurrency(receipt.currency, ocrText, target);
  return {
    sourceAmount,
    sourceCurrency: printed,
    amountCurrency: printed,
    rate: null,
    warning: receipt.conversion_warning?.trim() || null,
  };
}
