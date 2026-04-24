/**
 * SummaryCard.tsx
 *
 * A dashboard card that displays the headline metric for a financial domain,
 * a list of domain items, and an "Add" button for creating new instruments.
 *
 * The entire card is clickable and navigates to the domain's list page.
 * The AddButton stops propagation so it navigates to the create page instead.
 */

import type { JSX } from "react";
import { useNavigate } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card.js";
import { AddButton } from "./AddButton.js";
import { DomainItemList, type ColumnDef } from "./DomainItemList.js";
import type {
  SavingsSummary,
  LoansSummary,
  InsuranceSummary,
  PensionsSummary,
  SavingsItem,
  LoanItem,
  InsuranceItem,
  PensionItem,
} from "../../types/dashboard.js";

// ---------------------------------------------------------------------------
// Currency helper
// ---------------------------------------------------------------------------

/**
 * Converts a paise integer to a formatted rupee string.
 *
 * @param paise - Monetary value in paise.
 * @returns Formatted string, e.g. "₹2,50,000.00".
 */
function formatCurrency(paise: number): string {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  }).format(paise / 100);
}

// ---------------------------------------------------------------------------
// Domain-specific column definitions
// ---------------------------------------------------------------------------

const savingsColumns: ColumnDef<SavingsItem>[] = [
  { header: "Identifier", accessor: (i) => i.savings_identifier },
  { header: "Institution", accessor: (i) => i.institution_name },
  { header: "Type", accessor: (i) => i.savings_type.toUpperCase() },
  { header: "Principal", accessor: (i) => formatCurrency(i.principal_amount) },
];

const loansColumns: ColumnDef<LoanItem>[] = [
  { header: "Identifier", accessor: (i) => i.loan_identifier },
  { header: "Institution", accessor: (i) => i.institution_name },
  { header: "Balance", accessor: (i) => formatCurrency(i.outstanding_balance) },
  { header: "Next Payment", accessor: (i) => i.next_payment_date },
];

const insuranceColumns: ColumnDef<InsuranceItem>[] = [
  { header: "Policy No.", accessor: (i) => i.policy_number },
  { header: "Institution", accessor: (i) => i.institution_name },
  { header: "Type", accessor: (i) => i.policy_type.toUpperCase() },
  { header: "Renewal", accessor: (i) => i.renewal_date },
];

const pensionsColumns: ColumnDef<PensionItem>[] = [
  { header: "Identifier", accessor: (i) => i.pension_identifier },
  { header: "Institution", accessor: (i) => i.institution_name },
  { header: "Type", accessor: (i) => i.pension_type.toUpperCase() },
  { header: "Corpus", accessor: (i) => formatCurrency(i.total_corpus) },
];

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export type DomainSummary =
  | SavingsSummary
  | LoansSummary
  | InsuranceSummary
  | PensionsSummary;

export interface SummaryCardProps {
  /** The financial domain this card represents. */
  domain: "savings" | "loans" | "insurance" | "pensions";
  /** The domain summary data from the dashboard API. */
  summary: DomainSummary;
  /** Route path for the domain's list page (card click target). */
  navigateTo: string;
  /** Route path for the domain's create-new page (AddButton target). */
  addPath: string;
  /**
   * IDs of items that should display an alert badge.
   * Used for pending loan payments and expiring insurance policies.
   */
  alertIds?: number[];
  /** Text to display in the alert badge (e.g. "Due this month"). */
  alertLabel?: string;
}

// ---------------------------------------------------------------------------
// Headline metric helpers
// ---------------------------------------------------------------------------

function getHeadlineMetric(
  domain: SummaryCardProps["domain"],
  summary: DomainSummary
): string {
  switch (domain) {
    case "savings":
      return formatCurrency((summary as SavingsSummary).total_principal);
    case "loans":
      return formatCurrency((summary as LoansSummary).total_outstanding_balance);
    case "insurance":
      return `${(summary as InsuranceSummary).total_count} ${
        (summary as InsuranceSummary).total_count === 1 ? "policy" : "policies"
      }`;
    case "pensions":
      return formatCurrency((summary as PensionsSummary).total_corpus);
  }
}

function getDomainTitle(domain: SummaryCardProps["domain"]): string {
  switch (domain) {
    case "savings":
      return "Total Savings";
    case "loans":
      return "Total Debt";
    case "insurance":
      return "Insurance";
    case "pensions":
      return "Pensions";
  }
}

function getAddLabel(domain: SummaryCardProps["domain"]): string {
  switch (domain) {
    case "savings":
      return "Add Savings";
    case "loans":
      return "Add Loan";
    case "insurance":
      return "Add Insurance";
    case "pensions":
      return "Add Pension";
  }
}

function getEmptyMessage(domain: SummaryCardProps["domain"]): string {
  switch (domain) {
    case "savings":
      return "No savings instruments yet.";
    case "loans":
      return "No loans yet.";
    case "insurance":
      return "No insurance policies yet.";
    case "pensions":
      return "No pension instruments yet.";
  }
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Renders a summary card for a single financial domain on the dashboard.
 *
 * Displays the headline metric, an AddButton, and a DomainItemList.
 * The card itself is clickable and navigates to the domain's list page.
 *
 * @param props - Domain, summary data, navigation targets, and alert config.
 *
 * @example
 * ```tsx
 * <SummaryCard
 *   domain="loans"
 *   summary={data.loans}
 *   navigateTo="/loans"
 *   addPath="/loans/new"
 *   alertIds={data.loans.pending_payments.map((p) => p.id)}
 *   alertLabel="Due this month"
 * />
 * ```
 */
export function SummaryCard({
  domain,
  summary,
  navigateTo,
  addPath,
  alertIds,
  alertLabel,
}: SummaryCardProps): JSX.Element {
  const navigate = useNavigate();

  const title = getDomainTitle(domain);
  const headline = getHeadlineMetric(domain, summary);
  const addLabel = getAddLabel(domain);
  const emptyMessage = getEmptyMessage(domain);

  // Resolve the items array for the correct domain type.
  const items = summary.items as Array<
    SavingsItem | LoanItem | InsuranceItem | PensionItem
  >;

  // Resolve the correct column definitions.
  const columns = (() => {
    switch (domain) {
      case "savings":
        return savingsColumns as ColumnDef<(typeof items)[number]>[];
      case "loans":
        return loansColumns as ColumnDef<(typeof items)[number]>[];
      case "insurance":
        return insuranceColumns as ColumnDef<(typeof items)[number]>[];
      case "pensions":
        return pensionsColumns as ColumnDef<(typeof items)[number]>[];
    }
  })();

  return (
    <Card
      className="cursor-pointer hover:shadow-md transition-shadow"
      onClick={() => navigate(navigateTo)}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          navigate(navigateTo);
        }
      }}
      aria-label={`${title}: ${headline}`}
    >
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="text-sm font-medium text-muted-foreground">
            {title}
          </CardTitle>
          <AddButton navigateTo={addPath} label={addLabel} />
        </div>
        <p className="text-2xl font-bold">{headline}</p>
      </CardHeader>
      <CardContent>
        <DomainItemList
          items={items}
          columns={columns}
          onItemClick={(_item) => {
            navigate(navigateTo);
          }}
          emptyMessage={emptyMessage}
          alertIds={alertIds}
          alertLabel={alertLabel}
        />
      </CardContent>
    </Card>
  );
}

export default SummaryCard;
