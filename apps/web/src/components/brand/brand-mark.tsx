import Image from "next/image";
import { cn } from "@/lib/utils";

export const BRAND_LOGO_SRC = "/brand/logo.png";
export const BRAND_NAME = "Smart Money Manager";

export function BrandLogo({
  size = 32,
  className,
  alt = "",
  priority = false,
}: {
  size?: number;
  className?: string;
  alt?: string;
  priority?: boolean;
}) {
  return (
    <Image
      src={BRAND_LOGO_SRC}
      alt={alt}
      width={size}
      height={size}
      priority={priority}
      className={cn("shrink-0 object-contain", className)}
    />
  );
}

export function BrandMark({
  size = "md",
  subtitle,
  className,
  priority = false,
}: {
  size?: "sm" | "md";
  subtitle?: string;
  className?: string;
  priority?: boolean;
}) {
  const px = size === "sm" ? 32 : 36;
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <BrandLogo size={px} priority={priority} />
      <span className="min-w-0">
        <span className="block text-sm font-semibold leading-snug tracking-tight">
          {BRAND_NAME}
        </span>
        {subtitle ? (
          <span className="block text-[11px] text-[var(--muted-fg)]">
            {subtitle}
          </span>
        ) : null}
      </span>
    </span>
  );
}
