import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

/** Dedupes auth + client creation within a single server request. */
export const requireUser = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { supabase, user };
});
