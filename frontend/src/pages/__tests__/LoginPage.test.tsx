/**
 * LoginPage.test.tsx
 *
 * Component tests for LoginPage.
 * Covers: rendering, method selection toggle, client-side validation,
 * OTP dispatch, password login, and API error display.
 */

import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoginPage } from "../LoginPage.js";
import { AuthProvider } from "../../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

jest.mock("../../api/authApi.js", () => {
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

import * as authApiMock from "../../api/authApi.js";
const mockLogin = authApiMock.login as jest.MockedFunction<typeof authApiMock.login>;
const MockAuthApiError = authApiMock.AuthApiError as typeof import("../../api/authApi.js").AuthApiError;

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeJwt(sub: string): string {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({ sub, iat: 1700000000, exp: 1700086400 }));
  return `${header}.${payload}.fakesig`;
}

function renderLoginPage(props?: { onOtpSent?: (id: string) => void; onPasswordSuccess?: () => void }) {
  return render(
    <AuthProvider>
      <LoginPage {...props} />
    </AuthProvider>
  );
}

// Helper to get the password input field (not the radio button)
function getPasswordInput() {
  return document.getElementById("password") as HTMLInputElement | null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("LoginPage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("rendering", () => {
    it("renders the heading", () => {
      renderLoginPage();
      expect(screen.getByRole("heading", { name: /log in/i })).toBeInTheDocument();
    });

    it("renders the identifier input", () => {
      renderLoginPage();
      expect(screen.getByLabelText(/phone number or email/i)).toBeInTheDocument();
    });

    it("renders OTP and password radio buttons", () => {
      renderLoginPage();
      // Use exact names to avoid ambiguity with "One-time password (OTP)" matching /password/i
      expect(screen.getByRole("radio", { name: /one-time password \(otp\)/i })).toBeInTheDocument();
      expect(screen.getByRole("radio", { name: /^password$/i })).toBeInTheDocument();
    });

    it("defaults to OTP method — password input field is not visible", () => {
      renderLoginPage();
      expect(getPasswordInput()).toBeNull();
    });

    it("renders a forgot password link", () => {
      renderLoginPage();
      expect(screen.getByRole("link", { name: /forgot your password/i })).toHaveAttribute(
        "href",
        "/password/reset"
      );
    });

    it("renders a sign up link", () => {
      renderLoginPage();
      expect(screen.getByRole("link", { name: /sign up/i })).toHaveAttribute("href", "/signup");
    });
  });

  describe("method selection", () => {
    it("shows the password input when password method is selected", async () => {
      renderLoginPage();
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      expect(getPasswordInput()).not.toBeNull();
    });

    it("hides the password input when switching back to OTP", async () => {
      renderLoginPage();
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.click(screen.getByRole("radio", { name: /one-time password \(otp\)/i }));
      expect(getPasswordInput()).toBeNull();
    });
  });

  describe("client-side validation", () => {
    it("shows an error when identifier is empty on submit", async () => {
      renderLoginPage();
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        /please enter a phone number or email/i
      );
    });

    it("shows an error for an invalid identifier format", async () => {
      renderLoginPage();
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "not-valid");
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/valid phone number/i);
    });

    it("shows a password error when password method is selected and field is empty", async () => {
      renderLoginPage();
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/please enter your password/i);
    });
  });

  describe("OTP login flow", () => {
    it("calls login with method otp and calls onOtpSent on success", async () => {
      mockLogin.mockResolvedValueOnce({ token: "" });
      const onOtpSent = jest.fn();
      renderLoginPage({ onOtpSent });

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));

      await waitFor(() => {
        expect(mockLogin).toHaveBeenCalledWith({
          identifier: "user@example.com",
          method: "otp",
        });
        expect(onOtpSent).toHaveBeenCalledWith("user@example.com");
      });
    });
  });

  describe("password login flow", () => {
    it("calls login with password method and calls onPasswordSuccess on success", async () => {
      mockLogin.mockResolvedValueOnce({ token: makeJwt("1") });
      const onPasswordSuccess = jest.fn();
      renderLoginPage({ onPasswordSuccess });

      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      // Type into the password input field directly
      const passwordInput = getPasswordInput()!;
      await userEvent.type(passwordInput, "securepassword");
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));

      await waitFor(() => {
        expect(onPasswordSuccess).toHaveBeenCalled();
      });
    });
  });

  describe("API error handling", () => {
    it("displays the error message when login fails", async () => {
      mockLogin.mockRejectedValueOnce(
        new MockAuthApiError(401, {
          error: "invalid_credentials",
          message: "Invalid credentials. Please try again.",
        })
      );
      renderLoginPage();

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /login form/i }));

      expect(await screen.findByRole("alert")).toHaveTextContent(/invalid credentials/i);
    });
  });
});
