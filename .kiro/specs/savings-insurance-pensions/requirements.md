# Requirements Document

## Introduction

The Savings, Insurance, and Pensions feature extends the personal finance management application with three new tracking domains. Authenticated users can record and monitor savings instruments (Fixed Deposits, Recurring Deposits, and similar), insurance policies (term, health, auto, bike), and pension instruments (EPF, NPS, and similar). The system computes projected maturity values for savings, tracks renewal dates for insurance, and aggregates contribution history for pensions. All three domains are surfaced on the Dashboard alongside the existing Loans summary. This feature covers the backend Rails API only; the React frontend is not yet scaffolded.

---

## Glossary

- **User**: An authenticated account holder identified by phone or email.
- **Savings_Manager**: The Rails API service responsible for creating, reading, updating, and deleting savings instrument records.
- **Insurance_Manager**: The Rails API service responsible for creating, reading, updating, and deleting insurance policy records.
- **Pension_Manager**: The Rails API service responsible for creating, reading, updating, and deleting pension instrument records.
- **Savings_Instrument**: A financial asset record belonging to a User, representing a savings product such as an FD or RD.
- **Savings_Type**: An enumerated value describing the savings product category. Valid values: `fd` (Fixed Deposit), `rd` (Recurring Deposit), `other`.
- **Contribution_Frequency**: An enumerated value describing how often contributions are made. Valid values: `one_time`, `monthly`, `quarterly`, `annually`.
- **Principal_Amount**: The amount deposited or contributed at the start of a savings instrument, stored as an integer in the smallest currency unit (paise).
- **Recurring_Amount**: The periodic contribution amount for recurring savings instruments, stored as an integer in the smallest currency unit (paise).
- **Maturity_Value**: The projected total value of a savings instrument at its maturity date, computed from the principal, interest rate, and tenure.
- **Maturity_Date**: The calendar date on which a savings instrument reaches its term and the Maturity_Value becomes payable.
- **Insurance_Policy**: A financial protection record belonging to a User, representing an insurance contract.
- **Policy_Type**: An enumerated value describing the insurance category. Valid values: `term`, `health`, `auto`, `bike`.
- **Sum_Assured**: The maximum benefit amount payable under an insurance policy, stored as an integer in the smallest currency unit (paise).
- **Premium_Amount**: The periodic payment required to keep an insurance policy active, stored as an integer in the smallest currency unit (paise).
- **Premium_Frequency**: An enumerated value describing how often the premium is paid. Valid values: `monthly`, `quarterly`, `half_yearly`, `annually`.
- **Renewal_Date**: The calendar date on which an insurance policy must be renewed or the next premium is due.
- **Insured_Member**: A person covered under an insurance policy, identified by name and an optional policy-member identifier assigned by the insurer.
- **Pension_Instrument**: A long-term retirement savings record belonging to a User, representing a pension scheme such as EPF or NPS.
- **Pension_Type**: An enumerated value describing the pension scheme category. Valid values: `epf`, `nps`, `other`.
- **Pension_Contribution**: A record of a single contribution event for a pension instrument, capturing the amount, date, and contributor type.
- **Contributor_Type**: An enumerated value describing who made a pension contribution. Valid values: `employee`, `employer`, `self`.
- **Total_Corpus**: The sum of all Pension_Contribution amounts for a given Pension_Instrument, computed at query time.
- **Dashboard**: The aggregated summary view of all financial instruments for a User.
- **Value_Calculator**: The service responsible for computing Maturity_Value projections for savings instruments.

---

## Requirements

### Requirement 1: Create a Savings Instrument

**User Story:** As a User, I want to record a new savings instrument, so that I can track my deposits and projected returns in one place.

#### Acceptance Criteria

1. WHEN a User submits a valid savings instrument creation request, THE Savings_Manager SHALL persist a new Savings_Instrument record associated with that User.
2. THE Savings_Manager SHALL require the following fields on creation: institution name, savings identifier (account or certificate number), savings type, principal amount (integer, smallest currency unit), annual interest rate (decimal percentage), contribution frequency, and start date.
3. THE Savings_Manager SHALL accept the following optional fields on creation: maturity date, recurring amount (required when contribution frequency is not `one_time`), and notes.
4. IF the submitted principal amount is less than or equal to zero, THEN THE Savings_Manager SHALL return a 422 status with a descriptive validation error.
5. IF the submitted annual interest rate is less than zero or greater than 100, THEN THE Savings_Manager SHALL return a 422 status with a descriptive validation error.
6. IF the contribution frequency is not `one_time` and no recurring amount is provided, THEN THE Savings_Manager SHALL return a 422 status with a descriptive validation error.
7. IF the submitted recurring amount is present and less than or equal to zero, THEN THE Savings_Manager SHALL return a 422 status with a descriptive validation error.
8. IF the maturity date is present and is not after the start date, THEN THE Savings_Manager SHALL return a 422 status with a descriptive validation error.
9. THE Savings_Manager SHALL reject savings creation requests from unauthenticated callers with a 401 status.

