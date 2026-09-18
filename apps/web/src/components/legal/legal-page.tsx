import Link from "next/link";
import type { ReactNode } from "react";
import { BrandMark } from "@/components/brand/brand-mark";
import { SiteFooter } from "@/components/layout/site-footer";
import { LEGAL } from "@/lib/legal";

export type LegalTocItem = { id: string; label: string };

export function LegalPage({
  title,
  description,
  toc,
  children,
}: {
  title: string;
  description: string;
  toc: LegalTocItem[];
  children: ReactNode;
}) {
  return (
    <div className="auth-shell min-h-screen">
      <header className="sticky top-0 z-20 border-b border-[var(--border)]/80 bg-[var(--background)]/80 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-3 px-4 sm:h-16 sm:px-6">
          <Link href="/" aria-label={`${LEGAL.productName} home`}>
            <BrandMark size="sm" />
          </Link>
          <nav className="flex items-center gap-4 text-sm font-medium text-[var(--muted)]">
            <Link href="/terms" className="hover:text-[var(--foreground)]">
              Terms
            </Link>
            <Link href="/privacy" className="hover:text-[var(--foreground)]">
              Privacy
            </Link>
          </nav>
        </div>
      </header>

      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-10 sm:px-6 md:grid-cols-[220px_1fr] md:py-14">
        <nav
          aria-label="On this page"
          className="md:sticky md:top-24 md:self-start"
        >
          <p className="mb-3 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--muted-fg)]">
            On this page
          </p>
          <ul className="flex gap-2 overflow-x-auto pb-2 text-sm md:block md:space-y-1.5 md:overflow-visible md:pb-0">
            {toc.map((item) => (
              <li key={item.id} className="shrink-0">
                <a
                  href={`#${item.id}`}
                  className="block rounded-lg px-2 py-1 text-[var(--muted)] hover:bg-[var(--surface)] hover:text-[var(--foreground)]"
                >
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <article className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--accent-hover)]">
            Last updated: {LEGAL.lastUpdated}
          </p>
          <h1 className="mt-3 font-display text-3xl tracking-tight sm:text-4xl">
            {title}
          </h1>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-[var(--muted)] sm:text-base">
            {description}
          </p>
          <div className="legal-body mt-10 space-y-10 text-sm leading-relaxed text-[var(--foreground)] sm:text-[15px]">
            {children}
          </div>
        </article>
      </div>
      <SiteFooter />
    </div>
  );
}

export function LegalSection({
  id,
  title,
  children,
}: {
  id: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section id={id} className="scroll-mt-24 space-y-3">
      <h2 className="font-display text-xl tracking-tight">{title}</h2>
      {children}
    </section>
  );
}
