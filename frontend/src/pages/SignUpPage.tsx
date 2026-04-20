/**
 * SignUpPage.tsx
 *
 * Registration page. Accepts an identifier (phone or email), lets the user
 * choose between OTP-only and password-based authentication, validates the
 * form client-side, and calls the register endpoint via authApi.
 *
 * On success the user is redirected to the OTP verification page so they can
 * complete account activation.
 */

import { useState, type FormEvent, type JSX } from "react";
import { register, AuthApiError } from "../api/authApi.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type AuthMethod = "otp" | "password";

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

/** E.164 phone number: + followed by 7–15 digits. */
const E164_REGEX = /^\+[1-9]\d{6,14}$/;

/** Simplified RFC 5322 email check. */
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateIdentifier(value: string): string | null {
  if (!value.trim()) return "Please enter a phone number or email address.";
  if (!E164_REGEX.test(value) && !EMAIL_REGEX.test(value)) {
    return "Please enter a valid phone number (e.g. +14155552671) or email address.";
  }
  return null;
}

function validatePassword(value: string): string | null {
  if (!value) return "Please enter a password.";
  if (value.length < 8) return "Password must be at least 8 characters.";
  return null;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * `SignUpPage` renders the registration form.
 *
 * Props:
 * - `onSuccess` — called after a successful registration so the parent can
 *   navigate to the OTP verification page. Receives the identifier so the
 *   verify page can pre-fill it.
 */
export interface SignUpPageProps {
  /** Called with the registered identifier after a successful API call. */
  onSuccess?: (identifier: string) => void;
}

export function SignUpPage({ onSuccess }: SignUpPageProps): JSX.Element {
  // Form field state
  const [identifier, setIdentifier] = useState("");
  const [method, setMethod] = useState<AuthMethod>("otp");
  const [password, setPassword] = useState("");

  // UI state
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Per-field validation errors (shown after first submit attempt)
  const [fieldErrors, setFieldErrors] = useState<{
    identifier?: string;
    password?: string;
  }>({});

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  function handleMethodChange(newMethod: AuthMethod): void {
    setMethod(newMethod);
    // Clear password field and its error when switching away from password
    if (newMethod === "otp") {
      setPassword("");
      setFieldErrors((prev) => ({ ...prev, password: undefined }));
    }
    setErrorMessage(null);
  }

  async function handleSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);

    // Client-side validation
    const identifierError = validateIdentifier(identifier);
    const passwordError = method === "password" ? validatePassword(password) : null;

    if (identifierError || passwordError) {
      setFieldErrors({
        identifier: identifierError ?? undefined,
        password: passwordError ?? undefined,
      });
      return;
    }

    setFieldErrors({});
    setIsLoading(true);

    try {
      await register({
        identifier: identifier.trim(),
        ...(method === "password" ? { password } : {}),
      });

      setSuccessMessage(
        "Account created! Check your phone or email for a verification code."
      );

      if (onSuccess) {
        onSuccess(identifier.trim());
      } else {
        // Default navigation: redirect to OTP verify page with identifier in query
        const params = new URLSearchParams({ identifier: identifier.trim() });
        window.location.href = `/otp/verify?${params.toString()}`;
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
  // Render
  // -------------------------------------------------------------------------

  return (
    <main className="auth-page sign-up-page">
      <h1>Create your account</h1>

      <form onSubmit={handleSubmit} noValidate aria-label="Sign up form">
        {/* Identifier field */}
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

        {/* Authentication method selection */}
        <fieldset className="method-selection">
          <legend>Authentication method</legend>

          <label className="method-option">
            <input
              type="radio"
              name="auth-method"
              value="otp"
              checked={method === "otp"}
              onChange={() => handleMethodChange("otp")}
              disabled={isLoading}
            />
            One-time password (OTP)
          </label>

          <label className="method-option">
            <input
              type="radio"
              name="auth-method"
              value="password"
              checked={method === "password"}
              onChange={() => handleMethodChange("password")}
              disabled={isLoading}
            />
            Password
          </label>
        </fieldset>

        {/* Password field — only shown when method is "password" */}
        {method === "password" && (
          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              autoComplete="new-password"
              placeholder="At least 8 characters"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (fieldErrors.password) {
                  setFieldErrors((prev) => ({ ...prev, password: undefined }));
                }
              }}
              aria-describedby={fieldErrors.password ? "password-error" : undefined}
              aria-invalid={!!fieldErrors.password}
              disabled={isLoading}
            />
            {fieldErrors.password && (
              <span id="password-error" className="field-error" role="alert">
                {fieldErrors.password}
              </span>
            )}
          </div>
        )}

        {/* API-level error */}
        {errorMessage && (
          <div className="form-error" role="alert">
            {errorMessage}
          </div>
        )}

        {/* Success message */}
        {successMessage && (
          <div className="form-success" role="status">
            {successMessage}
          </div>
        )}

        <button type="submit" disabled={isLoading} className="btn-primary">
          {isLoading ? "Creating account…" : "Create account"}
        </button>
      </form>

      <p className="auth-link">
        Already have an account?{" "}
        <a href="/login">Log in</a>
      </p>
    </main>
  );
}

export default SignUpPage;
