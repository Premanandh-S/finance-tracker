# Implementation Tasks: User Authentication

## Task List

- [x] 1. Database migrations and ActiveRecord models
  - [x] 1.1 Create migration for `users` table (identifier, identifier_type, password_digest, verified, password_failed_attempts, password_locked_until)
  - [x] 1.2 Create migration for `otp_codes` table (user_id, code_digest, expires_at, used, failed_attempts)
  - [x] 1.3 Create migration for `otp_request_logs` table (user_id, requested_at)
  - [x] 1.4 Create migration for `jwt_denylist` table (jti, exp)
  - [x] 1.5 Implement `User` ActiveRecord model with `has_secure_password`, identifier format validations (E.164 phone / RFC 5322 email), and password length validation
  - [x] 1.6 Implement `OtpCode` ActiveRecord model with associations and scopes (active, expired, used)
  - [x] 1.7 Implement `JwtDenylist` ActiveRecord model with lookup scope by jti

- [x] 2. Core service objects
  - [x] 2.1 Implement `Auth::OtpDeliveryService` adapter that routes to SMS or email provider based on identifier type
  - [x] 2.2 Implement `Auth::OtpService#request_otp` — generates 6-digit numeric code, bcrypt-hashes and stores it, invalidates prior OTP, enforces rate limit (5 per 60 min), delivers via OtpDeliveryService
  - [x] 2.3 Implement `Auth::OtpService#verify_otp` — validates code against stored hash, checks expiry and attempt count, marks used on success, increments failure counter, locks after 5 failures
  - [x] 2.4 Implement `Auth::RegistrationService#register` — validates identifier uniqueness, creates unverified User, triggers OTP delivery
  - [x] 2.5 Implement `Auth::SessionService` — `issue_jwt` (HS256, 24h, UUID jti), `verify_jwt` (decode + denylist check), `refresh_jwt` (verify → issue new → denylist old), `invalidate_jwt` (add jti to denylist)
  - [x] 2.6 Implement `Auth::PasswordAuthService#authenticate` — finds user, checks lockout, bcrypt comparison, manages failure counter and 15-minute lockout after 10 failures
  - [x] 2.7 Implement `Auth::PasswordResetService` — `request_reset` (generic response for unknown identifiers, delegates to OtpService), `confirm_reset` (verify OTP, update password hash, invalidate all user JWTs)

- [x] 3. Rails controllers and routing
  - [x] 3.1 Add auth routes to `config/routes.rb` (register, otp/request, otp/verify, login, logout, refresh, password/reset/request, password/reset/confirm)
  - [x] 3.2 Implement `ApplicationController#authenticate_user!` — JWT verification middleware for protected routes
  - [x] 3.3 Implement `Auth::RegistrationsController#create` — delegates to RegistrationService, returns 422 on validation errors
    - [x] 3.4 Implement `Auth::OtpController` — `request` action (trigger OTP), `verify` action (verify OTP, return JWT); handle 429 rate limit and 423 locked responses
  - [x] 3.5 Implement `Auth::SessionsController` — `create` (dispatch to OTP or password auth), `destroy` (logout + denylist JWT), `refresh` (token refresh)
  - [x] 3.6 Implement `Auth::PasswordsController` — `reset_request` and `reset_confirm` actions
  - [x] 3.7 Implement consistent error response format `{ error: <code>, message: <human-readable> }` across all auth controllers

- [x] 4. Backend unit tests (RSpec)
  - [x] 4.1 Unit tests for `User` model — identifier format validation (valid/invalid phone and email), password length validation, duplicate identifier rejection
  - [x] 4.2 Unit tests for `Auth::OtpService` — code format, expiry, invalidation on re-request, rate limiting, lockout after 5 failures
  - [x] 4.3 Unit tests for `Auth::PasswordAuthService` — correct password succeeds, incorrect fails, failure counter increments, lockout at 10 failures, lockout duration
  - [x] 4.4 Unit tests for `Auth::SessionService` — JWT claims (sub, jti, iat, exp), HS256 algorithm, denylist lookup, refresh invalidates old token
  - [x] 4.5 Unit tests for `Auth::RegistrationService` — duplicate detection, unverified state on creation, OTP triggered
  - [x] 4.6 Unit tests for `Auth::PasswordResetService` — generic response for unknown identifiers, password updated on valid OTP, all JWTs invalidated after reset

