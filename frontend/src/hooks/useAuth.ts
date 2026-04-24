/**
 * useAuth.ts
 *
 * React Context + useReducer-based authentication hook.
 *
 * JWT storage strategy:
 * - Access token is stored in memory (React context) — never in localStorage or
 *   sessionStorage to avoid XSS exposure.
 * - Refresh token is delivered by the backend as an HTTP-only cookie; the
 *   frontend never reads it directly.
 * - Silent refresh: when a 401 is received on a protected request, call
 *   `handleUnauthorized()` which attempts `POST /auth/refresh`. On success the
 *   new token is stored and the caller receives `true`; on failure the state is
 *   cleared and the user is redirected to `/login`.
 */

import {
  createElement,
  createContext,
  useContext,
  useReducer,
  useCallback,
  type JSX,
  type ReactNode,
} from "react";
import {
  verifyOtp,
  login,
  logout as logoutApi,
  refreshToken,
} from "../api/authApi.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Minimal user object decoded from the JWT `sub` claim. */
export interface AuthUser {
  /** The user's ID, taken from the JWT `sub` claim. */
  id: string;
}

/** Shape of the auth state managed by the reducer. */
export interface AuthState {
  /** In-memory JWT access token. `null` when unauthenticated. */
  token: string | null;
  /** Decoded user info. `null` when unauthenticated. */
  user: AuthUser | null;
  /** Derived convenience flag — `true` when `token` is non-null. */
  isAuthenticated: boolean;
  /** `true` while an async auth action (login, logout, refresh) is in flight. */
  isLoading: boolean;
}

/** All actions the reducer handles. */
type AuthAction =
  | { type: "AUTH_START" }
  | { type: "AUTH_SUCCESS"; payload: { token: string; user: AuthUser } }
  | { type: "AUTH_FAILURE" }
  | { type: "LOGOUT" };

/** Public interface exposed by the `useAuth` hook. */
export interface AuthContextValue extends AuthState {
  /**
   * Authenticates the user via OTP verification.
   *
   * Calls `POST /auth/otp/verify`, stores the returned JWT in memory, and
   * decodes the `sub` claim to populate `user`.
   *
   * @param identifier - The user's phone number or email address.
   * @param otp - The 6-digit OTP code entered by the user.
   * @throws {AuthApiError} if the OTP is invalid, expired, or the account is locked.
   * @throws {Error} on network failure.
   */
  loginWithOtp(identifier: string, otp: string): Promise<void>;

  /**
   * Authenticates the user via password.
   *
   * Calls `POST /auth/login` with `method: "password"`, stores the returned
   * JWT in memory, and decodes the `sub` claim to populate `user`.
   *
   * @param identifier - The user's phone number or email address.
   * @param password - The user's password.
   * @throws {AuthApiError} if credentials are invalid or the account is locked.
   * @throws {Error} on network failure.
   */
  loginWithPassword(identifier: string, password: string): Promise<void>;

  /**
   * Logs out the current user.
   *
   * Calls `DELETE /auth/logout` to add the current JWT to the server-side
   * denylist, then clears the in-memory token and user state regardless of
   * whether the API call succeeds (best-effort server-side invalidation).
   *
   * @throws {AuthApiError} if the token is already invalid (non-fatal in practice).
   * @throws {Error} on network failure.
   */
  logout(): Promise<void>;

  /**
   * Attempts a silent token refresh using the HTTP-only refresh cookie.
   *
   * Should be called by `authApi.ts` whenever a 401 response is received on a
   * protected request. Calls `POST /auth/refresh`; on success the new token is
   * stored and `true` is returned so the caller can retry the original request.
   * On failure the auth state is cleared and the user is redirected to `/login`.
   *
   * @returns `true` if the refresh succeeded and a new token is now available;
   *          `false` if the refresh failed (state cleared, redirect triggered).
   */
  handleUnauthorized(): Promise<boolean>;
}

// ---------------------------------------------------------------------------
// Initial state — seed token from localStorage so page reloads stay logged in
// ---------------------------------------------------------------------------

function buildInitialState(): AuthState {
  try {
    const stored = localStorage.getItem("auth_token");
    if (stored) {
      const user = userFromToken(stored);
      return { token: stored, user, isAuthenticated: true, isLoading: false };
    }
  } catch {
    // Malformed token or localStorage unavailable — start unauthenticated
  }
  return { token: null, user: null, isAuthenticated: false, isLoading: false };
}

const initialState: AuthState = buildInitialState();

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case "AUTH_START":
      return { ...state, isLoading: true };

    case "AUTH_SUCCESS":
      return {
        token: action.payload.token,
        user: action.payload.user,
        isAuthenticated: true,
        isLoading: false,
      };

    case "AUTH_FAILURE":
      return { ...state, isLoading: false };

    case "LOGOUT":
      return {
        token: null,
        user: null,
        isAuthenticated: false,
        isLoading: false,
      };

    default:
      return state;
  }
}

// ---------------------------------------------------------------------------
// JWT helpers
// ---------------------------------------------------------------------------

