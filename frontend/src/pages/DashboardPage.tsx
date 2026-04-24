/**
 * DashboardPage.tsx
 *
 * The main dashboard page. Fetches the aggregated portfolio data from
 * GET /dashboard and renders four SummaryCards — one per financial domain.
 *
 * Shows a LoadingSkeleton while data is loading and an ErrorBanner on failure.
 * Loans with a pending payment this month are highlighted with a "Due this month"
 * badge. Insurance policies expiring within two months are highlighted with an
 * "Expiring soon" badge.
 *
 * Requirements: 7.1–7.7, 8.1–8.5, 9.1–9.4, 11.1–11.5, 12.5, 13.4
 */

import type { JSX } from "react";
import { PageLayout } from "@/components/shared/PageLayout.js";
import { useDashboard } from "@/hooks/useDashboard.js";
import { LoadingSkeleton } from "@/components/dashboard/LoadingSkeleton.js";
import { ErrorBanner } from "@/components/dashboard/ErrorBanner.js";
import { SummaryCard } from "@/components/dashboard/SummaryCard.js";

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * DashboardPage renders the aggregated financial portfolio overview.
 *
 * Four summary cards are shown: Total Savings, Total Debt, Insurance, and
 * Pensions. Each card is clickable and navigates to the corresponding domain
 * page. An "Add" button within each card navigates to the create-new page for
 * that domain.
 *
 * Loans due this month are highlighted with a "Due this month" badge.
 * Insurance policies expiring within two months are highlighted with an
 * "Expiring soon" badge.
 */
export function DashboardPage(): JSX.Element {
  const { data, loading, error, retry } = useDashboard();

  if (loading) {
    return (
      <PageLayout title="Dashboard">
        <LoadingSkeleton />
      </PageLayout>
    );
  }

  if (error || !data) {
    return (
      <PageLayout title="Dashboard">
        <ErrorBanner
          message={error ?? "Failed to load dashboard data."}
          onRetry={retry}
        />
      </PageLayout>
    );
  }

  const pendingPaymentIds = data.loans.pending_payments.map((p) => p.id);
  const expiringSoonIds = data.insurance.expiring_soon.map((p) => p.id);

  return (
    <PageLayout title="Dashboard">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <SummaryCard
          domain="savings"
          summary={data.savings}
          navigateTo="/savings"
          addPath="/savings/new"
        />
        <SummaryCard
          domain="loans"
          summary={data.loans}
          navigateTo="/loans"
          addPath="/loans/new"
          alertIds={pendingPaymentIds}
          alertLabel="Due this month"
        />
        <SummaryCard
          domain="insurance"
          summary={data.insurance}
          navigateTo="/insurance"
          addPath="/insurance/new"
          alertIds={expiringSoonIds}
          alertLabel="Expiring soon"
        />
        <SummaryCard
          domain="pensions"
          summary={data.pensions}
          navigateTo="/pensions"
          addPath="/pensions/new"
        />
      </div>
    </PageLayout>
  );
}

export default DashboardPage;
