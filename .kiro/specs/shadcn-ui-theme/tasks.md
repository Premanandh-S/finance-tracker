# Implementation Plan: Shadcn UI Theme

## Overview

Scaffold the `frontend/` React application from scratch using Vite + React + TypeScript, configure Tailwind CSS and Shadcn UI, implement theming with dark mode and localStorage persistence, build the shared authenticated layout, and construct all six page groups (Auth, Dashboard, Loans, Savings, Insurance, Pensions). Property-based tests cover the six correctness properties defined in the design document.

## Tasks

- [x] 1. Scaffold the Vite + React + TypeScript project
  - Run `npm create vite@latest frontend -- --template react-ts` to initialise the project under `frontend/`
  - Verify `frontend/package.json`, `frontend/tsconfig.json`, and `frontend/vite.config.ts` are generated
  - Install base dependencies: `react-router-dom`, `lucide-react`
  - _Requirements: 1.1, 1.4_

- [x] 2. Configure Tailwind CSS and Shadcn UI
  - [x] 2.1 Install and configure Tailwind CSS
    - Install `tailwindcss`, `postcss`, `autoprefixer` and generate `tailwind.config.js` and `postcss.config.js`
    - Add Tailwind directives (`@tailwind base/components/utilities`) to `src/globals.css`
    - _Requirements: 1.2_

  - [x] 2.2 Initialise Shadcn UI
    - Run `npx shadcn@latest init` to produce `components.json` and `src/lib/utils.ts`
    - Install initial Shadcn UI components needed across the app: `button`, `card`, `input`, `label`, `badge`, `table`, `dialog`, `sheet`, `tabs`, `select`, `radio-group`, `separator`, `avatar`, `skeleton`, `form`, `navigation-menu`, `toast`, `progress`
    - Confirm all component source files land under `src/components/ui/`
    - _Requirements: 1.3, 10.4_

- [x] 3. Define CSS variable theme tokens in globals.css
  - Write `:root` selector with all Shadcn UI neutral-palette HSL tokens: `--background`, `--foreground`, `--primary`, `--primary-foreground`, `--secondary`, `--secondary-foreground`, `--muted`, `--muted-foreground`, `--accent`, `--accent-foreground`, `--destructive`, `--destructive-foreground`, `--border`, `--input`, `--ring`, `--radius`
  - Write `.dark` selector with the corresponding dark-mode HSL overrides for every token
  - Ensure no hardcoded hex or RGB values appear — all color references use `hsl(var(--token))`
  - _Requirements: 1.5, 2.1, 2.2, 2.3, 10.5_

- [x] 4. Implement the useTheme hook
  - [x] 4.1 Write `src/hooks/useTheme.ts`
    - On mount, read `localStorage.getItem("theme")`; fall back to `"light"` if absent or storage is unavailable
    - Apply or remove the `.dark` class on `document.documentElement` based on the resolved theme
    - Expose `{ theme, setTheme, toggleTheme }` — `setTheme` writes to `localStorage` and updates the class; `toggleTheme` flips between `"light"` and `"dark"`
    - Wrap `localStorage` access in a try/catch so private-browsing failures degrade gracefully
    - _Requirements: 2.4, 2.5_

  - [ ]* 4.2 Write property test — Theme persistence round-trip (Property 1)
    - **Property 1: Theme persistence round-trip**
    - For any theme value from `["light", "dark"]`, calling `setTheme(value)` and then re-reading `localStorage.getItem("theme")` must return the same value
    - Use `fc.constantFrom("light", "dark")` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 1: Theme persistence round-trip`
    - File: `src/hooks/useTheme.test.ts`
    - **Validates: Requirements 2.5**

  - [ ]* 4.3 Write property test — Dark class invariant (Property 2)
    - **Property 2: Dark class invariant**
    - For any theme value, after `setTheme(value)` the presence of `.dark` on `document.documentElement.classList` must equal `theme === "dark"` exactly
    - Use `fc.constantFrom("light", "dark")` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 2: Dark class invariant`
    - File: `src/hooks/useTheme.test.ts`
    - **Validates: Requirements 2.4**

