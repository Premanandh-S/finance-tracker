/**
 * dashboardApi.ts
 *
 * Typed fetch wrapper for the GET /dashboard endpoint.
 * Base URL is read from the VITE_API_BASE_URL environment variable,
 * defaulting to http://localhost:3000.
 *
 * Requires a JWT token attached as `Authorization: Bearer <token>`.
 */

import type { DashboardPayload } from "../types/dashboard.js";

// ---------------------------------------------------------------------------
// Base URL
// ---------------------------------------------------------------------------

function resolveBaseUrl(): string {
  if (typeof process !== "undefined" && process.env?.VITE_API_BASE_URL) {
    return process.env.VITE_API_BASE_URL;
  }
  return "http://localhost:3000";
}

const BASE_URL: string = resolveBaseUrl();

// ---------------------------------------------------------------------------
// Error class
// ---------------------------------------------------------------------------

/**
 * Thrown whenever the backend responds with a non-2xx status on the dashboard
 * endpoint.
 */
export class DashboardApiError extends Error {
  /** Machine-readable error code from the backend (e.g. "token_invalid"). */
  readonly code: string;
  /** Raw HTTP status code. */
  readonly status: number;

  constructor(status: number, body: { error: string; message: string }) {
    super(body.message ?? "Something went wrong, please try again.");
    this.name = "DashboardApiError";
    this.code = body.error;
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

const NETWORK_ERROR_MESSAGE = "Something went wrong, please try again.";

/**
 * Executes a fetch call and resolves to the parsed JSON response body.
 * Throws `DashboardApiError` for non-2xx responses and a plain `Error` for
 * network-level failures.
 */
async function request<T>(url: string, init: RequestInit): Promise<T> {
  let response: Response;

  try {
    response = await fetch(url, init);
  } catch {
    throw new Error(NETWORK_ERROR_MESSAGE);
  }

  if (!response.ok) {
    let errorBody: { error: string; message: string };
    try {
      errorBody = await response.json();
    } catch {
      errorBody = { error: "unknown_error", message: NETWORK_ERROR_MESSAGE };
    }
    throw new DashboardApiError(response.status, errorBody);
  }

  return response.json() as Promise<T>;
}

// ---------------------------------------------------------------------------
// Endpoint wrapper
// ---------------------------------------------------------------------------

/**
 * GET /dashboard
 *
 * Returns the full dashboard payload for the authenticated user, containing
 * summaries for savings, loans, insurance, and pensions.
 *
 * @param token - JWT Bearer token.
 * @returns The full `DashboardPayload`.
 * @throws {DashboardApiError} on non-2xx responses (401 if unauthenticated).
 * @throws {Error} on network failure.
 */
export async function getDashboard(token: string): Promise<DashboardPayload> {
  return request<DashboardPayload>(`${BASE_URL}/dashboard`, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
}
