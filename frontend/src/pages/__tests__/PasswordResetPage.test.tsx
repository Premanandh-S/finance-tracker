/**
 * PasswordResetPage.test.tsx
 *
 * Component tests for PasswordResetPage.
 * Covers: step 1 rendering and validation, step 2 rendering and validation,
 * successful reset flow, and API error display.
 */

import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PasswordResetPage } from "../PasswordResetPage.js";

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
    requestPasswordReset: jest.fn(),
    confirmPasswordReset: jest.fn(),
    AuthApiError: MockAuthApiError,
  };
});

import * as authApiMock from "../../api/authApi.js";
const mockRequestPasswordReset = authApiMock.requestPasswordReset as jest.MockedFunction<
  typeof authApiMock.requestPasswordReset
>;
const mockConfirmPasswordReset = authApiMock.confirmPasswordReset as jest.MockedFunction<
  typeof authApiMock.confirmPasswordReset
>;
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

async function advanceToConfirmStep() {
  mockRequestPasswordReset.mockResolvedValueOnce({ message: "ok" });
  await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
  fireEvent.submit(screen.getByRole("form", { name: /password reset request form/i }));
  await screen.findByRole("form", { name: /password reset confirm form/i });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("PasswordResetPage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("Step 1 — Request", () => {
    it("renders the request step heading", () => {
      render(<PasswordResetPage />);
      expect(screen.getByRole("heading", { name: /reset your password/i })).toBeInTheDocument();
    });

    it("renders the identifier input", () => {
      render(<PasswordResetPage />);
      expect(screen.getByLabelText(/phone number or email/i)).toBeInTheDocument();
    });

    it("renders a back to login link", () => {
      render(<PasswordResetPage />);
      expect(screen.getByRole("link", { name: /back to login/i })).toHaveAttribute("href", "/login");
    });

    it("shows a validation error for empty identifier", async () => {
      render(<PasswordResetPage />);
      fireEvent.submit(screen.getByRole("form", { name: /password reset request form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        /please enter a phone number or email/i
      );
    });

    it("shows a validation error for invalid identifier format", async () => {
      render(<PasswordResetPage />);
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "not-valid");
      fireEvent.submit(screen.getByRole("form", { name: /password reset request form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/valid phone number/i);
    });

    it("advances to confirm step on successful request", async () => {
      render(<PasswordResetPage />);
      await advanceToConfirmStep();
      expect(screen.getByRole("heading", { name: /enter your new password/i })).toBeInTheDocument();
    });

    it("displays API error on request failure", async () => {
      mockRequestPasswordReset.mockRejectedValueOnce(
        new MockAuthApiError(429, {
          error: "otp_rate_limit",
          message: "Too many OTP requests. Please wait before trying again.",
        })
      );
      render(<PasswordResetPage />);
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /password reset request form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/too many otp requests/i);
    });
  });

  describe("Step 2 — Confirm", () => {
    beforeEach(async () => {
      render(<PasswordResetPage />);
      await advanceToConfirmStep();
    });

    it("renders the confirm step heading", () => {
      expect(screen.getByRole("heading", { name: /enter your new password/i })).toBeInTheDocument();
    });

    it("renders the OTP and new password inputs", () => {
      expect(screen.getByLabelText(/verification code/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/new password/i)).toBeInTheDocument();
    });

    it("shows a validation error for empty OTP", async () => {
      await userEvent.type(screen.getByLabelText(/new password/i), "newpassword");
      fireEvent.submit(screen.getByRole("form", { name: /password reset confirm form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/6-digit code/i);
    });

    it("shows a validation error for OTP that is not 6 digits", async () => {
      await userEvent.type(screen.getByLabelText(/verification code/i), "123");
      await userEvent.type(screen.getByLabelText(/new password/i), "newpassword");
      fireEvent.submit(screen.getByRole("form", { name: /password reset confirm form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/exactly 6 digits/i);
    });

    it("shows a validation error for password shorter than 8 characters", async () => {
      await userEvent.type(screen.getByLabelText(/verification code/i), "123456");
      await userEvent.type(screen.getByLabelText(/new password/i), "short");
      fireEvent.submit(screen.getByRole("form", { name: /password reset confirm form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/at least 8 characters/i);
    });

    it("calls confirmPasswordReset with correct payload on valid submission", async () => {
      mockConfirmPasswordReset.mockResolvedValueOnce({ message: "ok" });

      await userEvent.type(screen.getByLabelText(/verification code/i), "123456");
      await userEvent.type(screen.getByLabelText(/new password/i), "newpassword");
      fireEvent.submit(screen.getByRole("form", { name: /password reset confirm form/i }));

      await waitFor(() => {
        expect(mockConfirmPasswordReset).toHaveBeenCalledWith({
          identifier: "user@example.com",
          otp: "123456",
          new_password: "newpassword",
        });
      });
    });

    it("displays API error on confirm failure", async () => {
      mockConfirmPasswordReset.mockRejectedValueOnce(
        new MockAuthApiError(401, {
          error: "otp_invalid",
          message: "The OTP is invalid or has expired.",
        })
      );

      await userEvent.type(screen.getByLabelText(/verification code/i), "000000");
      await userEvent.type(screen.getByLabelText(/new password/i), "newpassword");
      fireEvent.submit(screen.getByRole("form", { name: /password reset confirm form/i }));

      expect(await screen.findByRole("alert")).toHaveTextContent(/invalid or has expired/i);
    });
  });
});
