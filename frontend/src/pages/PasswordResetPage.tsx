/**
 * PasswordResetPage.tsx
 *
 * Two-step password reset flow:
 *
 * Step 1 — Request: user enters their identifier; the backend sends an OTP.
 * Step 2 — Confirm: user enters the OTP and a new password; on success all
 *           existing sessions are invalidated and the user is redirected to
 *           the login page.
 *
 * The backend always returns a generic success response for the request step
 * regardless of whether the identifier is registered (no enumeration).
 */

import { useState, type FormEvent, type JSX } from "react";
import {
  requestPasswordReset,
  confirmPasswordReset,
  AuthApiError,
} from "../api/authApi.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ResetStep = "request" | "confirm";

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

const E164_REGEX = /^\+[1-9]\d{6,14}$/;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateIdentifier(value: string): string | null {
  if (!value.trim()) return "Please enter a phone number or email address.";
  if (!E164_REGEX.test(value) && !EMAIL_REGEX.test(value)) {
    return "Please enter a valid phone number (e.g. +14155552671) or email address.";
  }
  return null;
}

function validateOtp(value: string): string | null {
  if (!value) return "Please enter the 6-digit code.";
  if (!/^\d{6}$/.test(value)) return "The code must be exactly 6 digits.";
  return null;
}

