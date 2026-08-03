/** Local calendar date as YYYY-MM-DD (avoids UTC off-by-one vs toISOString). */
export function localDateYYYYMMDD(d = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function localMonthStartYYYYMMDD(d = new Date()): string {
  return localDateYYYYMMDD(new Date(d.getFullYear(), d.getMonth(), 1));
}

export function localMonthEndYYYYMMDD(d = new Date()): string {
  return localDateYYYYMMDD(new Date(d.getFullYear(), d.getMonth() + 1, 0));
}
