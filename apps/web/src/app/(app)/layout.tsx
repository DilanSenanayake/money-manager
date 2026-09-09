import { AppSidebar, MobileNav } from "@/components/layout/app-sidebar";
import { PageEnter } from "@/components/layout/page-enter";

export const dynamic = "force-dynamic";

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen md:grid md:grid-cols-[248px_1fr]">
      <div className="hidden md:block">
        <div className="sticky top-0 h-screen">
          <AppSidebar />
        </div>
      </div>
      <div className="flex min-h-screen flex-col pb-[calc(5.5rem+env(safe-area-inset-bottom))] md:pb-0">
        <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-[var(--border)] bg-[var(--surface)] px-4 pb-3 pt-[max(0.75rem,env(safe-area-inset-top))] md:hidden">
          <a
            href="#main-content"
            className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-[var(--accent)] focus:px-3 focus:py-2 focus:text-[var(--accent-fg)]"
          >
            Skip to content
          </a>
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-[var(--accent)] text-[11px] font-bold text-[var(--accent-fg)]">
            S
          </span>
          <p className="min-w-0 truncate text-sm font-semibold tracking-tight">
            Smart Money Manager
          </p>
        </header>
        <main
          id="main-content"
          className="mx-auto w-full max-w-6xl flex-1 px-3 py-5 sm:px-4 md:px-8 md:py-8"
        >
          <PageEnter>{children}</PageEnter>
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