- [x] 5. Set up React Router v6 with public/protected route split
  - [x] 5.1 Write `src/App.tsx` with `BrowserRouter` and route definitions
    - Public routes (`/login`, `/register`, `/verify-otp`, `/reset-password`) render page components directly with no layout shell
    - Protected routes (`/`, `/loans`, `/savings`, `/insurance`, `/pensions`) are wrapped in a `ProtectedRoute` component
    - Add a catch-all `*` route that renders a "Page not found" view using Shadcn UI `Card` and a `Button` linking back to `/`
    - _Requirements: 1.4, 3.6_

  - [x] 5.2 Write `src/components/auth/ProtectedRoute.tsx`
    - Check for an auth token in `localStorage`; if absent, redirect to `/login` using React Router `<Navigate>`
    - If present, render `children` wrapped in `AppLayout`
    - _Requirements: 3.6_

  - [ ]* 5.3 Write unit tests for ProtectedRoute
    - Example: unauthenticated access redirects to `/login`
    - Example: authenticated access renders children
    - File: `src/components/auth/ProtectedRoute.test.tsx`
    - _Requirements: 3.6_

- [x] 6. Build AppLayout, Sidebar, MobileNav, and ThemeToggle
  - [x] 6.1 Write `src/components/layout/ThemeToggle.tsx`
    - Shadcn UI `Button` with `variant="ghost"` and `size="icon"`
    - Renders a sun icon when theme is `"dark"` and a moon icon when theme is `"light"` (using `lucide-react`)
    - Calls `toggleTheme()` from `useTheme` on click
    - _Requirements: 2.6, 3.4_

  - [x] 6.2 Write `src/components/layout/Sidebar.tsx`
    - Built from Shadcn UI `NavigationMenu` and `Separator`
    - Renders `NAV_ITEMS` (Dashboard, Loans, Savings, Insurance, Pensions) as navigation links
    - Uses `useLocation()` to detect the active route; applies active styling to the matching item
    - Visible only on `md+` breakpoints via Tailwind (`hidden md:flex`)
    - _Requirements: 3.1, 3.3, 3.5, 3.7_

  - [x] 6.3 Write `src/components/layout/MobileNav.tsx`
    - A Shadcn UI `Button` (hamburger icon) that opens a Shadcn UI `Sheet` drawer
    - The drawer contains the same `NAV_ITEMS` list with active-route highlighting
    - Visible only on viewports below `md` via Tailwind (`flex md:hidden`)
    - _Requirements: 3.2, 3.5, 3.7_

  - [x] 6.4 Write `src/components/layout/AppLayout.tsx`
    - Renders `Sidebar` and `MobileNav` in a flex shell
    - Header area includes the application name, a Shadcn UI `Avatar` with user initials, and `ThemeToggle`
    - Renders `{children}` in the main content area
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 3.7_

  - [ ]* 6.5 Write unit tests for AppLayout and ThemeToggle
    - Render test: `Sidebar` is present in the DOM on `md+` viewport
    - Render test: `Sheet` trigger (hamburger) is present on mobile viewport
    - Example test: clicking `ThemeToggle` calls `toggleTheme`
    - File: `src/components/layout/AppLayout.test.tsx`
    - _Requirements: 3.1, 3.2, 3.4_

  - [ ]* 6.6 Write property test — Active nav link invariant (Property 3)
    - **Property 3: Active nav link invariant**
    - For any pathname that matches a `NavItem.href`, exactly one nav item should be marked active and all others inactive
    - Use `fc.constantFrom(...NAV_ITEMS.map(i => i.href))` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 3: Active nav link invariant`
    - File: `src/components/layout/Sidebar.test.tsx`
    - **Validates: Requirements 3.5**

- [x] 7. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Build shared PageLayout and FormField components
  - [x] 8.1 Write `src/components/shared/PageLayout.tsx`
    - Accepts `title: string`, optional `action?: React.ReactNode`, and `children: React.ReactNode`
    - Renders a page heading and the optional action slot (e.g., an "Add" button) in a flex row
    - All pages import this component to receive a consistent page shell
    - _Requirements: 10.2_

  - [x] 8.2 Write `src/components/shared/FormField.tsx`
    - Wraps Shadcn UI `FormItem`, `FormLabel`, `FormControl`, and `FormMessage` into a single composable component
    - Accepts `label: string`, `name: string`, `error?: string`, and `children: React.ReactNode`
    - _Requirements: 4.3, 10.3_

  - [ ]* 8.3 Write property test — Whitespace-only form inputs are invalid (Property 4)
    - **Property 4: Whitespace-only form inputs are invalid**
    - For any string composed entirely of whitespace characters, submitting it as a required field value should be rejected and `FormMessage` should appear beneath the field
    - Use `fc.stringOf(fc.constantFrom(" ", "\t", "\n"))` as the arbitrary; filter to non-empty strings
    - Tag: `// Feature: shadcn-ui-theme, Property 4: Whitespace-only form inputs are invalid`
    - File: `src/components/shared/FormField.test.tsx`
    - **Validates: Requirements 4.3**

  - [ ]* 8.4 Write snapshot tests for PageLayout and FormField
    - Snapshot test: `PageLayout` renders title and action slot correctly
    - Snapshot test: `FormField` renders label, control, and error message
    - File: `src/components/shared/PageLayout.test.tsx`, `src/components/shared/FormField.test.tsx`
    - _Requirements: 10.2, 10.3_

