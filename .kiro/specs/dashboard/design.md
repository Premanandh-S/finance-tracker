# Design Document — Dashboard

## Overview

The Dashboard feature provides a single aggregated view of a user's entire financial portfolio. It consists of three layers:

1. **Backend service** — `Dashboard::DashboardAggregator`, a new PORO that delegates to each domain's existing `dashboard_summary` method and assembles the results into one hash.
2. **Backend controller** — `DashboardController`, a thin Rails controller that authenticates the request and renders the aggregator's output.
3. **Frontend page** — A React page that fetches `GET /dashboard`, renders four summary cards (Total Savings, Total Debt, Insurance, Pensions), shows item lists under each card, highlights pending loan payments and expiring insurance policies, provides "Add" buttons for each domain, handles loading and error states, and navigates to domain pages on click.

Additionally, the OTP verify flow redirects to the Dashboard on success (frontend-only change), and two backend domain summary methods are extended: `Loans::PaymentCalculator.dashboard_summary` gains `loan_identifier` on each item and a top-level `pending_payments` array; `Insurance::InsuranceManager.dashboard_summary` gains a top-level `expiring_soon` array.

All monetary values are integers in the smallest currency unit (paise), consistent with the rest of the application.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  React Frontend                                                 │
│                                                                 │
│  OtpVerifyPage                                                  │
│  └── on success → navigate("/dashboard")                        │
│                                                                 │
│  DashboardPage                                                  │
│  ├── useDashboard (hook — fetch + state)                        │
│  ├── SummaryCard × 4  (Savings / Loans / Insurance / Pensions)  │
│  │   ├── AddButton → navigate to create page                    │
│  │   └── DomainItemList                                         │
│  │       ├── PendingPaymentBadge (loans with due-this-month)    │
│  │       └── ExpiringSoonBadge   (insurance expiring ≤ 2 months)│
│  ├── LoadingSkeleton (while loading)                            │
│  └── ErrorBanner + Retry (on failure)                           │
└────────────────────────────┬────────────────────────────────────┘
                             │ GET /dashboard
                             │ Authorization: Bearer <jwt>
