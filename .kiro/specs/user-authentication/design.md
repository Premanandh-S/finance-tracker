# Design Document: User Authentication

## Overview

This document describes the technical design for the user authentication system of the personal finance management web app. The system supports registration and login via phone number or email address, with two authentication methods: OTP-based and password-based. Sessions are managed using JWT tokens (HS256). The backend is a Rails API-only application backed by PostgreSQL; the frontend is a React SPA.

Key design goals:
- Security-first: bcrypt password hashing, rate limiting, account lockout, JWT invalidation
- Flexibility: users can authenticate via OTP or password, using either phone or email
- Stateless sessions with a server-side token denylist for logout/invalidation support
- Clean separation between transport (HTTP), business logic (service objects), and persistence (ActiveRecord models)

---

## Architecture

The authentication system follows a layered architecture within the Rails API:

```
React Client (frontend/)
      │  REST/JSON over HTTPS
      ▼
Rails Router → Auth Controllers
                    │
                    ▼
              Auth Service Objects
              ┌─────────────────────────────────────┐
              │  RegistrationService                │
              │  OtpService                         │
              │  PasswordAuthService                │
              │  SessionService (JWT issue/verify)  │
              │  PasswordResetService               │
              └─────────────────────────────────────┘
                    │
                    ▼
              ActiveRecord Models
              ┌──────────────────────────────────────┐
              │  User                                │
              │  OtpCode                             │
              │  JwtDenylist                         │
              └──────────────────────────────────────┘
                    │
                    ▼
              PostgreSQL Database
```

External dependencies:
- **SMS_Provider** (e.g., Twilio): delivers OTP codes to phone numbers
- **Email_Provider** (e.g., SendGrid / Rails ActionMailer): delivers OTP codes to email addresses

Both providers are wrapped behind an `OtpDeliveryService` interface so they can be swapped without changing business logic.

### Request Flow — OTP Login

```
Client → POST /auth/login {identifier, method: "otp"}
       → OtpService.request_otp(identifier)
           → generate 6-digit code
           → store OtpCode record (hashed)
           → deliver via SMS/Email provider
       ← 200 OK

Client → POST /auth/otp/verify {identifier, otp}
       → OtpService.verify_otp(identifier, otp)
           → check expiry, attempt count, match
           → mark OTP used
       → SessionService.issue_jwt(user)
       ← 200 OK { token: "..." }
```

### Request Flow — Password Login

```
Client → POST /auth/login {identifier, method: "password", password}
       → PasswordAuthService.authenticate(identifier, password)
           → find user, check lockout
           → BCrypt::Password.new(hash) == password
           → on failure: increment attempt counter, lock if threshold reached
       → SessionService.issue_jwt(user)
       ← 200 OK { token: "..." }
```

---

## Components and Interfaces

### Rails Controllers (`backend/app/controllers/auth/`)

| Controller | Endpoint | Responsibility |
|---|---|---|
| `RegistrationsController` | `POST /auth/register` | Accept identifier + optional password, trigger OTP for verification |
| `OtpController` | `POST /auth/otp/request` | Request a new OTP for an identifier |
| `OtpController` | `POST /auth/otp/verify` | Verify OTP, return JWT |
| `SessionsController` | `POST /auth/login` | Dispatch to OTP or password auth |
| `SessionsController` | `DELETE /auth/logout` | Add JWT to denylist |
| `SessionsController` | `POST /auth/refresh` | Issue new JWT from valid existing JWT |
| `PasswordsController` | `POST /auth/password/reset/request` | Trigger password-reset OTP |
| `PasswordsController` | `POST /auth/password/reset/confirm` | Verify OTP + set new password |

All controllers inherit from `ApplicationController` which provides `authenticate_user!` (JWT verification) for protected routes.

### Service Objects (`backend/app/services/auth/`)

**`OtpService`**
- `request_otp(identifier)` → generates, stores, and delivers OTP; enforces rate limit (5 per 60 min); invalidates prior OTP
- `verify_otp(identifier, code)` → validates code against stored hash, checks expiry and attempt count; marks used on success; increments failure counter

