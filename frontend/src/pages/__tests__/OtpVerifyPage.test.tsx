/**
 * OtpVerifyPage.test.tsx
 *
 * Component tests for OtpVerifyPage.
 * Covers: rendering, OTP input, countdown timer state, resend button state,
 * verify button disabled when expired, and API error display.
 */

import { render, screen, fireEvent, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { OtpVerifyPage } from "../OtpVerifyPage.js";
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
    verifyOtp: jest.fn(),
    requestOtp: jest.fn(),
    login: jest.fn(),
    logout: jest.fn().mockResolvedValue({ message: "ok" }),
    refreshToken: jest.fn(),
    AuthApiError: MockAuthApiError,
  };
});

import * as authApiMock from "../../api/authApi.js";
const mockVerifyOtp = authApiMock.verifyOtp as jest.MockedFunction<typeof authApiMock.verifyOtp>;
const mockRequestOtp = authApiMock.requestOtp as jest.MockedFunction<typeof authApiMock.requestOtp>;
const MockAuthApiError = authApiMock.AuthApiError as typeof import("../../api/authApi.js").AuthApiError;

const originalLocation = window.location;
beforeAll(() => {
  Object.defineProperty(window, "location", {
    configurable: true,
    value: { href: "", search: "" },
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

function renderOtpVerifyPage(props?: { identifier?: string; onSuccess?: () => void }) {
  return render(
    <AuthProvider>
      <OtpVerifyPage identifier="user@example.com" {...props} />
    </AuthProvider>
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("OtpVerifyPage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe("rendering", () => {
    it("renders the heading", () => {
      renderOtpVerifyPage();
      expect(screen.getByRole("heading", { name: /enter verification code/i })).toBeInTheDocument();
    });

    it("renders the OTP input", () => {
      renderOtpVerifyPage();
      expect(document.getElementById("otp")).not.toBeNull();
    });

    it("renders the countdown timer with initial value", () => {
      renderOtpVerifyPage();
      expect(screen.getByText(/code expires in 10:00/i)).toBeInTheDocument();
    });

    it("renders the verify button as enabled initially", () => {
      renderOtpVerifyPage();
      expect(screen.getByRole("button", { name: /^verify$/i })).not.toBeDisabled();
    });

    it("renders the resend button as disabled initially", () => {
      renderOtpVerifyPage();
      expect(screen.getByRole("button", { name: /resend/i })).toBeDisabled();
    });

    it("shows the identifier in the description", () => {
      renderOtpVerifyPage({ identifier: "user@example.com" });
      expect(screen.getByText(/user@example\.com/)).toBeInTheDocument();
    });
  });

  describe("countdown timer", () => {
    it("decrements the timer each second", () => {
      renderOtpVerifyPage();
      act(() => { jest.advanceTimersByTime(5000); });
      expect(screen.getByText(/code expires in 09:55/i)).toBeInTheDocument();
    });

    it("shows 'Code expired' when timer reaches zero", () => {
      renderOtpVerifyPage();
      act(() => { jest.advanceTimersByTime(10 * 60 * 1000); });
      expect(screen.getByText(/code expired/i)).toBeInTheDocument();
    });

    it("disables the verify button when timer expires", () => {
      renderOtpVerifyPage();
      act(() => { jest.advanceTimersByTime(10 * 60 * 1000); });
      expect(screen.getByRole("button", { name: /^verify$/i })).toBeDisabled();
    });

    it("enables the resend button when timer expires", () => {
      renderOtpVerifyPage();
      act(() => { jest.advanceTimersByTime(10 * 60 * 1000); });
      expect(screen.getByRole("button", { name: /resend/i })).not.toBeDisabled();
    });
  });

  describe("OTP input", () => {
    it("only accepts numeric digits", () => {
      renderOtpVerifyPage();
      const input = document.getElementById("otp") as HTMLInputElement;
      // Simulate typing non-numeric characters — the onChange handler filters them
      fireEvent.change(input, { target: { value: "abc123def" } });
      expect(input).toHaveValue("123");
    });

    it("limits input to 6 characters", () => {
      renderOtpVerifyPage();
      const input = document.getElementById("otp") as HTMLInputElement;
      fireEvent.change(input, { target: { value: "1234567890" } });
      expect(input).toHaveValue("123456");
    });
  });

  describe("verification", () => {
    it("shows an error when OTP is less than 6 digits", async () => {
      renderOtpVerifyPage();
      const input = document.getElementById("otp") as HTMLInputElement;
      fireEvent.change(input, { target: { value: "123" } });
      fireEvent.submit(screen.getByRole("form", { name: /otp verification form/i }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/6-digit code/i);
    });

    it("calls loginWithOtp and calls onSuccess on valid OTP", async () => {
      mockVerifyOtp.mockResolvedValueOnce({ token: makeJwt("1") });
      const onSuccess = jest.fn();
      renderOtpVerifyPage({ onSuccess });

      const input = document.getElementById("otp") as HTMLInputElement;
      fireEvent.change(input, { target: { value: "123456" } });
      fireEvent.submit(screen.getByRole("form", { name: /otp verification form/i }));

      await waitFor(() => {
        expect(onSuccess).toHaveBeenCalled();
      });
    });

    it("displays an error message on invalid OTP", async () => {
      mockVerifyOtp.mockRejectedValueOnce(
        new MockAuthApiError(401, {
          error: "otp_invalid",
          message: "The OTP is invalid or has expired.",
        })
      );
      renderOtpVerifyPage();

      const input = document.getElementById("otp") as HTMLInputElement;
      fireEvent.change(input, { target: { value: "000000" } });
      fireEvent.submit(screen.getByRole("form", { name: /otp verification form/i }));

      expect(await screen.findByRole("alert")).toHaveTextContent(/invalid or has expired/i);
    });
  });

  describe("resend", () => {
    it("calls requestOtp and resets the timer on resend", async () => {
      mockRequestOtp.mockResolvedValueOnce({ message: "ok" });
      renderOtpVerifyPage();

      // Expire the timer using fake timers
      act(() => { jest.advanceTimersByTime(10 * 60 * 1000); });

      // Click resend — use real timers for the async operation
      jest.useRealTimers();
      await userEvent.click(screen.getByRole("button", { name: /resend verification code/i }));

      await waitFor(() => {
        expect(mockRequestOtp).toHaveBeenCalledWith({ identifier: "user@example.com" });
      });

      // Timer should have reset
      expect(screen.getByText(/code expires in 10:00/i)).toBeInTheDocument();
    });
  });
});
