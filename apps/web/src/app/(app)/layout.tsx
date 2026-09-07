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
      <div className="flex min-h-screen flex-col pb-24 md:pb-0">
        <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-[var(--border)] bg-[var(--surface)] px-4 py-3 md:hidden">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-[var(--accent)] text-[11px] font-bold text-[var(--accent-fg)]">
            S
          </span>
          <p className="text-sm font-semibold tracking-tight">
            Smart Money Manager
          </p>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 md:px-8 md:py-8">
          <PageEnter>{children}</PageEnter>
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
