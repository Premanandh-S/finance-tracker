# Requirements Document

## Introduction

The Dashboard feature provides authenticated users with a single aggregated view of their entire financial portfolio. It consolidates data from all four financial domains — Savings, Loans, Insurance, and Pensions — into one API response and one frontend page. The backend exposes a dedicated `GET /dashboard` endpoint that calls each domain's existing `dashboard_summary` service method and assembles the results. The React frontend renders four summary cards (Total Savings, Total Debt, Insurance, Pensions) and navigates to the relevant domain page when a card is clicked.

All monetary values are in the smallest currency unit (paise) throughout, consistent with the rest of the application.

---

## Glossary

- **Dashboard**: The aggregated summary view of all financial instruments for a User, accessible via `GET /dashboard`.
- **Dashboard_Aggregator**: The Rails service responsible for assembling the full dashboard payload by delegating to each domain's summary method.
- **Dashboard_Controller**: The Rails controller that authenticates the request and delegates to Dashboard_Aggregator.
- **Savings_Summary**: The sub-section of the dashboard payload produced by `Savings::SavingsManager.dashboard_summary`, containing total count, total principal, and a list of savings instruments.
- **Loans_Summary**: The sub-section produced by the loans domain, containing total count, total outstanding balance, a list of loans, and a `pending_payments` array.
- **Insurance_Summary**: The sub-section produced by `Insurance::InsuranceManager.dashboard_summary`, containing total count, a list of insurance policies, and an `expiring_soon` array.
- **Pensions_Summary**: The sub-section produced by `Pensions::PensionManager.dashboard_summary`, containing total count, total corpus, and a list of pension instruments.
- **User**: An authenticated account holder identified by phone or email.
- **JWT**: The JSON Web Token used to authenticate API requests.
- **Total_Savings**: The sum of `principal_amount` across all of a User's SavingsInstruments.
- **Total_Debt**: The sum of `outstanding_balance` across all of a User's Loans.
- **Total_Corpus**: The sum of all PensionContribution amounts across all of a User's PensionInstruments.
- **Pending_Payment**: A Loan whose `next_payment_date` falls within the current calendar month.
- **Expiring_Soon**: An InsurancePolicy whose `renewal_date` falls within the current calendar month or the next calendar month.

---

## Requirements

### Requirement 1: Dashboard API Endpoint

**User Story:** As a User, I want a single API endpoint that returns all my financial data in one call, so that the frontend can render the dashboard without making multiple requests.

#### Acceptance Criteria

1. WHEN an authenticated User sends `GET /dashboard`, THE Dashboard_Controller SHALL return a JSON response containing Savings_Summary, Loans_Summary, Insurance_Summary, and Pensions_Summary.
2. THE Dashboard_Controller SHALL reject requests from unauthenticated callers with a 401 status.
3. THE Dashboard_Controller SHALL return a 200 status on success.
4. THE Dashboard_Aggregator SHALL delegate savings data collection to `Savings::SavingsManager.dashboard_summary`.
5. THE Dashboard_Aggregator SHALL delegate loans data collection to the loans domain summary method.
6. THE Dashboard_Aggregator SHALL delegate insurance data collection to `Insurance::InsuranceManager.dashboard_summary`.
7. THE Dashboard_Aggregator SHALL delegate pensions data collection to `Pensions::PensionManager.dashboard_summary`.
8. THE Dashboard_Aggregator SHALL assemble all four domain summaries into a single response hash with keys `savings`, `loans`, `insurance`, and `pensions`.

---

### Requirement 2: Savings Summary Section

**User Story:** As a User, I want to see my total savings and a list of my savings instruments on the dashboard, so that I can quickly understand my savings position.

#### Acceptance Criteria

1. THE Dashboard_Aggregator SHALL include in the Savings_Summary: `total_count` (integer), `total_principal` (integer in paise), and `items` (array).
2. THE Dashboard_Aggregator SHALL include in each Savings_Summary item: `id`, `institution_name`, `savings_identifier`, `savings_type`, `principal_amount`, and `maturity_date`.
3. WHEN a User has no savings instruments, THE Dashboard_Aggregator SHALL return a Savings_Summary with `total_count` of zero, `total_principal` of zero, and an empty `items` array.
4. THE Dashboard_Aggregator SHALL include only SavingsInstruments belonging to the requesting User in the Savings_Summary.

---

### Requirement 3: Loans Summary Section

**User Story:** As a User, I want to see my total debt and a list of my loans on the dashboard, so that I can quickly understand my debt position.