**`PasswordAuthService`**
- `authenticate(identifier, password)` → finds user, checks lockout, compares bcrypt hash, manages failure counter and lockout

**`RegistrationService`**
- `register(identifier, password: nil)` → creates unverified User, triggers OTP delivery

**`SessionService`**
- `issue_jwt(user)` → signs JWT (HS256, 24h expiry) with `user_id` and `jti` (unique token ID) claims
- `verify_jwt(token)` → decodes and validates JWT; checks denylist by `jti`
- `refresh_jwt(token)` → verifies existing token, issues new one, denylists old `jti`
- `invalidate_jwt(token)` → adds `jti` to `JwtDenylist`

**`PasswordResetService`**
- `request_reset(identifier)` → sends OTP (reuses OtpService); returns generic success regardless of whether identifier exists
- `confirm_reset(identifier, otp, new_password)` → verifies OTP, updates password hash, invalidates all JWTs for user

**`OtpDeliveryService`** (interface/adapter)
- `deliver(identifier, code)` → routes to `SmsProvider` or `EmailProvider` based on identifier type

### React Frontend (`frontend/src/`)

| Module | Path | Responsibility |
|---|---|---|
| `SignUpPage` | `pages/SignUpPage.tsx` | Identifier input + method selection |
| `LoginPage` | `pages/LoginPage.tsx` | Identifier + method selection |
| `OtpVerifyPage` | `pages/OtpVerifyPage.tsx` | OTP input + countdown timer |
| `PasswordResetPage` | `pages/PasswordResetPage.tsx` | Reset flow (request + confirm) |
| `useAuth` hook | `hooks/useAuth.ts` | Auth state, login/logout actions, token storage |
| `authApi` | `api/authApi.ts` | Typed wrappers for all auth endpoints |
| `ProtectedRoute` | `components/ProtectedRoute.tsx` | Redirects unauthenticated users to login |

JWT storage: stored in memory (React context) with an HTTP-only cookie used for the refresh token. This avoids XSS exposure of the access token while supporting silent refresh.

---

## Data Models

### `users` table

```sql
CREATE TABLE users (
  id                        BIGSERIAL PRIMARY KEY,
  identifier                VARCHAR(255) NOT NULL UNIQUE,
  identifier_type           VARCHAR(10)  NOT NULL CHECK (identifier_type IN ('phone', 'email')),
  password_digest           VARCHAR(255),                    -- bcrypt hash; NULL if OTP-only
  verified                  BOOLEAN      NOT NULL DEFAULT FALSE,
  password_failed_attempts  INTEGER      NOT NULL DEFAULT 0,
  password_locked_until     TIMESTAMP,
  created_at                TIMESTAMP    NOT NULL,
  updated_at                TIMESTAMP    NOT NULL
);

CREATE INDEX idx_users_identifier ON users (identifier);
```

ActiveRecord model: `User`
- `has_secure_password validations: false` (bcrypt via Rails; validations handled manually)
- Validations: identifier format (E.164 for phone, RFC 5322 for email), minimum password length (8 chars)

### `otp_codes` table

```sql
CREATE TABLE otp_codes (
  id                BIGSERIAL PRIMARY KEY,
  user_id           BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_digest       VARCHAR(255) NOT NULL,   -- bcrypt hash of the 6-digit code
  expires_at        TIMESTAMP    NOT NULL,
  used              BOOLEAN      NOT NULL DEFAULT FALSE,
  failed_attempts   INTEGER      NOT NULL DEFAULT 0,
  created_at        TIMESTAMP    NOT NULL,
  updated_at        TIMESTAMP    NOT NULL
);

CREATE INDEX idx_otp_codes_user_id ON otp_codes (user_id);
```

ActiveRecord model: `OtpCode`
- Only one active (unused, unexpired) OTP per user at a time; prior records are marked used when a new one is issued
- `code_digest` stores a bcrypt hash of the plaintext OTP to prevent exposure if the DB is compromised

