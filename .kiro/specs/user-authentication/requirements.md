# Requirements Document

## Introduction

This feature covers user authentication for the personal finance management web app. Users can register and log in using either a phone number or email address. Two authentication methods are supported: OTP-based (delivered via SMS for phone, or email for email address) and password-based. The system must securely manage sessions and protect access to all financial data.

## Glossary

- **Auth_System**: The authentication module of the Rails API backend responsible for registration, login, session management, and OTP delivery.
- **User**: A registered individual who has completed sign-up with a phone number or email address.
- **Identifier**: A phone number or email address used to uniquely identify a User.
- **OTP**: A one-time password — a time-limited numeric code sent to the User's phone (via SMS) or email for verification.
- **Password**: A secret string chosen by the User, stored as a bcrypt hash, used for password-based authentication.
- **Session**: An authenticated context represented by a JWT token issued to the User upon successful login.
- **JWT**: JSON Web Token — a signed token returned to the client and used to authenticate subsequent API requests.
- **OTP_Service**: The backend service responsible for generating, storing, and validating OTPs.
- **SMS_Provider**: A third-party service used to deliver OTP codes via SMS to a phone number.
- **Email_Provider**: A third-party service used to deliver OTP codes via email to an email address.
- **React_Client**: The React frontend application that communicates with the Rails API via REST.

---

## Requirements

### Requirement 1: User Registration

**User Story:** As a new user, I want to register with my phone number or email address, so that I can create an account and access the app.

#### Acceptance Criteria

1. THE Auth_System SHALL accept a phone number or email address as the Identifier during registration.
2. WHEN a registration request is submitted with an Identifier that already exists, THE Auth_System SHALL return an error response indicating the Identifier is already in use.
3. WHEN a registration request is submitted with an invalid phone number format, THE Auth_System SHALL return a descriptive validation error.
4. WHEN a registration request is submitted with an invalid email address format, THE Auth_System SHALL return a descriptive validation error.
5. THE Auth_System SHALL require the User to verify their Identifier via OTP before the account is activated.
6. WHEN a registration request is submitted with a valid Identifier, THE Auth_System SHALL send an OTP to that Identifier within 30 seconds.

---

### Requirement 2: OTP Generation and Delivery

**User Story:** As a user, I want to receive a one-time password on my phone or email, so that I can verify my identity without needing a password.

#### Acceptance Criteria

1. WHEN an OTP is requested for a phone number, THE OTP_Service SHALL generate a 6-digit numeric OTP and deliver it via the SMS_Provider.
2. WHEN an OTP is requested for an email address, THE OTP_Service SHALL generate a 6-digit numeric OTP and deliver it via the Email_Provider.
3. THE OTP_Service SHALL expire each OTP after 10 minutes from the time of generation.
4. THE OTP_Service SHALL invalidate a previously issued OTP when a new OTP is requested for the same Identifier.
5. IF the SMS_Provider or Email_Provider returns a delivery failure, THEN THE Auth_System SHALL return an error response indicating the OTP could not be delivered.
6. THE OTP_Service SHALL allow a maximum of 5 OTP requests per Identifier within any 60-minute window.
7. WHEN the OTP request limit is exceeded, THE Auth_System SHALL return an error response and SHALL NOT send an OTP until the rate limit window resets.

---

### Requirement 3: OTP Verification

**User Story:** As a user, I want to submit the OTP I received, so that I can authenticate and access my account.

#### Acceptance Criteria

1. WHEN a User submits a valid, unexpired OTP for their Identifier, THE Auth_System SHALL authenticate the User and return a JWT.
2. WHEN a User submits an OTP that does not match the issued OTP for their Identifier, THE Auth_System SHALL return an error response and SHALL NOT issue a JWT.
3. WHEN a User submits an OTP that has expired, THE Auth_System SHALL return an error response indicating the OTP has expired.
4. THE OTP_Service SHALL invalidate an OTP after it has been successfully verified, preventing reuse.
5. THE Auth_System SHALL lock OTP verification for an Identifier after 5 consecutive failed OTP attempts and SHALL require a new OTP to be requested before further attempts are allowed.

---

### Requirement 4: Password-Based Authentication

**User Story:** As a user, I want to set and use a password to log in, so that I have an alternative to OTP when I prefer not to wait for a code.

#### Acceptance Criteria