┌────────────────────────────▼────────────────────────────────────┐
│  Rails API                                                      │
│                                                                 │
│  DashboardController#show                                       │
│  └── Dashboard::DashboardAggregator.call(user:)                 │
│      ├── Savings::SavingsManager.dashboard_summary(user)        │
│      ├── Loans::PaymentCalculator.dashboard_summary(user)       │  ← adds loan_identifier + pending_payments
│      ├── Insurance::InsuranceManager.dashboard_summary(user)    │  ← adds expiring_soon
│      └── Pensions::PensionManager.dashboard_summary(user)       │
└─────────────────────────────────────────────────────────────────┘
```

The aggregator is intentionally thin — it owns no query logic. Each domain manager already encapsulates its own scoping and computation. The aggregator's only responsibility is to call all four and merge the results under the correct top-level keys.

---

## Components and Interfaces

### Backend

#### Route

```ruby
# backend/config/routes.rb
get "dashboard", to: "dashboard#show"
```

#### `DashboardController`

- File: `backend/app/controllers/dashboard_controller.rb`
- Inherits from `ApplicationController`
- Single action: `show`
- `before_action :authenticate_user!`
- Delegates entirely to `Dashboard::DashboardAggregator.call(user: current_user)`
- Renders the result as JSON with status 200

#### `Dashboard::DashboardAggregator`

- File: `backend/app/services/dashboard/dashboard_aggregator.rb`
- Module: `Dashboard`, class: `DashboardAggregator`
- Single public class method: `self.call(user:)`
- Calls all four domain summary methods and returns:

```ruby
{
  savings:   Savings::SavingsManager.dashboard_summary(user),
  loans:     Loans::PaymentCalculator.dashboard_summary(user),
  insurance: Insurance::InsuranceManager.dashboard_summary(user),
  pensions:  Pensions::PensionManager.dashboard_summary(user)
}
```

> **Note on loans:** `Loans::LoanManager` does not have a `dashboard_summary` method. That method already exists on `Loans::PaymentCalculator` (which owns all loan computation). The aggregator delegates to `Loans::PaymentCalculator.dashboard_summary(user)` directly, consistent with how `LoanManager` itself delegates computation to `PaymentCalculator`.

#### `Loans::PaymentCalculator.dashboard_summary` — Extended

The existing method is updated to:

1. Add `loan_identifier` to each item in the `items` array.
2. Add a top-level `pending_payments` array — loans whose `next_payment_date` falls within the current calendar month (i.e. `next_payment_date.year == Date.current.year && next_payment_date.month == Date.current.month`).

Each entry in `pending_payments` includes: `id`, `institution_name`, `loan_identifier`, `outstanding_balance`, `monthly_payment`, `next_payment_date`.

```ruby
# Updated return shape
{
  total_count:               loans.size,
  total_outstanding_balance: loans.sum(&:outstanding_balance),
  items: loans.map do |loan|
    {
      id:                  loan.id,
      institution_name:    loan.institution_name,
      loan_identifier:     loan.loan_identifier,          # NEW
      outstanding_balance: loan.outstanding_balance,
      next_payment_date:   next_payment_date(loan)
    }
  end,
  pending_payments: loans                                  # NEW
    .select { |loan| within_current_month?(next_payment_date(loan)) }
    .map do |loan|
      {
        id:                  loan.id,
        institution_name:    loan.institution_name,
        loan_identifier:     loan.loan_identifier,
        outstanding_balance: loan.outstanding_balance,
        monthly_payment:     loan.monthly_payment,
        next_payment_date:   next_payment_date(loan)
      }
    end
}
```

Where `within_current_month?(date)` returns true when `date.year == Date.current.year && date.month == Date.current.month`.

#### `Insurance::InsuranceManager.dashboard_summary` — Extended

The existing method is updated to add a top-level `expiring_soon` array — policies whose `renewal_date` falls within the current calendar month or the next calendar month.

Each entry in `expiring_soon` includes: `id`, `institution_name`, `policy_number`, `policy_type`, `renewal_date`.

```ruby
# Updated return shape
{
  total_count: policies.size,
  items: policies.map { |p| { id: p.id, institution_name: p.institution_name,
                               policy_number: p.policy_number, policy_type: p.policy_type,
                               sum_assured: p.sum_assured, renewal_date: p.renewal_date } },
  expiring_soon: policies                                  # NEW
    .select { |p| within_two_months?(p.renewal_date) }
    .map do |p|
      {
        id:               p.id,
        institution_name: p.institution_name,
        policy_number:    p.policy_number,
        policy_type:      p.policy_type,
        renewal_date:     p.renewal_date
      }
    end
}
```

Where `within_two_months?(date)` returns true when the date falls in the current calendar month or the next calendar month.

#### `Loans::LoanManager.dashboard_summary` — Not needed

The `dashboard_summary` method for loans already exists at `Loans::PaymentCalculator.dashboard_summary(user)`. No new method needs to be added to `LoanManager`. The aggregator calls `PaymentCalculator` directly.

### Frontend

#### OTP Verify — Post-Success Redirect

The existing OTP verify page/component is updated so that on a successful `POST /auth/otp/verify` response (200 with a JWT), the frontend:

1. Stores the JWT (same as the password login flow).
2. Navigates to `/dashboard` using the router's `navigate` function.

No backend changes are required. This is a purely frontend routing concern.

#### Component Tree

```
DashboardPage
├── useDashboard()                  — custom hook: fetch, loading, error, retry
├── <LoadingSkeleton />             — shown while loading === true
├── <ErrorBanner onRetry={retry} /> — shown when error !== null
└── <DashboardContent data={data} />
    ├── <SummaryCard domain="savings"   summary={data.savings}   />
    │   ├── <AddButton navigateTo="/savings/new" label="Add Savings" />
    │   └── <DomainItemList items={data.savings.items} columns={...} />
    ├── <SummaryCard domain="loans"     summary={data.loans}     />
    │   ├── <AddButton navigateTo="/loans/new" label="Add Loan" />
    │   ├── <PendingPaymentsAlert payments={data.loans.pending_payments} />
    │   └── <DomainItemList items={data.loans.items} columns={...} />
    │       └── "Due this month" badge on items whose id is in pending_payments
    ├── <SummaryCard domain="insurance" summary={data.insurance} />
    │   ├── <AddButton navigateTo="/insurance/new" label="Add Insurance" />
    │   ├── <ExpiringSoonAlert policies={data.insurance.expiring_soon} />
    │   └── <DomainItemList items={data.insurance.items} columns={...} />
    │       └── "Expiring soon" badge on items whose id is in expiring_soon
    └── <SummaryCard domain="pensions"  summary={data.pensions}  />
        ├── <AddButton navigateTo="/pensions/new" label="Add Pension" />
        └── <DomainItemList items={data.pensions.items} columns={...} />
```

#### `useDashboard` Hook

```typescript
interface DashboardState {
  data: DashboardPayload | null;
  loading: boolean;
  error: string | null;
}