### `otp_request_logs` table

Used for rate limiting OTP requests (5 per identifier per 60-minute window).

```sql
CREATE TABLE otp_request_logs (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_request_logs_user_time ON otp_request_logs (user_id, requested_at);
```

### `jwt_denylist` table

Used to invalidate specific JWTs on logout, password reset, or token refresh.

```sql
CREATE TABLE jwt_denylist (
  id         BIGSERIAL PRIMARY KEY,
  jti        VARCHAR(255) NOT NULL UNIQUE,   -- JWT ID claim
  exp        TIMESTAMP    NOT NULL,          -- token expiry; used for cleanup
  created_at TIMESTAMP    NOT NULL
);

CREATE INDEX idx_jwt_denylist_jti ON jwt_denylist (jti);
```

Expired entries can be pruned periodically (e.g., a scheduled Rails task) since a token past its `exp` is already invalid.

### JWT Payload Structure

```json
{
  "sub": "42",
  "jti": "a1b2c3d4-uuid",
  "iat": 1700000000,
  "exp": 1700086400
}
```

- `sub`: user ID
- `jti`: unique token ID (UUID v4), used for denylist lookup
- `iat`: issued-at timestamp
- `exp`: expiry (24 hours from `iat`)

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Valid identifiers are accepted

*For any* string that is a well-formed E.164 phone number or a valid RFC 5322 email address, the registration validation logic SHALL accept it as a valid identifier.

**Validates: Requirements 1.1**

---

### Property 2: Invalid identifier formats are rejected

*For any* string that is neither a valid E.164 phone number nor a valid email address, the registration validation logic SHALL reject it with a descriptive error and SHALL NOT create a user record.

**Validates: Requirements 1.3, 1.4**

---

### Property 3: Duplicate registration is rejected

*For any* identifier that is already registered, a second registration attempt SHALL return an error indicating the identifier is in use, and no new user record SHALL be created.

**Validates: Requirements 1.2**

---

### Property 4: Unverified users cannot access protected resources

*For any* user who has registered but not yet completed OTP verification, all requests to protected endpoints SHALL be rejected with a 401 response.

**Validates: Requirements 1.5**

---

### Property 5: OTP is always a 6-digit numeric code

*For any* valid identifier (phone or email), the OTP generated by OtpService SHALL be exactly 6 characters long and consist entirely of numeric digits (0–9).

**Validates: Requirements 2.1, 2.2**

---

### Property 6: OTP expiry and single-use enforcement

*For any* OTP that was generated more than 10 minutes ago, or that has already been successfully verified once, submitting it SHALL return an error and SHALL NOT issue a JWT.

**Validates: Requirements 2.3, 3.3, 3.4**

---

### Property 7: New OTP invalidates the previous OTP

*For any* identifier, if a second OTP is requested after a first has been issued, the first OTP SHALL be invalidated — submitting the first OTP after the second is issued SHALL return an error.

**Validates: Requirements 2.4**

---

### Property 8: OTP rate limiting is enforced

*For any* identifier, after 5 OTP requests within a 60-minute window, any further OTP request within that window SHALL be rejected and no OTP SHALL be delivered.

**Validates: Requirements 2.6, 2.7**

---

### Property 9: OTP authentication correctness

*For any* user and any OTP: if the OTP is valid (matches the issued code, is unexpired, and the account is not locked), authentication SHALL succeed and return a JWT; if the OTP is invalid or expired, authentication SHALL fail and no JWT SHALL be issued.

**Validates: Requirements 3.1, 3.2**

---

### Property 10: OTP verification lockout

*For any* identifier, after 5 consecutive failed OTP verification attempts, all further OTP verification attempts SHALL be rejected until a new OTP is requested, regardless of the submitted code.

**Validates: Requirements 3.5**

---

### Property 11: Password is never stored as plaintext

*For any* password string set by a user, the value stored in `password_digest` SHALL NOT equal the plaintext password, and SHALL be a valid bcrypt hash (verifiable via `BCrypt::Password.new(digest) == plaintext`).