1. WHEN a User sets a password during or after registration, THE Auth_System SHALL store the password as a bcrypt hash and SHALL NOT store the plaintext password.
2. THE Auth_System SHALL require passwords to be at least 8 characters in length.
3. WHEN a User submits a valid Identifier and matching password, THE Auth_System SHALL authenticate the User and return a JWT.
4. WHEN a User submits a valid Identifier and an incorrect password, THE Auth_System SHALL return an error response and SHALL NOT issue a JWT.
5. WHEN a User submits a valid Identifier and an incorrect password 10 consecutive times, THE Auth_System SHALL lock the account for 15 minutes and SHALL return an error response indicating the account is temporarily locked.
6. WHILE an account is locked, THE Auth_System SHALL reject all password-based login attempts for that Identifier and SHALL return an error response indicating the remaining lock duration.

---

### Requirement 5: Login Flow

**User Story:** As a registered user, I want to log in with my phone or email using either OTP or password, so that I can access my financial data.

#### Acceptance Criteria

1. THE Auth_System SHALL accept a login request containing an Identifier and an authentication method (OTP or password).
2. WHEN a login request is submitted with an Identifier that does not correspond to a registered User, THE Auth_System SHALL return an error response and SHALL NOT reveal whether the Identifier exists.
3. WHEN a login request specifies OTP as the authentication method, THE Auth_System SHALL trigger OTP generation and delivery to the Identifier.
4. WHEN a login request specifies password as the authentication method, THE Auth_System SHALL validate the submitted password against the stored hash for that Identifier.
5. WHEN authentication succeeds, THE Auth_System SHALL return a JWT with an expiry of 24 hours.

---

### Requirement 6: Session Management

**User Story:** As an authenticated user, I want my session to be securely maintained, so that I don't have to log in repeatedly during normal use.

#### Acceptance Criteria

1. THE Auth_System SHALL sign all JWTs with a secret key using the HS256 algorithm.
2. WHEN a request is received with a valid, unexpired JWT, THE Auth_System SHALL allow access to protected resources.
3. WHEN a request is received with an expired JWT, THE Auth_System SHALL return a 401 Unauthorized response.
4. WHEN a request is received with a malformed or tampered JWT, THE Auth_System SHALL return a 401 Unauthorized response.
5. WHEN a User logs out, THE Auth_System SHALL invalidate the current JWT so it cannot be reused.
6. THE Auth_System SHALL support token refresh, issuing a new JWT when a valid, unexpired JWT is presented to the refresh endpoint.

---

### Requirement 7: Password Reset

**User Story:** As a user who has forgotten their password, I want to reset it using an OTP, so that I can regain access to my account.

#### Acceptance Criteria

1. WHEN a password reset is requested for a registered Identifier, THE Auth_System SHALL send an OTP to that Identifier within 30 seconds.
2. WHEN a password reset is requested for an Identifier that does not correspond to a registered User, THE Auth_System SHALL return a generic success response and SHALL NOT reveal whether the Identifier exists.
3. WHEN a User submits a valid, unexpired OTP and a new password for a password reset, THE Auth_System SHALL update the stored password hash and invalidate all existing JWTs for that User.
4. WHEN a User submits an invalid or expired OTP during password reset, THE Auth_System SHALL return an error response and SHALL NOT update the password.
5. THE Auth_System SHALL require the new password to meet the same minimum length requirement as defined in Requirement 4.

---

### Requirement 8: React Client Integration

**User Story:** As a user, I want a clear and responsive sign-up and login UI, so that I can authenticate easily from any device.

#### Acceptance Criteria

1. THE React_Client SHALL provide a sign-up page that accepts an Identifier (phone or email) and allows the User to choose between OTP and password authentication methods.
2. THE React_Client SHALL provide a login page that accepts an Identifier and the chosen authentication method.
3. WHEN an OTP is requested, THE React_Client SHALL display an OTP input form and a countdown timer showing the remaining validity period.
4. WHEN authentication succeeds, THE React_Client SHALL store the JWT in memory or a secure HTTP-only cookie and SHALL redirect the User to the dashboard.
5. WHEN a JWT expires or is invalidated, THE React_Client SHALL redirect the User to the login page.
6. WHEN an API error response is received during authentication, THE React_Client SHALL display a user-readable error message without exposing internal error details.
7. THE React_Client SHALL provide a password reset flow accessible from the login page.
