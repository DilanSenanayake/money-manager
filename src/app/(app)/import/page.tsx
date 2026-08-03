import { getAccounts } from "@/app/actions/accounts";
import { getCategories } from "@/app/actions/categories";
import { AiImportPanel } from "@/components/ai/ai-import-panel";

export default async function ImportPage() {
  const [accounts, categories] = await Promise.all([
    getAccounts(),
    getCategories(),
  ]);

  return <AiImportPanel accounts={accounts} categories={categories} />;
}
