import { getAuthUser } from "@/app/actions/auth";
import { getExchangeRates, getProfile } from "@/app/actions/settings";
import { SettingsForm } from "@/components/settings/settings-form";

export default async function SettingsPage() {
  const [profile, rates, user] = await Promise.all([
    getProfile(),
    getExchangeRates(),
    getAuthUser(),
  ]);

  return (
    <SettingsForm
      profile={profile}
      rates={rates}
      email={user?.email ?? ""}
    />
  );
}
