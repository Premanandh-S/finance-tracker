# Requirements Document

## Introduction

This feature covers scaffolding the React frontend application and applying a consistent Shadcn UI theme across all pages of the personal finance management app. The frontend does not yet exist in the repository and must be created from scratch. Once scaffolded, every current page (Authentication, Dashboard, Loans, Savings, Insurance, Pensions) and all future pages must follow the Shadcn UI design system — using its component library, CSS variables, and theming conventions — so the application has a cohesive, professional look and feel.

## Glossary

- **React_App**: The React frontend application to be scaffolded under a `frontend/` directory in the repository.
- **Shadcn_UI**: An open-source component library built on Radix UI primitives and Tailwind CSS, providing accessible, composable UI components styled via CSS variables.
- **Theme**: The set of CSS custom properties (colors, radius, fonts) defined in `globals.css` that control the visual appearance of all Shadcn UI components.
- **Design_System**: The collection of Shadcn UI components, tokens, and layout conventions that all pages must use consistently.
- **Page**: A top-level route in the React_App corresponding to a user-facing screen (e.g., Login, Dashboard, Loans).
- **Component**: A reusable UI element built using Shadcn UI primitives (e.g., Button, Card, Input, Table).
- **Layout**: The shared shell wrapping all authenticated pages, including navigation sidebar/header and main content area.
- **Auth_Pages**: The Login, Registration, OTP Verification, and Password Reset pages.
- **Dashboard_Page**: The aggregated financial overview page showing Savings, Loans, Insurance, and Pensions summaries.
- **Loans_Page**: The page for entering and viewing loan details.
- **Savings_Page**: The page for entering and viewing savings instrument details.
- **Insurance_Page**: The page for entering and viewing insurance policy details.
- **Pensions_Page**: The page for entering and viewing pension instrument details.
- **Dark_Mode**: An alternative color scheme where background and foreground CSS variables are inverted for low-light environments.
- **Tailwind_CSS**: The utility-first CSS framework used by Shadcn UI for layout and spacing.

---

## Requirements

### Requirement 1: Frontend Scaffolding

**User Story:** As a developer, I want a React application scaffolded in the repository, so that I have a working foundation to build all frontend pages on.

#### Acceptance Criteria

1. THE React_App SHALL be initialised using Vite with the React + TypeScript template under a `frontend/` directory at the repository root.
2. THE React_App SHALL include Tailwind CSS configured with the `tailwind.config.js` and `postcss.config.js` files required by Shadcn UI.
3. THE React_App SHALL include Shadcn UI initialised via its CLI (`shadcn init`), producing a `components.json` configuration file and a `src/lib/utils.ts` utility file.
4. THE React_App SHALL include React Router configured for client-side navigation between all pages.
5. THE React_App SHALL include a `src/globals.css` file that defines the Shadcn UI CSS variable theme tokens (background, foreground, primary, secondary, muted, accent, destructive, border, input, ring, and radius).
6. WHEN the development server is started, THE React_App SHALL serve without build errors.

---

### Requirement 2: Shadcn UI Theme Configuration

**User Story:** As a designer, I want a single source-of-truth theme defined in CSS variables, so that changing a token updates the appearance across the entire application consistently.

#### Acceptance Criteria

