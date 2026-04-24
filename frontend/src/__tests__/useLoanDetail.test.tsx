/**
 * useLoanDetail.test.tsx
 *
 * Unit tests for the useLoanDetail hook.
 * Covers: fetching loan detail on mount, loading state, error handling,
 * updateLoan, deleteLoan, addRatePeriod, updateRatePeriod, deleteRatePeriod,
 * and refresh.
 */

/** @jsxRuntime classic */
/** @jsx React.createElement */
import * as React from "react";
import { renderHook, act } from "@testing-library/react";
import { useLoanDetail } from "../hooks/useLoanDetail.js";

// ---------------------------------------------------------------------------
// Mock loansApi so no real HTTP calls are made
// ---------------------------------------------------------------------------

jest.mock("../api/loansApi.js", () => ({
  getLoan: jest.fn(),
  updateLoan: jest.fn(),
  deleteLoan: jest.fn(),
  createRatePeriod: jest.fn(),
  updateRatePeriod: jest.fn(),
  deleteRatePeriod: jest.fn(),
}));

import * as loansApi from "../api/loansApi.js";

const mockGetLoan = loansApi.getLoan as jest.MockedFunction<typeof loansApi.getLoan>;
const mockUpdateLoan = loansApi.updateLoan as jest.MockedFunction<typeof loansApi.updateLoan>;
const mockDeleteLoan = loansApi.deleteLoan as jest.MockedFunction<typeof loansApi.deleteLoan>;
const mockCreateRatePeriod = loansApi.createRatePeriod as jest.MockedFunction<typeof loansApi.createRatePeriod>;
const mockUpdateRatePeriod = loansApi.updateRatePeriod as jest.MockedFunction<typeof loansApi.updateRatePeriod>;
const mockDeleteRatePeriod = loansApi.deleteRatePeriod as jest.MockedFunction<typeof loansApi.deleteRatePeriod>;

// ---------------------------------------------------------------------------
// Mock useAuth so we can control the token
// ---------------------------------------------------------------------------

jest.mock("../hooks/useAuth.js", () => ({
  useAuth: jest.fn(),
}));

import { useAuth } from "../hooks/useAuth.js";

const mockUseAuth = useAuth as jest.MockedFunction<typeof useAuth>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const FAKE_TOKEN = "fake-jwt-token";
const LOAN_ID = 42;

/** Minimal LoanDetail fixture for tests. */
function makeLoanDetail(id: number = LOAN_ID): loansApi.LoanDetail {
  return {
    id,
    institution_name: `Bank ${id}`,
    loan_identifier: `LOAN-${id}`,
    outstanding_balance: 100000 * id,
    interest_rate_type: "fixed",
    annual_interest_rate: "8.5",
    monthly_payment: 5000,
    payment_due_day: 5,
    next_payment_date: "2025-08-05",
    payoff_date: "2032-03-05",
    interest_rate_periods: [],
    amortisation_schedule: [
      {
        period: 1,
        payment_date: "2025-08-05",
        payment_amount: 5000,
        principal: 4292,
        interest: 708,
        remaining_balance: 95708,
      },
    ],
  };
}

/** Minimal UpdateLoanParams fixture. */
const UPDATE_PARAMS: loansApi.UpdateLoanParams = {
  institution_name: "Updated Bank",
  monthly_payment: 6000,
};

/** Minimal RatePeriodParams fixture. */
const RATE_PERIOD_PARAMS: loansApi.RatePeriodParams = {
  start_date: "2025-01-01",
  annual_interest_rate: 9.5,
};

