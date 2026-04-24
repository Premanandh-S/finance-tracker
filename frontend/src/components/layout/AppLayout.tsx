import type { JSX, ReactNode } from "react";
import { Sidebar } from "./Sidebar.js";
import { MobileNav } from "./MobileNav.js";
import { ThemeToggle } from "./ThemeToggle.js";
import { Avatar, AvatarFallback } from "@/components/ui/avatar.js";

interface AppLayoutProps {
  children: ReactNode;
}

/**
 * AppLayout is the authenticated shell wrapping all protected pages.
 *
 * Renders:
 * - Desktop sidebar (md+ breakpoints)
 * - Mobile hamburger nav (below md)
 * - Header with app name, user avatar, and theme toggle
 * - Main content area
 */
export function AppLayout({ children }: AppLayoutProps): JSX.Element {
  return (
    <div className="flex min-h-screen bg-background">
      {/* Desktop sidebar */}
      <Sidebar />

      {/* Main content column */}
      <div className="flex flex-1 flex-col">
        {/* Header */}
        <header className="flex h-14 items-center justify-between border-b px-4 bg-background">
          <div className="flex items-center gap-2">
            {/* Mobile nav trigger */}
            <MobileNav />
            <span className="font-semibold text-sm">FinanceApp</span>
          </div>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Avatar className="h-8 w-8">
              <AvatarFallback>U</AvatarFallback>
            </Avatar>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 p-6">
          {children}
        </main>
      </div>
    </div>
  );
}

export default AppLayout;