1. THE Design_System SHALL define all color tokens as HSL CSS custom properties inside `:root` and `.dark` selectors in `globals.css`.
2. THE Design_System SHALL use a `neutral` base color palette as the default theme (matching Shadcn UI's `neutral` preset).
3. THE Design_System SHALL expose a `--radius` CSS variable controlling the border-radius of all components.
4. WHEN the `.dark` class is applied to the `<html>` element, THE React_App SHALL switch all component colors to the dark-mode token values without requiring a page reload.
5. THE React_App SHALL persist the user's theme preference (light or dark) in `localStorage` and restore it on page load.
6. THE React_App SHALL provide a theme toggle control accessible from the Layout so the user can switch between light and Dark_Mode at any time.

---

### Requirement 3: Shared Layout

**User Story:** As a user, I want a consistent navigation structure on every authenticated page, so that I can move between sections of the app without confusion.

#### Acceptance Criteria

1. THE Layout SHALL render a sidebar navigation on desktop viewports (≥ 768 px) containing links to Dashboard, Loans, Savings, Insurance, and Pensions.
2. THE Layout SHALL render a top navigation bar on mobile viewports (< 768 px) with a hamburger menu that opens a drawer containing the same navigation links.
3. THE Layout SHALL display the application name and a user avatar or initials in the header area.
4. THE Layout SHALL include the theme toggle control described in Requirement 2.
5. WHEN a navigation link is active (matches the current route), THE Layout SHALL visually distinguish it from inactive links using the Shadcn UI `active` variant or equivalent styling.
6. THE Layout SHALL wrap all authenticated pages and SHALL NOT be rendered on Auth_Pages.
7. THE Layout SHALL be built exclusively from Shadcn UI components (e.g., `Sheet`, `NavigationMenu`, `Separator`, `Avatar`).

---

### Requirement 4: Authentication Pages

**User Story:** As a user, I want the login, registration, OTP, and password reset screens to look polished and consistent with the rest of the app, so that my first impression of the product is professional.

#### Acceptance Criteria

1. THE Auth_Pages SHALL be centred on the viewport and SHALL use the Shadcn UI `Card` component as the primary container.
2. THE Auth_Pages SHALL use the Shadcn UI `Input` component for all text fields and the `Button` component for all actions.
3. WHEN a form field contains a validation error, THE Auth_Pages SHALL display the error message using the Shadcn UI `FormMessage` component beneath the relevant field.
4. THE Auth_Pages SHALL use the Shadcn UI `Tabs` component to allow the user to switch between OTP and password authentication methods on the Login page.
5. WHEN an OTP has been requested, THE Auth_Pages SHALL display a countdown timer showing the remaining OTP validity period using a Shadcn UI `Badge` or `Progress` component.
6. THE Auth_Pages SHALL be fully responsive and usable on viewports as narrow as 320 px.

---

### Requirement 5: Dashboard Page

**User Story:** As a user, I want the dashboard to display my financial summary in clearly separated, visually consistent sections, so that I can quickly understand my overall financial position.

#### Acceptance Criteria

1. THE Dashboard_Page SHALL display four summary sections — Savings, Loans, Insurance, and Pensions — each rendered as a Shadcn UI `Card` component.
2. THE Dashboard_Page SHALL display a total value (e.g., total savings, total debt) in each summary Card using a prominent typographic style consistent with the Design_System.
3. THE Dashboard_Page SHALL use a responsive CSS grid layout so that summary Cards stack vertically on mobile and display in a multi-column grid on desktop.
4. WHEN a summary Card is clicked, THE Dashboard_Page SHALL navigate to the corresponding detail page (Loans_Page, Savings_Page, Insurance_Page, or Pensions_Page).
5. THE Dashboard_Page SHALL use Shadcn UI `Skeleton` components as loading placeholders while financial data is being fetched from the API.

---

### Requirement 6: Loans Page

**User Story:** As a user, I want the loans page to present my loan data in a structured, readable format that matches the app's theme, so that I can review and manage my loans easily.

#### Acceptance Criteria

1. THE Loans_Page SHALL display a list of loans using the Shadcn UI `Table` component with columns for loan number, outstanding balance, next payment date, and projected close date.
2. THE Loans_Page SHALL provide an "Add Loan" action using a Shadcn UI `Button` that opens a `Dialog` or `Sheet` containing the loan entry form.
3. THE Loans_Page loan entry form SHALL use Shadcn UI `Input`, `Select`, and `Label` components for all fields.
4. WHEN a loan row is clicked, THE Loans_Page SHALL navigate to a loan detail view that displays future payment schedule in a Shadcn UI `Table`.
5. THE Loans_Page SHALL use Shadcn UI `Badge` components to visually distinguish fixed-interest loans from floating-interest loans.

---

### Requirement 7: Savings Page

**User Story:** As a user, I want the savings page to clearly show my savings instruments and their projected values, styled consistently with the rest of the app.

#### Acceptance Criteria

1. THE Savings_Page SHALL display a list of savings instruments using the Shadcn UI `Table` component with columns for savings ID, type (FD/RD), current value, maturity date, and next payment date.
2. THE Savings_Page SHALL provide an "Add Savings" action using a Shadcn UI `Button` that opens a `Dialog` or `Sheet` containing the savings entry form.
3. THE Savings_Page savings entry form SHALL use Shadcn UI `Input`, `Select`, `RadioGroup`, and `Label` components for all fields.
4. WHEN a savings row is clicked, THE Savings_Page SHALL navigate to a savings detail view showing projected future payments or maturity value in a Shadcn UI `Table` or `Card`.
5. THE Savings_Page SHALL use Shadcn UI `Badge` components to visually distinguish FD instruments from RD instruments.

---

### Requirement 8: Insurance Page

**User Story:** As a user, I want the insurance page to display my policies in a clear, themed layout so that I can track coverage and renewal dates at a glance.

#### Acceptance Criteria

1. THE Insurance_Page SHALL display a list of insurance policies using the Shadcn UI `Table` component with columns for policy number, type, sum assured, and next renewal date.
2. THE Insurance_Page SHALL provide an "Add Insurance" action using a Shadcn UI `Button` that opens a `Dialog` or `Sheet` containing the insurance entry form.
3. THE Insurance_Page insurance entry form SHALL use Shadcn UI `Input`, `Select`, and `Label` components for all fields.
4. WHEN a policy row is clicked, THE Insurance_Page SHALL navigate to a policy detail view that lists covered individuals and their individual policy IDs in a Shadcn UI `Table`.
5. THE Insurance_Page SHALL use Shadcn UI `Badge` components to visually distinguish policy types (term, health, auto, bike).

---

### Requirement 9: Pensions Page

**User Story:** As a user, I want the pensions page to show my pension instruments in a consistent, themed layout so that I can monitor my contributions easily.

#### Acceptance Criteria

1. THE Pensions_Page SHALL display a list of pension instruments using the Shadcn UI `Table` component with columns for pension ID, institution name, monthly contribution, and total contributions to date.
2. THE Pensions_Page SHALL provide an "Add Pension" action using a Shadcn UI `Button` that opens a `Dialog` or `Sheet` containing the pension entry form.
3. THE Pensions_Page pension entry form SHALL use Shadcn UI `Input`, `Select`, and `Label` components for all fields.
4. THE Pensions_Page SHALL use Shadcn UI `Badge` components to visually distinguish pension types (e.g., EPF, NPS).

---

### Requirement 10: Design System Consistency for Future Pages

**User Story:** As a developer, I want clear conventions established so that any new page added to the app automatically follows the Shadcn UI theme without extra configuration.

#### Acceptance Criteria

1. THE Design_System SHALL provide a documented component usage guide (in `frontend/docs/design-system.md`) listing which Shadcn UI components to use for common UI patterns (forms, tables, dialogs, notifications, loading states).
2. THE React_App SHALL export a shared `PageLayout` component that all pages (current and future) import to receive the Layout shell automatically.
3. THE React_App SHALL export a shared `FormField` wrapper component that combines Shadcn UI `FormItem`, `FormLabel`, `FormControl`, and `FormMessage` so that all forms use a consistent field structure.
4. WHEN a new Shadcn UI component is needed, THE React_App SHALL install it via the Shadcn UI CLI (`shadcn add <component>`) so that component source is co-located under `src/components/ui/`.
5. THE Design_System SHALL use only CSS variables defined in `globals.css` for color values and SHALL NOT use hardcoded hex or RGB color values in component files.
