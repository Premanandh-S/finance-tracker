/**
 * useLoans.test.tsx
 *
 * Unit tests for the useLoans hook.
 * Covers: fetching loans on mount, loading state, error handling,
 * createLoan, deleteLoan, and refresh.
 */

/** @jsxRuntime classic */
/** @jsx React.createElement */
import * as React from "react";
import { renderHook, act } from "@testing-library/react";
import { useLoans } from "../hooks/useLoans.js";

// ---------------------------------------------------------------------------
// Mock loansApi so no real HTTP calls are made
// ---------------------------------------------------------------------------

jest.mock("../api/loansApi.js", () => ({
  listLoans: jest.fn(),
  createLoan: jest.fn(),
  deleteLoan: jest.fn(),
}));

import * as loansApi from "../api/loansApi.js";

const mockListLoans = loansApi.listLoans as jest.MockedFunction<typeof loansApi.listLoans>;
const mockCreateLoan = loansApi.createLoan as jest.MockedFunction<typeof loansApi.createLoan>;
const mockDeleteLoan = loansApi.deleteLoan as jest.MockedFunction<typeof loansApi.deleteLoan>;

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

/** Minimal Loan fixture for tests. */
function makeLoan(id: number): loansApi.Loan {
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
  };
}

/** Minimal CreateLoanParams fixture. */
const CREATE_PARAMS: loansApi.CreateLoanParams = {
  institution_name: "HDFC Bank",
  loan_identifier: "HL-001",
  outstanding_balance: 250000000,
  annual_interest_rate: 8.5,
  interest_rate_type: "fixed",
  monthly_payment: 2500000,
  payment_due_day: 5,
};

/** Minimal LoanDetail fixture returned by createLoan. */
function makeLoanDetail(id: number): loansApi.LoanDetail {
  return {
    ...makeLoan(id),
    interest_rate_periods: [],
    amortisation_schedule: [],
  };
}

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

