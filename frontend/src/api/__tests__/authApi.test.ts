/**
 * authApi.test.ts
 *
 * Unit tests for the authApi module.
 * All network calls are intercepted via global fetch mock — no real HTTP requests are made.
 */

import {
  AUTH_ERROR_MESSAGES,
  AuthApiError,
  register,
  requestOtp,
  verifyOtp,
  login,
  logout,
  refreshToken,
  requestPasswordReset,
  confirmPasswordReset,
} from "../authApi";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Creates a mock Response with the given status and JSON body. */
function mockResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Creates a mock Response that resolves to 200 with the given body. */
function ok(body: unknown): Response {
  return mockResponse(200, body);
}

/** Creates a mock Response that resolves to the given error status + error body. */
function err(status: number, code: string, message = "backend message"): Response {
  return mockResponse(status, { error: code, message });
}

// ---------------------------------------------------------------------------
// Setup / teardown
// ---------------------------------------------------------------------------

let fetchMock: jest.MockedFunction<typeof fetch>;

beforeEach(() => {
  fetchMock = jest.fn();
  global.fetch = fetchMock;
});

afterEach(() => {
  jest.resetAllMocks();
});

// ---------------------------------------------------------------------------
// AUTH_ERROR_MESSAGES
// ---------------------------------------------------------------------------

describe("AUTH_ERROR_MESSAGES", () => {
  it("contains all expected error codes", () => {
    const expectedCodes = [
      "identifier_taken",
      "invalid_identifier",
      "otp_delivery_failed",
      "otp_rate_limit",
      "otp_invalid",
      "otp_locked",
      "password_too_short",
      "invalid_credentials",
      "account_locked",
      "token_expired",
      "token_invalid",
    ];

    for (const code of expectedCodes) {
      expect(AUTH_ERROR_MESSAGES[code]).toBeDefined();
      expect(typeof AUTH_ERROR_MESSAGES[code]).toBe("string");
      expect(AUTH_ERROR_MESSAGES[code].length).toBeGreaterThan(0);
    }
  });
});

// ---------------------------------------------------------------------------
// AuthApiError
// ---------------------------------------------------------------------------

describe("AuthApiError", () => {
  it("uses the mapped user-readable message for known error codes", () => {
    const error = new AuthApiError(422, {
      error: "identifier_taken",
      message: "raw backend message",
    });

    expect(error.message).toBe(AUTH_ERROR_MESSAGES["identifier_taken"]);
    expect(error.code).toBe("identifier_taken");
    expect(error.status).toBe(422);
    expect(error.name).toBe("AuthApiError");
  });

  it("falls back to the backend message for unknown error codes", () => {
    const error = new AuthApiError(500, {
      error: "some_unknown_code",
      message: "raw backend message",
    });

    expect(error.message).toBe("raw backend message");
    expect(error.code).toBe("some_unknown_code");
  });

  it("exposes the full body on the error object", () => {
    const body = { error: "otp_rate_limit", message: "slow down", retry_after: 120 };
    const error = new AuthApiError(429, body);

    expect(error.body).toEqual(body);
    expect(error.body.retry_after).toBe(120);
  });
});

// ---------------------------------------------------------------------------
// register
// ---------------------------------------------------------------------------

describe("register", () => {
  it("calls POST /auth/register with the correct payload and returns the response", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "OTP sent" }));

    const result = await register({ identifier: "user@example.com" });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/register");
    expect(init.method).toBe("POST");
    expect(JSON.parse(init.body as string)).toEqual({ identifier: "user@example.com" });
    expect(result).toEqual({ message: "OTP sent" });
  });

  it("includes the password in the payload when provided", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "OTP sent" }));

    await register({ identifier: "user@example.com", password: "secret123" });

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(JSON.parse(init.body as string)).toEqual({
      identifier: "user@example.com",
      password: "secret123",
    });
  });

  it("throws AuthApiError with mapped message on identifier_taken (422)", async () => {
    fetchMock.mockResolvedValueOnce(err(422, "identifier_taken"));

    await expect(register({ identifier: "user@example.com" })).rejects.toMatchObject({
      code: "identifier_taken",
      status: 422,
      message: AUTH_ERROR_MESSAGES["identifier_taken"],
    });
  });

  it("throws a plain Error on network failure", async () => {
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    await expect(register({ identifier: "user@example.com" })).rejects.toThrow(
      "Something went wrong, please try again."
    );
  });
});

