/**
 * OtpVerifyPage.tsx
 *
 * OTP verification page. Displays a 6-digit OTP input, a countdown timer
 * showing the remaining validity period (10 minutes), a resend button that
 * becomes enabled when the timer reaches zero, and a verify button that is
 * disabled once the timer expires.
 *
 * On successful verification the user is redirected to the dashboard.
 */

import {
  useState,
  useEffect,
  useRef,
  useCallback,
  type FormEvent,
  type JSX,
} from "react";
import { requestOtp, AuthApiError } from "../api/authApi.js";
import { useAuth } from "../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** OTP validity window in seconds (10 minutes). */
const OTP_TTL_SECONDS = 10 * 60;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Formats a number of seconds as MM:SS.
 *
 * @param totalSeconds - Non-negative integer number of seconds.
 * @returns A string in the format "MM:SS".
 */
function formatCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * `OtpVerifyPage` renders the OTP verification form.
 *
 * Props:
 * - `identifier` — the phone number or email address the OTP was sent to.
 *   If not provided, the component reads it from the `identifier` query param.
 * - `onSuccess` — called after successful OTP verification so the parent can
 *   navigate to the dashboard.
 */
export interface OtpVerifyPageProps {
  /** The identifier the OTP was sent to. Falls back to URL query param. */
  identifier?: string;
  /** Called after successful verification. */
  onSuccess?: () => void;
}

export function OtpVerifyPage({ identifier: identifierProp, onSuccess }: OtpVerifyPageProps): JSX.Element {
  const { loginWithOtp } = useAuth();

  // Resolve identifier from prop or URL query string
  const identifier = identifierProp ?? new URLSearchParams(window.location.search).get("identifier") ?? "";

  // OTP input state
  const [otp, setOtp] = useState("");

  // Countdown timer state
  const [secondsLeft, setSecondsLeft] = useState(OTP_TTL_SECONDS);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // UI state
  const [isVerifying, setIsVerifying] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [resendMessage, setResendMessage] = useState<string | null>(null);

  // Derived state
  const isExpired = secondsLeft === 0;
  const canResend = isExpired && !isResending;

  // -------------------------------------------------------------------------
  // Timer management
  // -------------------------------------------------------------------------

  const startTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    setSecondsLeft(OTP_TTL_SECONDS);

    timerRef.current = setInterval(() => {
      setSecondsLeft((prev) => {
        if (prev <= 1) {
          if (timerRef.current) clearInterval(timerRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, []);

  // Start timer on mount
  useEffect(() => {
    startTimer();
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [startTimer]);

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  function handleOtpChange(value: string): void {
    // Allow only digits, max 6 characters
    const sanitized = value.replace(/\D/g, "").slice(0, 6);
    setOtp(sanitized);
    setErrorMessage(null);
  }

  async function handleVerify(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    setErrorMessage(null);

    if (otp.length !== 6) {
      setErrorMessage("Please enter the 6-digit code.");
      return;
    }

    if (isExpired) {
      setErrorMessage("The OTP has expired. Please request a new one.");
      return;
    }

    setIsVerifying(true);
    try {
      await loginWithOtp(identifier, otp);

      if (onSuccess) {
        onSuccess();
      } else {
        window.location.href = "/dashboard";
      }
    } catch (err) {
      if (err instanceof AuthApiError) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage("Something went wrong, please try again.");
      }
    } finally {
      setIsVerifying(false);
    }
  }

  async function handleResend(): Promise<void> {
    if (!canResend) return;
    setErrorMessage(null);
    setResendMessage(null);
    setIsResending(true);

    try {
      await requestOtp({ identifier });
      setOtp("");
      setResendMessage("A new code has been sent.");
      startTimer();
    } catch (err) {
      if (err instanceof AuthApiError) {
        setErrorMessage(err.message);
      } else {
        setErrorMessage("Something went wrong, please try again.");
      }
    } finally {
      setIsResending(false);
    }
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  return (
    <main className="auth-page otp-verify-page">
      <h1>Enter verification code</h1>

      <p className="otp-description">
        We sent a 6-digit code to <strong>{identifier || "your phone or email"}</strong>.
      </p>

      <form onSubmit={handleVerify} noValidate aria-label="OTP verification form">
        {/* OTP input */}
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
            onChange={(e) => handleOtpChange(e.target.value)}
            aria-describedby="otp-timer"
            disabled={isVerifying || isExpired}
          />
        </div>

        {/* Countdown timer */}
        <p
          id="otp-timer"
          className={`otp-timer ${isExpired ? "otp-timer--expired" : ""}`}
          aria-live="polite"
          aria-atomic="true"
        >
          {isExpired
            ? "Code expired"
            : `Code expires in ${formatCountdown(secondsLeft)}`}
        </p>

        {/* Error / success messages */}
        {errorMessage && (
          <div className="form-error" role="alert">
            {errorMessage}
          </div>
        )}
        {resendMessage && (
          <div className="form-success" role="status">
            {resendMessage}
          </div>
        )}

        {/* Verify button — disabled when expired or verifying */}
        <button
          type="submit"
          disabled={isVerifying || isExpired}
          className="btn-primary"
        >
          {isVerifying ? "Verifying…" : "Verify"}
        </button>
      </form>

      {/* Resend button — enabled only when timer has expired */}
      <button
        type="button"
        onClick={handleResend}
        disabled={!canResend}
        className="btn-secondary resend-btn"
        aria-label="Resend verification code"
      >
        {isResending ? "Sending…" : "Resend code"}
      </button>

      <p className="auth-link">
        <a href="/login">Back to login</a>
      </p>
    </main>
  );
}

export default OtpVerifyPage;
