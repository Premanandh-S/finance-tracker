import type { JSX } from "react";
import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog.js";
import { Button } from "@/components/ui/button.js";
import { LoanFormFields, type LoanFormValues } from "./LoanFormFields.js";
import { useLoanDetail } from "@/hooks/useLoanDetail.js";
import { LoansApiError } from "@/api/loansApi.js";
import { useToast } from "@/hooks/use-toast.js";
import type { LoanDetail } from "@/api/loansApi.js";

// ---------------------------------------------------------------------------
// Zod schema (same as AddLoanDialog)
// ---------------------------------------------------------------------------

const loanSchema = z.object({
  institution_name: z.string().min(1, "Required"),
  loan_identifier: z.string().min(1, "Required"),
  outstanding_balance_rupees: z.number().positive("Must be greater than 0"),
  annual_interest_rate: z.number().min(0).max(100),
  interest_rate_type: z.enum(["fixed", "floating"]),
  monthly_payment_rupees: z.number().positive("Must be greater than 0"),
  payment_due_day: z.number().int().min(1).max(28),
  interest_rate_periods: z
    .array(
      z.object({
        start_date: z.string().min(1, "Required"),
        end_date: z.string().optional(),
        annual_interest_rate: z.number().min(0).max(100),
      })
    )
    .optional(),
}) satisfies z.ZodType<Partial<LoanFormValues>>;

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface EditLoanDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  loan: LoanDetail | null;
  onSuccess?: () => void;
}

// ---------------------------------------------------------------------------
// Default form values (used for reset when no loan is provided)
// ---------------------------------------------------------------------------

const DEFAULT_VALUES: LoanFormValues = {
  institution_name: "",
  loan_identifier: "",
  outstanding_balance_rupees: 0,
  annual_interest_rate: 0,
  interest_rate_type: "fixed",
  monthly_payment_rupees: 0,
  payment_due_day: 1,
  interest_rate_periods: [],
};

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * EditLoanDialog renders a modal dialog pre-populated with the current loan
 * values for editing.
 *
 * On submit it converts rupee amounts to paise, calls `updateLoan` from
 * `useLoanDetail`, and either closes the dialog on success or surfaces errors
 * inline (422 field errors) or via toast (other API errors).
 *
 * Outstanding balance and monthly payment are displayed in rupees (paise ÷ 100)
 * and converted back to paise (× 100) before calling the API.
 *
 * Requirements: 14.1, 14.2, 14.3, 14.4
 */
export function EditLoanDialog({
  open,
  onOpenChange,
  loan,
  onSuccess,
}: EditLoanDialogProps): JSX.Element {
  const { updateLoan, isLoading } = useLoanDetail(loan?.id ?? 0);
  const { toast } = useToast();

  const {
    control,
    handleSubmit,
    watch,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<LoanFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(loanSchema) as any,
    defaultValues: DEFAULT_VALUES,
  });

  // -------------------------------------------------------------------------
  // Pre-populate form when loan changes (or dialog opens with a loan)
  // -------------------------------------------------------------------------

  useEffect(() => {
    if (loan) {
      reset({
        institution_name: loan.institution_name,
        loan_identifier: loan.loan_identifier,
        // Convert paise → rupees for display
        outstanding_balance_rupees: loan.outstanding_balance / 100,
        annual_interest_rate: parseFloat(loan.annual_interest_rate),
        interest_rate_type: loan.interest_rate_type,
        // Convert paise → rupees for display
        monthly_payment_rupees: loan.monthly_payment / 100,
        payment_due_day: loan.payment_due_day,
        interest_rate_periods: loan.interest_rate_periods.map((p) => ({
          start_date: p.start_date,
          end_date: p.end_date ?? "",
          annual_interest_rate: parseFloat(p.annual_interest_rate),
        })),
      });
    } else {
      reset(DEFAULT_VALUES);
    }
  }, [loan, reset]);

  // -------------------------------------------------------------------------
  // Submit handler
  // -------------------------------------------------------------------------

  async function onSubmit(values: LoanFormValues): Promise<void> {
    if (!loan) return;

    try {
      await updateLoan({
        institution_name: values.institution_name,
        loan_identifier: values.loan_identifier,
        // Convert rupees → paise (× 100), round to avoid floating-point drift
        outstanding_balance: Math.round(values.outstanding_balance_rupees * 100),
        annual_interest_rate: values.annual_interest_rate,
        interest_rate_type: values.interest_rate_type,
        monthly_payment: Math.round(values.monthly_payment_rupees * 100),
        payment_due_day: values.payment_due_day,
      });

      // Success — close dialog, notify parent, reset form
      onOpenChange(false);
      onSuccess?.();
      reset(DEFAULT_VALUES);
    } catch (err) {
      if (err instanceof LoansApiError && err.status === 422 && err.details) {
        // Map backend field errors onto react-hook-form fields
        for (const [field, messages] of Object.entries(err.details)) {
          const message = messages[0] ?? "Invalid value";

          // Map API field names to form field names
          if (field === "outstanding_balance") {
            setError("outstanding_balance_rupees", { message });
          } else if (field === "monthly_payment") {
            setError("monthly_payment_rupees", { message });
          } else {
            // Fields whose names match directly (institution_name, loan_identifier,
            // annual_interest_rate, interest_rate_type, payment_due_day)
            setError(field as keyof LoanFormValues, { message });
          }
        }
      } else {
        // Non-field error — show a toast
        const message =
          err instanceof Error
            ? err.message
            : "Something went wrong, please try again.";
        toast({
          title: "Failed to update loan",
          description: message,
          variant: "destructive",
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Dialog open-change — reset form when closing
  // -------------------------------------------------------------------------

  function handleOpenChange(nextOpen: boolean): void {
    onOpenChange(nextOpen);
    if (!nextOpen) {
      reset(DEFAULT_VALUES);
    }
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  const isBusy = isSubmitting || isLoading;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit Loan</DialogTitle>
        </DialogHeader>

        <form
          id="edit-loan-form"
          onSubmit={handleSubmit(onSubmit)}
          noValidate
          className="py-2"
        >
          <LoanFormFields control={control} errors={errors} watch={watch} />
        </form>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isBusy}
          >
            Cancel
          </Button>
          <Button type="submit" form="edit-loan-form" disabled={isBusy}>
            {isBusy ? "Saving…" : "Save Changes"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export default EditLoanDialog;
