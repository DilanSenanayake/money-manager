import Link from "next/link";
import { LEGAL } from "@/lib/legal";

export function SiteFooter({ className }: { className?: string }) {
  return (
    <footer
      className={
        className ??
        "border-t border-[var(--border)] bg-[var(--surface)]"
      }
    >
      <div className="mx-auto flex max-w-6xl flex-col gap-3 px-4 py-6 text-xs text-[var(--muted)] sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <p>
          © {new Date().getFullYear()} {LEGAL.productName}.
        </p>
        <nav className="flex flex-wrap gap-x-4 gap-y-1" aria-label="Legal">
          <Link href="/terms" className="font-medium hover:text-[var(--foreground)]">
            Terms
          </Link>
          <Link
            href="/privacy"
            className="font-medium hover:text-[var(--foreground)]"
          >
            Privacy
          </Link>
        </nav>
      </div>
    </footer>
  );
}
