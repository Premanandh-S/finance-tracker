# Requirements Document

## Introduction

The Loans feature allows authenticated users to track their loan portfolio within the personal finance management application. Users can record loan details including outstanding balance, interest rate (fixed or floating), monthly payment schedule, and institution information. The system computes and displays projected payoff timelines, future payment schedules, and recalculates projections whenever interest rates are updated. This feature covers the backend API (Rails) and the React frontend.

## Glossary

- **Loan**: A financial liability record belonging to a user, representing a borrowed amount being repaid over time.
- **Loan_Manager**: The Rails API service responsible for creating, reading, updating, and deleting loan records.
- **Payment_Calculator**: The service responsible for computing amortisation schedules, projected payoff dates, and outstanding balance projections.
- **Interest_Rate_Type**: An enumerated value of either `fixed` or `floating`, describing how the interest rate behaves over time.
- **Interest_Rate_Period**: A record associating a specific annual interest rate (as a percentage) with a date range, used to model floating rate changes over time.
- **Amortisation_Schedule**: An ordered list of projected monthly payment entries, each containing a payment date, principal component, interest component, and remaining balance.
- **Outstanding_Balance**: The remaining principal owed on a loan at a given point in time.
- **Monthly_Payment**: The fixed or computed amount the user pays each month toward a loan.
- **Payoff_Date**: The projected calendar date on which the Outstanding_Balance reaches zero.
- **User**: An authenticated account holder identified by phone or email.
- **Dashboard**: The aggregated summary view of all financial instruments for a User.

---

## Requirements

### Requirement 1: Create a Loan

**User Story:** As a User, I want to record a new loan, so that I can track my debt obligations in one place.

#### Acceptance Criteria

1. WHEN a User submits a valid loan creation request, THE Loan_Manager SHALL persist a new Loan record associated with that User.
2. THE Loan_Manager SHALL require the following fields on creation: institution name, loan number or identifier, outstanding balance (in the smallest currency unit as an integer), annual interest rate (as a decimal percentage), interest rate type, monthly payment amount, and payment due day of month (1–28).
3. IF the submitted outstanding balance is less than or equal to zero, THEN THE Loan_Manager SHALL return a 422 status with a descriptive validation error.
4. IF the submitted annual interest rate is less than zero or greater than 100, THEN THE Loan_Manager SHALL return a 422 status with a descriptive validation error.
5. IF the submitted payment due day is outside the range 1 to 28, THEN THE Loan_Manager SHALL return a 422 status with a descriptive validation error.
6. IF the interest rate type is `floating`, THEN THE Loan_Manager SHALL require at least one Interest_Rate_Period with a start date and annual interest rate.
7. THE Loan_Manager SHALL reject loan creation requests from unauthenticated callers with a 401 status.

---

### Requirement 2: Retrieve Loan List

**User Story:** As a User, I want to see all my loans, so that I can get an overview of my total debt.

#### Acceptance Criteria

1. WHEN a User requests their loan list, THE Loan_Manager SHALL return all Loan records belonging to that User.
2. THE Loan_Manager SHALL include in each list item: loan identifier, institution name, loan number, outstanding balance, interest rate type, current annual interest rate, monthly payment amount, next payment date, and projected Payoff_Date.
3. THE Loan_Manager SHALL return an empty array when the User has no loans.
4. THE Loan_Manager SHALL exclude Loan records belonging to other Users from the response.
5. THE Loan_Manager SHALL reject loan list requests from unauthenticated callers with a 401 status.

---

### Requirement 3: Retrieve Loan Detail

**User Story:** As a User, I want to view the full details of a specific loan, so that I can see the complete repayment schedule.

#### Acceptance Criteria

1. WHEN a User requests a specific Loan by its identifier, THE Loan_Manager SHALL return the full Loan record including all stored fields and the complete Amortisation_Schedule.
2. THE Loan_Manager SHALL compute the Amortisation_Schedule from the current Outstanding_Balance, current interest rate(s), monthly payment amount, and payment due day, projecting entries month by month until the Outstanding_Balance reaches zero.
3. IF the requested Loan does not belong to the requesting User, THEN THE Loan_Manager SHALL return a 404 status.
4. THE Loan_Manager SHALL reject loan detail requests from unauthenticated callers with a 401 status.

---

### Requirement 4: Update Loan Details

**User Story:** As a User, I want to update my loan information, so that I can correct data or reflect changes from my lender.

#### Acceptance Criteria

