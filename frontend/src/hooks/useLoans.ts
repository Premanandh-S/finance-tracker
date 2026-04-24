/**
 * useLoans.ts
 *
 * React hook for managing loans list state.
 *
 * Fetches the loan list on mount and provides actions to create, delete,
 * and refresh loans. Uses the JWT token from useAuth for authentication.
 */

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "./useAuth.js";
import {
  listLoans,
  createLoan,
  deleteLoan as deleteLoanApi,
  type Loan,
  type CreateLoanParams,
} from "../api/loansApi.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Public interface exposed by the `useLoans` hook. */
export interface UseLoansReturn {
  /** Array of loans belonging to the current user. */
  loans: Loan[];
  /** `true` while fetching or mutating loan data. */
  isLoading: boolean;
  /** Error message string, or `null` if no error. */
  error: string | null;
  /**
   * Creates a new loan for the current user.
   *
   * Calls `POST /loans`, then refreshes the loan list on success.
   *
   * @param params - Loan creation parameters.
   * @throws {LoansApiError} on validation errors (422) or auth failure (401).
   * @throws {Error} on network failure.
   */
  createLoan(params: CreateLoanParams): Promise<void>;
  /**
   * Deletes a loan by ID.
   *
   * Calls `DELETE /loans/:id`, then refreshes the loan list on success.
   *
   * @param id - Loan ID to delete.
   * @throws {LoansApiError} on not found (404) or auth failure (401).
   * @throws {Error} on network failure.
   */
  deleteLoan(id: number): Promise<void>;
  /**
   * Re-fetches the loan list from the server.
   *
   * Useful for refreshing after external changes or error recovery.
   */
  refresh(): Promise<void>;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Returns the current loans list and actions to create, delete, and refresh.
 *
 * Fetches the loan list on mount and whenever the auth token changes.
 * Must be called inside a component that is a descendant of `AuthProvider`.
 *
 * @returns The `UseLoansReturn` containing state (`loans`, `isLoading`,
 *          `error`) and actions (`createLoan`, `deleteLoan`, `refresh`).
 *
 * @example
 * ```tsx
 * const { loans, isLoading, error, createLoan, deleteLoan, refresh } = useLoans();
 * ```
 */
export function useLoans(): UseLoansReturn {
  const { token } = useAuth();
  const [loans, setLoans] = useState<Loan[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // -------------------------------------------------------------------------
  // refresh — fetch loan list
  // -------------------------------------------------------------------------

  const refresh = useCallback(async (): Promise<void> => {
    if (!token) {
      setLoans([]);
      setError(null);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const data = await listLoans(token);
      setLoans(data);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to load loans";
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, [token]);

  // -------------------------------------------------------------------------
  // Fetch on mount and when token changes
  // -------------------------------------------------------------------------

  useEffect(() => {
    void refresh();
  }, [refresh]);

  // -------------------------------------------------------------------------
  // createLoan
  // -------------------------------------------------------------------------

  const handleCreateLoan = useCallback(
    async (params: CreateLoanParams): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await createLoan(token, params);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to create loan";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, refresh]
  );

  // -------------------------------------------------------------------------
  // deleteLoan
  // -------------------------------------------------------------------------

  const handleDeleteLoan = useCallback(
    async (id: number): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await deleteLoanApi(token, id);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to delete loan";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, refresh]
  );

  // -------------------------------------------------------------------------
  // Return value
  // -------------------------------------------------------------------------

  return {
    loans,
    isLoading,
    error,
    createLoan: handleCreateLoan,
    deleteLoan: handleDeleteLoan,
    refresh,
  };
}
