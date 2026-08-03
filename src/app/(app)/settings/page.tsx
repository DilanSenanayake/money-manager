import { getExchangeRates, getProfile } from "@/app/actions/settings";
import { SettingsForm } from "@/components/settings/settings-form";

export default async function SettingsPage() {
  const [profile, rates] = await Promise.all([
    getProfile(),
    getExchangeRates(),
  ]);

  return <SettingsForm profile={profile} rates={rates} />;
}
