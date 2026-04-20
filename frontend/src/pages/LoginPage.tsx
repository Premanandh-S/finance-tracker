/**
 * LoginPage.tsx
 *
 * Login page. Accepts an identifier (phone or email), lets the user choose
 * between OTP and password authentication, validates the form, and dispatches
 * to the appropriate auth flow via authApi / useAuth.
 *
 * OTP path: calls POST /auth/login with method "otp" to trigger OTP delivery,
 * then redirects to the OTP verification page.
 *
 * Password path: calls loginWithPassword from useAuth, which calls
 * POST /auth/login with method "password" and stores the returned JWT.
 */

import { useState, type FormEvent, type JSX } from "react";
import { login, AuthApiError } from "../api/authApi.js";
import { useAuth } from "../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type AuthMethod = "otp" | "password";

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

function validatePassword(value: string): string | null {
  if (!value) return "Please enter your password.";
  return null;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * `LoginPage` renders the login form.
 *
 * Props:
 * - `onOtpSent` — called after OTP is successfully dispatched so the parent
 *   can navigate to the OTP verification page. Receives the identifier.
 * - `onPasswordSuccess` — called after a successful password login so the
 *   parent can navigate to the dashboard.
 */
export interface LoginPageProps {
  /** Called with the identifier after OTP is dispatched. */
  onOtpSent?: (identifier: string) => void;
  /** Called after a successful password login. */
  onPasswordSuccess?: () => void;
}

export function LoginPage({ onOtpSent, onPasswordSuccess }: LoginPageProps): JSX.Element {
  const { loginWithPassword } = useAuth();

  // Form field state
  const [identifier, setIdentifier] = useState("");
  const [method, setMethod] = useState<AuthMethod>("otp");
  const [password, setPassword] = useState("");

  // UI state
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Per-field validation errors
  const [fieldErrors, setFieldErrors] = useState<{
    identifier?: string;
    password?: string;
  }>({});

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  function handleMethodChange(newMethod: AuthMethod): void {
    setMethod(newMethod);
    if (newMethod === "otp") {
      setPassword("");
      setFieldErrors((prev) => ({ ...prev, password: undefined }));
    }
    setErrorMessage(null);
  }

  async function handleSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    setErrorMessage(null);

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
      if (method === "otp") {
        // Trigger OTP delivery via login endpoint
        await login({ identifier: identifier.trim(), method: "otp" });

        if (onOtpSent) {
          onOtpSent(identifier.trim());
        } else {
          const params = new URLSearchParams({ identifier: identifier.trim() });
          window.location.href = `/otp/verify?${params.toString()}`;
        }
      } else {
        // Password login — useAuth stores the JWT
        await loginWithPassword(identifier.trim(), password);

        if (onPasswordSuccess) {
          onPasswordSuccess();
        } else {
          window.location.href = "/dashboard";
        }
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
    <main className="auth-page login-page">
      <h1>Log in</h1>

      <form onSubmit={handleSubmit} noValidate aria-label="Login form">
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
              autoComplete="current-password"
              placeholder="Your password"
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

        <button type="submit" disabled={isLoading} className="btn-primary">
          {isLoading ? "Logging in…" : "Log in"}
        </button>
      </form>

      <p className="auth-link">
        <a href="/password/reset">Forgot your password?</a>
      </p>

      <p className="auth-link">
        Don&apos;t have an account?{" "}
        <a href="/signup">Sign up</a>
      </p>
    </main>
  );
}

export default LoginPage;