function useDashboard(): DashboardState & { retry: () => void }
```

- Calls `GET /dashboard` with the stored JWT on mount and on `retry()`
- Sets `loading: true` before the request, `loading: false` after
- On success: sets `data`, clears `error`
- On failure: sets `error` message, clears `data`

#### `SummaryCard` Props

```typescript
interface SummaryCardProps {
  domain: "savings" | "loans" | "insurance" | "pensions";
  summary: SavingsSummary | LoansSummary | InsuranceSummary | PensionsSummary;
  navigateTo: string;   // route path for the domain page
  addPath: string;      // route path for the create-new page
}
```

- Renders the headline metric (see Data Models below)
- Wraps the entire card in a clickable element that navigates to `navigateTo`
- Renders an `<AddButton>` linking to `addPath`
- Renders `<DomainItemList>` below the headline

#### `AddButton` Props

```typescript
interface AddButtonProps {
  navigateTo: string;  // route path for the create-new page
  label: string;       // accessible label, e.g. "Add Loan"
}
```

- Renders a "+" or "Add" button/link
- Navigates to `navigateTo` on click
- Must not trigger the parent card's navigation handler

#### `DomainItemList` Props

```typescript
interface DomainItemListProps {
  items: DomainItem[];
  columns: ColumnDef[];
  onItemClick: (item: DomainItem) => void;
  emptyMessage: string;
  alertIds?: number[];  // IDs of items that should show an alert badge
  alertLabel?: string;  // Badge text, e.g. "Due this month" or "Expiring soon"
}
```

- Renders a list of items with the specified columns
- Each item row is clickable and calls `onItemClick`
- When `items` is empty, renders `emptyMessage`
- When `alertIds` is provided, items whose `id` is in `alertIds` render the `alertLabel` badge

#### Navigation Targets

| Card / List | Navigates to | Add button navigates to |
|---|---|---|
| Total Savings / savings items | `/savings` | `/savings/new` |
| Total Debt / loans items | `/loans` | `/loans/new` |
| Insurance / insurance items | `/insurance` | `/insurance/new` |
| Pensions / pensions items | `/pensions` | `/pensions/new` |

---

## Data Models

### API Response Shape

`GET /dashboard` returns:

```json
{
  "savings": {
    "total_count": 3,
    "total_principal": 500000000,
    "items": [
      {
        "id": 1,
        "institution_name": "SBI",
        "savings_identifier": "FD-2024-001",
        "savings_type": "fd",
        "principal_amount": 200000000,
        "maturity_date": "2026-01-15"
      }
    ]
  },
  "loans": {
    "total_count": 2,
    "total_outstanding_balance": 250000000,
    "items": [
      {
        "id": 1,
        "institution_name": "HDFC Bank",
        "loan_identifier": "HL-2024-001",
        "outstanding_balance": 150000000,
        "next_payment_date": "2025-08-05"
      }
    ],
    "pending_payments": [
      {
        "id": 1,
        "institution_name": "HDFC Bank",
        "loan_identifier": "HL-2024-001",
        "outstanding_balance": 150000000,
        "monthly_payment": 1500000,
        "next_payment_date": "2025-08-05"
      }
    ]
  },
  "insurance": {
    "total_count": 1,
    "items": [
      {
        "id": 1,
        "institution_name": "LIC",
        "policy_number": "POL-001",
        "policy_type": "term",
        "sum_assured": 10000000000,
        "renewal_date": "2026-03-01"
      }
    ],
    "expiring_soon": [
      {
        "id": 2,
        "institution_name": "Star Health",
        "policy_number": "POL-002",
        "policy_type": "health",
        "renewal_date": "2025-09-15"
      }
    ]
  },
  "pensions": {
    "total_count": 1,
    "total_corpus": 800000000,
    "items": [
      {
        "id": 1,
        "institution_name": "EPFO",
        "pension_identifier": "EPF-2024-001",
        "pension_type": "epf",
        "total_corpus": 800000000
      }
    ]
  }
}
```

### Frontend TypeScript Types

```typescript
interface SavingsItem {
  id: number;
  institution_name: string;
  savings_identifier: string;
  savings_type: string;
  principal_amount: number;
  maturity_date: string;
}

interface SavingsSummary {
  total_count: number;
  total_principal: number;
  items: SavingsItem[];
}

interface LoanItem {
  id: number;
  institution_name: string;
  loan_identifier: string;
  outstanding_balance: number;
  next_payment_date: string;
}

interface PendingPaymentItem {
  id: number;
  institution_name: string;
  loan_identifier: string;
  outstanding_balance: number;
  monthly_payment: number;
  next_payment_date: string;
}

