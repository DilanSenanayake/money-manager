import type { ExchangeRate } from "@/lib/types";

/** Convert amount to base currency. Returns null when a required rate is missing. */
export function convertToBase(
  amount: number,
  fromCurrency: string,
  baseCurrency: string,
  rates: ExchangeRate[]
): number | null {
  if (fromCurrency === baseCurrency) return amount;

  const direct = rates.find(
    (r) => r.from_currency === fromCurrency && r.to_currency === baseCurrency
  );
  if (direct) return amount * Number(direct.rate);

  const inverse = rates.find(
    (r) => r.from_currency === baseCurrency && r.to_currency === fromCurrency
  );
  if (inverse && Number(inverse.rate) !== 0) {
    return amount / Number(inverse.rate);
  }

  return null;
}

export function missingRateCurrencies(
  currencies: string[],
  baseCurrency: string,
  rates: ExchangeRate[]
): string[] {
  return [...new Set(currencies.filter(Boolean))].filter(
    (currency) =>
      convertToBase(0, currency, baseCurrency, rates) === null
  );
}

/** Rates the user entered that cover these currencies against the base. */
export function ratesCovering(
  currencies: string[],
  baseCurrency: string,
  rates: ExchangeRate[]
): ExchangeRate[] {
  const needed = [...new Set(currencies.filter((c) => c && c !== baseCurrency))];
  const used: ExchangeRate[] = [];
  for (const currency of needed) {
    const direct = rates.find(
      (r) => r.from_currency === currency && r.to_currency === baseCurrency
    );
    if (direct) {
      used.push(direct);
      continue;
    }
    const inverse = rates.find(
      (r) =>
        r.from_currency === baseCurrency &&
        r.to_currency === currency &&
        Number(r.rate) !== 0
    );
    if (inverse) used.push(inverse);
  }
  return used;
}

export function accountCurrencyMap(
  accounts: { id: string; currency: string }[]
): Map<string, string> {
  return new Map(accounts.map((a) => [a.id, a.currency]));
}

/** Convert a transaction amount using its account currency → base. */
export function txAmountInBase(
  amount: number,
  accountId: string,
  currencyByAccount: Map<string, string>,
  baseCurrency: string,
  rates: ExchangeRate[]
): number | null {
  const from = currencyByAccount.get(accountId) ?? baseCurrency;
  return convertToBase(amount, from, baseCurrency, rates);
}

export function computeNetWorth(
  accounts: { balance: number; currency: string; type: string }[],
  baseCurrency: string,
  rates: ExchangeRate[]
): number | null {
  let sum = 0;
  for (const account of accounts) {
    const converted = convertToBase(
      Number(account.balance),
      account.currency,
      baseCurrency,
      rates
    );
    if (converted === null) return null;
    sum += account.type === "credit" ? -converted : converted;
  }
  return sum;
}