#### Acceptance Criteria

1. THE Dashboard_Aggregator SHALL include in the Loans_Summary: `total_count` (integer), `total_outstanding_balance` (integer in paise), and `items` (array).
2. THE Dashboard_Aggregator SHALL include in each Loans_Summary item: `id`, `institution_name`, `loan_identifier`, `outstanding_balance`, and `next_payment_date`.
3. WHEN a User has no loans, THE Dashboard_Aggregator SHALL return a Loans_Summary with `total_count` of zero, `total_outstanding_balance` of zero, and an empty `items` array.
4. THE Dashboard_Aggregator SHALL include only Loans belonging to the requesting User in the Loans_Summary.

---

### Requirement 4: Insurance Summary Section

**User Story:** As a User, I want to see a summary of my insurance policies on the dashboard, so that I can track my coverage at a glance.

#### Acceptance Criteria

1. THE Dashboard_Aggregator SHALL include in the Insurance_Summary: `total_count` (integer) and `items` (array).
2. THE Dashboard_Aggregator SHALL include in each Insurance_Summary item: `id`, `institution_name`, `policy_number`, `policy_type`, `sum_assured`, and `renewal_date`.
3. WHEN a User has no insurance policies, THE Dashboard_Aggregator SHALL return an Insurance_Summary with `total_count` of zero and an empty `items` array.
4. THE Dashboard_Aggregator SHALL include only InsurancePolicies belonging to the requesting User in the Insurance_Summary.

---

### Requirement 5: Pensions Summary Section

**User Story:** As a User, I want to see my total pension corpus and a list of my pension instruments on the dashboard, so that I can monitor my retirement savings.

#### Acceptance Criteria

1. THE Dashboard_Aggregator SHALL include in the Pensions_Summary: `total_count` (integer), `total_corpus` (integer in paise), and `items` (array).
2. THE Dashboard_Aggregator SHALL include in each Pensions_Summary item: `id`, `institution_name`, `pension_identifier`, `pension_type`, and `total_corpus`.
3. WHEN a User has no pension instruments, THE Dashboard_Aggregator SHALL return a Pensions_Summary with `total_count` of zero, `total_corpus` of zero, and an empty `items` array.
4. THE Dashboard_Aggregator SHALL include only PensionInstruments belonging to the requesting User in the Pensions_Summary.
5. THE Dashboard_Aggregator SHALL compute `total_corpus` for each PensionInstrument as the sum of all associated PensionContribution amounts.

---

### Requirement 6: Data Isolation

**User Story:** As a User, I want the dashboard to show only my own financial data, so that my financial information is never exposed to other users.

#### Acceptance Criteria

1. THE Dashboard_Aggregator SHALL scope all domain queries to the authenticated User, ensuring no data from other Users appears in any summary section.
2. WHEN two Users each have financial instruments, THE Dashboard_Controller SHALL return only the requesting User's instruments in the dashboard response.

---

### Requirement 7: Dashboard Page — Summary Cards

**User Story:** As a User, I want to see four summary cards on the dashboard page, so that I can get an at-a-glance view of my entire financial portfolio.

#### Acceptance Criteria

1. WHEN a User navigates to the Dashboard page, THE frontend SHALL fetch data from `GET /dashboard` using the stored JWT and render four summary cards: Total Savings, Total Debt, Insurance, and Pensions.
2. THE Total Savings card SHALL display the `total_principal` value from the Savings_Summary.
3. THE Total Debt card SHALL display the `total_outstanding_balance` value from the Loans_Summary.
4. THE Insurance card SHALL display the `total_count` of insurance policies from the Insurance_Summary.
5. THE Pensions card SHALL display the `total_corpus` value from the Pensions_Summary.
6. WHEN the dashboard data is loading, THE frontend SHALL display skeleton placeholder cards in place of the summary cards.
7. IF the `GET /dashboard` request fails, THEN THE frontend SHALL display an error message and provide a retry action.

---

### Requirement 8: Dashboard Page — Domain Lists

**User Story:** As a User, I want to see a list of items under each summary card, so that I can review individual instruments without navigating away from the dashboard.

#### Acceptance Criteria

