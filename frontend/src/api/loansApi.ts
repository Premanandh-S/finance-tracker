/**
 * loansApi.ts
 *
 * Typed fetch wrappers for all loans endpoints.
 * Base URL is read from the VITE_API_BASE_URL environment variable,
 * defaulting to http://localhost:3000.
 *
 * All functions require a JWT token which is attached as
 * `Authorization: Bearer <token>`.
 */

// ---------------------------------------------------------------------------
// Base URL
// ---------------------------------------------------------------------------

function resolveBaseUrl(): string {
  if (typeof process !== "undefined" && process.env?.VITE_API_BASE_URL) {
    return process.env.VITE_API_BASE_URL;
  }
  return "http://localhost:3000";
}

const BASE_URL: string = resolveBaseUrl();

// ---------------------------------------------------------------------------
// Error class
// ---------------------------------------------------------------------------

/** Validation error details map returned by the backend on 422 responses. */
export type LoansApiErrorDetails = Record<string, string[]>;

/**
 * Thrown whenever the backend responds with a non-2xx status on a loans
 * endpoint.
 */
export class LoansApiError extends Error {
  /** Machine-readable error code from the backend (e.g. "not_found"). */
  readonly code: string;
  /** Raw HTTP status code. */
  readonly status: number;
  /**
   * Field-level validation error details, present on 422 responses.
   * Maps field names to arrays of error messages.
   */
  readonly details: LoansApiErrorDetails | undefined;

  constructor(
    status: number,
    body: { error: string; message: string; details?: LoansApiErrorDetails }
  ) {
    super(body.message ?? "Something went wrong, please try again.");
    this.name = "LoansApiError";
    this.code = body.error;
    this.status = status;
    this.details = body.details;
  }
}

// ---------------------------------------------------------------------------
// Domain interfaces
// ---------------------------------------------------------------------------

export interface Loan {
  id: number;
  institution_name: string;
  loan_identifier: string;
  outstanding_balance: number;
  interest_rate_type: "fixed" | "floating";
  annual_interest_rate: string;
  monthly_payment: number;
  payment_due_day: number;
  next_payment_date: string;
  payoff_date: string;
}

export interface AmortisationEntry {
  period: number;
  payment_date: string;
  payment_amount: number;
  principal: number;
  interest: number;
  remaining_balance: number;
}

export interface InterestRatePeriod {
  id: number;
  start_date: string;
  end_date: string | null;
  annual_interest_rate: string;
}

export interface LoanDetail extends Loan {
  interest_rate_periods: InterestRatePeriod[];
  amortisation_schedule: AmortisationEntry[];
}

export interface DashboardLoanItem {
  id: number;
  institution_name: string;
  outstanding_balance: number;
  next_payment_date: string;
}

export interface DashboardLoansSummary {
  total_count: number;
  total_outstanding_balance: number;
  items: DashboardLoanItem[];
}

// ---------------------------------------------------------------------------
// Param interfaces
// ---------------------------------------------------------------------------

export interface RatePeriodParams {
  start_date: string;
  end_date?: string | null;
  annual_interest_rate: number;
}

export interface CreateLoanParams {
  institution_name: string;
  loan_identifier: string;
  outstanding_balance: number;
  annual_interest_rate: number;
  interest_rate_type: "fixed" | "floating";
  monthly_payment: number;
  payment_due_day: number;
  interest_rate_periods?: RatePeriodParams[];
}

export interface UpdateLoanParams {
  institution_name?: string;
  loan_identifier?: string;
  outstanding_balance?: number;
  annual_interest_rate?: number;
  interest_rate_type?: "fixed" | "floating";
  monthly_payment?: number;
  payment_due_day?: number;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

const NETWORK_ERROR_MESSAGE = "Something went wrong, please try again.";

/**
 * Builds the standard JSON request init object with an Authorization header.
 */
function buildInit(
  method: string,
  token: string,
  body?: unknown
): RequestInit {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
    Authorization: `Bearer ${token}`,
  };

  return {
    method,
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  };
}

/**
 * Executes a fetch call and resolves to the parsed JSON response body.
 * Throws `LoansApiError` for non-2xx responses and a plain `Error` for
 * network-level failures (no response received).
 */
async function request<T>(url: string, init: RequestInit): Promise<T> {
  let response: Response;

  try {
    response = await fetch(url, init);
  } catch {
    throw new Error(NETWORK_ERROR_MESSAGE);
  }

  if (!response.ok) {
    let errorBody: { error: string; message: string; details?: LoansApiErrorDetails };
    try {
      errorBody = await response.json();
    } catch {
      errorBody = {
        error: "unknown_error",
        message: NETWORK_ERROR_MESSAGE,
      };
    }
    throw new LoansApiError(response.status, errorBody);
  }

  // 204 No Content — return undefined cast to T
  if (response.status === 204) {
    return undefined as unknown as T;
  }

  return response.json() as Promise<T>;
}

