/**
 * AddButton.tsx
 *
 * A small "Add" button used within each dashboard domain section to navigate
 * to the create-new page for that domain.
 *
 * The click handler calls `event.stopPropagation()` so that clicking the
 * button does not also trigger the parent card's navigation handler.
 */

import type { JSX } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button.js";

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface AddButtonProps {
  /** Route path to navigate to when the button is clicked (e.g. "/loans/new"). */
  navigateTo: string;
  /** Accessible label for the button (e.g. "Add Loan"). */
  label: string;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Renders a small "+" button that navigates to `navigateTo` on click.
 *
 * Stops event propagation so the parent card's click handler is not triggered.
 *
 * @param props - `navigateTo` and `label`.
 * @returns A button element.
 *
 * @example
 * ```tsx
 * <AddButton navigateTo="/loans/new" label="Add Loan" />
 * ```
 */
export function AddButton({ navigateTo, label }: AddButtonProps): JSX.Element {
  const navigate = useNavigate();

  function handleClick(event: React.MouseEvent): void {
    event.stopPropagation();
    navigate(navigateTo);
  }

  return (
    <Button
      variant="outline"
      size="sm"
      onClick={handleClick}
      aria-label={label}
      className="shrink-0"
    >
      + {label}
    </Button>
  );
}

export default AddButton;
