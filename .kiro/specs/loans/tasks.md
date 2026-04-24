# Implementation Plan: Loans Feature

## Overview

This plan implements the Loans feature across the Rails API backend and the React frontend. The backend is built first (schema → models → services → controllers), followed by the frontend (API layer → hooks → pages → components). All monetary values are stored as integers (smallest currency unit — paise) to avoid floating-point errors.

---

## Tasks

- [x] 1. Create database schema and run migrations
  - Create migration for `loans` table with all required columns and constraints
  - Create migration for `interest_rate_periods` table with foreign key to loans
  - Add `has_many :loans, dependent: :destroy` association to User model
  - Run migrations and verify schema matches design
  - _Requirements: 1.1, 1.2, 5.1, 7.1_

- [x] 2. Implement Loan and InterestRatePeriod models
  - [x] 2.1 Create Loan model with validations and associations
    - Define `Loan` model with `belongs_to :user` and `has_many :interest_rate_periods, dependent: :destroy`
    - Add validations for all fields per design (outstanding_balance > 0, annual_interest_rate 0–100, payment_due_day 1–28, interest_rate_type inclusion)
    - Add custom validation `floating_rate_requires_at_least_one_period` on create
    - Define `INTEREST_RATE_TYPES` constant and `for_user` scope
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 2.2 Create InterestRatePeriod model with validations and associations
    - Define `InterestRatePeriod` model with `belongs_to :loan`
    - Add validations for start_date (presence) and annual_interest_rate (0–100)
    - Allow end_date to be nullable (open-ended current period)
    - _Requirements: 1.6, 7.1, 7.2_

- [x] 3. Implement Loans::PaymentCalculator service
  - [x] 3.1 Create PaymentCalculator with fixed-rate amortisation logic
    - Create `app/services/loans/payment_calculator.rb` with module namespace
    - Implement `self.amortisation_schedule(loan)` for fixed-rate loans
    - Per-period interest: `floor((balance × rate / 100) / 12 + 0.5)` (round half-up)
    - Principal: `monthly_payment - interest`; remaining balance: `previous_balance - principal`
    - Handle final period adjustment (exact remaining amount, remaining_balance = 0)
    - Cap schedule at 600 periods as safety guard
    - Define `NonConvergingLoanError` inner error class
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 3.2 Add floating-rate amortisation logic to PaymentCalculator
    - Extend `amortisation_schedule` to handle floating-rate loans
    - Rate lookup: find InterestRatePeriod where `start_date <= payment_date` and (`end_date >= payment_date` OR `end_date IS NULL`)
    - Fall back to most recent period's rate when payment_date is beyond all defined periods
    - Apply same principal/balance arithmetic as fixed-rate
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 3.3 Implement next_payment_date and payoff_date calculations
    - Implement `self.next_payment_date(loan, as_of: Date.today)`
    - If `as_of.day < payment_due_day` → return same month; otherwise → return next month
    - Implement `self.payoff_date(loan)` — return payment_date of final schedule entry, nil if empty
    - _Requirements: 9.1, 9.2, 9.3, 2.2, 3.1_

  - [x] 3.4 Implement dashboard_summary calculation
    - Implement `self.dashboard_summary(user)`
    - Return `{ total_count:, total_outstanding_balance:, items: [...] }`
    - Each item: `{ id:, institution_name:, outstanding_balance:, next_payment_date: }`
    - Return zeros and empty array when user has no loans
    - _Requirements: 10.1, 10.2, 10.3_

