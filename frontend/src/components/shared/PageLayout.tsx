import type { JSX, ReactNode } from "react";

interface PageLayoutProps {
  /** The page title displayed in the heading. */
  title: string;
  /** Optional action slot — typically an "Add" button rendered to the right of the title. */
  action?: ReactNode;
  /** The page content. */
  children: ReactNode;
}

/**
 * PageLayout is the shared wrapper for all authenticated pages.
 *
 * Renders a page heading with an optional action slot (e.g., an "Add" button)
 * in a flex row, followed by the page content.
 *
 * @example
 * ```tsx
 * <PageLayout title="Loans" action={<Button>Add Loan</Button>}>
 *   <LoansTable />
 * </PageLayout>
 * ```
 */
export function PageLayout({ title, action, children }: PageLayoutProps): JSX.Element {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        {action && <div>{action}</div>}
      </div>
      <div>{children}</div>
    </div>
  );
}