---

### Requirement 2: Retrieve Savings List

**User Story:** As a User, I want to see all my savings instruments, so that I can get an overview of my total savings.

#### Acceptance Criteria

1. WHEN a User requests their savings list, THE Savings_Manager SHALL return all Savings_Instrument records belonging to that User.
2. THE Savings_Manager SHALL include in each list item: savings identifier, institution name, savings type, principal amount, annual interest rate, contribution frequency, start date, maturity date (if present), and projected Maturity_Value.
3. THE Savings_Manager SHALL return an empty array when the User has no savings instruments.
4. THE Savings_Manager SHALL exclude Savings_Instrument records belonging to other Users from the response.
5. THE Savings_Manager SHALL reject savings list requests from unauthenticated callers with a 401 status.

---

### Requirement 3: Retrieve Savings Instrument Detail

**User Story:** As a User, I want to view the full details of a specific savings instrument, so that I can see its projected growth over time.

#### Acceptance Criteria

1. WHEN a User requests a specific Savings_Instrument by its identifier, THE Savings_Manager SHALL return the full record including all stored fields and the projected Maturity_Value.
2. WHEN the savings type is `rd` or any recurring contribution frequency, THE Savings_Manager SHALL include a projected payment schedule showing each future contribution date and the running total after each contribution.
3. IF the requested Savings_Instrument does not belong to the requesting User, THEN THE Savings_Manager SHALL return a 404 status.
4. THE Savings_Manager SHALL reject savings detail requests from unauthenticated callers with a 401 status.

---

### Requirement 4: Update a Savings Instrument

**User Story:** As a User, I want to update my savings instrument details, so that I can correct data or reflect changes from my institution.

#### Acceptance Criteria

1. WHEN a User submits a valid savings update request, THE Savings_Manager SHALL persist the updated fields and return the updated Savings_Instrument record.
2. THE Savings_Manager SHALL apply the same validation rules on update as on creation for any field that is present in the update request.
3. IF the Savings_Instrument to be updated does not belong to the requesting User, THEN THE Savings_Manager SHALL return a 404 status.
4. THE Savings_Manager SHALL reject savings update requests from unauthenticated callers with a 401 status.

---

### Requirement 5: Delete a Savings Instrument

**User Story:** As a User, I want to delete a savings instrument record, so that I can remove matured or incorrectly entered instruments.

#### Acceptance Criteria

1. WHEN a User requests deletion of a Savings_Instrument, THE Savings_Manager SHALL permanently remove the record.
2. IF the Savings_Instrument to be deleted does not belong to the requesting User, THEN THE Savings_Manager SHALL return a 404 status.
3. THE Savings_Manager SHALL reject savings deletion requests from unauthenticated callers with a 401 status.

---

### Requirement 6: Maturity Value Projection for One-Time Savings

**User Story:** As a User, I want the system to compute the projected maturity value of my Fixed Deposit, so that I know how much I will receive at maturity.

#### Acceptance Criteria

1. WHEN the Value_Calculator computes the Maturity_Value for a one-time savings instrument with a maturity date, THE Value_Calculator SHALL apply the compound interest formula: `principal × (1 + annual_rate / 100 / compounding_frequency) ^ (compounding_frequency × tenure_years)`, where compounding frequency defaults to 4 (quarterly) unless specified.
2. THE Value_Calculator SHALL compute tenure_years as the number of years between the start date and the maturity date, expressed as a decimal.
3. WHEN no maturity date is provided, THE Value_Calculator SHALL return the principal amount as the current value with no projection.
4. THE Value_Calculator SHALL return the Maturity_Value as an integer in the smallest currency unit, rounded to the nearest unit.

---

### Requirement 7: Projected Payment Schedule for Recurring Savings

**User Story:** As a User, I want to see the projected contribution schedule for my Recurring Deposit, so that I know my future payment dates and expected final value.

#### Acceptance Criteria

