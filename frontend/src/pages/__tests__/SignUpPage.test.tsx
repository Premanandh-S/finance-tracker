/**
 * SignUpPage.test.tsx
 *
 * Component tests for SignUpPage.
 * Covers: rendering, method selection toggle, client-side validation,
 * successful registration, and API error display.
 */

import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { SignUpPage } from "../SignUpPage.js";

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
    register: jest.fn(),
    AuthApiError: MockAuthApiError,
  };
});

// Import after mock so we get the mocked version
import * as authApiMock from "../../api/authApi.js";
const mockRegister = authApiMock.register as jest.MockedFunction<typeof authApiMock.register>;

// Minimal AuthApiError re-export for use in test assertions
const MockAuthApiError = authApiMock.AuthApiError as typeof import("../../api/authApi.js").AuthApiError;

// Prevent actual navigation
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
// Tests
// ---------------------------------------------------------------------------

describe("SignUpPage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("rendering", () => {
    it("renders the heading", () => {
      render(<SignUpPage />);
      expect(screen.getByRole("heading", { name: /create your account/i })).toBeInTheDocument();
    });

    it("renders the identifier input", () => {
      render(<SignUpPage />);
      expect(screen.getByLabelText(/phone number or email/i)).toBeInTheDocument();
    });

    it("renders OTP and password radio buttons", () => {
      render(<SignUpPage />);
      expect(screen.getByRole("radio", { name: /one-time password \(otp\)/i })).toBeInTheDocument();
      expect(screen.getByRole("radio", { name: /^password$/i })).toBeInTheDocument();
    });

    it("defaults to OTP method — password input field is not visible", () => {
      render(<SignUpPage />);
      expect(document.getElementById("password")).toBeNull();
    });

    it("renders a link to the login page", () => {
      render(<SignUpPage />);
      expect(screen.getByRole("link", { name: /log in/i })).toHaveAttribute("href", "/login");
    });
  });

  describe("method selection", () => {
    it("shows the password field when password method is selected", async () => {
      render(<SignUpPage />);
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      expect(document.getElementById("password")).not.toBeNull();
    });

    it("hides the password field when switching back to OTP", async () => {
      render(<SignUpPage />);
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.click(screen.getByRole("radio", { name: /one-time password \(otp\)/i }));
      expect(document.getElementById("password")).toBeNull();
    });
  });

  describe("client-side validation", () => {
    it("shows an error when identifier is empty on submit", async () => {
      render(<SignUpPage />);
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        /please enter a phone number or email/i
      );
    });

    it("shows an error for an invalid identifier format", async () => {
      render(<SignUpPage />);
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "not-valid");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/valid phone number/i);
    });

    it("shows a password error when password method is selected and field is empty", async () => {
      render(<SignUpPage />);
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/please enter a password/i);
    });

    it("shows a password length error for passwords shorter than 8 characters", async () => {
      render(<SignUpPage />);
      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      await userEvent.type(document.getElementById("password") as HTMLInputElement, "short");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/at least 8 characters/i);
    });
  });

  describe("successful registration", () => {
    it("calls register with identifier only for OTP method", async () => {
      mockRegister.mockResolvedValueOnce({ message: "ok" });
      const onSuccess = jest.fn();
      render(<SignUpPage onSuccess={onSuccess} />);

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));

      await waitFor(() => {
        expect(mockRegister).toHaveBeenCalledWith({ identifier: "user@example.com" });
      });
    });

    it("calls register with identifier and password for password method", async () => {
      mockRegister.mockResolvedValueOnce({ message: "ok" });
      const onSuccess = jest.fn();
      render(<SignUpPage onSuccess={onSuccess} />);

      await userEvent.click(screen.getByRole("radio", { name: /^password$/i }));
      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      await userEvent.type(document.getElementById("password") as HTMLInputElement, "securepassword");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));

      await waitFor(() => {
        expect(mockRegister).toHaveBeenCalledWith({
          identifier: "user@example.com",
          password: "securepassword",
        });
      });
    });

    it("calls onSuccess with the identifier after successful registration", async () => {
      mockRegister.mockResolvedValueOnce({ message: "ok" });
      const onSuccess = jest.fn();
      render(<SignUpPage onSuccess={onSuccess} />);

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalledWith("user@example.com");
      });
    });
  });

  describe("API error handling", () => {
    it("displays the error message when registration fails with AuthApiError", async () => {
      mockRegister.mockRejectedValueOnce(
        new MockAuthApiError(422, {
          error: "identifier_taken",
          message: "This identifier is already registered.",
        })
      );
      render(<SignUpPage />);

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));

      expect(await screen.findByRole("alert")).toHaveTextContent(/already registered/i);
    });

    it("displays a generic error message on network failure", async () => {
      mockRegister.mockRejectedValueOnce(new Error("Network error"));
      render(<SignUpPage />);

      await userEvent.type(screen.getByLabelText(/phone number or email/i), "user@example.com");
      fireEvent.submit(screen.getByRole("form", { name: /sign up form/i }));

      expect(await screen.findByRole("alert")).toHaveTextContent(/something went wrong/i);
    });
  });
});
