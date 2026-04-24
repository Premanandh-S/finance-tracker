/**
 * useDashboard.ts
 *
 * React hook for fetching and managing the dashboard data state.
 *
 * Calls GET /dashboard on mount and on explicit retry. Uses the JWT token
 * from useAuth for authentication. On a 401 response the global auth
 * interceptor (handleUnauthorized) is invoked to attempt a token refresh or
 * redirect to login.
 */

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "./useAuth.js";
import { getDashboard, DashboardApiError } from "../api/dashboardApi.js";
import type { DashboardPayload } from "../types/dashboard.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Public interface exposed by the `useDashboard` hook. */
export interface UseDashboardReturn {
  /** The full dashboard payload, or `null` before the first successful load. */
  data: DashboardPayload | null;
  /** `true` while the dashboard data is being fetched. */
  loading: boolean;
  /** Human-readable error message, or `null` when there is no error. */
  error: string | null;
  /**
   * Re-fetches the dashboard data from the server.
   *
   * Resets `loading` to `true` and clears the previous error before
   * initiating the request.
   */
  retry: () => void;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Returns the dashboard data and state for the authenticated user.
 *
 * Fetches `GET /dashboard` on mount and whenever the auth token changes.
 * Must be called inside a component that is a descendant of `AuthProvider`.
 *
 * @returns `UseDashboardReturn` with `data`, `loading`, `error`, and `retry`.
 *
 * @example
 * ```tsx
 * const { data, loading, error, retry } = useDashboard();
 * if (loading) return <LoadingSkeleton />;
 * if (error) return <ErrorBanner onRetry={retry} />;
 * return <DashboardContent data={data!} />;
 * ```
 */
export function useDashboard(): UseDashboardReturn {
  const { token, handleUnauthorized } = useAuth();
  const [data, setData] = useState<DashboardPayload | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  // Incrementing this counter triggers a re-fetch via the useEffect dependency.
  const [fetchCount, setFetchCount] = useState<number>(0);

  // -------------------------------------------------------------------------
  // Fetch dashboard data
  // -------------------------------------------------------------------------

  useEffect(() => {
    if (!token) {
      setData(null);
      setLoading(false);
      setError(null);
      return;
    }

    let cancelled = false;

    async function fetchDashboard(): Promise<void> {
      setLoading(true);
      setError(null);

      try {
        const payload = await getDashboard(token!);
        if (!cancelled) {
          setData(payload);
        }
      } catch (err) {
        if (cancelled) return;

        if (err instanceof DashboardApiError && err.status === 401) {
          // Delegate to the global auth interceptor — it will either refresh
          // the token (triggering a re-render with the new token) or redirect
          // to login.
          await handleUnauthorized();
          return;
        }

        const message =
          err instanceof Error ? err.message : "Failed to load dashboard";
        setError(message);
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void fetchDashboard();

    return () => {
      cancelled = true;
    };
  }, [token, fetchCount, handleUnauthorized]);

  // -------------------------------------------------------------------------
  // retry
  // -------------------------------------------------------------------------

  const retry = useCallback((): void => {
    setFetchCount((c) => c + 1);
  }, []);

  // -------------------------------------------------------------------------
  // Return value
  // -------------------------------------------------------------------------

  return { data, loading, error, retry };
}