// ---------------------------------------------------------------------------
// Endpoint wrappers
// ---------------------------------------------------------------------------

/**
 * GET /loans
 *
 * Returns all loans belonging to the authenticated user.
 *
 * @param token - JWT Bearer token.
 * @returns Array of loan list items with computed next_payment_date and payoff_date.
 * @throws {LoansApiError} on non-2xx responses.
 * @throws {Error} on network failure.
 */
export async function listLoans(token: string): Promise<Loan[]> {
  return request<Loan[]>(`${BASE_URL}/loans`, buildInit("GET", token));
}

/**
 * GET /loans/:id
 *
 * Returns the full loan detail including amortisation schedule.
 *
 * @param token - JWT Bearer token.
 * @param id - Loan ID.
 * @returns Full loan detail with interest_rate_periods and amortisation_schedule.
 * @throws {LoansApiError} on non-2xx responses (404 if not found or wrong user).
 * @throws {Error} on network failure.
 */
export async function getLoan(token: string, id: number): Promise<LoanDetail> {
  return request<LoanDetail>(`${BASE_URL}/loans/${id}`, buildInit("GET", token));
}

/**
 * POST /loans
 *
 * Creates a new loan for the authenticated user.
 *
 * @param token - JWT Bearer token.
 * @param params - Loan creation parameters.
 * @returns The newly created loan detail (201).
 * @throws {LoansApiError} on validation errors (422) or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function createLoan(
  token: string,
  params: CreateLoanParams
): Promise<LoanDetail> {
  return request<LoanDetail>(`${BASE_URL}/loans`, buildInit("POST", token, params));
}

/**
 * PATCH /loans/:id
 *
 * Updates an existing loan's fields.
 *
 * @param token - JWT Bearer token.
 * @param id - Loan ID.
 * @param params - Fields to update (all optional).
 * @returns The updated loan.
 * @throws {LoansApiError} on validation errors (422), not found (404), or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function updateLoan(
  token: string,
  id: number,
  params: UpdateLoanParams
): Promise<Loan> {
  return request<Loan>(`${BASE_URL}/loans/${id}`, buildInit("PATCH", token, params));
}

/**
 * DELETE /loans/:id
 *
 * Permanently deletes a loan and all its associated interest rate periods.
 *
 * @param token - JWT Bearer token.
 * @param id - Loan ID.
 * @returns void (204 No Content).
 * @throws {LoansApiError} on not found (404) or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function deleteLoan(token: string, id: number): Promise<void> {
  return request<void>(`${BASE_URL}/loans/${id}`, buildInit("DELETE", token));
}

/**
 * POST /loans/:loanId/interest_rate_periods
 *
 * Adds a new interest rate period to a floating-rate loan.
 *
 * @param token - JWT Bearer token.
 * @param loanId - Loan ID.
 * @param params - Rate period parameters.
 * @returns The updated loan detail with recalculated amortisation schedule (201).
 * @throws {LoansApiError} on validation errors (422), not found (404), or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function createRatePeriod(
  token: string,
  loanId: number,
  params: RatePeriodParams
): Promise<LoanDetail> {
  return request<LoanDetail>(
    `${BASE_URL}/loans/${loanId}/interest_rate_periods`,
    buildInit("POST", token, params)
  );
}

/**
 * PATCH /loans/:loanId/interest_rate_periods/:periodId
 *
 * Updates an existing interest rate period.
 *
 * @param token - JWT Bearer token.
 * @param loanId - Loan ID.
 * @param periodId - Interest rate period ID.
 * @param params - Updated rate period parameters.
 * @returns The updated loan detail with recalculated amortisation schedule.
 * @throws {LoansApiError} on validation errors (422), not found (404), or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function updateRatePeriod(
  token: string,
  loanId: number,
  periodId: number,
  params: RatePeriodParams
): Promise<LoanDetail> {
  return request<LoanDetail>(
    `${BASE_URL}/loans/${loanId}/interest_rate_periods/${periodId}`,
    buildInit("PATCH", token, params)
  );
}

/**
 * DELETE /loans/:loanId/interest_rate_periods/:periodId
 *
 * Removes an interest rate period from a loan.
 *
 * @param token - JWT Bearer token.
 * @param loanId - Loan ID.
 * @param periodId - Interest rate period ID.
 * @returns void (204 No Content).
 * @throws {LoansApiError} on not found (404) or auth failure (401).
 * @throws {Error} on network failure.
 */
export async function deleteRatePeriod(
  token: string,
  loanId: number,
  periodId: number
): Promise<void> {
  return request<void>(
    `${BASE_URL}/loans/${loanId}/interest_rate_periods/${periodId}`,
    buildInit("DELETE", token)
  );
}