1. WHEN the Value_Calculator computes the payment schedule for a recurring savings instrument, THE Value_Calculator SHALL generate one entry per contribution period from the next contribution date until the maturity date.
2. THE Value_Calculator SHALL compute each entry's contribution date by advancing from the start date by the contribution frequency interval (monthly → 1 month, quarterly → 3 months, annually → 12 months).
3. THE Value_Calculator SHALL include in each schedule entry: the contribution date, the contribution amount (recurring amount), and the running total of all contributions made up to and including that entry.
4. WHEN no maturity date is provided for a recurring savings instrument, THE Value_Calculator SHALL return an empty schedule.
5. THE Value_Calculator SHALL cap the projected schedule at 600 entries as a safety guard.

---

### Requirement 8: Create an Insurance Policy

**User Story:** As a User, I want to record an insurance policy, so that I can track my coverage and renewal dates in one place.

#### Acceptance Criteria

1. WHEN a User submits a valid insurance policy creation request, THE Insurance_Manager SHALL persist a new Insurance_Policy record associated with that User.
2. THE Insurance_Manager SHALL require the following fields on creation: institution name, policy number, policy type, sum assured (integer, smallest currency unit), premium amount (integer, smallest currency unit), premium frequency, and renewal date.
3. THE Insurance_Manager SHALL accept the following optional fields on creation: policy start date, notes, and one or more Insured_Members (each with a name and an optional insurer-assigned member identifier).
4. IF the submitted sum assured is less than or equal to zero, THEN THE Insurance_Manager SHALL return a 422 status with a descriptive validation error.
5. IF the submitted premium amount is less than or equal to zero, THEN THE Insurance_Manager SHALL return a 422 status with a descriptive validation error.
6. IF the renewal date is in the past relative to the current date, THEN THE Insurance_Manager SHALL return a 422 status with a descriptive validation error.
7. THE Insurance_Manager SHALL reject insurance creation requests from unauthenticated callers with a 401 status.

---

### Requirement 9: Retrieve Insurance Policy List

**User Story:** As a User, I want to see all my insurance policies, so that I can review my coverage at a glance.

#### Acceptance Criteria

1. WHEN a User requests their insurance policy list, THE Insurance_Manager SHALL return all Insurance_Policy records belonging to that User.
2. THE Insurance_Manager SHALL include in each list item: policy number, institution name, policy type, sum assured, premium amount, premium frequency, and renewal date.
3. THE Insurance_Manager SHALL return an empty array when the User has no insurance policies.
4. THE Insurance_Manager SHALL exclude Insurance_Policy records belonging to other Users from the response.
5. THE Insurance_Manager SHALL reject insurance list requests from unauthenticated callers with a 401 status.

---

### Requirement 10: Retrieve Insurance Policy Detail

**User Story:** As a User, I want to view the full details of a specific insurance policy, so that I can see who is covered and what the policy covers.

#### Acceptance Criteria

1. WHEN a User requests a specific Insurance_Policy by its identifier, THE Insurance_Manager SHALL return the full record including all stored fields and the list of Insured_Members.
2. THE Insurance_Manager SHALL include in the detail response: policy number, institution name, policy type, sum assured, premium amount, premium frequency, renewal date, policy start date (if present), notes (if present), and all associated Insured_Members with their names and insurer-assigned member identifiers.
3. IF the requested Insurance_Policy does not belong to the requesting User, THEN THE Insurance_Manager SHALL return a 404 status.
4. THE Insurance_Manager SHALL reject insurance detail requests from unauthenticated callers with a 401 status.

---

### Requirement 11: Update an Insurance Policy

**User Story:** As a User, I want to update my insurance policy details, so that I can reflect renewals, coverage changes, or corrections.

#### Acceptance Criteria

1. WHEN a User submits a valid insurance update request, THE Insurance_Manager SHALL persist the updated fields and return the updated Insurance_Policy record.
2. THE Insurance_Manager SHALL apply the same validation rules on update as on creation for any field that is present in the update request.
3. IF the Insurance_Policy to be updated does not belong to the requesting User, THEN THE Insurance_Manager SHALL return a 404 status.
4. THE Insurance_Manager SHALL reject insurance update requests from unauthenticated callers with a 401 status.

---

### Requirement 12: Delete an Insurance Policy

**User Story:** As a User, I want to delete an insurance policy record, so that I can remove expired or incorrectly entered policies.

#### Acceptance Criteria

1. WHEN a User requests deletion of an Insurance_Policy, THE Insurance_Manager SHALL permanently remove the record and all associated Insured_Members.
2. IF the Insurance_Policy to be deleted does not belong to the requesting User, THEN THE Insurance_Manager SHALL return a 404 status.
3. THE Insurance_Manager SHALL reject insurance deletion requests from unauthenticated callers with a 401 status.

---

### Requirement 13: Manage Insured Members