**Validates: Requirements 4.1**

---

### Property 12: Password minimum length is enforced

*For any* string shorter than 8 characters, password validation SHALL reject it. *For any* string of 8 or more characters, password validation SHALL accept it (subject to other constraints).

**Validates: Requirements 4.2, 7.5**

---

### Property 13: Password authentication correctness

*For any* user with a set password: submitting the correct password SHALL return a JWT; submitting any other string as the password SHALL return an error and no JWT SHALL be issued.

**Validates: Requirements 4.3, 4.4**

---

### Property 14: Account lockout after repeated password failures

*For any* user, after 10 consecutive failed password login attempts, all further password-based login attempts SHALL be rejected for 15 minutes, and the error response SHALL indicate the remaining lock duration.

**Validates: Requirements 4.5, 4.6**

---

### Property 15: No identifier enumeration

*For any* identifier that is not registered in the system, the error response returned by login and password-reset-request endpoints SHALL be indistinguishable from the response returned for an incorrect credential on a registered identifier.

**Validates: Requirements 5.2, 7.2**

---

### Property 16: JWT expiry and algorithm

*For any* JWT issued by the system: the `exp` claim SHALL be exactly 86400 seconds (24 hours) after the `iat` claim, and the JWT header SHALL specify `"alg": "HS256"`.

**Validates: Requirements 5.5, 6.1**

---

### Property 17: Valid JWT grants access; invalid JWT is rejected

*For any* valid, unexpired, non-denylisted JWT, requests to protected endpoints SHALL succeed (200). *For any* expired, malformed, tampered, or denylisted token, requests to protected endpoints SHALL return 401 Unauthorized.

**Validates: Requirements 6.2, 6.3, 6.4**

---

### Property 18: Logout invalidates the JWT

*For any* valid JWT, after the logout endpoint is called with that token, any subsequent request using the same token SHALL return 401 Unauthorized.

**Validates: Requirements 6.5**

---

### Property 19: Token refresh invalidates old token and issues new one

*For any* valid unexpired JWT, calling the refresh endpoint SHALL return a new valid JWT and SHALL invalidate the original token so it can no longer be used to access protected resources.

**Validates: Requirements 6.6**

---

### Property 20: Password reset updates password and invalidates all sessions

*For any* user, after a successful password reset (valid OTP + new password meeting length requirements): (a) the new password SHALL authenticate successfully, (b) the old password SHALL no longer authenticate, and (c) all JWTs issued before the reset SHALL be rejected.

**Validates: Requirements 7.3**

---

### Property 21: Invalid OTP during password reset does not change password

*For any* user and any OTP that is invalid or expired, submitting it during a password reset SHALL return an error and the stored password hash SHALL remain unchanged.

**Validates: Requirements 7.4**

---

## Error Handling

### Backend (Rails API)

| Scenario | HTTP Status | Response Body |
|---|---|---|
| Identifier already registered | 422 Unprocessable Entity | `{ error: "identifier_taken", message: "..." }` |
| Invalid identifier format | 422 Unprocessable Entity | `{ error: "invalid_identifier", message: "..." }` |
| OTP delivery failure | 503 Service Unavailable | `{ error: "otp_delivery_failed", message: "..." }` |
| OTP rate limit exceeded | 429 Too Many Requests | `{ error: "otp_rate_limit", message: "...", retry_after: <seconds> }` |
| OTP invalid or expired | 401 Unauthorized | `{ error: "otp_invalid", message: "..." }` |
| OTP verification locked | 423 Locked | `{ error: "otp_locked", message: "..." }` |
| Password too short | 422 Unprocessable Entity | `{ error: "password_too_short", message: "..." }` |
| Incorrect password | 401 Unauthorized | `{ error: "invalid_credentials", message: "..." }` |
| Account locked (password) | 423 Locked | `{ error: "account_locked", message: "...", locked_until: <iso8601> }` |
| JWT expired | 401 Unauthorized | `{ error: "token_expired", message: "..." }` |
| JWT invalid/tampered | 401 Unauthorized | `{ error: "token_invalid", message: "..." }` |
| Identifier not found (login/reset) | 401 Unauthorized | `{ error: "invalid_credentials", message: "..." }` (generic — no enumeration) |