// ---------------------------------------------------------------------------
// requestOtp
// ---------------------------------------------------------------------------

describe("requestOtp", () => {
  it("calls POST /auth/otp/request and returns the response", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "OTP sent" }));

    const result = await requestOtp({ identifier: "+15551234567" });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/otp/request");
    expect(init.method).toBe("POST");
    expect(result).toEqual({ message: "OTP sent" });
  });

  it("throws AuthApiError on otp_rate_limit (429)", async () => {
    fetchMock.mockResolvedValueOnce(err(429, "otp_rate_limit"));

    await expect(requestOtp({ identifier: "+15551234567" })).rejects.toMatchObject({
      code: "otp_rate_limit",
      status: 429,
      message: AUTH_ERROR_MESSAGES["otp_rate_limit"],
    });
  });
});

// ---------------------------------------------------------------------------
// verifyOtp
// ---------------------------------------------------------------------------

describe("verifyOtp", () => {
  it("calls POST /auth/otp/verify and returns the token", async () => {
    fetchMock.mockResolvedValueOnce(ok({ token: "jwt.token.here" }));

    const result = await verifyOtp({ identifier: "user@example.com", otp: "123456" });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/otp/verify");
    expect(init.method).toBe("POST");
    expect(JSON.parse(init.body as string)).toEqual({
      identifier: "user@example.com",
      otp: "123456",
    });
    expect(result.token).toBe("jwt.token.here");
  });

  it("throws AuthApiError on otp_invalid (401)", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "otp_invalid"));

    await expect(
      verifyOtp({ identifier: "user@example.com", otp: "000000" })
    ).rejects.toMatchObject({
      code: "otp_invalid",
      status: 401,
      message: AUTH_ERROR_MESSAGES["otp_invalid"],
    });
  });

  it("throws AuthApiError on otp_locked (423)", async () => {
    fetchMock.mockResolvedValueOnce(err(423, "otp_locked"));

    await expect(
      verifyOtp({ identifier: "user@example.com", otp: "000000" })
    ).rejects.toMatchObject({ code: "otp_locked", status: 423 });
  });
});

// ---------------------------------------------------------------------------
// login
// ---------------------------------------------------------------------------

describe("login", () => {
  it("calls POST /auth/login with OTP method", async () => {
    fetchMock.mockResolvedValueOnce(ok({ token: "jwt.token.here" }));

    await login({ identifier: "user@example.com", method: "otp" });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/login");
    expect(JSON.parse(init.body as string)).toEqual({
      identifier: "user@example.com",
      method: "otp",
    });
  });

  it("calls POST /auth/login with password method and includes password", async () => {
    fetchMock.mockResolvedValueOnce(ok({ token: "jwt.token.here" }));

    await login({ identifier: "user@example.com", method: "password", password: "secret123" });

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(JSON.parse(init.body as string)).toEqual({
      identifier: "user@example.com",
      method: "password",
      password: "secret123",
    });
  });

  it("throws AuthApiError on invalid_credentials (401)", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "invalid_credentials"));

    await expect(
      login({ identifier: "user@example.com", method: "password", password: "wrong" })
    ).rejects.toMatchObject({
      code: "invalid_credentials",
      status: 401,
      message: AUTH_ERROR_MESSAGES["invalid_credentials"],
    });
  });

  it("throws AuthApiError on account_locked (423)", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(423, { error: "account_locked", message: "locked", locked_until: "2026-04-18T12:00:00Z" })
    );

    await expect(
      login({ identifier: "user@example.com", method: "password", password: "wrong" })
    ).rejects.toMatchObject({
      code: "account_locked",
      status: 423,
      message: AUTH_ERROR_MESSAGES["account_locked"],
    });
  });
});

// ---------------------------------------------------------------------------
// logout
// ---------------------------------------------------------------------------

describe("logout", () => {
  it("calls DELETE /auth/logout with Authorization header", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "Logged out" }));

    await logout("my.jwt.token");

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/logout");
    expect(init.method).toBe("DELETE");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      "Bearer my.jwt.token"
    );
  });

  it("throws AuthApiError on token_expired (401)", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "token_expired"));

    await expect(logout("expired.token")).rejects.toMatchObject({
      code: "token_expired",
      status: 401,
      message: AUTH_ERROR_MESSAGES["token_expired"],
    });
  });
});

