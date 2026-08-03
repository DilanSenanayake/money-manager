import { getAccounts } from "@/app/actions/accounts";
import { AccountsManager } from "@/components/accounts/accounts-manager";

export default async function AccountsPage() {
  const accounts = await getAccounts();
  return <AccountsManager accounts={accounts} />;
}
