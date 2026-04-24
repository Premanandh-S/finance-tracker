# Design Document: Shadcn UI Theme

## Overview

This document describes the technical design for scaffolding the React frontend and applying a consistent Shadcn UI design system across the personal finance management app. The frontend does not yet exist; it will be created from scratch under `frontend/` at the repository root.

The design covers:
- Vite + React + TypeScript project initialisation
- Tailwind CSS and Shadcn UI configuration
- CSS variable-based theming with dark mode and localStorage persistence
- Shared authenticated layout (sidebar on desktop, hamburger drawer on mobile)
- Page-level component structure for Auth, Dashboard, Loans, Savings, Insurance, and Pensions
- Shared `PageLayout` and `FormField` components for future-page consistency
- A design-system guide document

The frontend communicates with the existing Rails 7 API backend over HTTP. All data fetching is out of scope for this spec; pages render with mock/skeleton states where real data would appear.

---

## Architecture

### High-Level Structure

```
frontend/
├── public/
├── src/
│   ├── components/
│   │   ├── ui/                  # Shadcn UI generated components (Button, Card, …)
│   │   ├── layout/
│   │   │   ├── AppLayout.tsx    # Authenticated shell (sidebar + header)
│   │   │   ├── Sidebar.tsx      # Desktop sidebar nav
│   │   │   ├── MobileNav.tsx    # Mobile hamburger + Sheet drawer
│   │   │   └── ThemeToggle.tsx  # Light/dark toggle button
│   │   └── shared/
│   │       ├── PageLayout.tsx   # Exported PageLayout wrapper
│   │       └── FormField.tsx    # Exported FormField wrapper
│   ├── pages/
│   │   ├── auth/
│   │   │   ├── LoginPage.tsx
│   │   │   ├── RegisterPage.tsx
│   │   │   ├── OtpVerifyPage.tsx
│   │   │   └── PasswordResetPage.tsx
│   │   ├── DashboardPage.tsx
│   │   ├── LoansPage.tsx
│   │   ├── SavingsPage.tsx
│   │   ├── InsurancePage.tsx
│   │   └── PensionsPage.tsx
│   ├── hooks/
│   │   └── useTheme.ts          # Theme state + localStorage persistence
│   ├── lib/
│   │   └── utils.ts             # Shadcn UI cn() utility
│   ├── globals.css              # CSS variable tokens + Tailwind directives
│   ├── App.tsx                  # Router root
│   └── main.tsx                 # Vite entry point
├── docs/
│   └── design-system.md         # Component usage guide
├── components.json              # Shadcn UI config
├── tailwind.config.js
├── postcss.config.js
├── tsconfig.json
└── vite.config.ts
```

### Routing

React Router v6 is used for client-side navigation. Routes are split into two groups:

- **Public routes** (no layout shell): `/login`, `/register`, `/verify-otp`, `/reset-password`
- **Protected routes** (wrapped in `AppLayout`): `/`, `/loans`, `/savings`, `/insurance`, `/pensions`

```
/                  → DashboardPage   (protected)
/loans             → LoansPage       (protected)
/savings           → SavingsPage     (protected)
/insurance         → InsurancePage   (protected)
/pensions          → PensionsPage    (protected)
/login             → LoginPage       (public)
/register          → RegisterPage    (public)
/verify-otp        → OtpVerifyPage   (public)
/reset-password    → PasswordResetPage (public)
```

A `ProtectedRoute` wrapper component checks for an auth token in localStorage and redirects to `/login` if absent.

### Theme Architecture

Theme state is managed by a `useTheme` hook that:
1. Reads the stored preference from `localStorage` on mount
2. Applies or removes the `.dark` class on `<html>`
3. Persists changes back to `localStorage`

Shadcn UI components read CSS variables from `:root` (light) or `.dark` (dark), so toggling the class is the only runtime change needed.

```
useTheme hook
  ├── reads localStorage("theme") on mount
  ├── applies .dark class to document.documentElement
  ├── exposes { theme, setTheme, toggleTheme }
  └── writes to localStorage on every change
```

---

## Components and Interfaces

### AppLayout

Wraps all authenticated pages. Renders `Sidebar` on `md+` breakpoints and `MobileNav` on smaller viewports. Includes `ThemeToggle` in the header.

```tsx
interface AppLayoutProps {
  children: React.ReactNode;
}
```

### Sidebar

Desktop navigation. Built from Shadcn UI `NavigationMenu` and `Separator`. Highlights the active route using React Router's `useLocation`.

```tsx
interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType;
}

const NAV_ITEMS: NavItem[] = [
  { label: "Dashboard", href: "/", icon: LayoutDashboard },
  { label: "Loans", href: "/loans", icon: CreditCard },
  { label: "Savings", href: "/savings", icon: PiggyBank },
  { label: "Insurance", href: "/insurance", icon: Shield },
  { label: "Pensions", href: "/pensions", icon: Landmark },
];
```