- [x] 9. Build Authentication pages
  - [x] 9.1 Write `src/pages/auth/LoginPage.tsx`
    - Centred `Card` layout (`min-h-screen flex items-center justify-center`)
    - Shadcn UI `Tabs` with two panels: "OTP" and "Password"
    - OTP panel: phone/email `Input`, "Send OTP" `Button`, and a `Badge` or `Progress` countdown once OTP is sent
    - Password panel: identifier `Input`, password `Input`, "Login" `Button`
    - All fields wrapped in `FormField`; validation errors surface via `FormMessage`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 9.2 Write `src/pages/auth/RegisterPage.tsx`
    - Centred `Card` layout
    - Fields: name, identifier (phone/email), password, confirm password — all using `Input` wrapped in `FormField`
    - "Register" `Button`; validation errors via `FormMessage`
    - _Requirements: 4.1, 4.2, 4.3, 4.6_

  - [x] 9.3 Write `src/pages/auth/OtpVerifyPage.tsx`
    - Centred `Card` layout
    - 6-digit OTP `Input` wrapped in `FormField`
    - Countdown timer using `Badge` or `Progress`
    - "Verify" `Button`; validation errors via `FormMessage`
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6_

  - [x] 9.4 Write `src/pages/auth/PasswordResetPage.tsx`
    - Centred `Card` layout
    - Fields: identifier, new password, confirm password — all using `Input` wrapped in `FormField`
    - "Reset Password" `Button`; validation errors via `FormMessage`
    - _Requirements: 4.1, 4.2, 4.3, 4.6_

  - [ ]* 9.5 Write render tests for Auth pages
    - For each auth page: confirm `Card`, `Input`, `Button`, and `FormMessage` are present in the DOM
    - For `LoginPage`: confirm `Tabs` with both panels is present
    - Files: `src/pages/auth/LoginPage.test.tsx`, `RegisterPage.test.tsx`, `OtpVerifyPage.test.tsx`, `PasswordResetPage.test.tsx`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 10. Build DashboardPage
  - [x] 10.1 Write `src/pages/DashboardPage.tsx`
    - Use `PageLayout` with title "Dashboard"
    - Four `SummaryCard` sub-components (Savings, Loans, Insurance, Pensions) in a responsive CSS grid: `grid-cols-1 sm:grid-cols-2 xl:grid-cols-4`
    - Each card shows a title and a total value; clicking navigates to the corresponding detail page via React Router `useNavigate`
    - While `isLoading` is `true`, each card renders `Skeleton` placeholders instead of real values
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 10.2 Write property test — Skeleton-to-content transition (Property 6)
    - **Property 6: Skeleton-to-content transition**
    - For any `DashboardSummary` value, when `isLoading=true` the card must render `Skeleton` elements and no real data; when `isLoading=false` the card must render real data and no `Skeleton` elements
    - Use `fc.record({ totalSavings: fc.float(), totalDebt: fc.float(), insurancePoliciesCount: fc.nat(), totalPensionContributions: fc.float() })` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 6: Skeleton-to-content transition`
    - File: `src/pages/DashboardPage.test.tsx`
    - **Validates: Requirements 5.5**

- [x] 11. Build LoansPage
  - [x] 11.1 Write `src/pages/LoansPage.tsx`
    - Use `PageLayout` with title "Loans" and an "Add Loan" `Button` in the action slot
    - Shadcn UI `Table` with columns: loan number, outstanding balance, next payment date, projected close date
    - Each row has a `Badge` showing `"fixed"` or `"floating"` interest type
    - Clicking a row navigates to a loan detail route
    - "Add Loan" button opens a `Dialog` or `Sheet` containing a form with `Input`, `Select`, and `Label` components wrapped in `FormField`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 11.2 Write property test — Badge label matches loan type (Property 5, loans domain)
    - **Property 5: Badge label matches record type — loans**
    - For any `Loan` record with `interestType` from `["fixed", "floating"]`, the rendered `Badge` text must equal `interestType` exactly
    - Use `fc.record({ interestType: fc.constantFrom("fixed", "floating"), ...otherFields })` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 5: Badge label matches record type`
    - File: `src/pages/DomainPages.test.tsx`
    - **Validates: Requirements 6.5**