1. WHEN a User submits a valid loan update request, THE Loan_Manager SHALL persist the updated fields and return the updated Loan record.
2. THE Loan_Manager SHALL apply the same validation rules on update as on creation for any field that is present in the update request.
3. IF the updated Loan does not belong to the requesting User, THEN THE Loan_Manager SHALL return a 404 status.
4. THE Loan_Manager SHALL reject loan update requests from unauthenticated callers with a 401 status.

---

### Requirement 5: Delete a Loan

**User Story:** As a User, I want to delete a loan record, so that I can remove loans I have fully repaid or entered in error.

#### Acceptance Criteria

1. WHEN a User requests deletion of a Loan, THE Loan_Manager SHALL permanently remove the Loan record and all associated Interest_Rate_Periods.
2. IF the Loan to be deleted does not belong to the requesting User, THEN THE Loan_Manager SHALL return a 404 status.
3. THE Loan_Manager SHALL reject loan deletion requests from unauthenticated callers with a 401 status.

---

### Requirement 6: Fixed-Rate Amortisation Calculation

**User Story:** As a User, I want the system to compute my repayment schedule for a fixed-rate loan, so that I know exactly when my loan will be paid off.

#### Acceptance Criteria

1. WHEN the Payment_Calculator computes an Amortisation_Schedule for a fixed-rate Loan, THE Payment_Calculator SHALL apply the same annual interest rate to every projected payment period.
2. THE Payment_Calculator SHALL compute each period's interest component as `(outstanding_balance × annual_rate) / 12`, rounded to the nearest smallest currency unit.
3. THE Payment_Calculator SHALL compute each period's principal component as `monthly_payment − interest_component`.
4. THE Payment_Calculator SHALL set the remaining balance for each period as `previous_balance − principal_component`.
5. WHEN the remaining balance after applying a payment would be less than or equal to zero, THE Payment_Calculator SHALL set the final payment amount to the exact remaining balance plus accrued interest for that period, and mark that period as the payoff period.
6. THE Payment_Calculator SHALL produce an Amortisation_Schedule where the sum of all principal components equals the initial Outstanding_Balance, within a rounding tolerance of 1 smallest currency unit.

---

### Requirement 7: Floating-Rate Amortisation Calculation

**User Story:** As a User, I want the system to compute my repayment schedule for a floating-rate loan using my entered rate periods, so that I can see how rate changes affect my payoff timeline.

#### Acceptance Criteria

1. WHEN the Payment_Calculator computes an Amortisation_Schedule for a floating-rate Loan, THE Payment_Calculator SHALL apply the Interest_Rate_Period whose date range covers each projected payment date.
2. WHEN a projected payment date falls after the end of all defined Interest_Rate_Periods, THE Payment_Calculator SHALL apply the rate from the most recent Interest_Rate_Period.
3. THE Payment_Calculator SHALL recompute the interest component for each period using the applicable rate for that period's payment date.
4. THE Payment_Calculator SHALL produce a valid Amortisation_Schedule for a floating-rate Loan using the same principal and balance rules defined for fixed-rate loans.

---

### Requirement 8: Interest Rate Update and Schedule Recalculation

**User Story:** As a User, I want to update the interest rate on a floating-rate loan, so that my projected payoff timeline reflects the latest rate from my lender.

#### Acceptance Criteria

1. WHEN a User adds or updates an Interest_Rate_Period on a floating-rate Loan, THE Loan_Manager SHALL persist the new Interest_Rate_Period and return the updated Amortisation_Schedule.
2. THE Payment_Calculator SHALL recompute the full Amortisation_Schedule from the current date forward whenever an Interest_Rate_Period is added or modified.
3. IF a User attempts to add an Interest_Rate_Period to a fixed-rate Loan, THEN THE Loan_Manager SHALL return a 422 status with a descriptive error.
4. THE Loan_Manager SHALL reject interest rate update requests from unauthenticated callers with a 401 status.

---

### Requirement 9: Next Payment Date Computation

**User Story:** As a User, I want to see the next payment date for each loan, so that I can plan my cash flow.

#### Acceptance Criteria

1. WHEN the Payment_Calculator determines the next payment date for a Loan, THE Payment_Calculator SHALL return the nearest future calendar date whose day-of-month matches the Loan's payment due day.
2. WHEN today's date is on or after the payment due day in the current month, THE Payment_Calculator SHALL return the payment due day in the following month as the next payment date.
3. WHEN today's date is before the payment due day in the current month, THE Payment_Calculator SHALL return the payment due day in the current month as the next payment date.

---

### Requirement 10: Dashboard Loan Summary

**User Story:** As a User, I want to see a summary of my loans on the dashboard, so that I can quickly understand my total debt position.

#### Acceptance Criteria

