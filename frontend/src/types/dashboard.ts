/**
 * dashboard.ts
 *
 * TypeScript interfaces for the GET /dashboard API response payload.
 *
 * All monetary values are integers in the smallest currency unit (paise).
 * Dates are ISO 8601 strings (YYYY-MM-DD).
 */

// ---------------------------------------------------------------------------
// Savings
// ---------------------------------------------------------------------------

/** A single savings instrument item in the dashboard summary. */
export interface SavingsItem {
  id: number;
  institution_name: string;
  savings_identifier: string;
  savings_type: string;
  /** Principal amount in paise. */
  principal_amount: number;
  /** ISO 8601 date string (YYYY-MM-DD). */
  maturity_date: string;
}

/** The savings section of the dashboard payload. */
export interface SavingsSummary {
  total_count: number;
  /** Sum of all principal amounts in paise. */
  total_principal: number;
  items: SavingsItem[];
}

// ---------------------------------------------------------------------------
// Loans
// ---------------------------------------------------------------------------

/** A single loan item in the dashboard summary. */
export interface LoanItem {
  id: number;
  institution_name: string;
  loan_identifier: string;
  /** Outstanding balance in paise. */
  outstanding_balance: number;
  /** ISO 8601 date string (YYYY-MM-DD). */
  next_payment_date: string;
}

/** A loan whose next payment is due within the current calendar month. */
export interface PendingPaymentItem {
  id: number;
  institution_name: string;
  loan_identifier: string;
  /** Outstanding balance in paise. */
  outstanding_balance: number;
  /** Monthly payment amount in paise. */
  monthly_payment: number;
  /** ISO 8601 date string (YYYY-MM-DD). */
  next_payment_date: string;
}

/** The loans section of the dashboard payload. */
export interface LoansSummary {
  total_count: number;
  /** Sum of all outstanding balances in paise. */
  total_outstanding_balance: number;
  items: LoanItem[];
  /** Loans whose next payment falls within the current calendar month. */
  pending_payments: PendingPaymentItem[];
}

// ---------------------------------------------------------------------------
// Insurance
// ---------------------------------------------------------------------------

/** A single insurance policy item in the dashboard summary. */
export interface InsuranceItem {
  id: number;
  institution_name: string;
  policy_number: string;
  policy_type: string;
  /** Sum assured in paise. */
  sum_assured: number;
  /** ISO 8601 date string (YYYY-MM-DD). */
  renewal_date: string;
}

/** An insurance policy whose renewal date falls within the next two months. */
export interface ExpiringSoonItem {
  id: number;
  institution_name: string;
  policy_number: string;
  policy_type: string;
  /** ISO 8601 date string (YYYY-MM-DD). */
  renewal_date: string;
}

/** The insurance section of the dashboard payload. */
export interface InsuranceSummary {
  total_count: number;
  items: InsuranceItem[];
  /** Policies whose renewal date falls within the current or next calendar month. */
  expiring_soon: ExpiringSoonItem[];
}

// ---------------------------------------------------------------------------
// Pensions
// ---------------------------------------------------------------------------

/** A single pension instrument item in the dashboard summary. */
export interface PensionItem {
  id: number;
  institution_name: string;
  pension_identifier: string;
  pension_type: string;
  /** Total corpus (sum of all contributions) in paise. */
  total_corpus: number;
}

/** The pensions section of the dashboard payload. */
export interface PensionsSummary {
  total_count: number;
  /** Sum of all pension contribution amounts in paise. */
  total_corpus: number;
  items: PensionItem[];
}

// ---------------------------------------------------------------------------
// Top-level payload
// ---------------------------------------------------------------------------

/** The full response payload returned by GET /dashboard. */
export interface DashboardPayload {
  savings: SavingsSummary;
  loans: LoansSummary;
  insurance: InsuranceSummary;
  pensions: PensionsSummary;
}
