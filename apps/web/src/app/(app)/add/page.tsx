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

  const raw = params.mode;
  const initialMode =
    raw === "receipt" ||
    raw === "sms" ||
    raw === "text" ||
    raw === "manual" ||
    raw === "smart" ||
    raw === "voice"
      ? raw
      : params.type === "income" || params.type === "expense"
        ? "manual"
        : "smart";

  return (
    <QuickAddPanel
      accounts={accounts}
      categories={categories}
      initialType={initialType}
      initialMode={initialMode}
    />
  );
}