### MobileNav

Mobile navigation. A `Button` with a hamburger icon opens a Shadcn UI `Sheet` (drawer) containing the same `NAV_ITEMS` list.

### ThemeToggle

A Shadcn UI `Button` (variant `ghost`, size `icon`) that calls `toggleTheme()` from `useTheme`. Renders a sun icon in dark mode and a moon icon in light mode.

### PageLayout

Shared wrapper exported for all pages. Accepts a `title` and optional `action` slot (e.g., an "Add" button).

```tsx
interface PageLayoutProps {
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}
```

### FormField

Combines Shadcn UI `FormItem`, `FormLabel`, `FormControl`, and `FormMessage` into a single composable wrapper.

```tsx
interface FormFieldWrapperProps {
  label: string;
  name: string;
  error?: string;
  children: React.ReactNode;
}
```

### Auth Pages

All auth pages share a common centred layout:

```tsx
// Structural pattern for all auth pages
<div className="min-h-screen flex items-center justify-center">
  <Card className="w-full max-w-md">
    <CardHeader>...</CardHeader>
    <CardContent>...</CardContent>
  </Card>
</div>
```

`LoginPage` uses Shadcn UI `Tabs` with two panels: "OTP" and "Password". The OTP panel shows a `Badge` or `Progress` countdown once an OTP has been sent.

### Dashboard Page

Four `Card` components in a responsive CSS grid. Each card shows a summary total and navigates to the detail page on click.

```tsx
// Grid layout
<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
  <SummaryCard title="Savings" ... />
  <SummaryCard title="Loans" ... />
  <SummaryCard title="Insurance" ... />
  <SummaryCard title="Pensions" ... />
</div>
```

While data is loading, each `SummaryCard` renders `Skeleton` placeholders instead of real values.

### Domain Pages (Loans, Savings, Insurance, Pensions)

Each domain page follows the same structural pattern:

```
PageLayout (title + "Add X" Button)
└── Table (list of records)
    └── TableRow (click → detail route)
        └── Badge (type indicator)

"Add X" Button → opens Dialog or Sheet
  └── form using FormField wrappers
      └── Input / Select / RadioGroup / Label
```

---

## Data Models

These are the frontend TypeScript types that mirror the backend domain models. They are used for typing API responses and component props. Actual persistence is handled by the Rails API.

