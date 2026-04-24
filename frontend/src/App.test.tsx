/**
 * App.test.tsx
 *
 * Routing integration tests.
 *
 * Verifies that each route renders the correct page component, and that
 * protected routes require authentication while public routes do not.
 *
 * Requirements: 1.4, 3.6
 */

import { render, screen } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { ProtectedRoute } from "./components/auth/ProtectedRoute.js";
import { DashboardPage } from "./pages/DashboardPage.js";
import { LoansPage } from "./pages/LoansPage.js";
import { SavingsPage } from "./pages/SavingsPage.js";
import { InsurancePage } from "./pages/InsurancePage.js";
import { PensionsPage } from "./pages/PensionsPage.js";
import { LoginPage } from "./pages/auth/LoginPage.js";
import { AuthProvider } from "./hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

jest.mock("./api/authApi.js", () => {
  class MockAuthApiError extends Error {
    code: string;
    status: number;
    constructor(status: number, body: { error: string; message: string }) {
      super(body.message);
      this.name = "AuthApiError";
      this.code = body.error;
      this.status = status;
    }
  }
  return {
    login: jest.fn(),
    verifyOtp: jest.fn(),
    logout: jest.fn().mockResolvedValue({ message: "ok" }),
    refreshToken: jest.fn(),
    AuthApiError: MockAuthApiError,
  };
});

// The shared FormField uses Shadcn's FormLabel/FormControl which require a
// react-hook-form FormProvider context. Since these routing tests only verify
// that the correct page is rendered (not form behaviour), we replace it with
// a lightweight stub that renders the label and children without the RHF
// context dependency.
jest.mock("./components/shared/FormField.js", () => ({
  FormField: ({
    label,
    name,
    children,
    error,
  }: {
    label: string;
    name: string;
    children: React.ReactNode;
    error?: string;
  }) => (
    <div>
      <label htmlFor={name}>{label}</label>
      {children}
      {error && <span>{error}</span>}
    </div>
  ),
}));

import React from "react";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Renders a route tree using MemoryRouter so we can test specific paths
 * without relying on the BrowserRouter inside App.tsx.
 */
function renderRoute(initialPath: string) {
  return render(
    <AuthProvider>
      <MemoryRouter initialEntries={[initialPath]}>
        <Routes>
          {/* Public routes */}
          <Route path="/login" element={<LoginPage />} />

          {/* Protected routes */}
          <Route element={<ProtectedRoute />}>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/loans" element={<LoansPage />} />
            <Route path="/savings" element={<SavingsPage />} />
            <Route path="/insurance" element={<InsurancePage />} />
            <Route path="/pensions" element={<PensionsPage />} />
          </Route>
        </Routes>
      </MemoryRouter>
    </AuthProvider>
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("Routing integration", () => {
  beforeEach(() => {
    localStorage.setItem("auth_token", "test-token");
  });

  afterEach(() => {
    localStorage.removeItem("auth_token");
    jest.clearAllMocks();
  });

  describe("protected routes (authenticated)", () => {
    it("navigating to / renders DashboardPage", () => {
      renderRoute("/");
      expect(screen.getByRole("heading", { name: /^dashboard$/i })).toBeInTheDocument();
    });

    it("navigating to /loans renders LoansPage", () => {
      renderRoute("/loans");
      expect(screen.getByRole("heading", { name: /^loans$/i })).toBeInTheDocument();
    });

    it("navigating to /savings renders SavingsPage", () => {
      renderRoute("/savings");
      expect(screen.getByRole("heading", { name: /^savings$/i })).toBeInTheDocument();
    });

    it("navigating to /insurance renders InsurancePage", () => {
      renderRoute("/insurance");
      expect(screen.getByRole("heading", { name: /^insurance$/i })).toBeInTheDocument();
    });

    it("navigating to /pensions renders PensionsPage", () => {
      renderRoute("/pensions");
      expect(screen.getByRole("heading", { name: /^pensions$/i })).toBeInTheDocument();
    });
  });

  describe("public routes", () => {
    it("navigating to /login renders LoginPage without AppLayout", () => {
      renderRoute("/login");
      // LoginPage renders a "Log in" CardTitle (rendered as a div by Shadcn)
      expect(screen.getByText(/^log in$/i)).toBeInTheDocument();
      // AppLayout renders "FinanceApp" in the header — it must NOT be present
      expect(screen.queryByText("FinanceApp")).not.toBeInTheDocument();
    });
  });

  describe("unauthenticated access", () => {
    it("navigating to a protected route without auth_token redirects to /login", () => {
      localStorage.removeItem("auth_token");
      renderRoute("/");
      // After redirect, LoginPage should be rendered
      expect(screen.getByText(/^log in$/i)).toBeInTheDocument();
    });
  });
});
