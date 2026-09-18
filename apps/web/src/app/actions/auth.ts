"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { authCredentialsSchema, currencySchema } from "@/lib/schemas";
import type { ActionResult } from "@/lib/api/result";

export async function signUp(formData: FormData) {
  const supabase = await createClient();
  const email = String(formData.get("email") || "").trim();
  const password = String(formData.get("password") || "");
  const displayName = String(formData.get("display_name") || "").trim();
  const currencyParsed = currencySchema.safeParse(
    String(formData.get("base_currency") || "USD")
  );
  const baseCurrency = currencyParsed.success ? currencyParsed.data : "USD";
  const agreed =
    formData.get("agree") === "on" || formData.get("agree") === "true";

  if (!agreed) {
    return { error: "Please agree to the Terms and Privacy Policy." };
  }

  const authParsed = authCredentialsSchema.safeParse({ email, password });
  if (!authParsed.success) {
    return { error: authParsed.error.issues[0]?.message ?? "Invalid credentials" };
  }

  const { data, error } = await supabase.auth.signUp({
    email: authParsed.data.email,
    password: authParsed.data.password,
    options: {
      data: {
        display_name: displayName || email.split("@")[0],
        base_currency: baseCurrency,
      },
    },
  });

  if (error) {
    return { error: "Could not create account. Check your email and try again." };
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
  const email = String(formData.get("email") || "").trim();
  const password = String(formData.get("password") || "");

  const authParsed = authCredentialsSchema.safeParse({ email, password });
  if (!authParsed.success) {
    return { error: authParsed.error.issues[0]?.message ?? "Invalid credentials" };
  }

  const { error } = await supabase.auth.signInWithPassword({
    email: authParsed.data.email,
    password: authParsed.data.password,
  });

  if (error) {
    return { error: "Invalid email or password" };
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

async function requireEmailUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user?.email) {
    return { error: "Unauthorized" as const, supabase: null, user: null };
  }
  return { error: null, supabase, user };
}

async function confirmPassword(
  supabase: Awaited<ReturnType<typeof createClient>>,
  email: string,
  password: string
) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  return error ? "Password is incorrect" : null;
}

export async function changePassword(input: {
  currentPassword: string;
  newPassword: string;
}): Promise<ActionResult> {
  const parsed = authCredentialsSchema.shape.password.safeParse(
    input.newPassword
  );
  if (!parsed.success) {
    return {
      error: parsed.error.issues[0]?.message ?? "Enter a valid password",
    };
  }
  if (!input.currentPassword) {
    return { error: "Enter your current password" };
  }
  if (input.currentPassword === parsed.data) {
    return { error: "New password must be different" };
  }

  const auth = await requireEmailUser();
  if (auth.error || !auth.supabase || !auth.user?.email) {
    return { error: auth.error ?? "Unauthorized" };
  }

  const mismatch = await confirmPassword(
    auth.supabase,
    auth.user.email,
    input.currentPassword
  );
  if (mismatch) return { error: "Current password is incorrect" };

  const { error } = await auth.supabase.auth.updateUser({
    password: parsed.data,
  });
  if (error) {
    return { error: "Could not update password. Try again." };
  }
  return { success: true };
}

export async function deleteOwnAccount(
  password: string
): Promise<ActionResult> {
  if (!password) {
    return { error: "Enter your password to confirm" };
  }

  const auth = await requireEmailUser();
  if (auth.error || !auth.supabase || !auth.user?.email) {
    return { error: auth.error ?? "Unauthorized" };
  }

  const mismatch = await confirmPassword(
    auth.supabase,
    auth.user.email,
    password
  );
  if (mismatch) return { error: mismatch };

  const { error } = await auth.supabase.rpc("delete_own_account");
  if (error) {
    return { error: "Could not delete account. Try again." };
  }

  await auth.supabase.auth.signOut();
  redirect("/login");
}
