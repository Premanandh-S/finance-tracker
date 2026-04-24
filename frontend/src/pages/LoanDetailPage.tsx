import { useState, type JSX } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { PageLayout } from "@/components/shared/PageLayout.js";
import { AmortisationTable, formatCurrency } from "@/components/loans/AmortisationTable.js";
import { EditLoanDialog } from "@/components/loans/EditLoanDialog.js";
import { useLoanDetail } from "@/hooks/useLoanDetail.js";
import { Button } from "@/components/ui/button.js";
import { Badge } from "@/components/ui/badge.js";
import { Skeleton } from "@/components/ui/skeleton.js";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card.js";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog.js";
import type { InterestRatePeriod } from "@/api/loansApi.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function ordinal(n: number): string {
  if (n === 1) return "1st";
  if (n === 2) return "2nd";
  if (n === 3) return "3rd";
  return `${n}th`;
}

// ---------------------------------------------------------------------------
// Skeleton placeholders
// ---------------------------------------------------------------------------

function SummarySkeleton(): JSX.Element {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-6 w-40" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          {Array.from({ length: 9 }).map((_, i) => (
            <div key={i} className="flex flex-col gap-1">
              <Skeleton className="h-3 w-24" />
              <Skeleton className="h-5 w-32" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

function TableSkeleton(): JSX.Element {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-6 w-48" />
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-8 w-full" />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Rate period form state
// ---------------------------------------------------------------------------

interface RatePeriodFormState {
  start_date: string;
  end_date: string;
  annual_interest_rate: string;
}

const EMPTY_RATE_FORM: RatePeriodFormState = {
  start_date: "",
  end_date: "",
  annual_interest_rate: "",
};

// ---------------------------------------------------------------------------
// Rate period row
// ---------------------------------------------------------------------------

interface RatePeriodRowProps {
  period: InterestRatePeriod;
  isEditing: boolean;
  formState: RatePeriodFormState;
  isBusy: boolean;
  onEdit: () => void;
  onDelete: () => void;
  onFormChange: (field: keyof RatePeriodFormState, value: string) => void;
  onSave: () => void;
  onCancel: () => void;
}

function RatePeriodRow({
  period,
  isEditing,
  formState,
  isBusy,
  onEdit,
  onDelete,
  onFormChange,
  onSave,
  onCancel,
}: RatePeriodRowProps): JSX.Element {
  if (isEditing) {
    return (
      <div className="flex flex-col gap-3 rounded-md border p-4 bg-muted/30">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="flex flex-col gap-1">
            <label className="text-xs font-medium text-muted-foreground">Start Date</label>
            <input
              type="date"
              value={formState.start_date}
              onChange={(e) => onFormChange("start_date", e.target.value)}
              className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-medium text-muted-foreground">End Date (optional)</label>
            <input
              type="date"
              value={formState.end_date}
              onChange={(e) => onFormChange("end_date", e.target.value)}
              className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-medium text-muted-foreground">Rate (%)</label>
            <input
              type="number"
              step="0.01"
              min="0"
              max="100"
              value={formState.annual_interest_rate}
              onChange={(e) => onFormChange("annual_interest_rate", e.target.value)}
              className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
        </div>
        <div className="flex gap-2">
          <Button size="sm" onClick={onSave} disabled={isBusy}>
            {isBusy ? "Saving…" : "Save"}
          </Button>
          <Button size="sm" variant="outline" onClick={onCancel} disabled={isBusy}>
            Cancel
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-between rounded-md border p-3">
      <div className="flex flex-wrap gap-4 text-sm">
        <span>
          <span className="text-muted-foreground">From: </span>
          {formatDate(period.start_date)}
        </span>
        <span>
          <span className="text-muted-foreground">To: </span>
          {period.end_date ? formatDate(period.end_date) : "Open-ended"}
        </span>
        <span>
          <span className="text-muted-foreground">Rate: </span>
          {period.annual_interest_rate}%
        </span>
      </div>
      <div className="flex gap-2 ml-4 shrink-0">
        <Button size="sm" variant="outline" onClick={onEdit} disabled={isBusy}>
          Edit
        </Button>
        <Button size="sm" variant="destructive" onClick={onDelete} disabled={isBusy}>
          Delete
        </Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

/**
 * LoanDetailPage displays the full detail for a single loan, including:
 * - Summary section with all loan fields
 * - Amortisation schedule table
 * - Interest rate periods management (floating-rate loans only)
 * - Edit and Delete actions
 *
 * Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7
 */
export function LoanDetailPage(): JSX.Element {
  const { id: idParam } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const loanId = Number(idParam);

  const {
    loan,
    isLoading,
    error,
    deleteLoan,
    addRatePeriod,
    updateRatePeriod,
    deleteRatePeriod,
    refresh,
  } = useLoanDetail(loanId);

  const [editOpen, setEditOpen] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  // editingPeriodId: null = not editing, -1 = adding new, number = editing existing
  const [editingPeriodId, setEditingPeriodId] = useState<number | null>(null);
  const [ratePeriodForm, setRatePeriodForm] = useState<RatePeriodFormState>(EMPTY_RATE_FORM);

  async function handleDeleteLoan(): Promise<void> {
    setIsDeleting(true);
    try {
      await deleteLoan();
      navigate("/loans");
    } catch {
      setIsDeleting(false);
      setDeleteConfirmOpen(false);
    }
  }

  function handleStartAddPeriod(): void {
    setEditingPeriodId(-1);
    setRatePeriodForm(EMPTY_RATE_FORM);
  }

  function handleStartEditPeriod(period: InterestRatePeriod): void {
    setEditingPeriodId(period.id);
    setRatePeriodForm({
      start_date: period.start_date,
      end_date: period.end_date ?? "",
      annual_interest_rate: period.annual_interest_rate,
    });
  }

  function handleCancelPeriodEdit(): void {
    setEditingPeriodId(null);
    setRatePeriodForm(EMPTY_RATE_FORM);
  }

  function handleRatePeriodFormChange(field: keyof RatePeriodFormState, value: string): void {
    setRatePeriodForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSavePeriod(): Promise<void> {
    const params = {
      start_date: ratePeriodForm.start_date,
      end_date: ratePeriodForm.end_date || null,
      annual_interest_rate: parseFloat(ratePeriodForm.annual_interest_rate),
    };
    try {
      if (editingPeriodId === -1) {
        await addRatePeriod(params);
      } else if (editingPeriodId !== null) {
        await updateRatePeriod(editingPeriodId, params);
      }
      setEditingPeriodId(null);
      setRatePeriodForm(EMPTY_RATE_FORM);
    } catch {
      // Error surfaced via hook's error state
    }
  }

  async function handleDeletePeriod(periodId: number): Promise<void> {
    try {
      await deleteRatePeriod(periodId);
    } catch {
      // Error surfaced via hook's error state
    }
  }

  const pageActions = (
    <div className="flex gap-2">
      <Button asChild variant="outline" size="sm">
        <Link to="/loans">← Back</Link>
      </Button>
      <Button
        variant="outline"
        size="sm"
        onClick={() => setEditOpen(true)}
        disabled={!loan || isLoading}
      >
        Edit Loan
      </Button>
      <Button
        variant="destructive"
        size="sm"
        onClick={() => setDeleteConfirmOpen(true)}
        disabled={!loan || isLoading}
      >
        Delete Loan
      </Button>
    </div>
  );

  if (isLoading && !loan) {
    return (
      <PageLayout title="Loan Detail" action={pageActions}>
        <div className="flex flex-col gap-6">
          <SummarySkeleton />
          <TableSkeleton />
        </div>
      </PageLayout>
    );
  }

  if (error && !loan) {
    return (
      <PageLayout title="Loan Detail" action={pageActions}>
        <p className="text-sm text-destructive">{error}</p>
      </PageLayout>
    );
  }

  const title = loan
    ? `${loan.institution_name} — ${loan.loan_identifier}`
    : "Loan Detail";

  return (
    <PageLayout title={title} action={pageActions}>
      {error && <p className="text-sm text-destructive mb-2">{error}</p>}

      <div className="flex flex-col gap-6">
        {/* Summary card */}
        {loan ? (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                Loan Summary
                <Badge variant={loan.interest_rate_type === "fixed" ? "default" : "secondary"}>
                  {loan.interest_rate_type}
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-3">
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Institution</dt>
                  <dd className="mt-1 text-sm font-medium">{loan.institution_name}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Loan Identifier</dt>
                  <dd className="mt-1 text-sm font-medium">{loan.loan_identifier}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Outstanding Balance</dt>
                  <dd className="mt-1 text-sm font-medium tabular-nums">{formatCurrency(loan.outstanding_balance)}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Annual Interest Rate</dt>
                  <dd className="mt-1 text-sm font-medium">{loan.annual_interest_rate}%</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Interest Type</dt>
                  <dd className="mt-1 text-sm font-medium capitalize">{loan.interest_rate_type}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Monthly Payment</dt>
                  <dd className="mt-1 text-sm font-medium tabular-nums">{formatCurrency(loan.monthly_payment)}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Payment Due Day</dt>
                  <dd className="mt-1 text-sm font-medium">{ordinal(loan.payment_due_day)} of each month</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Next Payment Date</dt>
                  <dd className="mt-1 text-sm font-medium">{formatDate(loan.next_payment_date)}</dd>
                </div>
                <div>
                  <dt className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Projected Payoff Date</dt>
                  <dd className="mt-1 text-sm font-medium">{formatDate(loan.payoff_date)}</dd>
                </div>
              </dl>
            </CardContent>
          </Card>
        ) : (
          <SummarySkeleton />
        )}

        {/* Floating-rate: interest rate periods */}
        {loan?.interest_rate_type === "floating" && (
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Interest Rate Periods</CardTitle>
                {editingPeriodId !== -1 && (
                  <Button size="sm" onClick={handleStartAddPeriod} disabled={isLoading}>
                    Add Rate Period
                  </Button>
                )}
              </div>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col gap-3">
                {loan.interest_rate_periods.length === 0 && editingPeriodId !== -1 && (
                  <p className="text-sm text-muted-foreground">
                    No rate periods defined. Add one to configure the floating rate schedule.
                  </p>
                )}
                {loan.interest_rate_periods.map((period) => (
                  <RatePeriodRow
                    key={period.id}
                    period={period}
                    isEditing={editingPeriodId === period.id}
                    formState={ratePeriodForm}
                    isBusy={isLoading}
                    onEdit={() => handleStartEditPeriod(period)}
                    onDelete={() => void handleDeletePeriod(period.id)}
                    onFormChange={handleRatePeriodFormChange}
                    onSave={() => void handleSavePeriod()}
                    onCancel={handleCancelPeriodEdit}
                  />
                ))}
                {editingPeriodId === -1 && (
                  <div className="flex flex-col gap-3 rounded-md border p-4 bg-muted/30">
                    <p className="text-sm font-medium">New Rate Period</p>
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                      <div className="flex flex-col gap-1">
                        <label className="text-xs font-medium text-muted-foreground">Start Date</label>
                        <input
                          type="date"
                          value={ratePeriodForm.start_date}
                          onChange={(e) => handleRatePeriodFormChange("start_date", e.target.value)}
                          className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                        />
                      </div>
                      <div className="flex flex-col gap-1">
                        <label className="text-xs font-medium text-muted-foreground">End Date (optional)</label>
                        <input
                          type="date"
                          value={ratePeriodForm.end_date}
                          onChange={(e) => handleRatePeriodFormChange("end_date", e.target.value)}
                          className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                        />
                      </div>
                      <div className="flex flex-col gap-1">
                        <label className="text-xs font-medium text-muted-foreground">Rate (%)</label>
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          value={ratePeriodForm.annual_interest_rate}
                          onChange={(e) => handleRatePeriodFormChange("annual_interest_rate", e.target.value)}
                          className="rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                        />
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Button size="sm" onClick={() => void handleSavePeriod()} disabled={isLoading}>
                        {isLoading ? "Saving…" : "Save"}
                      </Button>
                      <Button size="sm" variant="outline" onClick={handleCancelPeriodEdit} disabled={isLoading}>
                        Cancel
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Amortisation schedule */}
        {loan ? (
          <Card>
            <CardHeader>
              <CardTitle>Amortisation Schedule</CardTitle>
            </CardHeader>
            <CardContent className="overflow-x-auto p-0">
              <AmortisationTable schedule={loan.amortisation_schedule} />
            </CardContent>
          </Card>
        ) : (
          <TableSkeleton />
        )}
      </div>

      {/* Edit loan dialog */}
      <EditLoanDialog
        open={editOpen}
        onOpenChange={setEditOpen}
        loan={loan}
        onSuccess={refresh}
      />

      {/* Delete confirmation dialog */}
      <Dialog open={deleteConfirmOpen} onOpenChange={setDeleteConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Loan</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Are you sure you want to delete{" "}
            <span className="font-medium text-foreground">{loan?.loan_identifier}</span>{" "}
            from{" "}
            <span className="font-medium text-foreground">{loan?.institution_name}</span>?
            This action cannot be undone.
          </p>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setDeleteConfirmOpen(false)}
              disabled={isDeleting}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={() => void handleDeleteLoan()}
              disabled={isDeleting}
            >
              {isDeleting ? "Deleting…" : "Delete Loan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageLayout>
  );
}

export default LoanDetailPage;
