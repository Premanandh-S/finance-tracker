/**
 * ProtectedRoute.test.tsx
 *
 * Component tests for ProtectedRoute.
 * Covers: renders children when authenticated, redirects when unauthenticated,
 * shows loading fallback while auth state is loading.
 */

import { render, screen, waitFor } from "@testing-library/react";
import { ProtectedRoute } from "../ProtectedRoute.js";
import { AuthContext } from "../../hooks/useAuth.js";
import type { AuthContextValue } from "../../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Mocks — prevent import.meta from being evaluated in authApi
// ---------------------------------------------------------------------------

jest.mock("../../api/authApi.js", () => ({
  verifyOtp: jest.fn(),
  login: jest.fn(),
  logout: jest.fn(),
  refreshToken: jest.fn(),
  AuthApiError: class AuthApiError extends Error {
    code: string;
    status: number;
    constructor(status: number, body: { error: string; message: string }) {
      super(body.message);
      this.code = body.error;
      this.status = status;
    }
  },
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const originalLocation = window.location;
beforeAll(() => {
  Object.defineProperty(window, "location", {
    configurable: true,
    value: { href: "" },
  });
});
afterAll(() => {
  Object.defineProperty(window, "location", {
    configurable: true,
    value: originalLocation,
  });
});

function makeAuthContext(overrides: Partial<AuthContextValue>): AuthContextValue {
  return {
    token: null,
    user: null,
    isAuthenticated: false,
    isLoading: false,
    loginWithOtp: jest.fn(),
    loginWithPassword: jest.fn(),
    logout: jest.fn(),
    handleUnauthorized: jest.fn(),
    ...overrides,
  };
}

function renderWithAuth(ctx: AuthContextValue, children: React.ReactNode) {
  return render(
    <AuthContext.Provider value={ctx}>
      <ProtectedRoute>{children}</ProtectedRoute>
    </AuthContext.Provider>
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("ProtectedRoute", () => {
  beforeEach(() => {
    (window.location as { href: string }).href = "";
  });

  it("renders children when the user is authenticated", () => {
    const ctx = makeAuthContext({ isAuthenticated: true, token: "tok", user: { id: "1" } });
    renderWithAuth(ctx, <div>Protected content</div>);
    expect(screen.getByText("Protected content")).toBeInTheDocument();
  });

  it("redirects to /login when the user is not authenticated", async () => {
    const ctx = makeAuthContext({ isAuthenticated: false });
    renderWithAuth(ctx, <div>Protected content</div>);

    await waitFor(() => {
      expect(window.location.href).toBe("/login");
    });
    expect(screen.queryByText("Protected content")).not.toBeInTheDocument();
  });

  it("redirects to a custom path when redirectTo is provided", async () => {
    const ctx = makeAuthContext({ isAuthenticated: false });
    render(
      <AuthContext.Provider value={ctx}>
        <ProtectedRoute redirectTo="/auth/login">
          <div>Protected content</div>
        </ProtectedRoute>
      </AuthContext.Provider>
    );

    await waitFor(() => {
      expect(window.location.href).toBe("/auth/login");
    });
  });

  it("shows the loading fallback while auth state is loading", () => {
    const ctx = makeAuthContext({ isLoading: true });
    renderWithAuth(ctx, <div>Protected content</div>);
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
    expect(screen.queryByText("Protected content")).not.toBeInTheDocument();
  });

  it("renders a custom loading fallback", () => {
    const ctx = makeAuthContext({ isLoading: true });
    render(
      <AuthContext.Provider value={ctx}>
        <ProtectedRoute loadingFallback={<span>Please wait…</span>}>
          <div>Protected content</div>
        </ProtectedRoute>
      </AuthContext.Provider>
    );
    expect(screen.getByText("Please wait…")).toBeInTheDocument();
  });
});