- [x] 12. Build SavingsPage
  - [x] 12.1 Write `src/pages/SavingsPage.tsx`
    - Use `PageLayout` with title "Savings" and an "Add Savings" `Button` in the action slot
    - Shadcn UI `Table` with columns: savings ID, type (FD/RD), current value, maturity date, next payment date
    - Each row has a `Badge` showing `"FD"` or `"RD"`
    - Clicking a row navigates to a savings detail route
    - "Add Savings" button opens a `Dialog` or `Sheet` with a form using `Input`, `Select`, `RadioGroup`, and `Label` wrapped in `FormField`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 12.2 Write property test — Badge label matches savings type (Property 5, savings domain)
    - **Property 5: Badge label matches record type — savings**
    - For any `SavingsInstrument` record with `type` from `["FD", "RD"]`, the rendered `Badge` text must equal `type` exactly
    - Use `fc.record({ type: fc.constantFrom("FD", "RD"), ...otherFields })` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 5: Badge label matches record type`
    - File: `src/pages/DomainPages.test.tsx`
    - **Validates: Requirements 7.5**

- [x] 13. Build InsurancePage
  - [x] 13.1 Write `src/pages/InsurancePage.tsx`
    - Use `PageLayout` with title "Insurance" and an "Add Insurance" `Button` in the action slot
    - Shadcn UI `Table` with columns: policy number, type, sum assured, next renewal date
    - Each row has a `Badge` showing the policy type (`"term"`, `"health"`, `"auto"`, `"bike"`)
    - Clicking a row navigates to a policy detail route showing covered individuals in a `Table`
    - "Add Insurance" button opens a `Dialog` or `Sheet` with a form using `Input`, `Select`, and `Label` wrapped in `FormField`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 13.2 Write property test — Badge label matches insurance type (Property 5, insurance domain)
    - **Property 5: Badge label matches record type — insurance**
    - For any `InsurancePolicy` record with `type` from `["term", "health", "auto", "bike"]`, the rendered `Badge` text must equal `type` exactly
    - Use `fc.record({ type: fc.constantFrom("term", "health", "auto", "bike"), ...otherFields })` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 5: Badge label matches record type`
    - File: `src/pages/DomainPages.test.tsx`
    - **Validates: Requirements 8.5**