```ts
// Theme
type Theme = "light" | "dark" | "system";

// Navigation
interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

// Auth
interface User {
  id: number;
  identifier: string; // phone or email
  name?: string;
}

// Loans
interface Loan {
  id: number;
  loanNumber: string;
  institutionName: string;
  outstandingBalance: number;
  interestRate: number;
  interestType: "fixed" | "floating";
  nextPaymentDate: string;   // ISO 8601
  projectedCloseDate: string;
}

interface LoanPayment {
  month: string;
  principal: number;
  interest: number;
  balance: number;
}

// Savings
interface SavingsInstrument {
  id: number;
  savingsId: string;
  institutionName: string;
  type: "FD" | "RD";
  amountContributed: number;
  currentValue: number;
  startDate: string;
  maturityDate?: string;
  nextPaymentDate?: string;
}

// Insurance
interface InsurancePolicy {
  id: number;
  policyNumber: string;
  institutionName: string;
  type: "term" | "health" | "auto" | "bike";
  sumAssured: number;
  nextRenewalDate: string;
  coveredIndividuals: CoveredIndividual[];
}

interface CoveredIndividual {
  name: string;
  individualPolicyId: string;
}

// Pensions
interface PensionInstrument {
  id: number;
  pensionId: string;
  institutionName: string;
  type: "EPF" | "NPS";
  monthlyContribution: number;
  contributionStartDate: string;
  maturityDate?: string;
  totalContributions: number;
}

// Dashboard summary (aggregated)
interface DashboardSummary {
  totalSavings: number;
  totalDebt: number;
  insurancePoliciesCount: number;
  totalPensionContributions: number;
}
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Theme persistence round-trip

*For any* theme value (`"light"` or `"dark"`), setting the theme via `setTheme` and then reading back the value from `localStorage` and re-initialising `useTheme` should produce the same theme value.

**Validates: Requirements 2.5**

### Property 2: Dark class invariant

*For any* theme value, after `useTheme` applies the theme, the presence of the `.dark` class on `document.documentElement` should be exactly equal to `theme === "dark"` — never partially applied or stale.

**Validates: Requirements 2.4**

### Property 3: Active nav link invariant

*For any* route pathname that matches a `NavItem.href`, exactly one nav item should be marked active and all others should be marked inactive.

**Validates: Requirements 3.5**

### Property 4: Whitespace-only form inputs are invalid

*For any* string composed entirely of whitespace characters, submitting it as a required form field value should be rejected and the `FormMessage` error should be displayed beneath the field.

**Validates: Requirements 4.3**

### Property 5: Badge label matches record type

*For any* domain record (loan, savings instrument, insurance policy, or pension instrument), the `Badge` rendered for that record should display a label that corresponds exactly to the record's type field — and no other value. This holds for all valid type values across all four domains (`"fixed"` / `"floating"` for loans; `"FD"` / `"RD"` for savings; `"term"` / `"health"` / `"auto"` / `"bike"` for insurance; `"EPF"` / `"NPS"` for pensions).

**Validates: Requirements 6.5, 7.5, 8.5, 9.4**

### Property 6: Skeleton-to-content transition

*For any* dashboard summary card, while the loading flag is `true` the card should render `Skeleton` elements and no real data values; once the loading flag becomes `false` the card should render real data values and no `Skeleton` elements.

**Validates: Requirements 5.5**

---

## Error Handling

### Form Validation Errors

All forms use React Hook Form with Zod schemas for client-side validation. Errors surface via Shadcn UI `FormMessage` beneath each field. Required fields, minimum lengths, and format constraints (e.g., numeric-only OTP) are enforced before submission.

### API Errors

API call failures (network errors, 4xx/5xx responses) are caught and displayed using Shadcn UI `Toast` notifications. The toast is triggered from the data-fetching layer and does not require page-level error state.

### Auth Redirect

If a protected route is accessed without a valid auth token, `ProtectedRoute` redirects to `/login` immediately. No error message is shown for this case — the redirect itself is the signal.

### Theme Initialisation Failure

If `localStorage` is unavailable (e.g., private browsing with storage blocked), `useTheme` falls back to `"light"` without throwing. The toggle still works for the session; it just won't persist.

### Missing Route

A catch-all `*` route renders a minimal "Page not found" view using Shadcn UI `Card` and a `Button` linking back to `/`.

---

## Testing Strategy

### PBT Applicability Assessment

This feature is primarily UI scaffolding, layout, and theming. The majority of acceptance criteria describe visual structure, component selection, and responsive behaviour — areas where property-based testing is not appropriate. However, a small set of criteria involve pure logic (theme persistence, active-link detection, badge label mapping, form validation) that are amenable to property-based testing.

### Property-Based Tests

**Library**: [fast-check](https://github.com/dubzzz/fast-check) (TypeScript-native PBT library, well-maintained, integrates with Vitest).

Each property test runs a minimum of **100 iterations**.

Tag format: `// Feature: shadcn-ui-theme, Property N: <property text>`

| Property | Test file | What varies |
|---|---|---|
| 1 — Theme persistence round-trip | `src/hooks/useTheme.test.ts` | Arbitrary theme value from `["light", "dark"]` |
| 2 — Dark class invariant | `src/hooks/useTheme.test.ts` | Arbitrary theme value |
| 3 — Active nav link invariant | `src/components/layout/Sidebar.test.tsx` | Arbitrary pathname from `NAV_ITEMS` hrefs |
| 4 — Whitespace-only inputs invalid | `src/components/shared/FormField.test.tsx` | Arbitrary whitespace-only strings |
| 5 — Badge label matches record type | `src/pages/DomainPages.test.tsx` | Arbitrary records across all four domains |
| 6 — Skeleton-to-content transition | `src/pages/DashboardPage.test.tsx` | Arbitrary `DashboardSummary` values |

### Unit / Example-Based Tests

- **Auth pages**: Render tests confirming `Card`, `Tabs`, `Input`, `Button`, `FormMessage` are present in the DOM.
- **AppLayout**: Snapshot test confirming sidebar renders on `md+` and `Sheet` trigger renders on mobile (using `@testing-library/react` with viewport mocking).
- **ProtectedRoute**: Example test — unauthenticated access redirects to `/login`; authenticated access renders children.
- **ThemeToggle**: Example test — clicking the toggle calls `toggleTheme`.
- **PageLayout / FormField**: Snapshot tests confirming structural output.

### Integration Tests

- **Routing**: Verify that navigating to each route renders the correct page component.
- **Theme toggle in layout**: Verify that clicking `ThemeToggle` inside `AppLayout` adds/removes `.dark` on `<html>`.

### Tools

- **Vitest** — test runner (native Vite integration, fast)
- **@testing-library/react** — component rendering and querying
- **fast-check** — property-based test generation
- **jsdom** — DOM environment for Vitest

### What Is Not Tested

- Visual appearance, colour values, and spacing (covered by manual review and design-system.md)
- Responsive breakpoint rendering (covered by manual browser testing)
- Shadcn UI component internals (tested by the library authors)
