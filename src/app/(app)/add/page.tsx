import { getAccounts } from "@/app/actions/accounts";
import { getCategories } from "@/app/actions/categories";
import { QuickAddPanel } from "@/components/ai/quick-add-panel";

type SearchParams = Promise<{
  type?: string;
  mode?: string;
}>;

export default async function AddPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const params = await searchParams;
  const [accounts, categories] = await Promise.all([
    getAccounts(),
    getCategories(),
  ]);

  const initialType =
    params.type === "income" || params.type === "expense"
      ? params.type
      : "expense";
  const initialMode =
    params.mode === "receipt" ||
    params.mode === "sms" ||
    params.mode === "text" ||
    params.mode === "manual"
      ? params.mode
      : undefined;

  return (
    <QuickAddPanel
      accounts={accounts}
      categories={categories}
      initialType={initialType}
      initialMode={initialMode}
    />
  );
}
