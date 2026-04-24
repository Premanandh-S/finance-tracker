import { useState, type JSX } from "react";
import { useNavigate } from "react-router-dom";
import { PageLayout } from "@/components/shared/PageLayout.js";
import { Button } from "@/components/ui/button.js";
import { Badge } from "@/components/ui/badge.js";
import { Skeleton } from "@/components/ui/skeleton.js";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table.js";
import { useLoans } from "@/hooks/useLoans.js";
import { AddLoanDialog } from "@/components/loans/AddLoanDialog.js";
import { formatCurrency } from "@/components/loans/AmortisationTable.js";
import type { Loan } from "@/api/loansApi.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Format an ISO date string to a locale-friendly display value. */
function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ---------------------------------------------------------------------------
// Skeleton rows shown while loading
// ---------------------------------------------------------------------------

function SkeletonRows(): JSX.Element {
  return (
    <>
      {[1, 2, 3].map((n) => (
        <TableRow key={n}>
          <TableCell><Skeleton className="h-4 w-28" /></TableCell>
          <TableCell><Skeleton className="h-4 w-32" /></TableCell>
          <TableCell><Skeleton className="h-5 w-16" /></TableCell>
          <TableCell className="text-right"><Skeleton className="h-4 w-24 ml-auto" /></TableCell>
          <TableCell><Skeleton className="h-4 w-24" /></TableCell>
          <TableCell><Skeleton className="h-4 w-24" /></TableCell>
        </TableRow>
      ))}
    </>
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * LoansPage displays the user's loans in a table and provides an
 * "Add Loan" dialog for creating new loan records.
 *
 * Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
 */
export function LoansPage(): JSX.Element {
  const navigate = useNavigate();
  const { loans, isLoading, error, refresh } = useLoans();
  const [dialogOpen, setDialogOpen] = useState(false);

  function handleRowClick(loan: Loan) {
    navigate(`/loans/${loan.id}`);
  }

  function handleRowKeyDown(e: React.KeyboardEvent, loan: Loan) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      navigate(`/loans/${loan.id}`);
    }
  }

  const addLoanButton = (
    <Button onClick={() => setDialogOpen(true)}>Add Loan</Button>
  );

  return (
    <PageLayout title="Loans" action={addLoanButton}>
      {/* Error state */}
      {error && (
        <p className="text-sm text-destructive mb-4">{error}</p>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Loan Identifier</TableHead>
            <TableHead>Institution</TableHead>
            <TableHead>Interest Type</TableHead>
            <TableHead className="text-right">Outstanding Balance</TableHead>
            <TableHead>Next Payment</TableHead>
            <TableHead>Payoff Date</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading ? (
            <SkeletonRows />
          ) : loans.length === 0 ? (
            <TableRow>
              <TableCell colSpan={6} className="text-center text-muted-foreground py-10">
                No loans yet. Add your first loan to get started.
              </TableCell>
            </TableRow>
          ) : (
            loans.map((loan) => (
              <TableRow
                key={loan.id}
                className="cursor-pointer"
                onClick={() => handleRowClick(loan)}
                onKeyDown={(e) => handleRowKeyDown(e, loan)}
                tabIndex={0}
                role="button"
                aria-label={`View details for loan ${loan.loan_identifier}`}
              >
                <TableCell className="font-medium">{loan.loan_identifier}</TableCell>
                <TableCell>{loan.institution_name}</TableCell>
                <TableCell>
                  <Badge variant={loan.interest_rate_type === "fixed" ? "default" : "secondary"}>
                    {loan.interest_rate_type}
                  </Badge>
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {formatCurrency(loan.outstanding_balance)}
                </TableCell>
                <TableCell>{formatDate(loan.next_payment_date)}</TableCell>
                <TableCell>{formatDate(loan.payoff_date)}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>

      <AddLoanDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onSuccess={refresh}
      />
    </PageLayout>
  );
}

export default LoansPage;