/** Sets up useAuth mock to return a token. */
function setupAuthWithToken(token: string | null = FAKE_TOKEN) {
  mockUseAuth.mockReturnValue({
    token,
    user: token ? { id: "1" } : null,
    isAuthenticated: token !== null,
    isLoading: false,
    loginWithOtp: jest.fn(),
    loginWithPassword: jest.fn(),
    logout: jest.fn(),
    handleUnauthorized: jest.fn(),
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useLoanDetail", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    setupAuthWithToken(FAKE_TOKEN);
  });

  // -------------------------------------------------------------------------
  // Fetch on mount
  // -------------------------------------------------------------------------

  it("fetches loan detail on mount and sets loan state", async () => {
    const detail = makeLoanDetail();
    mockGetLoan.mockResolvedValueOnce(detail);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    expect(mockGetLoan).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID);
    expect(result.current.loan).toEqual(detail);
    expect(result.current.error).toBeNull();
  });

  it("starts with loan as null before fetch completes", () => {
    // Never resolves during this test
    mockGetLoan.mockReturnValue(new Promise(() => {}));

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    expect(result.current.loan).toBeNull();
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  it("sets isLoading to true while fetching, false after", async () => {
    let resolveGet!: (value: loansApi.LoanDetail) => void;
    const getPromise = new Promise<loansApi.LoanDetail>((resolve) => {
      resolveGet = resolve;
    });
    mockGetLoan.mockReturnValueOnce(getPromise);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    // isLoading should be true while the promise is pending
    expect(result.current.isLoading).toBe(true);

    // Resolve the promise
    await act(async () => {
      resolveGet(makeLoanDetail());
      await getPromise;
    });

    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // Error handling
  // -------------------------------------------------------------------------

  it("sets error when fetch fails", async () => {
    mockGetLoan.mockRejectedValueOnce(new Error("Network error"));

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.error).toBe("Network error");
    expect(result.current.loan).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // updateLoan
  // -------------------------------------------------------------------------

  it("updateLoan calls the API and refreshes the loan detail", async () => {
    const initial = makeLoanDetail();
    const updated = { ...makeLoanDetail(), institution_name: "Updated Bank" };

    mockGetLoan
      .mockResolvedValueOnce(initial)   // initial fetch on mount
      .mockResolvedValueOnce(updated);  // refresh after update
    mockUpdateLoan.mockResolvedValueOnce(updated);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.loan).toEqual(initial);

    // Call updateLoan
    await act(async () => {
      await result.current.updateLoan(UPDATE_PARAMS);
    });

    expect(mockUpdateLoan).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID, UPDATE_PARAMS);
    expect(mockGetLoan).toHaveBeenCalledTimes(2);
    expect(result.current.loan).toEqual(updated);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when updateLoan fails", async () => {
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    const apiError = new Error("Validation failed");
    mockUpdateLoan.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.updateLoan(UPDATE_PARAMS);
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Validation failed");
    expect(result.current.error).toBe("Validation failed");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // deleteLoan
  // -------------------------------------------------------------------------

  it("deleteLoan calls the API without refreshing", async () => {
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    mockDeleteLoan.mockResolvedValueOnce(undefined);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });

    // Call deleteLoan
    await act(async () => {
      await result.current.deleteLoan();
    });

    expect(mockDeleteLoan).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID);
    // getLoan should only have been called once (on mount), not again after delete
    expect(mockGetLoan).toHaveBeenCalledTimes(1);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when deleteLoan fails", async () => {
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    const apiError = new Error("Loan not found");
    mockDeleteLoan.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.deleteLoan();
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Loan not found");
    expect(result.current.error).toBe("Loan not found");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // addRatePeriod
  // -------------------------------------------------------------------------

  it("addRatePeriod calls the API and refreshes the loan detail", async () => {
    const initial = makeLoanDetail();
    const withPeriod: loansApi.LoanDetail = {
      ...makeLoanDetail(),
      interest_rate_periods: [
        { id: 1, start_date: "2025-01-01", end_date: null, annual_interest_rate: "9.5" },
      ],
    };

    mockGetLoan
      .mockResolvedValueOnce(initial)     // initial fetch on mount
      .mockResolvedValueOnce(withPeriod); // refresh after addRatePeriod
    mockCreateRatePeriod.mockResolvedValueOnce(withPeriod);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      await result.current.addRatePeriod(RATE_PERIOD_PARAMS);
    });

    expect(mockCreateRatePeriod).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID, RATE_PERIOD_PARAMS);
    expect(mockGetLoan).toHaveBeenCalledTimes(2);
    expect(result.current.loan).toEqual(withPeriod);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when addRatePeriod fails", async () => {
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    const apiError = new Error("Invalid operation");
    mockCreateRatePeriod.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.addRatePeriod(RATE_PERIOD_PARAMS);
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Invalid operation");
    expect(result.current.error).toBe("Invalid operation");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // updateRatePeriod
  // -------------------------------------------------------------------------

  it("updateRatePeriod calls the API and refreshes the loan detail", async () => {
    const PERIOD_ID = 7;
    const initial = makeLoanDetail();
    const updated: loansApi.LoanDetail = {
      ...makeLoanDetail(),
      interest_rate_periods: [
        { id: PERIOD_ID, start_date: "2025-01-01", end_date: null, annual_interest_rate: "9.5" },
      ],
    };

    mockGetLoan
      .mockResolvedValueOnce(initial)   // initial fetch on mount
      .mockResolvedValueOnce(updated);  // refresh after updateRatePeriod
    mockUpdateRatePeriod.mockResolvedValueOnce(updated);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      await result.current.updateRatePeriod(PERIOD_ID, RATE_PERIOD_PARAMS);
    });

    expect(mockUpdateRatePeriod).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID, PERIOD_ID, RATE_PERIOD_PARAMS);
    expect(mockGetLoan).toHaveBeenCalledTimes(2);
    expect(result.current.loan).toEqual(updated);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when updateRatePeriod fails", async () => {
    const PERIOD_ID = 7;
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    const apiError = new Error("Rate period not found");
    mockUpdateRatePeriod.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.updateRatePeriod(PERIOD_ID, RATE_PERIOD_PARAMS);
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Rate period not found");
    expect(result.current.error).toBe("Rate period not found");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // deleteRatePeriod
  // -------------------------------------------------------------------------

  it("deleteRatePeriod calls the API and refreshes the loan detail", async () => {
    const PERIOD_ID = 3;
    const initial: loansApi.LoanDetail = {
      ...makeLoanDetail(),
      interest_rate_periods: [
        { id: PERIOD_ID, start_date: "2025-01-01", end_date: null, annual_interest_rate: "9.5" },
      ],
    };
    const afterDelete = makeLoanDetail(); // no rate periods

    mockGetLoan
      .mockResolvedValueOnce(initial)      // initial fetch on mount
      .mockResolvedValueOnce(afterDelete); // refresh after deleteRatePeriod
    mockDeleteRatePeriod.mockResolvedValueOnce(undefined);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    await act(async () => {
      await result.current.deleteRatePeriod(PERIOD_ID);
    });

    expect(mockDeleteRatePeriod).toHaveBeenCalledWith(FAKE_TOKEN, LOAN_ID, PERIOD_ID);
    expect(mockGetLoan).toHaveBeenCalledTimes(2);
    expect(result.current.loan).toEqual(afterDelete);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when deleteRatePeriod fails", async () => {
    const PERIOD_ID = 3;
    mockGetLoan.mockResolvedValueOnce(makeLoanDetail());
    const apiError = new Error("Rate period not found");
    mockDeleteRatePeriod.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.deleteRatePeriod(PERIOD_ID);
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Rate period not found");
    expect(result.current.error).toBe("Rate period not found");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // refresh
  // -------------------------------------------------------------------------

  it("refresh re-fetches the loan detail", async () => {
    const first = makeLoanDetail();
    const second = { ...makeLoanDetail(), institution_name: "Refreshed Bank" };

    mockGetLoan
      .mockResolvedValueOnce(first)
      .mockResolvedValueOnce(second);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.loan).toEqual(first);

    // Manually call refresh
    await act(async () => {
      await result.current.refresh();
    });

    expect(mockGetLoan).toHaveBeenCalledTimes(2);
    expect(result.current.loan).toEqual(second);
  });

  // -------------------------------------------------------------------------
  // No token
  // -------------------------------------------------------------------------

  it("does not fetch loan detail when token is null", async () => {
    setupAuthWithToken(null);

    const { result } = renderHook(() => useLoanDetail(LOAN_ID));

    await act(async () => {
      await Promise.resolve();
    });

    expect(mockGetLoan).not.toHaveBeenCalled();
    expect(result.current.loan).toBeNull();
    expect(result.current.error).toBeNull();
  });
});