interface LoansSummary {
  total_count: number;
  total_outstanding_balance: number;
  items: LoanItem[];
  pending_payments: PendingPaymentItem[];
}

interface InsuranceItem {
  id: number;
  institution_name: string;
  policy_number: string;
  policy_type: string;
  sum_assured: number;
  renewal_date: string;
}

interface ExpiringSoonItem {
  id: number;
  institution_name: string;
  policy_number: string;
  policy_type: string;
  renewal_date: string;
}

interface InsuranceSummary {
  total_count: number;
  items: InsuranceItem[];
  expiring_soon: ExpiringSoonItem[];
}

interface PensionItem {
  id: number;
  institution_name: string;
  pension_identifier: string;
  pension_type: string;
  total_corpus: number;
}

interface PensionsSummary {
  total_count: number;
  total_corpus: number;
  items: PensionItem[];
}

interface DashboardPayload {
  savings: SavingsSummary;
  loans: LoansSummary;
  insurance: InsuranceSummary;
  pensions: PensionsSummary;
}
```

### Summary Card Headline Metrics

| Card | Metric displayed | Source field |
|---|---|---|
| Total Savings | `total_principal` formatted as currency | `data.savings.total_principal` |
| Total Debt | `total_outstanding_balance` formatted as currency | `data.loans.total_outstanding_balance` |
| Insurance | `total_count` + "policies" | `data.insurance.total_count` |
| Pensions | `total_corpus` formatted as currency | `data.pensions.total_corpus` |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Aggregated response always contains all four domain keys

*For any* authenticated user, calling `Dashboard::DashboardAggregator.call(user:)` SHALL return a hash containing exactly the keys `:savings`, `:loans`, `:insurance`, and `:pensions`, regardless of how many instruments the user has in each domain.

**Validates: Requirements 1.1, 1.8**

---

### Property 2: Savings summary shape is always correct

*For any* user with any number of savings instruments, the `:savings` section of the aggregated response SHALL contain `:total_count` (a non-negative integer), `:total_principal` (a non-negative integer), and `:items` (an array), and each item in `:items` SHALL contain the keys `:id`, `:institution_name`, `:savings_identifier`, `:savings_type`, `:principal_amount`, and `:maturity_date`.

**Validates: Requirements 2.1, 2.2**

---

### Property 3: Loans summary shape is always correct

*For any* user with any number of loans, the `:loans` section of the aggregated response SHALL contain `:total_count` (a non-negative integer), `:total_outstanding_balance` (a non-negative integer), `:items` (an array), and `:pending_payments` (an array), and each item in `:items` SHALL contain the keys `:id`, `:institution_name`, `:loan_identifier`, `:outstanding_balance`, and `:next_payment_date`.

**Validates: Requirements 3.1, 3.2, 12.1, 12.3**

---

### Property 4: Insurance summary shape is always correct

*For any* user with any number of insurance policies, the `:insurance` section of the aggregated response SHALL contain `:total_count` (a non-negative integer), `:items` (an array), and `:expiring_soon` (an array), and each item in `:items` SHALL contain the keys `:id`, `:institution_name`, `:policy_number`, `:policy_type`, `:sum_assured`, and `:renewal_date`.

**Validates: Requirements 4.1, 4.2, 13.1**

---

### Property 5: Pensions summary shape is always correct

*For any* user with any number of pension instruments, the `:pensions` section of the aggregated response SHALL contain `:total_count` (a non-negative integer), `:total_corpus` (a non-negative integer), and `:items` (an array), and each item in `:items` SHALL contain the keys `:id`, `:institution_name`, `:pension_identifier`, `:pension_type`, and `:total_corpus`.

**Validates: Requirements 5.1, 5.2**

---

### Property 6: Pension item total_corpus equals sum of contributions

*For any* pension instrument with any set of contribution records, the `total_corpus` value in that instrument's dashboard item SHALL equal the arithmetic sum of all associated `PensionContribution#amount` values.

**Validates: Requirements 5.5**

---

### Property 7: Dashboard data is scoped to the requesting user

*For any* two distinct users, each with instruments in any or all of the four domains, calling `Dashboard::DashboardAggregator.call(user: user_a)` SHALL return only instruments belonging to `user_a` across all four sections, and calling it for `user_b` SHALL return only instruments belonging to `user_b` — with no cross-contamination between users.

**Validates: Requirements 2.4, 3.4, 4.4, 5.4, 6.1, 6.2**

---

### Property 8: pending_payments contains exactly the loans due this month