**User Story:** As a User, I want to add, update, and remove people covered under an insurance policy, so that I can keep the coverage details accurate.

#### Acceptance Criteria

1. WHEN a User adds an Insured_Member to an Insurance_Policy, THE Insurance_Manager SHALL persist the member record associated with that policy and return the updated policy detail.
2. THE Insurance_Manager SHALL require a name for each Insured_Member; the insurer-assigned member identifier is optional.
3. WHEN a User updates an Insured_Member, THE Insurance_Manager SHALL persist the updated member fields and return the updated policy detail.
4. WHEN a User removes an Insured_Member, THE Insurance_Manager SHALL permanently delete the member record and return the updated policy detail.
5. IF the Insurance_Policy for the member operation does not belong to the requesting User, THEN THE Insurance_Manager SHALL return a 404 status.
6. THE Insurance_Manager SHALL reject insured member management requests from unauthenticated callers with a 401 status.

---

### Requirement 14: Create a Pension Instrument

**User Story:** As a User, I want to record a pension instrument, so that I can track my retirement savings in one place.

#### Acceptance Criteria

1. WHEN a User submits a valid pension instrument creation request, THE Pension_Manager SHALL persist a new Pension_Instrument record associated with that User.
2. THE Pension_Manager SHALL require the following fields on creation: institution name, pension account identifier, and pension type.
3. THE Pension_Manager SHALL accept the following optional fields on creation: monthly contribution amount (integer, smallest currency unit), contribution start date, maturity date, and notes.
4. IF the submitted monthly contribution amount is present and less than or equal to zero, THEN THE Pension_Manager SHALL return a 422 status with a descriptive validation error.
5. IF the maturity date is present and is not after the contribution start date, THEN THE Pension_Manager SHALL return a 422 status with a descriptive validation error.
6. THE Pension_Manager SHALL reject pension creation requests from unauthenticated callers with a 401 status.

---

### Requirement 15: Retrieve Pension Instrument List

**User Story:** As a User, I want to see all my pension instruments, so that I can review my retirement savings at a glance.

#### Acceptance Criteria

1. WHEN a User requests their pension list, THE Pension_Manager SHALL return all Pension_Instrument records belonging to that User.
2. THE Pension_Manager SHALL include in each list item: pension account identifier, institution name, pension type, monthly contribution amount (if present), contribution start date (if present), maturity date (if present), and Total_Corpus.
3. THE Pension_Manager SHALL return an empty array when the User has no pension instruments.
4. THE Pension_Manager SHALL exclude Pension_Instrument records belonging to other Users from the response.
5. THE Pension_Manager SHALL reject pension list requests from unauthenticated callers with a 401 status.

---

### Requirement 16: Retrieve Pension Instrument Detail

**User Story:** As a User, I want to view the full details of a specific pension instrument, so that I can see my complete contribution history.

#### Acceptance Criteria

1. WHEN a User requests a specific Pension_Instrument by its identifier, THE Pension_Manager SHALL return the full record including all stored fields, the Total_Corpus, and the complete list of Pension_Contributions ordered by contribution date descending.
2. THE Pension_Manager SHALL include in each Pension_Contribution entry: contribution date, amount (integer, smallest currency unit), and contributor type.
3. IF the requested Pension_Instrument does not belong to the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
4. THE Pension_Manager SHALL reject pension detail requests from unauthenticated callers with a 401 status.

---

### Requirement 17: Update a Pension Instrument

**User Story:** As a User, I want to update my pension instrument details, so that I can correct data or reflect changes from my provider.

#### Acceptance Criteria

1. WHEN a User submits a valid pension update request, THE Pension_Manager SHALL persist the updated fields and return the updated Pension_Instrument record.
2. THE Pension_Manager SHALL apply the same validation rules on update as on creation for any field that is present in the update request.
3. IF the Pension_Instrument to be updated does not belong to the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
4. THE Pension_Manager SHALL reject pension update requests from unauthenticated callers with a 401 status.

---

### Requirement 18: Delete a Pension Instrument

**User Story:** As a User, I want to delete a pension instrument record, so that I can remove instruments entered in error.

#### Acceptance Criteria

1. WHEN a User requests deletion of a Pension_Instrument, THE Pension_Manager SHALL permanently remove the record and all associated Pension_Contributions.
2. IF the Pension_Instrument to be deleted does not belong to the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
3. THE Pension_Manager SHALL reject pension deletion requests from unauthenticated callers with a 401 status.

---

### Requirement 19: Record a Pension Contribution

**User Story:** As a User, I want to log individual contribution events for a pension instrument, so that I can maintain an accurate contribution history.

