import { AppSidebar, MobileNav } from "@/components/layout/app-sidebar";

export const dynamic = "force-dynamic";

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="app-grid min-h-screen md:grid md:grid-cols-[240px_1fr]">
      <div className="hidden md:block">
        <div className="sticky top-0 h-screen">
          <AppSidebar />
        </div>
      </div>
      <div className="flex min-h-screen flex-col pb-20 md:pb-0">
        <header className="flex items-center justify-between border-b border-slate-200/70 bg-white/70 px-4 py-3 backdrop-blur md:hidden dark:border-slate-800 dark:bg-slate-950/70">
          <p className="font-display text-lg text-teal-800">Ledgerly</p>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 md:px-8">
          {children}
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
