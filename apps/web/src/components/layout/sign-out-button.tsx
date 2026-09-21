"use client";

import { LogOut } from "lucide-react";
import { signOut } from "@/app/actions/auth";
import { trackEvent } from "@/lib/analytics";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function SignOutButton({
  className,
  wide = false,
}: {
  className?: string;
  wide?: boolean;
}) {
  return (
    <form
      action={signOut}
      onSubmit={() => trackEvent("logout")}
    >
      <Button
        type="submit"
        variant="ghost"
        className={cn(
          "gap-2.5 font-medium",
          wide && "w-full justify-start",
          className
        )}
      >
        <LogOut className="h-4 w-4" />
        Sign out
      </Button>
    </form>
  );
}