1. WHEN a User requests the dashboard, THE Loan_Manager SHALL provide a loans summary containing the total count of active loans and the sum of all Outstanding_Balances across the User's loans.
2. THE Loan_Manager SHALL include each Loan's identifier, institution name, outstanding balance, and next payment date in the dashboard loans summary.
3. WHEN a User has no loans, THE Loan_Manager SHALL return a loans summary with a total count of zero and a total outstanding balance of zero.

---

### Requirement 11: Loans List Page

**User Story:** As a User, I want to see all my loans on a dedicated page, so that I can review my debt at a glance.

#### Acceptance Criteria

1. WHEN a User navigates to the Loans page, THE frontend SHALL fetch the loan list from `GET /loans` using the stored JWT and display the results in a table.
2. THE Loans page SHALL display the following columns for each loan: loan identifier, institution name, interest type (as a badge), outstanding balance, next payment date, and projected payoff date.
3. WHEN the loan list is loading, THE Loans page SHALL display skeleton placeholder rows in place of the table content.
4. WHEN the User has no loans, THE Loans page SHALL display an empty-state message prompting the User to add their first loan.
5. WHEN a User clicks a loan row, THE frontend SHALL navigate to the Loan Detail page for that loan.
6. THE Loans page SHALL display an "Add Loan" button that opens the Add Loan dialog.

---

### Requirement 12: Add Loan Dialog

**User Story:** As a User, I want to add a new loan through a form, so that I can start tracking it immediately.

#### Acceptance Criteria

1. WHEN a User submits the Add Loan form with valid data, THE frontend SHALL call `POST /loans` and, on success, add the new loan to the list without a full page reload.
2. THE Add Loan form SHALL include fields for: institution name, loan identifier, outstanding balance, annual interest rate, interest rate type (fixed/floating), monthly payment amount, and payment due day.
3. WHEN the interest rate type is set to `floating`, THE Add Loan form SHALL reveal an additional section for entering at least one interest rate period (start date and annual rate).
4. THE frontend SHALL validate all required fields client-side before submitting and display inline error messages for any invalid fields.
5. WHEN the API returns a 422 validation error, THE frontend SHALL display the server-side error messages inline next to the relevant fields.
6. WHEN the form is submitted successfully, THE dialog SHALL close and the loans list SHALL refresh to include the new loan.

---

### Requirement 13: Loan Detail Page

**User Story:** As a User, I want to view the full details and repayment schedule of a specific loan, so that I can understand my repayment timeline.

#### Acceptance Criteria

1. WHEN a User navigates to `/loans/:id`, THE frontend SHALL fetch the loan detail from `GET /loans/:id` and display all loan fields and the amortisation schedule.
2. THE Loan Detail page SHALL display a summary section with: institution name, loan identifier, outstanding balance, interest rate, interest type, monthly payment, payment due day, next payment date, and projected payoff date.
3. THE Loan Detail page SHALL display the amortisation schedule in a table with columns: period number, payment date, payment amount, principal, interest, and remaining balance.
4. WHEN the loan detail is loading, THE Loan Detail page SHALL display skeleton placeholders.
5. THE Loan Detail page SHALL provide an "Edit" button that opens the Edit Loan dialog pre-populated with the current loan values.
6. THE Loan Detail page SHALL provide a "Delete" button that prompts the User for confirmation before calling `DELETE /loans/:id`.
7. WHEN a floating-rate loan is displayed, THE Loan Detail page SHALL show the list of interest rate periods and provide controls to add or edit rate periods.

---

### Requirement 14: Edit Loan Dialog

**User Story:** As a User, I want to edit an existing loan's details, so that I can keep my records accurate.

#### Acceptance Criteria

1. WHEN a User submits the Edit Loan form with valid data, THE frontend SHALL call `PATCH /loans/:id` and, on success, update the displayed loan detail without a full page reload.
2. THE Edit Loan form SHALL apply the same validation rules as the Add Loan form.
3. WHEN the API returns a 422 validation error, THE frontend SHALL display the server-side error messages inline.
4. WHEN the form is submitted successfully, THE dialog SHALL close and the loan detail SHALL refresh with the updated values.

---

### Requirement 15: Dashboard Loans Summary

**User Story:** As a User, I want to see a loans summary on the dashboard, so that I can quickly understand my total debt position.

#### Acceptance Criteria

1. WHEN a User views the Dashboard, THE frontend SHALL fetch the loans summary from the backend and display the total outstanding debt in the "Total Debt" summary card.
2. THE Dashboard loans card SHALL navigate to the Loans page when clicked.
3. WHEN the dashboard data is loading, THE frontend SHALL display skeleton placeholders in the summary cards.
