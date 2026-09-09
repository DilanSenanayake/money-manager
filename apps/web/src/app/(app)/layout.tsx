import {
  AppSidebar,
  MobileHeader,
  MobileNav,
} from "@/components/layout/app-sidebar";
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
        <MobileHeader />
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
