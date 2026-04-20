/**
 * ProtectedRoute.tsx
 *
 * A wrapper component that guards access to authenticated content.
 *
 * If the user is not authenticated (`isAuthenticated` is false in the auth
 * context), the component immediately redirects to `/login` via
 * `window.location.href` and renders nothing. If the auth state is still
 * loading (e.g. during a silent refresh), a loading indicator is shown.
 *
 * Usage:
 * ```tsx
 * <ProtectedRoute>
 *   <Dashboard />
 * </ProtectedRoute>
 * ```
 *
 * Or with a custom redirect target:
 * ```tsx
 * <ProtectedRoute redirectTo="/auth/login">
 *   <Settings />
 * </ProtectedRoute>
 * ```
 */

import { useEffect, type JSX, type ReactNode } from "react";
import { useAuth } from "../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ProtectedRouteProps {
  /** The content to render when the user is authenticated. */
  children: ReactNode;
  /**
   * The path to redirect unauthenticated users to.
   * Defaults to `/login`.
   */
  redirectTo?: string;
  /**
   * Optional custom loading element shown while auth state is being resolved.
   * Defaults to a simple "Loading…" paragraph.
   */
  loadingFallback?: ReactNode;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * `ProtectedRoute` renders its children only when the user is authenticated.
 *
 * Unauthenticated users are redirected to `redirectTo` (default: `/login`).
 * While the auth state is loading, `loadingFallback` is rendered instead.
 *
 * @param props.children - Content to render for authenticated users.
 * @param props.redirectTo - Redirect destination for unauthenticated users.
 * @param props.loadingFallback - Element to show while auth state loads.
 */
export function ProtectedRoute({
  children,
  redirectTo = "/login",
  loadingFallback = <p aria-live="polite">Loading…</p>,
}: ProtectedRouteProps): JSX.Element | null {
  const { isAuthenticated, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      window.location.href = redirectTo;
    }
  }, [isAuthenticated, isLoading, redirectTo]);

  if (isLoading) {
    return <>{loadingFallback}</>;
  }

  if (!isAuthenticated) {
    // Redirect is triggered by the effect above; render nothing in the meantime
    return null;
  }

  return <>{children}</>;
}

export default ProtectedRoute;