- [x] 4. Implement Loans::LoanManager service
  - [x] 4.1 Create LoanManager with create method
    - Create `app/services/loans/loan_manager.rb` with module namespace
    - Implement `self.create(user:, params:)` — validate and persist Loan associated with user
    - Define inner error classes: `NotFoundError`, `ValidationError`
    - Raise `ValidationError` with field details on invalid params
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 4.2 Implement list method in LoanManager
    - Implement `self.list(user:)` — return array of hashes with computed next_payment_date and payoff_date
    - Return empty array when user has no loans
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 4.3 Implement show method in LoanManager
    - Implement `self.show(user:, loan_id:)` — find loan, verify ownership, raise `NotFoundError` if not found or wrong user
    - Return hash with full loan detail including amortisation_schedule
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 4.4 Implement update method in LoanManager
    - Implement `self.update(user:, loan_id:, params:)` — find loan, verify ownership, apply validations, return updated record
    - Raise `NotFoundError` or `ValidationError` as appropriate
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 4.5 Implement destroy method in LoanManager
    - Implement `self.destroy(user:, loan_id:)` — find loan, verify ownership, permanently delete (cascade via dependent: :destroy)
    - Raise `NotFoundError` if loan not found or belongs to another user
    - _Requirements: 5.1, 5.2_

  - [x] 4.6 Implement add_or_update_rate_period method in LoanManager
    - Implement `self.add_or_update_rate_period(user:, loan_id:, params:)`
    - Reject fixed-rate loans with `ValidationError` ("invalid_operation")
    - Create or update InterestRatePeriod, return updated loan with recalculated schedule
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 5. Implement LoansController
  - [x] 5.1 Create LoansController with all five actions
    - Create `app/controllers/loans_controller.rb`
    - Add `before_action :authenticate_user!`
    - `index`: call `LoanManager.list`, render JSON
    - `show`: call `LoanManager.show`, render JSON; `NotFoundError` → 404
    - `create`: call `LoanManager.create`, render JSON 201; `ValidationError` → 422
    - `update`: call `LoanManager.update`, render JSON; `NotFoundError` → 404, `ValidationError` → 422
    - `destroy`: call `LoanManager.destroy`, render 204; `NotFoundError` → 404
    - Catch `NonConvergingLoanError` → 422 with `error: "non_converging_loan"`
    - _Requirements: 1.1, 1.7, 2.1, 2.4, 2.5, 3.1, 3.3, 3.4, 4.1, 4.4, 5.1, 5.3_

  - [x] 5.2 Add routes for loans and interest rate periods
    - Add `resources :loans, only: [:index, :show, :create, :update, :destroy]` to routes.rb
    - Add nested `resources :interest_rate_periods, only: [:create, :update, :destroy]` under loans
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 8.1_

- [x] 6. Implement InterestRatePeriodsController
  - Create `app/controllers/loans/interest_rate_periods_controller.rb`
  - Add `before_action :authenticate_user!`
  - `create`: call `LoanManager.add_or_update_rate_period`, render JSON 201
  - `update`: call `LoanManager.add_or_update_rate_period`, render JSON
  - `destroy`: find rate period via scoped loan, verify ownership, destroy, render 204
  - `ValidationError` (fixed-rate rejection) → 422 with `error: "invalid_operation"`
  - `NotFoundError` → 404
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 7. Implement frontend API layer
  - Create `frontend/src/api/loansApi.ts` following the same pattern as `authApi.ts`
  - Define TypeScript interfaces: `Loan`, `LoanDetail`, `AmortisationEntry`, `InterestRatePeriod`, `CreateLoanParams`, `UpdateLoanParams`, `RatePeriodParams`, `DashboardLoansSummary`
  - Implement typed fetch wrappers: `listLoans`, `getLoan`, `createLoan`, `updateLoan`, `deleteLoan`, `createRatePeriod`, `updateRatePeriod`, `deleteRatePeriod`
  - Define `LoansApiError` class with `code`, `status`, and `details` fields
  - All functions accept a JWT token and attach it as `Authorization: Bearer <token>`
  - _Requirements: 11.1, 12.1, 13.1, 14.1_

- [x] 8. Implement useLoans and useLoanDetail hooks
  - [x] 8.1 Create useLoans hook
    - Create `frontend/src/hooks/useLoans.ts`
    - Fetch loan list on mount using `listLoans` from loansApi
    - Expose: `loans`, `isLoading`, `error`, `createLoan(params)`, `deleteLoan(id)`, `refresh()`
    - Use `useAuth` to get the current token
    - _Requirements: 11.1, 11.3, 11.4, 12.1, 12.6_

  - [x] 8.2 Create useLoanDetail hook
    - Create `frontend/src/hooks/useLoanDetail.ts` (or add to useLoans.ts)
    - Fetch loan detail on mount using `getLoan` from loansApi
    - Expose: `loan`, `isLoading`, `error`, `updateLoan(params)`, `deleteLoan()`, `addRatePeriod(params)`, `updateRatePeriod(periodId, params)`, `deleteRatePeriod(periodId)`, `refresh()`
    - _Requirements: 13.1, 13.5, 13.6, 13.7, 14.1_

