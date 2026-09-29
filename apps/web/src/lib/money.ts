export function asMoneyInput(value: unknown): string {
  if (typeof value === "number" && Number.isFinite(value)) return value.toFixed(2);
  if (typeof value === "string") return value;
  return "";
}

/** Canonical decimal text. Does not use binary floating point on the string the user typed. */
export function canonicalMoney(
  raw: string,
  options?: { allowZero?: boolean }
): string | null {
  let text = raw.trim().replaceAll(",", "").replaceAll(" ", "");
  if (text.startsWith("+")) text = text.slice(1);
  if (text.startsWith(".")) text = `0${text}`;
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(text);
  if (!match) return null;
  const whole = match[1].replace(/^0+(?=\d)/, "");
  const frac = (match[2] ?? "").padEnd(2, "0");
  if (!options?.allowZero && whole === "0" && frac === "00") return null;
  return `${whole}.${frac}`;
}

export function canonicalRate(raw: string): string | null {
  let text = raw.trim().replaceAll(",", "").replaceAll(" ", "");
  if (text.startsWith("+")) text = text.slice(1);
  if (text.startsWith(".")) text = `0${text}`;
  const match = /^(\d+)(?:\.(\d{1,8}))?$/.exec(text);
  if (!match) return null;
  const whole = match[1].replace(/^0+(?=\d)/, "");
  const fracRaw = match[2];
  if (fracRaw == null) {
    if (whole === "0") return null;
    return whole;
  }
  const frac = fracRaw.replace(/0+$/, "");
  if (whole === "0" && frac.length === 0) return null;
  if (frac.length === 0) return whole;
  return `${whole}.${frac}`;
}
