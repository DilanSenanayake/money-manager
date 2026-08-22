import { getBudgetProgress } from "@/app/actions/dashboard";
import { getCategories } from "@/app/actions/categories";
import { getProfile } from "@/app/actions/settings";
import { BudgetsManager } from "@/components/budgets/budgets-manager";

export default async function BudgetsPage() {
  const [budgets, categories, profile] = await Promise.all([
    getBudgetProgress(),
    getCategories(),
    getProfile(),
  ]);

  return (
    <BudgetsManager
      budgets={budgets}
      categories={categories}
      currency={profile.base_currency}
    />
  );
}