- [x] 9. Implement shared loan form components
  - [x] 9.1 Create LoanFormFields component
    - Create `frontend/src/components/loans/LoanFormFields.tsx`
    - Render all loan form fields: institution name, loan identifier, outstanding balance (in rupees, converted to paise on submit), annual interest rate, interest rate type (Select), monthly payment, payment due day
    - When interest_rate_type is `floating`, reveal an interest rate periods section with add/remove controls
    - Use `FormField` wrapper for consistent label + error layout
    - _Requirements: 12.2, 12.3, 12.4_

  - [x] 9.2 Create AddLoanDialog component
    - Create `frontend/src/components/loans/AddLoanDialog.tsx`
    - Use react-hook-form + zod schema for validation
    - On submit: call `createLoan` from the hook, close dialog on success, show toast on API error
    - Display server-side field errors inline when API returns 422
    - _Requirements: 12.1, 12.4, 12.5, 12.6_

  - [x] 9.3 Create EditLoanDialog component
    - Create `frontend/src/components/loans/EditLoanDialog.tsx`
    - Pre-populate form with current loan values
    - On submit: call `updateLoan` from the hook, close dialog on success
    - Display server-side field errors inline when API returns 422
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 10. Implement AmortisationTable component
  - Create `frontend/src/components/loans/AmortisationTable.tsx`
  - Render amortisation schedule in a table with columns: Period, Payment Date, Payment Amount, Principal, Interest, Remaining Balance
  - Format monetary values using `formatCurrency` helper (paise → ₹ with en-IN locale)
  - Format dates as locale-friendly strings
  - _Requirements: 13.3_

- [x] 11. Update LoansPage with real data
  - Replace mock data in `frontend/src/pages/LoansPage.tsx` with `useLoans` hook
  - Show `Skeleton` rows while loading
  - Show empty-state message when loans array is empty
  - Wire "Add Loan" button to `AddLoanDialog`
  - Navigate to `/loans/:id` on row click
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

- [x] 12. Implement LoanDetailPage
  - Create `frontend/src/pages/LoanDetailPage.tsx`
  - Use `useLoanDetail(id)` hook (id from `useParams`)
  - Show `Skeleton` placeholders while loading
  - Render loan summary section with all fields
  - Render `AmortisationTable` with the schedule
  - For floating-rate loans: render interest rate periods list with add/edit/delete controls
  - "Edit" button opens `EditLoanDialog` pre-populated with current values
  - "Delete" button shows confirmation dialog; on confirm calls `deleteLoan()` and navigates back to `/loans`
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

- [x] 13. Add /loans/:id route to App.tsx
  - Import `LoanDetailPage` in `App.tsx`
  - Add `<Route path="/loans/:id" element={<LoanDetailPage />} />` inside the ProtectedRoute block
  - _Requirements: 13.1_

- [x] 14. Update DashboardPage with real loans data
  - Fetch loans summary from the backend (via `listLoans` or a dedicated dashboard endpoint) in `DashboardPage.tsx`
  - Replace mock `totalDebt` with the real `total_outstanding_balance` from the API
  - Show `Skeleton` in the Total Debt card while loading
  - _Requirements: 15.1, 15.2, 15.3_

---

## Notes

- All monetary values are stored as integers (paise). The UI accepts rupees and converts on submit; displays convert back using `formatCurrency`.
- The implementation follows existing project conventions: services as POROs, thin models, YARD documentation, custom errors as inner classes, `frozen_string_literal: true` on all Ruby files.
- Frontend follows existing patterns: typed API wrappers in `src/api/`, state hooks in `src/hooks/`, shadcn/ui components, `FormField` wrapper for form layout.
