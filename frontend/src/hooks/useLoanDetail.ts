/**
 * useLoanDetail.ts
 *
 * React hook for managing a single loan's detail state.
 *
 * Fetches the loan detail on mount and provides actions to update, delete,
 * and manage interest rate periods. Uses the JWT token from useAuth for
 * authentication.
 */

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "./useAuth.js";
import {
  getLoan,
  updateLoan as updateLoanApi,
  deleteLoan as deleteLoanApi,
  createRatePeriod,
  updateRatePeriod as updateRatePeriodApi,
  deleteRatePeriod as deleteRatePeriodApi,
  type LoanDetail,
  type UpdateLoanParams,
  type RatePeriodParams,
} from "../api/loansApi.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Public interface exposed by the `useLoanDetail` hook. */
export interface UseLoanDetailReturn {
  /** Full loan detail including amortisation schedule, or `null` before first load. */
  loan: LoanDetail | null;
  /** `true` while fetching or mutating loan data. */
  isLoading: boolean;
  /** Error message string, or `null` if no error. */
  error: string | null;
  /**
   * Updates the loan's fields.
   *
   * Calls `PATCH /loans/:id`, then refreshes the loan detail on success.
   *
   * @param params - Fields to update (all optional).
   * @throws {LoansApiError} on validation errors (422) or auth failure (401).
   * @throws {Error} on network failure.
   */
  updateLoan(params: UpdateLoanParams): Promise<void>;
  /**
   * Deletes the loan.
   *
   * Calls `DELETE /loans/:id`. No refresh is performed — the caller is
   * expected to navigate away after deletion.
   *
   * @throws {LoansApiError} on not found (404) or auth failure (401).
   * @throws {Error} on network failure.
   */
  deleteLoan(): Promise<void>;
  /**
   * Adds a new interest rate period to the loan.
   *
   * Calls `POST /loans/:id/interest_rate_periods`, then refreshes the loan
   * detail on success.
   *
   * @param params - Rate period parameters.
   * @throws {LoansApiError} on validation errors (422) or auth failure (401).
   * @throws {Error} on network failure.
   */
  addRatePeriod(params: RatePeriodParams): Promise<void>;
  /**
   * Updates an existing interest rate period.
   *
   * Calls `PATCH /loans/:id/interest_rate_periods/:periodId`, then refreshes
   * the loan detail on success.
   *
   * @param periodId - Interest rate period ID.
   * @param params - Updated rate period parameters.
   * @throws {LoansApiError} on validation errors (422) or auth failure (401).
   * @throws {Error} on network failure.
   */
  updateRatePeriod(periodId: number, params: RatePeriodParams): Promise<void>;
  /**
   * Deletes an interest rate period from the loan.
   *
   * Calls `DELETE /loans/:id/interest_rate_periods/:periodId`, then refreshes
   * the loan detail on success.
   *
   * @param periodId - Interest rate period ID.
   * @throws {LoansApiError} on not found (404) or auth failure (401).
   * @throws {Error} on network failure.
   */
  deleteRatePeriod(periodId: number): Promise<void>;
  /**
   * Re-fetches the loan detail from the server.
   *
   * Useful for refreshing after external changes or error recovery.
   */
  refresh(): Promise<void>;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Returns the full detail for a single loan and actions to mutate it.
 *
 * Fetches the loan detail on mount and whenever the loan ID or auth token
 * changes. Must be called inside a component that is a descendant of
 * `AuthProvider`.
 *
 * @param id - The loan ID to fetch.
 * @returns The `UseLoanDetailReturn` containing state (`loan`, `isLoading`,
 *          `error`) and actions (`updateLoan`, `deleteLoan`, `addRatePeriod`,
 *          `updateRatePeriod`, `deleteRatePeriod`, `refresh`).
 *
 * @example
 * ```tsx
 * const { loan, isLoading, error, updateLoan, deleteLoan } = useLoanDetail(id);
 * ```
 */
export function useLoanDetail(id: number): UseLoanDetailReturn {
  const { token } = useAuth();
  const [loan, setLoan] = useState<LoanDetail | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // -------------------------------------------------------------------------
  // refresh — fetch loan detail
  // -------------------------------------------------------------------------

  const refresh = useCallback(async (): Promise<void> => {
    if (!token) {
      setLoan(null);
      setError(null);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const data = await getLoan(token, id);
      setLoan(data);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to load loan";
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, [token, id]);

  // -------------------------------------------------------------------------
  // Fetch on mount and when id or token changes
  // -------------------------------------------------------------------------

  useEffect(() => {
    void refresh();
  }, [refresh]);

  // -------------------------------------------------------------------------
  // updateLoan
  // -------------------------------------------------------------------------

  const handleUpdateLoan = useCallback(
    async (params: UpdateLoanParams): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await updateLoanApi(token, id, params);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to update loan";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, id, refresh]
  );

  // -------------------------------------------------------------------------
  // deleteLoan
  // -------------------------------------------------------------------------

  const handleDeleteLoan = useCallback(async (): Promise<void> => {
    if (!token) {
      throw new Error("Not authenticated");
    }

    setIsLoading(true);
    setError(null);

    try {
      await deleteLoanApi(token, id);
      // No refresh — caller is expected to navigate away
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to delete loan";
      setError(message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [token, id]);

  // -------------------------------------------------------------------------
  // addRatePeriod
  // -------------------------------------------------------------------------

  const handleAddRatePeriod = useCallback(
    async (params: RatePeriodParams): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await createRatePeriod(token, id, params);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to add rate period";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, id, refresh]
  );

  // -------------------------------------------------------------------------
  // updateRatePeriod
  // -------------------------------------------------------------------------

  const handleUpdateRatePeriod = useCallback(
    async (periodId: number, params: RatePeriodParams): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await updateRatePeriodApi(token, id, periodId, params);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to update rate period";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, id, refresh]
  );

  // -------------------------------------------------------------------------
  // deleteRatePeriod
  // -------------------------------------------------------------------------

  const handleDeleteRatePeriod = useCallback(
    async (periodId: number): Promise<void> => {
      if (!token) {
        throw new Error("Not authenticated");
      }

      setIsLoading(true);
      setError(null);

      try {
        await deleteRatePeriodApi(token, id, periodId);
        await refresh();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Failed to delete rate period";
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [token, id, refresh]
  );

  // -------------------------------------------------------------------------
  // Return value
  // -------------------------------------------------------------------------

  return {
    loan,
    isLoading,
    error,
    updateLoan: handleUpdateLoan,
    deleteLoan: handleDeleteLoan,
    addRatePeriod: handleAddRatePeriod,
    updateRatePeriod: handleUpdateRatePeriod,
    deleteRatePeriod: handleDeleteRatePeriod,
    refresh,
  };
}
