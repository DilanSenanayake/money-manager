import type { ExchangeRate } from "@/lib/types";

/** Convert amount to base currency using user-provided rates (1:1 if same or missing). */
export function convertToBase(
  amount: number,
  fromCurrency: string,
  baseCurrency: string,
  rates: ExchangeRate[]
): number {
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

  return amount;
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
): number {
  const from = currencyByAccount.get(accountId) ?? baseCurrency;
  return convertToBase(amount, from, baseCurrency, rates);
}

export function computeNetWorth(
  accounts: { balance: number; currency: string; type: string }[],
  baseCurrency: string,
  rates: ExchangeRate[]
): number {
  return accounts.reduce((sum, account) => {
    const converted = convertToBase(
      Number(account.balance),
      account.currency,
      baseCurrency,
      rates
    );
    // Credit card balances are liabilities (stored as positive owed → subtract)
    if (account.type === "credit") {
      return sum - converted;
    }
    return sum + converted;
  }, 0);
}