- [x] 5. Backend integration tests (RSpec request specs)
  - [x] 5.1 `POST /auth/register` — success, duplicate identifier, invalid format
  - [x] 5.2 `POST /auth/otp/request` — success, rate limit exceeded
  - [x] 5.3 `POST /auth/otp/verify` — valid OTP returns JWT, invalid OTP, expired OTP, locked after 5 failures
  - [x] 5.4 `POST /auth/login` — OTP path, password path, unknown identifier (no enumeration), account locked
  - [x] 5.5 `DELETE /auth/logout` — JWT added to denylist, subsequent request returns 401
  - [x] 5.6 `POST /auth/refresh` — new JWT issued, old JWT rejected
  - [x] 5.7 `POST /auth/password/reset/request` — registered and unregistered identifiers both return generic success
  - [x] 5.8 `POST /auth/password/reset/confirm` — valid OTP updates password, invalid OTP does not, all prior JWTs rejected after reset
  - [x] 5.9 Protected endpoint returns 401 for expired, malformed, and denylisted tokens

- [x] 6. Backend property-based tests (RSpec + Rantly)
  - [x] 6.1 Property 1 & 2 — identifier validation: valid E.164 and RFC 5322 identifiers are accepted; arbitrary strings that are neither are rejected
  - [x] 6.2 Property 3 — duplicate registration: registering the same identifier twice always returns an error and creates only one user record
  - [x] 6.3 Property 5 — OTP format: generated OTP is always exactly 6 numeric digits
  - [x] 6.4 Property 6 — OTP expiry and single-use: OTP submitted after 10 minutes or after successful use always returns an error
  - [x] 6.5 Property 7 — OTP invalidation on re-request: first OTP is always rejected after a second OTP is issued
  - [x] 6.6 Property 8 — OTP rate limiting: 6th OTP request within 60 minutes is always rejected
  - [x] 6.7 Property 9 — OTP auth correctness: valid OTP always issues JWT; invalid OTP never issues JWT
  - [x] 6.8 Property 11 — password never stored as plaintext: password_digest never equals the plaintext input and is a valid bcrypt hash
  - [x] 6.9 Property 12 — password length: strings < 8 chars always rejected; strings >= 8 chars always accepted
  - [x] 6.10 Property 13 — password auth correctness: correct password always issues JWT; any other string never issues JWT
  - [x] 6.11 Property 15 — no identifier enumeration: error response for unknown identifier is indistinguishable from incorrect-credential response
  - [x] 6.12 Property 16 — JWT expiry and algorithm: exp is always iat + 86400; header always specifies HS256
  - [x] 6.13 Property 17 — JWT validity: valid unexpired non-denylisted token always grants access; expired/malformed/denylisted token always returns 401
  - [x] 6.14 Property 18 — logout invalidation: token always returns 401 after logout
  - [x] 6.15 Property 19 — token refresh: new token is valid; old token is rejected after refresh
  - [x] 6.16 Property 20 — password reset correctness: new password authenticates; old password does not; all prior JWTs rejected
  - [x] 6.17 Property 21 — invalid OTP during reset: password_digest is unchanged when invalid/expired OTP is submitted

- [x] 7. React frontend — API client and auth hook
  - [x] 7.1 Implement `authApi.ts` — typed fetch wrappers for all auth endpoints with error code → message mapping
  - [x] 7.2 Implement `useAuth` hook — auth state (user, token), login/logout actions, JWT storage in memory, 401 redirect trigger, silent refresh via HTTP-only cookie

- [-] 8. React frontend — pages and components
  - [x] 8.1 Implement `SignUpPage` — identifier input, method selection (OTP / password), form validation, API call via authApi
  - [x] 8.2 Implement `LoginPage` — identifier input, method selection, form validation, API call via authApi
  - [x] 8.3 Implement `OtpVerifyPage` — 6-digit OTP input, countdown timer (10 min), resend button enabled at zero, verify button disabled when timer expired
  - [x] 8.4 Implement `PasswordResetPage` — request step (identifier input) and confirm step (OTP + new password input)
  - [x] 8.5 Implement `ProtectedRoute` component — redirects unauthenticated users to `/login`

- [ ] 9. React frontend tests (Jest + React Testing Library)
  - [ ] 9.1 Component tests for `SignUpPage` and `LoginPage` — renders correct elements, method selection toggles, error messages displayed on API error
  - [ ] 9.2 Component tests for `OtpVerifyPage` — countdown timer renders, OTP input present, resend button state
  - [ ] 9.3 Unit tests for `useAuth` hook — token stored on login, cleared on logout, redirect triggered on 401
  - [ ] 9.4 Unit tests for `authApi` — correct endpoint URLs called, error codes mapped to readable messages, network error handled
  - [ ] 9.5 Integration tests for full sign-up flow (mocked API): identifier → OTP → verify → redirect to dashboard
  - [ ] 9.6 Integration tests for login flows (OTP and password paths) and password reset flow
  - [ ] 9.7 Integration test for session expiry — 401 response triggers redirect to login
