import { getAccounts } from "@/app/actions/accounts";
import { getCategories } from "@/app/actions/categories";
import { getProfile } from "@/app/actions/settings";
import { getTransactions } from "@/app/actions/transactions";
import { TransactionsManager } from "@/components/transactions/transactions-manager";
import type { TransactionFilter } from "@/lib/schemas";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function TransactionsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const filters: TransactionFilter = {
    q: typeof params.q === "string" ? params.q : undefined,
    account_id:
      typeof params.account_id === "string" ? params.account_id : undefined,
    category_id:
      typeof params.category_id === "string" ? params.category_id : undefined,
    type:
      typeof params.type === "string"
        ? (params.type as TransactionFilter["type"])
        : undefined,
    from: typeof params.from === "string" ? params.from : undefined,
    to: typeof params.to === "string" ? params.to : undefined,
  };

  const [transactions, accounts, categories, profile] = await Promise.all([
    getTransactions(filters),
    getAccounts(),
    getCategories(),
    getProfile(),
  ]);

  return (
    <TransactionsManager
      transactions={transactions}
      accounts={accounts}
      categories={categories}
      defaultCurrency={profile.base_currency}
      initialFilters={filters}
    />
  );
}
