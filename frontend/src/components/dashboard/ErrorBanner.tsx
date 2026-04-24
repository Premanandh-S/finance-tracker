/**
 * ErrorBanner.tsx
 *
 * Renders an error message and a "Retry" button for the dashboard error state.
 * The retry button calls the `onRetry` callback to re-fetch the dashboard data.
 */

import type { JSX } from "react";
import { Button } from "@/components/ui/button.js";

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface ErrorBannerProps {
  /** Human-readable error message to display. */
  message?: string;
  /** Callback invoked when the user clicks the "Retry" button. */
  onRetry: () => void;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Renders an error banner with a message and a retry button.
 *
 * @param props - `message` (optional) and `onRetry` callback.
 *
 * @example
 * ```tsx
 * <ErrorBanner
 *   message="Failed to load dashboard data."
 *   onRetry={retry}
 * />
 * ```
 */
export function ErrorBanner({
  message = "Something went wrong. Please try again.",
  onRetry,
}: ErrorBannerProps): JSX.Element {
  return (
    <div
      role="alert"
      className="flex flex-col items-center gap-4 rounded-lg border border-destructive/50 bg-destructive/10 p-6 text-center"
    >
      <p className="text-sm text-destructive font-medium">{message}</p>
      <Button variant="outline" onClick={onRetry}>
        Retry
      </Button>
    </div>
  );
}

export default ErrorBanner;
