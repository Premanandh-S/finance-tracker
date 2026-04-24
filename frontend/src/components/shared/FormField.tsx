import type { JSX, ReactNode } from "react";
import { Label } from "@/components/ui/label.js";

interface FormFieldWrapperProps {
  /** The label text displayed above the field. */
  label: string;
  /** The field name — used as the label's `htmlFor` value. */
  name: string;
  /** Optional error message displayed below the field. */
  error?: string;
  /** The form control (e.g., Input, Select). */
  children: ReactNode;
}

/**
 * FormField is a composable wrapper that renders a label, a form control,
 * and an optional validation error message in a consistent layout.
 *
 * It works with any state management approach (react-hook-form, useState, etc.)
 * because it does not depend on react-hook-form context.
 *
 * @example
 * ```tsx
 * <FormField label="Email" name="email" error={errors.email}>
 *   <Input id="email" type="email" value={email} onChange={...} />
 * </FormField>
 * ```
 */
export function FormField({
  label,
  name,
  error,
  children,
}: FormFieldWrapperProps): JSX.Element {
  return (
    <div className="space-y-2">
      <Label htmlFor={name}>{label}</Label>
      {children}
      {error && (
        <p className="text-sm font-medium text-destructive">{error}</p>
      )}
    </div>
  );
}
