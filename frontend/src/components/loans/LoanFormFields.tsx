import type { JSX } from "react";
import { Controller, useFieldArray, type Control, type FieldErrors, type UseFormWatch } from "react-hook-form";
import { Input } from "@/components/ui/input.js";
import { Button } from "@/components/ui/button.js";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select.js";
import { FormField } from "@/components/shared/FormField.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LoanFormValues {
  institution_name: string;
  loan_identifier: string;
  /** User enters in rupees; converted to paise on submit */
  outstanding_balance_rupees: number;
  annual_interest_rate: number;
  interest_rate_type: "fixed" | "floating";
  /** User enters in rupees; converted to paise on submit */
  monthly_payment_rupees: number;
  payment_due_day: number;
  interest_rate_periods: Array<{
    start_date: string;
    end_date?: string;
    annual_interest_rate: number;
  }>;
}

export interface LoanFormFieldsProps {
  control: Control<LoanFormValues>;
  errors: FieldErrors<LoanFormValues>;
  watch: UseFormWatch<LoanFormValues>;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * LoanFormFields renders all loan form fields for use inside react-hook-form.
 *
 * It is designed to be embedded in both AddLoanDialog and EditLoanDialog.
 * The parent is responsible for wrapping this in a <form> element and
 * providing the react-hook-form control, errors, and watch.
 *
 * Outstanding balance and monthly payment are entered in rupees by the user.
 * The parent dialog is responsible for converting to paise (× 100) before
 * calling the API.
 *
 * Requirements: 12.2, 12.3, 12.4
 */
export function LoanFormFields({
  control,
  errors,
  watch,
}: LoanFormFieldsProps): JSX.Element {
  const interestRateType = watch("interest_rate_type");

  const { fields, append, remove } = useFieldArray({
    control,
    name: "interest_rate_periods",
  });

  function handleAddPeriod() {
    append({ start_date: "", end_date: "", annual_interest_rate: 0 });
  }

  return (
    <div className="space-y-4">
      {/* Institution Name */}
      <FormField
        label="Institution Name"
        name="institution_name"
        error={errors.institution_name?.message}
      >
        <Input
          id="institution_name"
          placeholder="e.g. HDFC Bank"
          {...control.register("institution_name")}
        />
      </FormField>

      {/* Loan Identifier */}
      <FormField
        label="Loan Identifier"
        name="loan_identifier"
        error={errors.loan_identifier?.message}
      >
        <Input
          id="loan_identifier"
          placeholder="e.g. HL-2024-001"
          {...control.register("loan_identifier")}
        />
      </FormField>

      {/* Outstanding Balance */}
      <FormField
        label="Outstanding Balance (₹)"
        name="outstanding_balance_rupees"
        error={errors.outstanding_balance_rupees?.message}
      >
        <Input
          id="outstanding_balance_rupees"
          type="number"
          min="0"
          step="0.01"
          placeholder="e.g. 2500000"
          {...control.register("outstanding_balance_rupees", {
            valueAsNumber: true,
          })}
        />
      </FormField>

      {/* Annual Interest Rate */}
      <FormField
        label="Annual Interest Rate (%)"
        name="annual_interest_rate"
        error={errors.annual_interest_rate?.message}
      >
        <Input
          id="annual_interest_rate"
          type="number"
          min="0"
          max="100"
          step="0.01"
          placeholder="e.g. 8.5"
          {...control.register("annual_interest_rate", {
            valueAsNumber: true,
          })}
        />
      </FormField>

      {/* Interest Rate Type */}
      <FormField
        label="Interest Rate Type"
        name="interest_rate_type"
        error={errors.interest_rate_type?.message}
      >
        <InterestRateTypeSelect control={control} />
      </FormField>

      {/* Monthly Payment */}
      <FormField
        label="Monthly Payment (₹)"
        name="monthly_payment_rupees"
        error={errors.monthly_payment_rupees?.message}
      >
        <Input
          id="monthly_payment_rupees"
          type="number"
          min="0"
          step="0.01"
          placeholder="e.g. 25000"
          {...control.register("monthly_payment_rupees", {
            valueAsNumber: true,
          })}
        />
      </FormField>

      {/* Payment Due Day */}
      <FormField
        label="Payment Due Day (1–28)"
        name="payment_due_day"
        error={errors.payment_due_day?.message}
      >
        <Input
          id="payment_due_day"
          type="number"
          min="1"
          max="28"
          placeholder="e.g. 5"
          {...control.register("payment_due_day", {
            valueAsNumber: true,
          })}
        />
      </FormField>

      {/* Interest Rate Periods — only shown for floating rate */}
      {interestRateType === "floating" && (
        <div className="space-y-3 rounded-md border p-4">
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium">Interest Rate Periods</p>
            <Button type="button" variant="outline" size="sm" onClick={handleAddPeriod}>
              Add Period
            </Button>
          </div>

          {fields.length === 0 && (
            <p className="text-sm text-muted-foreground">
              Add at least one interest rate period for a floating-rate loan.
            </p>
          )}

          {fields.map((field, index) => (
            <div
              key={field.id}
              className="grid grid-cols-[1fr_1fr_1fr_auto] gap-2 items-start"
            >
              {/* Start Date */}
              <FormField
                label="Start Date"
                name={`interest_rate_periods.${index}.start_date`}
                error={errors.interest_rate_periods?.[index]?.start_date?.message}
              >
                <Input
                  id={`interest_rate_periods.${index}.start_date`}
                  type="date"
                  {...control.register(`interest_rate_periods.${index}.start_date`)}
                />
              </FormField>

              {/* End Date (optional) */}
              <FormField
                label="End Date (optional)"
                name={`interest_rate_periods.${index}.end_date`}
                error={errors.interest_rate_periods?.[index]?.end_date?.message}
              >
                <Input
                  id={`interest_rate_periods.${index}.end_date`}
                  type="date"
                  {...control.register(`interest_rate_periods.${index}.end_date`)}
                />
              </FormField>

              {/* Annual Interest Rate */}
              <FormField
                label="Rate (%)"
                name={`interest_rate_periods.${index}.annual_interest_rate`}
                error={
                  errors.interest_rate_periods?.[index]?.annual_interest_rate?.message
                }
              >
                <Input
                  id={`interest_rate_periods.${index}.annual_interest_rate`}
                  type="number"
                  min="0"
                  max="100"
                  step="0.01"
                  placeholder="e.g. 9.5"
                  {...control.register(
                    `interest_rate_periods.${index}.annual_interest_rate`,
                    { valueAsNumber: true }
                  )}
                />
              </FormField>

              {/* Remove button */}
              <div className="pt-7">
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => remove(index)}
                  aria-label={`Remove interest rate period ${index + 1}`}
                >
                  Remove
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Internal sub-component: controlled Select for interest_rate_type
// ---------------------------------------------------------------------------

/**
 * Wraps the shadcn Select for interest_rate_type so it can be driven by
 * react-hook-form's Controller pattern without exposing Controller in the
 * parent component's JSX.
 */
function InterestRateTypeSelect({
  control,
}: {
  control: Control<LoanFormValues>;
}): JSX.Element {
  // We use Controller here because shadcn Select is not a native input and
  // cannot be driven by register() alone.
  return (
    <Controller
      control={control}
      name="interest_rate_type"
      render={({ field }) => (
        <Select value={field.value} onValueChange={field.onChange}>
          <SelectTrigger id="interest_rate_type">
            <SelectValue placeholder="Select interest rate type" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="fixed">Fixed</SelectItem>
            <SelectItem value="floating">Floating</SelectItem>
          </SelectContent>
        </Select>
      )}
    />
  );
}
