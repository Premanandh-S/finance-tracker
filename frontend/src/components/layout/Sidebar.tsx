import type { JSX } from "react";
import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  CreditCard,
  PiggyBank,
  Shield,
  Landmark,
} from "lucide-react";
import { Separator } from "@/components/ui/separator.js";
import { cn } from "@/lib/utils.js";

/** Navigation item definition. */
export interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

/** The application's primary navigation items. */
export const NAV_ITEMS: NavItem[] = [
  { label: "Dashboard", href: "/", icon: LayoutDashboard },
  { label: "Loans", href: "/loans", icon: CreditCard },
  { label: "Savings", href: "/savings", icon: PiggyBank },
  { label: "Insurance", href: "/insurance", icon: Shield },
  { label: "Pensions", href: "/pensions", icon: Landmark },
];

/**
 * Sidebar renders the desktop navigation menu.
 *
 * Visible only on md+ breakpoints. Highlights the active route.
 */
export function Sidebar(): JSX.Element {
  const { pathname } = useLocation();

  return (
    <aside className="hidden md:flex flex-col w-64 min-h-screen border-r bg-background px-4 py-6 gap-1">
      <nav aria-label="Main navigation">
        {NAV_ITEMS.map((item, index) => {
          const isActive = pathname === item.href;
          const Icon = item.icon;
          return (
            <div key={item.href}>
              {index > 0 && index === 1 && <Separator className="my-2" />}
              <Link
                to={item.href}
                aria-current={isActive ? "page" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                )}
              >
                <Icon className="h-4 w-4 shrink-0" />
                {item.label}
              </Link>
            </div>
          );
        })}
      </nav>
    </aside>
  );
}
