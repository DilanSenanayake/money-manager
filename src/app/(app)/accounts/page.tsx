import { getAccounts } from "@/app/actions/accounts";
import { getProfile } from "@/app/actions/settings";
import { AccountsManager } from "@/components/accounts/accounts-manager";

export default async function AccountsPage() {
  const [accounts, profile] = await Promise.all([getAccounts(), getProfile()]);
  return (
    <AccountsManager
      accounts={accounts}
      defaultCurrency={profile.base_currency}
    />
  );
}
