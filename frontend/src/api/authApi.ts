/**
 * authApi.ts
 *
 * Typed fetch wrappers for all authentication endpoints.
 * Base URL is read from the VITE_API_BASE_URL environment variable,
 * defaulting to http://localhost:3000.
 */

// ---------------------------------------------------------------------------
// Base URL
// ---------------------------------------------------------------------------

const BASE_URL: string =
  (typeof import.meta !== "undefined" &&
    (import.meta as { env?: Record<string, string> }).env
      ?.VITE_API_BASE_URL) ||
  "http://localhost:3000";

// ---------------------------------------------------------------------------
// Error code → user-readable message map
// ---------------------------------------------------------------------------

export const AUTH_ERROR_MESSAGES: Record<string, string> = {
  identifier_taken: "This identifier is already registered.",
  invalid_identifier: "Please enter a valid phone number or email address.",
  otp_delivery_failed: "We couldn't send the OTP. Please try again.",
  otp_rate_limit: "Too many OTP requests. Please wait before trying again.",
  otp_invalid: "The OTP is invalid or has expired.",
  otp_locked: "Too many failed attempts. Please request a new OTP.",
  password_too_short: "Password must be at least 8 characters.",
  invalid_credentials: "Invalid credentials. Please try again.",
  account_locked:
    "Your account is temporarily locked. Please try again later.",
  token_expired: "Your session has expired. Please log in again.",
  token_invalid: "Invalid session token. Please log in again.",
};

const NETWORK_ERROR_MESSAGE = "Something went wrong, please try again.";

// ---------------------------------------------------------------------------
// Shared request / response types
// ---------------------------------------------------------------------------

/** Raw error envelope returned by the backend. */
export interface ApiErrorBody {
  error: string;
  message: string;
  /** Present on otp_rate_limit responses. */
  retry_after?: number;
  /** Present on account_locked responses (ISO 8601). */
  locked_until?: string;
}

/** Thrown (or returned) whenever the backend responds with a non-2xx status. */
export class AuthApiError extends Error {
  /** Machine-readable error code from the backend (e.g. "otp_invalid"). */
  readonly code: string;
  /** User-readable message derived from AUTH_ERROR_MESSAGES or the backend message. */
  override readonly message: string;
  /** Raw HTTP status code. */
  readonly status: number;
  /** Full error body from the backend. */
  readonly body: ApiErrorBody;

  constructor(status: number, body: ApiErrorBody) {
    const message =
      AUTH_ERROR_MESSAGES[body.error] ??
      body.message ??
      NETWORK_ERROR_MESSAGE;
    super(message);
    this.name = "AuthApiError";
    this.code = body.error;
    this.message = message;
    this.status = status;
    this.body = body;
  }
}

// ---------------------------------------------------------------------------
// Request / response shapes for each endpoint
// ---------------------------------------------------------------------------

// POST /auth/register
export interface RegisterRequest {
  identifier: string;
  password?: string;
}

export interface RegisterResponse {
  message: string;
}

// POST /auth/otp/request
export interface OtpRequestRequest {
  identifier: string;
}

export interface OtpRequestResponse {
  message: string;
}

// POST /auth/otp/verify
export interface OtpVerifyRequest {
  identifier: string;
  otp: string;
}

export interface OtpVerifyResponse {
  token: string;
}

// POST /auth/login
export interface LoginRequest {
  identifier: string;
  method: "otp" | "password";
  password?: string;
}

export interface LoginResponse {
  token: string;
}

// DELETE /auth/logout  (requires Authorization header)
export interface LogoutResponse {
  message: string;
}

// POST /auth/refresh  (requires Authorization header)
export interface RefreshResponse {
  token: string;
}

// POST /auth/password/reset/request
export interface PasswordResetRequestRequest {
  identifier: string;
}

export interface PasswordResetRequestResponse {
  message: string;
}

// POST /auth/password/reset/confirm
export interface PasswordResetConfirmRequest {
  identifier: string;
  otp: string;
  new_password: string;
}