// ---------------------------------------------------------------------------
// refreshToken
// ---------------------------------------------------------------------------

describe("refreshToken", () => {
  it("calls POST /auth/refresh with Authorization header and returns new token", async () => {
    fetchMock.mockResolvedValueOnce(ok({ token: "new.jwt.token" }));

    const result = await refreshToken("old.jwt.token");

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/refresh");
    expect(init.method).toBe("POST");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      "Bearer old.jwt.token"
    );
    expect(result.token).toBe("new.jwt.token");
  });

  it("throws AuthApiError on token_invalid (401)", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "token_invalid"));

    await expect(refreshToken("bad.token")).rejects.toMatchObject({
      code: "token_invalid",
      status: 401,
    });
  });
});

// ---------------------------------------------------------------------------
// requestPasswordReset
// ---------------------------------------------------------------------------

describe("requestPasswordReset", () => {
  it("calls POST /auth/password/reset/request and returns generic success", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "If registered, an OTP was sent." }));

    const result = await requestPasswordReset({ identifier: "user@example.com" });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/password/reset/request");
    expect(init.method).toBe("POST");
    expect(result.message).toBeDefined();
  });

  it("returns the same generic response for unregistered identifiers (no enumeration)", async () => {
    // Backend always returns 200 for this endpoint regardless of whether identifier exists
    fetchMock.mockResolvedValueOnce(ok({ message: "If registered, an OTP was sent." }));

    const result = await requestPasswordReset({ identifier: "unknown@example.com" });

    expect(result.message).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// confirmPasswordReset
// ---------------------------------------------------------------------------

describe("confirmPasswordReset", () => {
  it("calls POST /auth/password/reset/confirm with correct payload", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "Password updated" }));

    const result = await confirmPasswordReset({
      identifier: "user@example.com",
      otp: "123456",
      new_password: "newpassword123",
    });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/auth/password/reset/confirm");
    expect(init.method).toBe("POST");
    expect(JSON.parse(init.body as string)).toEqual({
      identifier: "user@example.com",
      otp: "123456",
      new_password: "newpassword123",
    });
    expect(result.message).toBeDefined();
  });

  it("throws AuthApiError on otp_invalid (401)", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "otp_invalid"));

    await expect(
      confirmPasswordReset({
        identifier: "user@example.com",
        otp: "000000",
        new_password: "newpassword123",
      })
    ).rejects.toMatchObject({ code: "otp_invalid", status: 401 });
  });

  it("throws AuthApiError on password_too_short (422)", async () => {
    fetchMock.mockResolvedValueOnce(err(422, "password_too_short"));

    await expect(
      confirmPasswordReset({
        identifier: "user@example.com",
        otp: "123456",
        new_password: "short",
      })
    ).rejects.toMatchObject({
      code: "password_too_short",
      status: 422,
      message: AUTH_ERROR_MESSAGES["password_too_short"],
    });
  });
});

// ---------------------------------------------------------------------------
// Request headers — shared behaviour
// ---------------------------------------------------------------------------

describe("request headers", () => {
  it("always sends Content-Type: application/json and Accept: application/json", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "ok" }));

    await register({ identifier: "user@example.com" });

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers["Content-Type"]).toBe("application/json");
    expect(headers["Accept"]).toBe("application/json");
  });

  it("does not include Authorization header for unauthenticated endpoints", async () => {
    fetchMock.mockResolvedValueOnce(ok({ message: "ok" }));

    await register({ identifier: "user@example.com" });

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers["Authorization"]).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// Non-JSON error body handling
// ---------------------------------------------------------------------------

describe("non-JSON error body", () => {
  it("falls back to a generic error when the error response body is not valid JSON", async () => {
    const badResponse = new Response("Internal Server Error", {
      status: 500,
      headers: { "Content-Type": "text/plain" },
    });
    fetchMock.mockResolvedValueOnce(badResponse);

    await expect(register({ identifier: "user@example.com" })).rejects.toMatchObject({
      code: "unknown_error",
      status: 500,
    });
  });
});
