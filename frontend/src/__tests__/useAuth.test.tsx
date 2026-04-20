/**
 * useAuth.test.tsx
 *
 * Unit tests for the useAuth hook and AuthProvider.
 * Covers: token storage on login, state cleared on logout,
 * redirect triggered on failed refresh (401 path), and
 * guard against usage outside AuthProvider.
 */

/** @jsxRuntime classic */
/** @jsx React.createElement */
import * as React from "react";
import { renderHook, act } from "@testing-library/react";
import { AuthProvider, useAuth } from "../hooks/useAuth.js";

// ---------------------------------------------------------------------------
// Mock authApi so no real HTTP calls are made
// ---------------------------------------------------------------------------

jest.mock("../api/authApi.js", () => ({
  verifyOtp: jest.fn(),
  login: jest.fn(),
  logout: jest.fn(),
  refreshToken: jest.fn(),
}));

import * as authApi from "../api/authApi.js";

const mockVerifyOtp = authApi.verifyOtp as jest.MockedFunction<typeof authApi.verifyOtp>;
const mockLogin = authApi.login as jest.MockedFunction<typeof authApi.login>;
const mockLogout = authApi.logout as jest.MockedFunction<typeof authApi.logout>;
const mockRefreshToken = authApi.refreshToken as jest.MockedFunction<typeof authApi.refreshToken>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Builds a minimal JWT with the given `sub` claim.
 * The signature segment is a placeholder — we only decode the payload.
 */
function makeJwt(sub: string): string {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({ sub, iat: 1700000000, exp: 1700086400 }));
  return `${header}.${payload}.fakesig`;
}

/** Renders the hook inside an AuthProvider. */
function renderUseAuth() {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <AuthProvider>{children}</AuthProvider>
  );
  return renderHook(() => useAuth(), { wrapper });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useAuth", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset window.location.href between tests
    Object.defineProperty(window, "location", {
      writable: true,
      value: { href: "" },
    });
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  it("starts with unauthenticated state", () => {
    const { result } = renderUseAuth();
    expect(result.current.token).toBeNull();
    expect(result.current.user).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // loginWithOtp
  // -------------------------------------------------------------------------

  it("stores token and user after successful OTP login", async () => {
    const token = makeJwt("42");
    mockVerifyOtp.mockResolvedValueOnce({ token });

    const { result } = renderUseAuth();

    await act(async () => {
      await result.current.loginWithOtp("user@example.com", "123456");
    });

    expect(result.current.token).toBe(token);
    expect(result.current.user).toEqual({ id: "42" });
    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.isLoading).toBe(false);
  });

  it("clears loading state and re-throws on OTP login failure", async () => {
    const error = new Error("otp_invalid");
    mockVerifyOtp.mockRejectedValueOnce(error);

    const { result } = renderUseAuth();

    await expect(
      act(async () => {
        await result.current.loginWithOtp("user@example.com", "000000");
      })
    ).rejects.toThrow("otp_invalid");

    expect(result.current.token).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // loginWithPassword
  // -------------------------------------------------------------------------

  it("stores token and user after successful password login", async () => {
    const token = makeJwt("99");
    mockLogin.mockResolvedValueOnce({ token });

    const { result } = renderUseAuth();

    await act(async () => {
      await result.current.loginWithPassword("user@example.com", "secret123");
    });

    expect(result.current.token).toBe(token);
    expect(result.current.user).toEqual({ id: "99" });
    expect(result.current.isAuthenticated).toBe(true);
    expect(mockLogin).toHaveBeenCalledWith({
      identifier: "user@example.com",
      method: "password",
      password: "secret123",
    });
  });

  it("clears loading state and re-throws on password login failure", async () => {
    const error = new Error("invalid_credentials");
    mockLogin.mockRejectedValueOnce(error);

    const { result } = renderUseAuth();

    await expect(
      act(async () => {
        await result.current.loginWithPassword("user@example.com", "wrong");
      })
    ).rejects.toThrow("invalid_credentials");

    expect(result.current.token).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // logout
  // -------------------------------------------------------------------------

  it("clears token and user after logout", async () => {
    const token = makeJwt("7");
    mockVerifyOtp.mockResolvedValueOnce({ token });
    mockLogout.mockResolvedValueOnce({ message: "Logged out" });

    const { result } = renderUseAuth();

    // Log in first
    await act(async () => {
      await result.current.loginWithOtp("user@example.com", "123456");
    });
    expect(result.current.isAuthenticated).toBe(true);

    // Now log out
    await act(async () => {
      await result.current.logout();
    });

    expect(result.current.token).toBeNull();
    expect(result.current.user).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(mockLogout).toHaveBeenCalledWith(token);
  });

  it("clears state even when the logout API call fails", async () => {
    const token = makeJwt("7");
    mockVerifyOtp.mockResolvedValueOnce({ token });
    mockLogout.mockRejectedValueOnce(new Error("token_expired"));

    const { result } = renderUseAuth();

    await act(async () => {
      await result.current.loginWithOtp("user@example.com", "123456");
    });

    // logout should not throw even if the API fails
    await act(async () => {
      await result.current.logout();
    });

    expect(result.current.token).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
  });

  // -------------------------------------------------------------------------
  // handleUnauthorized — silent refresh
  // -------------------------------------------------------------------------

  it("stores new token and returns true when refresh succeeds", async () => {
    const oldToken = makeJwt("5");
    const newToken = makeJwt("5");
    mockVerifyOtp.mockResolvedValueOnce({ token: oldToken });
    mockRefreshToken.mockResolvedValueOnce({ token: newToken });

    const { result } = renderUseAuth();

    await act(async () => {
      await result.current.loginWithOtp("user@example.com", "123456");
    });

    let refreshResult: boolean | undefined;
    await act(async () => {
      refreshResult = await result.current.handleUnauthorized();
    });

    expect(refreshResult).toBe(true);
    expect(result.current.token).toBe(newToken);
    expect(result.current.isAuthenticated).toBe(true);
  });

  it("clears state, redirects to /login, and returns false when refresh fails", async () => {
    const token = makeJwt("5");
    mockVerifyOtp.mockResolvedValueOnce({ token });
    mockRefreshToken.mockRejectedValueOnce(new Error("token_expired"));

    const { result } = renderUseAuth();

    await act(async () => {
      await result.current.loginWithOtp("user@example.com", "123456");
    });

    let refreshResult: boolean | undefined;
    await act(async () => {
      refreshResult = await result.current.handleUnauthorized();
    });

    expect(refreshResult).toBe(false);
    expect(result.current.token).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(window.location.href).toBe("/login");
  });

  // -------------------------------------------------------------------------
  // Guard — usage outside AuthProvider
  // -------------------------------------------------------------------------

  it("throws when useAuth is called outside AuthProvider", () => {
    // Suppress the expected React error boundary console output
    const consoleSpy = jest.spyOn(console, "error").mockImplementation(() => {});

    expect(() => renderHook(() => useAuth())).toThrow(
      "useAuth must be used within an AuthProvider"
    );

    consoleSpy.mockRestore();
  });
});
