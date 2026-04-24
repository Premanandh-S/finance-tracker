# Implementation Plan: Dashboard

## Overview

Implement the Dashboard feature end-to-end: extend two existing backend domain summary methods, build the new aggregator service and controller, update the OTP verify frontend flow to redirect to the dashboard, and build the full dashboard React page with summary cards, domain item lists, "Add" buttons, pending-payment badges, and expiring-soon badges.

## Tasks

- [x] 1. Extend `Loans::PaymentCalculator.dashboard_summary`
  - Add `loan_identifier` to each hash in the `items` array
  - Add a private helper `within_current_month?(date)` that returns true when `date.year == Date.current.year && date.month == Date.current.month`
  - Add a top-level `pending_payments` key: an array of loans whose `next_payment_date` is within the current calendar month, each entry containing `id`, `institution_name`, `loan_identifier`, `outstanding_balance`, `monthly_payment`, `next_payment_date`
  - File: `backend/app/services/loans/payment_calculator.rb`
  - _Requirements: 3.2, 12.1, 12.2, 12.3, 12.4, 12.6_

- [x] 2. Extend `Insurance::InsuranceManager.dashboard_summary`
  - Add a private helper `within_two_months?(date)` that returns true when the date falls in the current calendar month or the next calendar month (use `Date.current` for time-zone safety)
  - Add a top-level `expiring_soon` key: an array of policies whose `renewal_date` is within the current or next calendar month, each entry containing `id`, `institution_name`, `policy_number`, `policy_type`, `renewal_date`
  - File: `backend/app/services/insurance/insurance_manager.rb`
  - _Requirements: 13.1, 13.2, 13.3, 13.5_

- [x] 3. Create `Dashboard::DashboardAggregator` service
  - Create file `backend/app/services/dashboard/dashboard_aggregator.rb`
  - Define module `Dashboard`, class `DashboardAggregator`
  - Implement `self.call(user:)` that delegates to all four domain summary methods and returns a hash with keys `:savings`, `:loans`, `:insurance`, `:pensions`
  - Follow project conventions: `# frozen_string_literal: true`, YARD doc comments, no state
  - _Requirements: 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 4. Create `DashboardController` and route
  - Create file `backend/app/controllers/dashboard_controller.rb`
  - Inherit from `ApplicationController`, add `before_action :authenticate_user!`
  - Implement `show` action: call `Dashboard::DashboardAggregator.call(user: current_user)` and render as JSON with status 200
  - Add `get "dashboard", to: "dashboard#show"` to `backend/config/routes.rb`
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 5. Checkpoint — verify backend compiles and routes are correct
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Update OTP verify frontend flow to redirect to Dashboard
  - In the OTP verify page/component, after a successful `POST /auth/otp/verify` response (200 with JWT), store the JWT (same as the existing password login flow) and call `navigate("/dashboard")`
  - No changes to the backend OTP controller
  - _Requirements: 10.1, 10.2_

- [x] 7. Define TypeScript types for the Dashboard API payload
  - Create or update a types file (e.g. `src/types/dashboard.ts`) with interfaces: `SavingsItem`, `SavingsSummary`, `LoanItem`, `PendingPaymentItem`, `LoansSummary`, `InsuranceItem`, `ExpiringSoonItem`, `InsuranceSummary`, `PensionItem`, `PensionsSummary`, `DashboardPayload`
  - _Requirements: 7.1, 8.1, 8.2, 8.3, 8.4, 12.5, 13.4_

- [x] 8. Implement `useDashboard` custom hook
  - Create `src/hooks/useDashboard.ts`
  - Hook calls `GET /dashboard` with the stored JWT on mount and on `retry()`
  - Manages `data: DashboardPayload | null`, `loading: boolean`, `error: string | null`
  - On 401 response, delegate to the global auth interceptor (navigate to login)
  - On other errors, set `error` message
  - _Requirements: 7.1, 7.6, 7.7_

- [x] 9. Implement `AddButton` component
  - Create `src/components/dashboard/AddButton.tsx`
  - Renders a "+" or "Add" button/link that navigates to the `navigateTo` prop on click
  - Must stop event propagation so it does not trigger the parent card's navigation handler
  - Props: `navigateTo: string`, `label: string`
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 10. Implement `DomainItemList` component
  - Create `src/components/dashboard/DomainItemList.tsx`
  - Renders a list of items with configurable columns; each row is clickable
  - Accepts optional `alertIds: number[]` and `alertLabel: string`; renders the badge on matching rows
  - Renders `emptyMessage` when `items` is empty
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 12.5, 13.4_

- [x] 11. Implement `SummaryCard` component
  - Create `src/components/dashboard/SummaryCard.tsx`
  - Renders the headline metric for the domain (total_principal / total_outstanding_balance / total_count / total_corpus)
  - Wraps the card in a clickable element navigating to `navigateTo`
  - Renders `<AddButton>` with the domain's `addPath`
  - Renders `<DomainItemList>` with the domain's items, columns, and alert configuration
  - Props: `domain`, `summary`, `navigateTo`, `addPath`
  - _Requirements: 7.2, 7.3, 7.4, 7.5, 9.1, 9.2, 9.3, 9.4, 11.1, 11.2, 11.3, 11.4_

- [x] 12. Implement `LoadingSkeleton` and `ErrorBanner` components
  - Create `src/components/dashboard/LoadingSkeleton.tsx` — renders four skeleton placeholder cards
  - Create `src/components/dashboard/ErrorBanner.tsx` — renders an error message and a "Retry" button that calls `onRetry`
  - _Requirements: 7.6, 7.7_

- [x] 13. Implement `DashboardPage`
  - Create `src/pages/DashboardPage.tsx`
  - Uses `useDashboard()` hook for data, loading, error, and retry
  - Renders `<LoadingSkeleton />` while loading
  - Renders `<ErrorBanner onRetry={retry} />` on error
  - Renders four `<SummaryCard>` components with correct domain data, navigation targets, add paths, and alert configurations:
    - Loans card: passes `alertIds` derived from `data.loans.pending_payments` IDs and `alertLabel="Due this month"`
    - Insurance card: passes `alertIds` derived from `data.insurance.expiring_soon` IDs and `alertLabel="Expiring soon"`
  - Register the route `/dashboard` in the app router
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 8.1, 8.2, 8.3, 8.4, 8.5, 9.1, 9.2, 9.3, 9.4, 11.1, 11.2, 11.3, 11.4, 12.5, 13.4_

- [x] 14. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- No test tasks are included per project instructions
- All monetary values are integers in paise throughout — format for display in the UI (e.g. divide by 100 for rupees)
- `within_current_month?` and `within_two_months?` helpers in the backend should use `Date.current` (not `Date.today`) for time-zone correctness and test compatibility with `freeze_time`
- The `pending_payments` and `expiring_soon` arrays are computed from the same in-memory loan/policy arrays already loaded for `items` — no additional DB queries needed
- The `AddButton` click handler must call `event.stopPropagation()` to prevent the parent card's navigation from firing