1. THE Dashboard page SHALL render a list of savings instruments below the Total Savings card, showing `savings_identifier`, `institution_name`, `savings_type`, and `principal_amount` for each item.
2. THE Dashboard page SHALL render a list of loans below the Total Debt card, showing `loan_identifier`, `institution_name`, `outstanding_balance`, and `next_payment_date` for each item.
3. THE Dashboard page SHALL render a list of insurance policies below the Insurance card, showing `policy_number`, `institution_name`, `policy_type`, and `renewal_date` for each item.
4. THE Dashboard page SHALL render a list of pension instruments below the Pensions card, showing `pension_identifier`, `institution_name`, `pension_type`, and `total_corpus` for each item.
5. WHEN a domain has no items, THE Dashboard page SHALL display an empty-state message within that domain's section.

---

### Requirement 9: Dashboard Page — Navigation

**User Story:** As a User, I want to click on a summary card or a list item to navigate to the relevant domain page, so that I can drill into details without manually navigating.

#### Acceptance Criteria

1. WHEN a User clicks the Total Savings card or any savings list item, THE frontend SHALL navigate to the Savings page.
2. WHEN a User clicks the Total Debt card or any loans list item, THE frontend SHALL navigate to the Loans page.
3. WHEN a User clicks the Insurance card or any insurance list item, THE frontend SHALL navigate to the Insurance Policies page.
4. WHEN a User clicks the Pensions card or any pensions list item, THE frontend SHALL navigate to the Pension Instruments page.

---

### Requirement 10: Post-OTP Redirect to Dashboard

**User Story:** As a User, I want to be automatically redirected to the Dashboard page after successfully verifying my OTP, so that I land on my portfolio overview immediately after logging in.

#### Acceptance Criteria

1. WHEN the frontend receives a successful response (200 with a JWT) from `POST /auth/otp/verify`, THE frontend SHALL store the JWT and navigate to the Dashboard page.
2. THE redirect SHALL happen without any additional user interaction.
3. THE backend OTP verify endpoint SHALL remain unchanged — this is a frontend-only routing concern.

---

### Requirement 11: Create New Instrument Buttons on Dashboard

**User Story:** As a User, I want quick-access buttons on the Dashboard to create a new instrument in each domain, so that I can add new financial records without navigating away from the dashboard first.

#### Acceptance Criteria

1. THE Dashboard page SHALL display an "Add" or "+" button/link within the Savings section that navigates to the create new Savings instrument page.
2. THE Dashboard page SHALL display an "Add" or "+" button/link within the Loans section that navigates to the create new Loan page.
3. THE Dashboard page SHALL display an "Add" or "+" button/link within the Insurance section that navigates to the create new Insurance policy page.
4. THE Dashboard page SHALL display an "Add" or "+" button/link within the Pensions section that navigates to the create new Pension instrument page.
5. EACH "Add" button SHALL be clearly accessible within its respective domain section on the Dashboard.

---

### Requirement 12: Pending Monthly Loan Payments Alert

**User Story:** As a User, I want the Dashboard to highlight loans whose next payment is due this month, so that I can see at a glance which EMI payments I need to make.

#### Acceptance Criteria

1. THE Loans_Summary SHALL include a top-level `pending_payments` array containing all Loans for the requesting User whose `next_payment_date` falls within the current calendar month.
2. EACH entry in `pending_payments` SHALL include: `id`, `institution_name`, `loan_identifier`, `outstanding_balance`, `monthly_payment`, and `next_payment_date`.
3. THE `loan_identifier` field SHALL be included in each item of the Loans_Summary `items` array (in addition to `pending_payments`).
4. WHEN no loans have a `next_payment_date` in the current calendar month, THE `pending_payments` array SHALL be empty.
5. THE Dashboard page SHALL visually distinguish loans in `pending_payments` (e.g. a "Due this month" badge or highlighted row) so the User can identify pending EMI payments at a glance.
6. THE `pending_payments` data SHALL be scoped to the requesting User only.

---

### Requirement 13: Insurance Expiring Soon Alert

**User Story:** As a User, I want the Dashboard to highlight insurance policies expiring within the next two months, so that I know which policies I need to renew soon.

#### Acceptance Criteria

1. THE Insurance_Summary SHALL include a top-level `expiring_soon` array containing all InsurancePolicies for the requesting User whose `renewal_date` falls within the current calendar month or the next calendar month.
2. EACH entry in `expiring_soon` SHALL include: `id`, `institution_name`, `policy_number`, `policy_type`, and `renewal_date`.
3. WHEN no insurance policies have a `renewal_date` within the current or next calendar month, THE `expiring_soon` array SHALL be empty.
4. THE Dashboard page SHALL visually distinguish policies in `expiring_soon` (e.g. an "Expiring soon" badge) so the User can identify policies requiring renewal at a glance.
5. THE `expiring_soon` data SHALL be scoped to the requesting User only.