*For any* user with any set of loans, the `pending_payments` array in the Loans_Summary SHALL contain exactly those loans whose `next_payment_date` falls within the current calendar month — no more, no fewer. A loan whose `next_payment_date` is in a different month SHALL NOT appear in `pending_payments`.

**Validates: Requirements 12.1, 12.4, 12.6**

---

### Property 9: pending_payments entries have the correct shape

*For any* loan that appears in `pending_payments`, its entry SHALL contain exactly the keys `:id`, `:institution_name`, `:loan_identifier`, `:outstanding_balance`, `:monthly_payment`, and `:next_payment_date`, with `:outstanding_balance` and `:monthly_payment` as non-negative integers.

**Validates: Requirements 12.2**

---

### Property 10: expiring_soon contains exactly the policies renewing within two months

*For any* user with any set of insurance policies, the `expiring_soon` array in the Insurance_Summary SHALL contain exactly those policies whose `renewal_date` falls within the current calendar month or the next calendar month — no more, no fewer. A policy whose `renewal_date` is outside that window SHALL NOT appear in `expiring_soon`.

**Validates: Requirements 13.1, 13.3, 13.5**

---

### Property 11: expiring_soon entries have the correct shape

*For any* policy that appears in `expiring_soon`, its entry SHALL contain exactly the keys `:id`, `:institution_name`, `:policy_number`, `:policy_type`, and `:renewal_date`.

**Validates: Requirements 13.2**

---

## Error Handling

### Backend

The `DashboardController#show` action has no domain-specific error paths — the aggregator delegates to methods that are already scoped to the user and return empty collections when no data exists. The only error surface is authentication:

| Condition | Response |
|---|---|
| Missing or malformed JWT | 401 `token_invalid` (handled by `ApplicationController#authenticate_user!`) |
| Expired JWT | 401 `token_expired` |
| Revoked JWT | 401 `token_invalid` |

No 404 or 422 responses are possible from this endpoint — an authenticated user with no instruments receives a valid 200 response with zero counts and empty arrays.

### Frontend

| Condition | Behaviour |
|---|---|
| `GET /dashboard` returns 401 | Redirect to login page (handled by the global API client's auth interceptor) |
| `GET /dashboard` returns any other error | Show `ErrorBanner` with a human-readable message and a "Retry" button |
| Network timeout / offline | Show `ErrorBanner` with a retry action |
| Data loading | Show `LoadingSkeleton` in place of all four cards |
| Domain has zero items | Show per-domain empty-state message within that section |

The retry action re-invokes the `useDashboard` hook's fetch function, resetting `loading` to `true` and clearing the previous error.

---

## Testing Strategy

> **Note:** Per project instructions, no test cases are to be written for this feature.

The testing strategy below documents the intended approach for reference.

### Backend

**Unit tests** (example-based, `RSpec`):
- `DashboardController#show` — authenticated request returns 200 with correct structure; unauthenticated request returns 401.
- `Dashboard::DashboardAggregator.call` — verifies delegation to all four domain summary methods using `instance_double` stubs; verifies the assembled hash has the correct top-level keys.
- `Loans::PaymentCalculator.dashboard_summary` — verifies `loan_identifier` is present in items; verifies `pending_payments` contains only loans due this month.
- `Insurance::InsuranceManager.dashboard_summary` — verifies `expiring_soon` contains only policies renewing within two months.

**Property-based tests** (`RSpec` + a property-based testing library such as `rantly` or `propcheck`):
- Each of the eleven correctness properties above maps to one property-based test.
- Minimum 100 iterations per property test.
- Tag format: `Feature: dashboard, Property N: <property_text>`

### Frontend

**Unit tests** (example-based, `React Testing Library` + `Jest`/`Vitest`):
- `useDashboard` hook — loading state, success state, error state, retry behaviour (mock `fetch`).
- `SummaryCard` — renders correct headline metric for each domain; click navigates to correct route; `AddButton` navigates to correct create route.
- `AddButton` — click navigates to the correct create path; does not trigger parent card navigation.
- `DomainItemList` — renders items with correct columns; renders empty-state message when items is empty; renders alert badge on items whose id is in `alertIds`.
- `ErrorBanner` — renders message and calls `onRetry` when button is clicked.
- `LoadingSkeleton` — renders four skeleton cards.

**Integration tests** (example-based, `React Testing Library`):
- `DashboardPage` — full render with mocked API; verifies all four cards appear with correct data; verifies navigation on card click; verifies skeleton during load; verifies error banner on failure; verifies "Due this month" badge on pending loans; verifies "Expiring soon" badge on expiring policies.
- OTP verify flow — verifies redirect to `/dashboard` on successful OTP verification.