#### Acceptance Criteria

1. WHEN a User submits a valid contribution record request, THE Pension_Manager SHALL persist a new Pension_Contribution associated with the specified Pension_Instrument and return the updated instrument detail.
2. THE Pension_Manager SHALL require the following fields for each contribution: contribution date, amount (integer, smallest currency unit, greater than zero), and contributor type.
3. IF the submitted contribution amount is less than or equal to zero, THEN THE Pension_Manager SHALL return a 422 status with a descriptive validation error.
4. IF the Pension_Instrument for the contribution does not belong to the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
5. THE Pension_Manager SHALL reject contribution recording requests from unauthenticated callers with a 401 status.

---

### Requirement 20: Update a Pension Contribution

**User Story:** As a User, I want to correct a previously recorded pension contribution, so that I can fix data entry errors.

#### Acceptance Criteria

1. WHEN a User submits a valid contribution update request, THE Pension_Manager SHALL persist the updated contribution fields and return the updated instrument detail.
2. THE Pension_Manager SHALL apply the same validation rules on update as on creation for any field that is present in the update request.
3. IF the Pension_Contribution to be updated does not belong to a Pension_Instrument owned by the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
4. THE Pension_Manager SHALL reject contribution update requests from unauthenticated callers with a 401 status.

---

### Requirement 21: Delete a Pension Contribution

**User Story:** As a User, I want to remove an incorrectly recorded pension contribution, so that my contribution history remains accurate.

#### Acceptance Criteria

1. WHEN a User requests deletion of a Pension_Contribution, THE Pension_Manager SHALL permanently remove the contribution record and return the updated instrument detail.
2. IF the Pension_Contribution to be deleted does not belong to a Pension_Instrument owned by the requesting User, THEN THE Pension_Manager SHALL return a 404 status.
3. THE Pension_Manager SHALL reject contribution deletion requests from unauthenticated callers with a 401 status.

---

### Requirement 22: Dashboard Summary — Savings

**User Story:** As a User, I want to see a savings summary on the dashboard, so that I can quickly understand my total savings position.

#### Acceptance Criteria

1. WHEN a User requests the dashboard, THE Savings_Manager SHALL provide a savings summary containing the total count of savings instruments and the sum of all principal amounts across the User's savings instruments.
2. THE Savings_Manager SHALL include each Savings_Instrument's identifier, institution name, savings type, principal amount, and maturity date (if present) in the dashboard savings summary.
3. WHEN a User has no savings instruments, THE Savings_Manager SHALL return a savings summary with a total count of zero and a total principal of zero.

---

### Requirement 23: Dashboard Summary — Insurance

**User Story:** As a User, I want to see an insurance summary on the dashboard, so that I can quickly review my active policies and upcoming renewals.

#### Acceptance Criteria

1. WHEN a User requests the dashboard, THE Insurance_Manager SHALL provide an insurance summary containing the total count of insurance policies and the list of policies with their renewal dates.
2. THE Insurance_Manager SHALL include each Insurance_Policy's policy number, institution name, policy type, sum assured, and renewal date in the dashboard insurance summary.
3. WHEN a User has no insurance policies, THE Insurance_Manager SHALL return an insurance summary with a total count of zero and an empty list.

---

### Requirement 24: Dashboard Summary — Pensions

**User Story:** As a User, I want to see a pension summary on the dashboard, so that I can quickly understand my total retirement savings.

#### Acceptance Criteria

1. WHEN a User requests the dashboard, THE Pension_Manager SHALL provide a pension summary containing the total count of pension instruments and the aggregate Total_Corpus across all of the User's pension instruments.
2. THE Pension_Manager SHALL include each Pension_Instrument's account identifier, institution name, pension type, and Total_Corpus in the dashboard pension summary.
3. WHEN a User has no pension instruments, THE Pension_Manager SHALL return a pension summary with a total count of zero and a total corpus of zero.

---

### Requirement 25: Data Isolation Across Users

**User Story:** As a User, I want my financial data to be private, so that other users cannot access my savings, insurance, or pension records.

#### Acceptance Criteria

1. THE Savings_Manager SHALL ensure that a Savings_Instrument created by one User is never returned in another User's list, detail, update, or delete responses.
2. THE Insurance_Manager SHALL ensure that an Insurance_Policy created by one User is never returned in another User's list, detail, update, or delete responses.
3. THE Pension_Manager SHALL ensure that a Pension_Instrument created by one User is never returned in another User's list, detail, update, or delete responses.
4. WHEN a User attempts to access a record belonging to another User, THE respective Manager SHALL return a 404 status without revealing whether the record exists.