export interface PasswordResetConfirmResponse {
  message: string;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Builds the standard JSON request init object.
 * Attaches an Authorization header when a token is provided.
 */
function buildInit(
  method: string,
  body?: unknown,
  token?: string
): RequestInit {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  return {
    method,
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  };
}

/**
 * Executes a fetch call and resolves to the parsed JSON response body.
 * Throws `AuthApiError` for non-2xx responses and a plain `Error` for
 * network-level failures (no response received).
 */
async function request<T>(url: string, init: RequestInit): Promise<T> {
  let response: Response;

  try {
    response = await fetch(url, init);
  } catch {
    // Network error — no response received
    throw new Error(NETWORK_ERROR_MESSAGE);
  }

  if (!response.ok) {
    let errorBody: ApiErrorBody;
    try {
      errorBody = (await response.json()) as ApiErrorBody;
    } catch {
      // Non-JSON error body — construct a generic error
      errorBody = {
        error: "unknown_error",
        message: NETWORK_ERROR_MESSAGE,
      };
    }
    throw new AuthApiError(response.status, errorBody);
  }

  // 204 No Content — return empty object cast to T
  if (response.status === 204) {
    return {} as T;
  }

  return response.json() as Promise<T>;
}

// ---------------------------------------------------------------------------
// Endpoint wrappers
// ---------------------------------------------------------------------------

/**
 * POST /auth/register
 *
 * Registers a new user with the given identifier and optional password.
 * Triggers OTP delivery for account verification.
 *
 * @param payload - { identifier, password? }
 * @returns Generic success message from the server.
 * @throws {AuthApiError} on validation errors (identifier_taken, invalid_identifier, password_too_short, otp_delivery_failed)
 * @throws {Error} on network failure
 */
export async function register(
  payload: RegisterRequest
): Promise<RegisterResponse> {
  return request<RegisterResponse>(
    `${BASE_URL}/auth/register`,
    buildInit("POST", payload)
  );
}

/**
 * POST /auth/otp/request
 *
 * Requests a new OTP for the given identifier.
 *
 * @param payload - { identifier }
 * @returns Generic success message from the server.
 * @throws {AuthApiError} on rate limit (otp_rate_limit) or delivery failure (otp_delivery_failed)
 * @throws {Error} on network failure
 */
export async function requestOtp(
  payload: OtpRequestRequest
): Promise<OtpRequestResponse> {
  return request<OtpRequestResponse>(
    `${BASE_URL}/auth/otp/request`,
    buildInit("POST", payload)
  );
}

/**
 * POST /auth/otp/verify
 *
 * Verifies the OTP for the given identifier and returns a JWT on success.
 *
 * @param payload - { identifier, otp }
 * @returns { token } — the issued JWT.
 * @throws {AuthApiError} on invalid/expired OTP (otp_invalid) or locked account (otp_locked)
 * @throws {Error} on network failure
 */
export async function verifyOtp(
  payload: OtpVerifyRequest
): Promise<OtpVerifyResponse> {
  return request<OtpVerifyResponse>(
    `${BASE_URL}/auth/otp/verify`,
    buildInit("POST", payload)
  );
}

/**
 * POST /auth/login
 *
 * Initiates a login session using either OTP or password authentication.
 *
 * @param payload - { identifier, method, password? }
 * @returns { token } — the issued JWT (password path) or a success message (OTP path triggers delivery).
 * @throws {AuthApiError} on invalid credentials (invalid_credentials), locked account (account_locked), or OTP errors
 * @throws {Error} on network failure
 */
export async function login(payload: LoginRequest): Promise<LoginResponse> {
  return request<LoginResponse>(
    `${BASE_URL}/auth/login`,
    buildInit("POST", payload)
  );
}

/**
 * DELETE /auth/logout
 *
 * Logs out the current user by adding the JWT to the server-side denylist.
 * Requires a valid Bearer token.
 *
 * @param token - The current JWT (Bearer token).
 * @returns Generic success message from the server.
 * @throws {AuthApiError} on token errors (token_expired, token_invalid)
 * @throws {Error} on network failure
 */
export async function logout(token: string): Promise<LogoutResponse> {
  return request<LogoutResponse>(
    `${BASE_URL}/auth/logout`,
    buildInit("DELETE", undefined, token)
  );
}

/**
 * POST /auth/refresh
 *
 * Issues a new JWT from a valid, unexpired existing JWT.
 * The old token is added to the denylist.
 * Requires a valid Bearer token.
 *
 * @param token - The current JWT (Bearer token).
 * @returns { token } — the newly issued JWT.
 * @throws {AuthApiError} on token errors (token_expired, token_invalid)
 * @throws {Error} on network failure
 */
export async function refreshToken(token: string): Promise<RefreshResponse> {
  return request<RefreshResponse>(
    `${BASE_URL}/auth/refresh`,
    buildInit("POST", undefined, token)
  );
}

/**
 * POST /auth/password/reset/request
 *
 * Requests a password-reset OTP for the given identifier.
 * Always returns a generic success response to prevent identifier enumeration.
 *
 * @param payload - { identifier }
 * @returns Generic success message from the server.
 * @throws {AuthApiError} on OTP delivery failure (otp_delivery_failed) or rate limit (otp_rate_limit)
 * @throws {Error} on network failure
 */
export async function requestPasswordReset(
  payload: PasswordResetRequestRequest
): Promise<PasswordResetRequestResponse> {
  return request<PasswordResetRequestResponse>(
    `${BASE_URL}/auth/password/reset/request`,
    buildInit("POST", payload)
  );
}

/**
 * POST /auth/password/reset/confirm
 *
 * Confirms a password reset by verifying the OTP and setting the new password.
 * All existing JWTs for the user are invalidated on success.
 *
 * @param payload - { identifier, otp, new_password }
 * @returns Generic success message from the server.
 * @throws {AuthApiError} on invalid OTP (otp_invalid), password too short (password_too_short)
 * @throws {Error} on network failure
 */
export async function confirmPasswordReset(
  payload: PasswordResetConfirmRequest
): Promise<PasswordResetConfirmResponse> {
  return request<PasswordResetConfirmResponse>(
    `${BASE_URL}/auth/password/reset/confirm`,
    buildInit("POST", payload)
  );
}