All error responses follow a consistent envelope: `{ error: <code>, message: <human-readable> }`. Internal details (stack traces, DB errors) are never exposed to the client.

### Frontend (React)

- API errors are caught in `authApi.ts` and mapped to user-readable messages via an error code → message map
- Network errors (no response) show a generic "Something went wrong, please try again" message
- The OTP countdown timer is driven by the frontend; when it reaches zero, the "Resend OTP" button is enabled and the verify button is disabled
- 401 responses on protected routes trigger an automatic redirect to `/login` via the `useAuth` hook

---

## Testing Strategy

### Backend (RSpec)

**Unit tests** (`spec/services/auth/`):
- `OtpService`: OTP generation format, expiry logic, invalidation on re-request, rate limiting, lockout
- `PasswordAuthService`: bcrypt comparison, failure counter, lockout logic
- `SessionService`: JWT structure (claims, algorithm), denylist lookup, refresh logic
- `RegistrationService`: identifier validation, duplicate detection, unverified state
- `PasswordResetService`: generic response for unknown identifiers, password update, JWT invalidation

**Integration tests** (`spec/requests/auth/`):
- Full request/response cycle for each endpoint
- OTP delivery mocked via test doubles (no real SMS/email sent)
- JWT round-trip: issue → use → expire → refresh → logout

**Property-based tests** (`spec/properties/auth/`):
- Library: [RSpec + Faker + custom generators](https://github.com/thoughtbot/factory_bot) with [rantly](https://github.com/rantly-rb/rantly) for property-based generation
- Minimum 100 iterations per property test
- Each test is tagged with the property it validates

Tag format: `# Feature: user-authentication, Property N: <property_text>`

Properties to implement as property-based tests:
- Property 1, 2: identifier validation (generate valid/invalid identifiers)
- Property 3: duplicate registration (generate identifier, register twice)
- Property 5: OTP format (generate identifiers, verify 6-digit numeric output)
- Property 6: OTP expiry/single-use (time-travel with `Timecop`)
- Property 7: OTP invalidation on re-request
- Property 8: OTP rate limiting (generate N requests, verify 6th is rejected)
- Property 9: OTP auth correctness (generate valid/invalid OTPs)
- Property 11: password never stored as plaintext (generate password strings)
- Property 12: password length validation (generate strings of varying length)
- Property 13: password auth correctness (generate correct/incorrect passwords)
- Property 15: no identifier enumeration (generate unregistered identifiers, compare responses)
- Property 16: JWT expiry and algorithm (generate auth events, decode JWT)
- Property 17: JWT validity (generate valid/invalid/expired tokens)
- Property 18: logout invalidation (generate sessions, logout, retry)
- Property 19: token refresh (generate sessions, refresh, verify old token rejected)
- Property 20: password reset correctness (generate users, reset, verify)
- Property 21: invalid OTP during reset (generate invalid OTPs, verify no change)

Example-based tests cover: Properties 4, 10, 14 (lockout scenarios with fixed attempt counts), and all Requirement 8 (React UI) acceptance criteria.

### Frontend (Jest + React Testing Library)

**Unit/component tests** (`frontend/src/__tests__/`):
- `SignUpPage`, `LoginPage`: render correct elements, method selection
- `OtpVerifyPage`: countdown timer renders, OTP input present
- `useAuth` hook: token storage, redirect on 401
- `authApi`: correct endpoint calls, error mapping

**Integration tests**:
- Full sign-up flow (mocked API): identifier → OTP → verify → redirect
- Full login flow (OTP and password paths)
- Password reset flow
- Session expiry → redirect to login

PBT is not applied to the React frontend — UI rendering and interaction tests are better served by example-based component tests and snapshot tests.