- [x] 14. Build PensionsPage
  - [x] 14.1 Write `src/pages/PensionsPage.tsx`
    - Use `PageLayout` with title "Pensions" and an "Add Pension" `Button` in the action slot
    - Shadcn UI `Table` with columns: pension ID, institution name, monthly contribution, total contributions to date
    - Each row has a `Badge` showing the pension type (`"EPF"` or `"NPS"`)
    - "Add Pension" button opens a `Dialog` or `Sheet` with a form using `Input`, `Select`, and `Label` wrapped in `FormField`
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [ ]* 14.2 Write property test — Badge label matches pension type (Property 5, pensions domain)
    - **Property 5: Badge label matches record type — pensions**
    - For any `PensionInstrument` record with `type` from `["EPF", "NPS"]`, the rendered `Badge` text must equal `type` exactly
    - Use `fc.record({ type: fc.constantFrom("EPF", "NPS"), ...otherFields })` as the arbitrary
    - Tag: `// Feature: shadcn-ui-theme, Property 5: Badge label matches record type`
    - File: `src/pages/DomainPages.test.tsx`
    - **Validates: Requirements 9.4**

- [x] 15. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Wire up routing integration and configure Vitest
  - [x] 16.1 Configure Vitest in `frontend/vite.config.ts`
    - Add `test` block with `environment: "jsdom"`, `globals: true`, and `setupFiles` pointing to a test setup file
    - Create `src/test/setup.ts` that imports `@testing-library/jest-dom`
    - Install dev dependencies: `vitest`, `@testing-library/react`, `@testing-library/jest-dom`, `@testing-library/user-event`, `fast-check`, `jsdom`
    - _Requirements: (testing infrastructure for all test tasks)_

  - [x] 16.2 Write routing integration tests
    - Verify navigating to `/` renders `DashboardPage`
    - Verify navigating to `/loans` renders `LoansPage`
    - Verify navigating to `/savings` renders `SavingsPage`
    - Verify navigating to `/insurance` renders `InsurancePage`
    - Verify navigating to `/pensions` renders `PensionsPage`
    - Verify navigating to `/login` renders `LoginPage` without `AppLayout`
    - File: `src/App.test.tsx`
    - _Requirements: 1.4, 3.6_

  - [ ]* 16.3 Write integration test — Theme toggle in layout
    - Verify that clicking `ThemeToggle` inside a rendered `AppLayout` adds `.dark` to `document.documentElement` when theme is `"light"`, and removes it when theme is `"dark"`
    - File: `src/components/layout/AppLayout.test.tsx`
    - _Requirements: 2.4, 2.6_

- [x] 17. Create the design system documentation
  - Write `frontend/docs/design-system.md` covering:
    - Component selection guide: which Shadcn UI component to use for forms, tables, dialogs, notifications, and loading states
    - Theme token reference: all CSS variables defined in `globals.css` with their intended use
    - Layout conventions: how to use `PageLayout` and `FormField` in new pages
    - Adding new components: the `shadcn add <component>` workflow
    - Dark mode: how the `.dark` class and `useTheme` hook work together
  - _Requirements: 10.1_

- [x] 18. Final checkpoint — Ensure all tests pass
  - Run `vitest --run` from the `frontend/` directory and confirm all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical milestones
- Property tests use `fast-check` with a minimum of 100 iterations per property
- Unit tests use `@testing-library/react` with `jsdom`
- All Shadcn UI components are installed via `shadcn add <component>` so source lives under `src/components/ui/`
- No hardcoded hex/RGB colors — all color values reference CSS variables from `globals.css`
- Data fetching is out of scope; pages render with mock/static data or skeleton states