/**
 * Decodes the base64url-encoded payload of a JWT and returns the parsed JSON.
 *
 * No signature verification is performed here — the backend is the authority
 * on token validity. This is used only to extract display-safe claims (e.g.
 * `sub`) from a token that the backend has already issued and validated.
 *
 * @param token - A compact JWT string (header.payload.signature).
 * @returns The decoded payload as a plain object.
 * @throws {Error} if the token is malformed or the payload cannot be parsed.
 */
function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Malformed JWT: expected 3 parts");
  }
  // atob requires standard base64; JWT uses base64url — replace URL-safe chars
  const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  try {
    return JSON.parse(atob(base64)) as Record<string, unknown>;
  } catch {
    throw new Error("Malformed JWT: payload is not valid base64 JSON");
  }
}

/**
 * Extracts the `AuthUser` from a JWT by decoding the `sub` claim.
 *
 * @param token - A compact JWT string.
 * @returns An `AuthUser` with the `id` set to the `sub` claim value.
 * @throws {Error} if the token is malformed or `sub` is missing.
 */
function userFromToken(token: string): AuthUser {
  const payload = decodeJwtPayload(token);
  const sub = payload["sub"];
  if (typeof sub !== "string" || sub.length === 0) {
    throw new Error("JWT payload missing or invalid `sub` claim");
  }
  return { id: sub };
}

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

/** @internal Exported for testing purposes only. Use `useAuth` in application code. */
export const AuthContext = createContext<AuthContextValue | null>(null);

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/**
 * `AuthProvider` wraps the application (or a subtree) and makes auth state
 * and actions available to all descendant components via `useAuth`.
 *
 * Place this near the root of your component tree, above any component that
 * calls `useAuth`.
 *
 * @example
 * ```tsx
 * <AuthProvider>
 *   <App />
 * </AuthProvider>
 * ```
 */
export function AuthProvider({ children }: { children: ReactNode }): JSX.Element {
  const [state, dispatch] = useReducer(authReducer, initialState);

  // -------------------------------------------------------------------------
  // loginWithOtp
  // -------------------------------------------------------------------------

  const loginWithOtp = useCallback(
    async (identifier: string, otp: string): Promise<void> => {
      dispatch({ type: "AUTH_START" });
      try {
        const { token } = await verifyOtp({ identifier, otp });
        const user = userFromToken(token);
        localStorage.setItem("auth_token", token);
        dispatch({ type: "AUTH_SUCCESS", payload: { token, user } });
      } catch (err) {
        dispatch({ type: "AUTH_FAILURE" });
        throw err;
      }
    },
    []
  );

  // -------------------------------------------------------------------------
  // loginWithPassword
  // -------------------------------------------------------------------------

  const loginWithPassword = useCallback(
    async (identifier: string, password: string): Promise<void> => {
      dispatch({ type: "AUTH_START" });
      try {
        const { token } = await login({ identifier, method: "password", password });
        const user = userFromToken(token);
        localStorage.setItem("auth_token", token);
        dispatch({ type: "AUTH_SUCCESS", payload: { token, user } });
      } catch (err) {
        dispatch({ type: "AUTH_FAILURE" });
        throw err;
      }
    },
    []
  );

  // -------------------------------------------------------------------------
  // logout
  // -------------------------------------------------------------------------

  const logout = useCallback(async (): Promise<void> => {
    dispatch({ type: "AUTH_START" });
    const currentToken = state.token;
    localStorage.removeItem("auth_token");
    dispatch({ type: "LOGOUT" });
    if (currentToken) {
      try {
        await logoutApi(currentToken);
      } catch {
        // Server-side denylist failure is non-fatal; local state is already cleared
      }
    }
  }, [state.token]);

  // -------------------------------------------------------------------------
  // handleUnauthorized
  // -------------------------------------------------------------------------

  const handleUnauthorized = useCallback(async (): Promise<boolean> => {
    const currentToken = state.token;
    try {
      const { token } = await refreshToken(currentToken ?? "");
      const user = userFromToken(token);
      localStorage.setItem("auth_token", token);
      dispatch({ type: "AUTH_SUCCESS", payload: { token, user } });
      return true;
    } catch {
      // Refresh failed — clear state and redirect to login
      localStorage.removeItem("auth_token");
      dispatch({ type: "LOGOUT" });
      window.location.href = "/login";
      return false;
    }
  }, [state.token]);

  // -------------------------------------------------------------------------
  // Context value
  // -------------------------------------------------------------------------

  const value: AuthContextValue = {
    ...state,
    loginWithOtp,
    loginWithPassword,
    logout,
    handleUnauthorized,
  };

  return createElement(AuthContext.Provider, { value }, children);
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Returns the current auth state and actions from the nearest `AuthProvider`.
 *
 * Must be called inside a component that is a descendant of `AuthProvider`.
 *
 * @returns The `AuthContextValue` containing state (`token`, `user`,
 *          `isAuthenticated`, `isLoading`) and actions (`loginWithOtp`,
 *          `loginWithPassword`, `logout`, `handleUnauthorized`).
 * @throws {Error} if called outside of an `AuthProvider`.
 *
 * @example
 * ```tsx
 * const { isAuthenticated, loginWithPassword, logout } = useAuth();
 * ```
 */
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (ctx === null) {
    throw new Error(
      "useAuth must be used within an AuthProvider. " +
        "Wrap your component tree with <AuthProvider>."
    );
  }
  return ctx;
}
