/**
 * loansApi.test.ts
 *
 * Unit tests for the loansApi module.
 * All network calls are intercepted via global fetch mock — no real HTTP requests are made.
 *
 * @jest-environment node
 */

import {
  LoansApiError,
  listLoans,
  getLoan,
  createLoan,
  updateLoan,
  deleteLoan,
  createRatePeriod,
  updateRatePeriod,
  deleteRatePeriod,
} from "../loansApi";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const TOKEN = "test.jwt.token";

/** Creates a mock Response with the given status and JSON body. */
function mockResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function ok(body: unknown): Response {
  return mockResponse(200, body);
}

function created(body: unknown): Response {
  return mockResponse(201, body);
}

function noContent(): Response {
  return new Response(null, { status: 204 });
}

function err(status: number, code: string, message = "backend error message"): Response {
  return mockResponse(status, { error: code, message });
}

function validationErr(
  message: string,
  details: Record<string, string[]>
): Response {
  return mockResponse(422, { error: "validation_failed", message, details });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const LOAN_LIST_ITEM = {
  id: 1,
  institution_name: "HDFC Bank",
  loan_identifier: "HL-2024-001",
  outstanding_balance: 250000000,
  interest_rate_type: "fixed",
  annual_interest_rate: "8.5",
  monthly_payment: 2500000,
  payment_due_day: 5,
  next_payment_date: "2025-08-05",
  payoff_date: "2032-03-05",
};

const LOAN_DETAIL = {
  ...LOAN_LIST_ITEM,
  interest_rate_periods: [],
  amortisation_schedule: [
    {
      period: 1,
      payment_date: "2025-08-05",
      payment_amount: 2500000,
      principal: 729167,
      interest: 1770833,
      remaining_balance: 249270833,
    },
  ],
};

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
// LoansApiError
// ---------------------------------------------------------------------------

describe("LoansApiError", () => {
  it("stores code, status, and message", () => {
    const error = new LoansApiError(404, {
      error: "not_found",
      message: "Loan not found",
    });

    expect(error.code).toBe("not_found");
    expect(error.status).toBe(404);
    expect(error.message).toBe("Loan not found");
    expect(error.name).toBe("LoansApiError");
  });

  it("stores details for 422 validation errors", () => {
    const details = { outstanding_balance: ["must be greater than 0"] };
    const error = new LoansApiError(422, {
      error: "validation_failed",
      message: "Validation failed",
      details,
    });

    expect(error.details).toEqual(details);
    expect(error.status).toBe(422);
    expect(error.code).toBe("validation_failed");
  });

  it("has undefined details when not provided", () => {
    const error = new LoansApiError(404, {
      error: "not_found",
      message: "Loan not found",
    });

    expect(error.details).toBeUndefined();
  });

  it("is an instance of Error", () => {
    const error = new LoansApiError(500, {
      error: "server_error",
      message: "Internal server error",
    });

    expect(error).toBeInstanceOf(Error);
  });
});

// ---------------------------------------------------------------------------
// listLoans
// ---------------------------------------------------------------------------

describe("listLoans", () => {
  it("calls GET /loans with Authorization header and returns loan array", async () => {
    fetchMock.mockResolvedValueOnce(ok([LOAN_LIST_ITEM]));

    const result = await listLoans(TOKEN);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans");
    expect(url).not.toMatch(/\/loans\/\d/);
    expect(init.method).toBe("GET");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(result).toEqual([LOAN_LIST_ITEM]);
  });

  it("returns an empty array when the user has no loans", async () => {
    fetchMock.mockResolvedValueOnce(ok([]));

    const result = await listLoans(TOKEN);

    expect(result).toEqual([]);
  });

  it("throws LoansApiError on 401 unauthorized", async () => {
    fetchMock.mockResolvedValueOnce(err(401, "token_invalid", "Unauthorized"));

    await expect(listLoans(TOKEN)).rejects.toMatchObject({
      code: "token_invalid",
      status: 401,
    });
  });

  it("throws a plain Error on network failure", async () => {
    fetchMock.mockRejectedValueOnce(new TypeError("Failed to fetch"));

    await expect(listLoans(TOKEN)).rejects.toThrow(
      "Something went wrong, please try again."
    );
  });
});

// ---------------------------------------------------------------------------
// getLoan
// ---------------------------------------------------------------------------

describe("getLoan", () => {
  it("calls GET /loans/:id with Authorization header and returns loan detail", async () => {
    fetchMock.mockResolvedValueOnce(ok(LOAN_DETAIL));

    const result = await getLoan(TOKEN, 1);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1");
    expect(init.method).toBe("GET");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(result).toEqual(LOAN_DETAIL);
    expect(result.amortisation_schedule).toHaveLength(1);
    expect(result.interest_rate_periods).toEqual([]);
  });

  it("throws LoansApiError with status 404 when loan not found", async () => {
    fetchMock.mockResolvedValueOnce(err(404, "not_found", "Loan not found"));

    await expect(getLoan(TOKEN, 999)).rejects.toMatchObject({
      code: "not_found",
      status: 404,
      message: "Loan not found",
    });
  });
});

// ---------------------------------------------------------------------------
// createLoan
// ---------------------------------------------------------------------------

describe("createLoan", () => {
  const createParams = {
    institution_name: "HDFC Bank",
    loan_identifier: "HL-2024-001",
    outstanding_balance: 250000000,
    annual_interest_rate: 8.5,
    interest_rate_type: "fixed" as const,
    monthly_payment: 2500000,
    payment_due_day: 5,
  };

  it("calls POST /loans with Authorization header and returns 201 loan detail", async () => {
    fetchMock.mockResolvedValueOnce(created(LOAN_DETAIL));

    const result = await createLoan(TOKEN, createParams);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans");
    expect(url).not.toMatch(/\/loans\/\d/);
    expect(init.method).toBe("POST");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(JSON.parse(init.body as string)).toEqual(createParams);
    expect(result).toEqual(LOAN_DETAIL);
  });

  it("throws LoansApiError with details on 422 validation error", async () => {
    const details = { outstanding_balance: ["must be greater than 0"] };
    fetchMock.mockResolvedValueOnce(
      validationErr("Outstanding balance must be greater than 0", details)
    );

    await expect(createLoan(TOKEN, { ...createParams, outstanding_balance: 0 })).rejects.toMatchObject({
      code: "validation_failed",
      status: 422,
      details,
    });
  });

  it("includes interest_rate_periods when provided", async () => {
    fetchMock.mockResolvedValueOnce(created(LOAN_DETAIL));

    const paramsWithPeriods = {
      ...createParams,
      interest_rate_type: "floating" as const,
      interest_rate_periods: [
        { start_date: "2024-01-01", annual_interest_rate: 8.5 },
      ],
    };

    await createLoan(TOKEN, paramsWithPeriods);

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const body = JSON.parse(init.body as string);
    expect(body.interest_rate_periods).toHaveLength(1);
    expect(body.interest_rate_periods[0].annual_interest_rate).toBe(8.5);
  });
});

// ---------------------------------------------------------------------------
// updateLoan
// ---------------------------------------------------------------------------

describe("updateLoan", () => {
  it("calls PATCH /loans/:id with Authorization header and returns updated loan", async () => {
    const updated = { ...LOAN_LIST_ITEM, institution_name: "SBI" };
    fetchMock.mockResolvedValueOnce(ok(updated));

    const result = await updateLoan(TOKEN, 1, { institution_name: "SBI" });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1");
    expect(init.method).toBe("PATCH");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(JSON.parse(init.body as string)).toEqual({ institution_name: "SBI" });
    expect(result.institution_name).toBe("SBI");
  });

  it("throws LoansApiError with details on 422 validation error", async () => {
    const details = { payment_due_day: ["must be between 1 and 28"] };
    fetchMock.mockResolvedValueOnce(
      validationErr("Payment due day must be between 1 and 28", details)
    );

    await expect(updateLoan(TOKEN, 1, { payment_due_day: 31 })).rejects.toMatchObject({
      code: "validation_failed",
      status: 422,
      details,
    });
  });

  it("throws LoansApiError with status 404 when loan not found", async () => {
    fetchMock.mockResolvedValueOnce(err(404, "not_found", "Loan not found"));

    await expect(updateLoan(TOKEN, 999, { institution_name: "SBI" })).rejects.toMatchObject({
      code: "not_found",
      status: 404,
    });
  });
});

// ---------------------------------------------------------------------------
// deleteLoan
// ---------------------------------------------------------------------------

describe("deleteLoan", () => {
  it("calls DELETE /loans/:id with Authorization header and returns void", async () => {
    fetchMock.mockResolvedValueOnce(noContent());

    const result = await deleteLoan(TOKEN, 1);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1");
    expect(init.method).toBe("DELETE");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(result).toBeUndefined();
  });

  it("throws LoansApiError with status 404 when loan not found", async () => {
    fetchMock.mockResolvedValueOnce(err(404, "not_found", "Loan not found"));

    await expect(deleteLoan(TOKEN, 999)).rejects.toMatchObject({
      code: "not_found",
      status: 404,
    });
  });
});

// ---------------------------------------------------------------------------
// createRatePeriod
// ---------------------------------------------------------------------------

describe("createRatePeriod", () => {
  const ratePeriodParams = {
    start_date: "2025-01-01",
    annual_interest_rate: 9.0,
  };

  it("calls POST /loans/:id/interest_rate_periods with Authorization header", async () => {
    const detailWithPeriod = {
      ...LOAN_DETAIL,
      interest_rate_periods: [
        { id: 1, start_date: "2025-01-01", end_date: null, annual_interest_rate: "9.0" },
      ],
    };
    fetchMock.mockResolvedValueOnce(created(detailWithPeriod));

    const result = await createRatePeriod(TOKEN, 1, ratePeriodParams);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1/interest_rate_periods");
    expect(init.method).toBe("POST");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(JSON.parse(init.body as string)).toEqual(ratePeriodParams);
    expect(result.interest_rate_periods).toHaveLength(1);
  });

  it("throws LoansApiError on 422 when adding period to fixed-rate loan", async () => {
    fetchMock.mockResolvedValueOnce(
      mockResponse(422, {
        error: "invalid_operation",
        message: "Cannot add interest rate periods to a fixed-rate loan",
      })
    );

    await expect(createRatePeriod(TOKEN, 1, ratePeriodParams)).rejects.toMatchObject({
      code: "invalid_operation",
      status: 422,
    });
  });
});

// ---------------------------------------------------------------------------
// updateRatePeriod
// ---------------------------------------------------------------------------

describe("updateRatePeriod", () => {
  const ratePeriodParams = {
    start_date: "2025-06-01",
    annual_interest_rate: 10.0,
  };

  it("calls PATCH /loans/:id/interest_rate_periods/:id with Authorization header", async () => {
    const updatedDetail = {
      ...LOAN_DETAIL,
      interest_rate_periods: [
        { id: 5, start_date: "2025-06-01", end_date: null, annual_interest_rate: "10.0" },
      ],
    };
    fetchMock.mockResolvedValueOnce(ok(updatedDetail));

    const result = await updateRatePeriod(TOKEN, 1, 5, ratePeriodParams);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1/interest_rate_periods/5");
    expect(init.method).toBe("PATCH");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(JSON.parse(init.body as string)).toEqual(ratePeriodParams);
    expect(result.interest_rate_periods[0].annual_interest_rate).toBe("10.0");
  });

  it("throws LoansApiError with status 404 when period not found", async () => {
    fetchMock.mockResolvedValueOnce(err(404, "not_found", "Loan not found"));

    await expect(updateRatePeriod(TOKEN, 1, 999, ratePeriodParams)).rejects.toMatchObject({
      code: "not_found",
      status: 404,
    });
  });
});

// ---------------------------------------------------------------------------
// deleteRatePeriod
// ---------------------------------------------------------------------------

describe("deleteRatePeriod", () => {
  it("calls DELETE /loans/:id/interest_rate_periods/:id with Authorization header and returns void", async () => {
    fetchMock.mockResolvedValueOnce(noContent());

    const result = await deleteRatePeriod(TOKEN, 1, 5);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain("/loans/1/interest_rate_periods/5");
    expect(init.method).toBe("DELETE");
    expect((init.headers as Record<string, string>)["Authorization"]).toBe(
      `Bearer ${TOKEN}`
    );
    expect(result).toBeUndefined();
  });

  it("throws LoansApiError with status 404 when period not found", async () => {
    fetchMock.mockResolvedValueOnce(err(404, "not_found", "Loan not found"));

    await expect(deleteRatePeriod(TOKEN, 1, 999)).rejects.toMatchObject({
      code: "not_found",
      status: 404,
    });
  });
});

// ---------------------------------------------------------------------------
// Request headers — shared behaviour
// ---------------------------------------------------------------------------

describe("request headers", () => {
  it("always sends Content-Type: application/json and Accept: application/json", async () => {
    fetchMock.mockResolvedValueOnce(ok([]));

    await listLoans(TOKEN);

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers["Content-Type"]).toBe("application/json");
    expect(headers["Accept"]).toBe("application/json");
  });

  it("always includes Authorization: Bearer <token>", async () => {
    fetchMock.mockResolvedValueOnce(ok([]));

    await listLoans("my.special.token");

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers["Authorization"]).toBe("Bearer my.special.token");
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

    await expect(listLoans(TOKEN)).rejects.toMatchObject({
      code: "unknown_error",
      status: 500,
    });
  });
});