describe("useLoans", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    setupAuthWithToken(FAKE_TOKEN);
  });

  // -------------------------------------------------------------------------
  // Fetch on mount
  // -------------------------------------------------------------------------

  it("fetches loans on mount and sets loans state", async () => {
    const loans = [makeLoan(1), makeLoan(2)];
    mockListLoans.mockResolvedValueOnce(loans);

    const { result } = renderHook(() => useLoans());

    // Wait for the async fetch to complete
    await act(async () => {
      await Promise.resolve();
    });

    expect(mockListLoans).toHaveBeenCalledWith(FAKE_TOKEN);
    expect(result.current.loans).toEqual(loans);
    expect(result.current.error).toBeNull();
  });

  it("starts with an empty loans array before fetch completes", () => {
    // Never resolves during this test
    mockListLoans.mockReturnValue(new Promise(() => {}));

    const { result } = renderHook(() => useLoans());

    expect(result.current.loans).toEqual([]);
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  it("sets isLoading to true while fetching, false after", async () => {
    let resolveList!: (value: loansApi.Loan[]) => void;
    const listPromise = new Promise<loansApi.Loan[]>((resolve) => {
      resolveList = resolve;
    });
    mockListLoans.mockReturnValueOnce(listPromise);

    const { result } = renderHook(() => useLoans());

    // isLoading should be true while the promise is pending
    expect(result.current.isLoading).toBe(true);

    // Resolve the promise
    await act(async () => {
      resolveList([makeLoan(1)]);
      await listPromise;
    });

    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // Error handling
  // -------------------------------------------------------------------------

  it("sets error when fetch fails", async () => {
    mockListLoans.mockRejectedValueOnce(new Error("Network error"));

    const { result } = renderHook(() => useLoans());

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.error).toBe("Network error");
    expect(result.current.loans).toEqual([]);
    expect(result.current.isLoading).toBe(false);
  });

  it("clears error on successful fetch after a previous failure", async () => {
    mockListLoans
      .mockRejectedValueOnce(new Error("Network error"))
      .mockResolvedValueOnce([makeLoan(1)]);

    const { result } = renderHook(() => useLoans());

    // Wait for first (failing) fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.error).toBe("Network error");

    // Trigger refresh which succeeds
    await act(async () => {
      await result.current.refresh();
    });

    expect(result.current.error).toBeNull();
    expect(result.current.loans).toEqual([makeLoan(1)]);
  });

  // -------------------------------------------------------------------------
  // createLoan
  // -------------------------------------------------------------------------

  it("createLoan calls the API and refreshes the list", async () => {
    const initialLoans = [makeLoan(1)];
    const updatedLoans = [makeLoan(1), makeLoan(2)];

    mockListLoans
      .mockResolvedValueOnce(initialLoans)  // initial fetch on mount
      .mockResolvedValueOnce(updatedLoans); // refresh after create
    mockCreateLoan.mockResolvedValueOnce(makeLoanDetail(2));

    const { result } = renderHook(() => useLoans());

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.loans).toEqual(initialLoans);

    // Call createLoan
    await act(async () => {
      await result.current.createLoan(CREATE_PARAMS);
    });

    expect(mockCreateLoan).toHaveBeenCalledWith(FAKE_TOKEN, CREATE_PARAMS);
    expect(mockListLoans).toHaveBeenCalledTimes(2);
    expect(result.current.loans).toEqual(updatedLoans);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when createLoan fails", async () => {
    mockListLoans.mockResolvedValueOnce([]);
    const apiError = new Error("Validation failed");
    mockCreateLoan.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoans());

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.createLoan(CREATE_PARAMS);
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

  it("deleteLoan calls the API and refreshes the list", async () => {
    const initialLoans = [makeLoan(1), makeLoan(2)];
    const updatedLoans = [makeLoan(2)];

    mockListLoans
      .mockResolvedValueOnce(initialLoans)  // initial fetch on mount
      .mockResolvedValueOnce(updatedLoans); // refresh after delete
    mockDeleteLoan.mockResolvedValueOnce(undefined);

    const { result } = renderHook(() => useLoans());

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.loans).toEqual(initialLoans);

    // Call deleteLoan
    await act(async () => {
      await result.current.deleteLoan(1);
    });

    expect(mockDeleteLoan).toHaveBeenCalledWith(FAKE_TOKEN, 1);
    expect(mockListLoans).toHaveBeenCalledTimes(2);
    expect(result.current.loans).toEqual(updatedLoans);
    expect(result.current.isLoading).toBe(false);
  });

  it("sets error and re-throws when deleteLoan fails", async () => {
    mockListLoans.mockResolvedValueOnce([makeLoan(1)]);
    const apiError = new Error("Loan not found");
    mockDeleteLoan.mockRejectedValueOnce(apiError);

    const { result } = renderHook(() => useLoans());

    await act(async () => {
      await Promise.resolve();
    });

    let thrownError: Error | undefined;
    await act(async () => {
      try {
        await result.current.deleteLoan(999);
      } catch (err) {
        thrownError = err as Error;
      }
    });

    expect(thrownError?.message).toBe("Loan not found");
    expect(result.current.error).toBe("Loan not found");
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // refresh
  // -------------------------------------------------------------------------

  it("refresh re-fetches the loan list", async () => {
    const firstLoans = [makeLoan(1)];
    const secondLoans = [makeLoan(1), makeLoan(2)];

    mockListLoans
      .mockResolvedValueOnce(firstLoans)
      .mockResolvedValueOnce(secondLoans);

    const { result } = renderHook(() => useLoans());

    // Wait for initial fetch
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.loans).toEqual(firstLoans);

    // Manually call refresh
    await act(async () => {
      await result.current.refresh();
    });

    expect(mockListLoans).toHaveBeenCalledTimes(2);
    expect(result.current.loans).toEqual(secondLoans);
  });

  // -------------------------------------------------------------------------
  // No token
  // -------------------------------------------------------------------------

  it("does not fetch loans when token is null", async () => {
    setupAuthWithToken(null);

    const { result } = renderHook(() => useLoans());

    await act(async () => {
      await Promise.resolve();
    });

    expect(mockListLoans).not.toHaveBeenCalled();
    expect(result.current.loans).toEqual([]);
    expect(result.current.error).toBeNull();
  });
});
