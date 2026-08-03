"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { currencySchema } from "@/lib/schemas";

export async function signUp(formData: FormData) {
  const supabase = await createClient();
  const email = String(formData.get("email") || "");
  const password = String(formData.get("password") || "");
  const displayName = String(formData.get("display_name") || "");
  const currencyParsed = currencySchema.safeParse(
    String(formData.get("base_currency") || "USD")
  );
  const baseCurrency = currencyParsed.success ? currencyParsed.data : "USD";

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        display_name: displayName || email.split("@")[0],
        base_currency: baseCurrency,
      },
    },
  });

  if (error) {
    return { error: error.message };
  }

  // Email confirmation may be required — only go home if we have a session
  if (data.session) {
    redirect("/dashboard");
  }

  return {
    message:
      "Account created. Check your email to confirm, then sign in.",
  };
}

export async function signIn(formData: FormData) {
  const supabase = await createClient();
  const email = String(formData.get("email") || "");
  const password = String(formData.get("password") || "");

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    return { error: error.message };
  }

  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function getAuthUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}