function validatePassword(value: string): string | null {
  if (!value) return "Please enter a new password.";
  if (value.length < 8) return "Password must be at least 8 characters.";
  return null;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * `PasswordResetPage` renders the two-step password reset flow.
 *
 * Props:
 * - `onSuccess` — called after a successful password reset so the parent can
 *   navigate to the login page.
 */
export interface PasswordResetPageProps {
  /** Called after a successful password reset. */
  onSuccess?: () => void;
}

export function PasswordResetPage({ onSuccess }: PasswordResetPageProps): JSX.Element {
  // Step state
  const [step, setStep] = useState<ResetStep>("request");

  // Step 1 fields
  const [identifier, setIdentifier] = useState("");

  // Step 2 fields
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");

  // UI state
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Per-field validation errors
  const [fieldErrors, setFieldErrors] = useState<{
    identifier?: string;
    otp?: string;
    newPassword?: string;
  }>({});

  // -------------------------------------------------------------------------
  // Step 1: Request reset
  // -------------------------------------------------------------------------

  async function handleRequestSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);

    const identifierError = validateIdentifier(identifier);
    if (identifierError) {
      setFieldErrors({ identifier: identifierError });
      return;
    }

    setFieldErrors({});
    setIsLoading(true);

    try {
      await requestPasswordReset({ identifier: identifier.trim() });
      // Always advance to confirm step — backend returns generic success
      setStep("confirm");
    } catch (err) {
      if (err instanceof AuthApiError) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage("Something went wrong, please try again.");
      }
    } finally {
      setIsLoading(false);
    }
  }

  // -------------------------------------------------------------------------
  // Step 2: Confirm reset
  // -------------------------------------------------------------------------

  async function handleConfirmSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);

    const otpError = validateOtp(otp);
    const passwordError = validatePassword(newPassword);

    if (otpError || passwordError) {
      setFieldErrors({
        otp: otpError ?? undefined,
        newPassword: passwordError ?? undefined,
      });
      return;
    }

    setFieldErrors({});
    setIsLoading(true);

    try {
      await confirmPasswordReset({
        identifier: identifier.trim(),
        otp,
        new_password: newPassword,
      });

      setSuccessMessage("Password reset successfully. You can now log in with your new password.");

      if (onSuccess) {
        onSuccess();
      } else {
        window.location.href = "/login";
      }
    } catch (err) {
      if (err instanceof AuthApiError) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage("Something went wrong, please try again.");
      }
    } finally {
      setIsLoading(false);
    }
  }

  // -------------------------------------------------------------------------
  // Render — Step 1: Request
  // -------------------------------------------------------------------------

  if (step === "request") {
    return (
      <main className="auth-page password-reset-page">
        <h1>Reset your password</h1>
        <p>Enter your phone number or email and we&apos;ll send you a reset code.</p>

        <form onSubmit={handleRequestSubmit} noValidate aria-label="Password reset request form">
          <div className="form-group">
            <label htmlFor="identifier">Phone number or email</label>
            <input
              id="identifier"
              type="text"
              autoComplete="username"
              placeholder="+14155552671 or you@example.com"
              value={identifier}
              onChange={(e) => {
                setIdentifier(e.target.value);
                if (fieldErrors.identifier) {
                  setFieldErrors((prev) => ({ ...prev, identifier: undefined }));
                }
              }}
              aria-describedby={fieldErrors.identifier ? "identifier-error" : undefined}
              aria-invalid={!!fieldErrors.identifier}
              disabled={isLoading}
            />
            {fieldErrors.identifier && (
              <span id="identifier-error" className="field-error" role="alert">
                {fieldErrors.identifier}
              </span>
            )}
          </div>

          {errorMessage && (
            <div className="form-error" role="alert">
              {errorMessage}
            </div>
          )}

          <button type="submit" disabled={isLoading} className="btn-primary">
            {isLoading ? "Sending code…" : "Send reset code"}
          </button>
        </form>

        <p className="auth-link">
          <a href="/login">Back to login</a>
        </p>
      </main>
    );
  }

  // -------------------------------------------------------------------------
  // Render — Step 2: Confirm
  // -------------------------------------------------------------------------

  return (
    <main className="auth-page password-reset-page">
      <h1>Enter your new password</h1>
      <p>
        We sent a 6-digit code to <strong>{identifier}</strong>. Enter it below
        along with your new password.
      </p>

      <form onSubmit={handleConfirmSubmit} noValidate aria-label="Password reset confirm form">
        {/* OTP field */}
        <div className="form-group">
          <label htmlFor="otp">Verification code</label>
          <input
            id="otp"
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={6}
            value={otp}
            onChange={(e) => {
              const sanitized = e.target.value.replace(/\D/g, "").slice(0, 6);
              setOtp(sanitized);
              if (fieldErrors.otp) {
                setFieldErrors((prev) => ({ ...prev, otp: undefined }));
              }
            }}
            aria-describedby={fieldErrors.otp ? "otp-error" : undefined}
            aria-invalid={!!fieldErrors.otp}
            disabled={isLoading}
          />
          {fieldErrors.otp && (
            <span id="otp-error" className="field-error" role="alert">
              {fieldErrors.otp}
            </span>
          )}
        </div>

        {/* New password field */}
        <div className="form-group">
          <label htmlFor="new-password">New password</label>
          <input
            id="new-password"
            type="password"
            autoComplete="new-password"
            placeholder="At least 8 characters"
            value={newPassword}
            onChange={(e) => {
              setNewPassword(e.target.value);
              if (fieldErrors.newPassword) {
                setFieldErrors((prev) => ({ ...prev, newPassword: undefined }));
              }
            }}
            aria-describedby={fieldErrors.newPassword ? "new-password-error" : undefined}
            aria-invalid={!!fieldErrors.newPassword}
            disabled={isLoading}
          />
          {fieldErrors.newPassword && (
            <span id="new-password-error" className="field-error" role="alert">
              {fieldErrors.newPassword}
            </span>
          )}
        </div>

        {errorMessage && (
          <div className="form-error" role="alert">
            {errorMessage}
          </div>
        )}

        {successMessage && (
          <div className="form-success" role="status">
            {successMessage}
          </div>
        )}

        <button type="submit" disabled={isLoading} className="btn-primary">
          {isLoading ? "Resetting password…" : "Reset password"}
        </button>
      </form>

      <p className="auth-link">
        <a href="/login">Back to login</a>
      </p>
    </main>
  );
}

export default PasswordResetPage;
