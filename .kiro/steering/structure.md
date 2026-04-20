# Project Structure

## Top Level

```
backend/   # Ruby on Rails API
README.md  # Product requirements and tech stack notes
```

Frontend (React) is not yet scaffolded.

## Backend

```
backend/
├── app/
│   ├── models/
│   │   ├── user.rb               # Core user model; identifier + password auth
│   │   ├── otp_code.rb           # OTP records with bcrypt digest and expiry
│   │   ├── otp_request_log.rb    # Rate-limit audit log for OTP requests
│   │   └── jwt_denylist.rb       # Revoked JWT tokens (jti + exp)
│   └── services/
│       └── auth/
│           ├── otp_service.rb          # OTP generation, storage, rate limiting, delivery
│           └── otp_delivery_service.rb # Routes OTP to SMS or email provider
├── db/
│   └── migrate/                  # One file per migration, timestamped
└── spec/
    ├── models/                   # Model unit tests
    └── services/
        └── auth/                 # Service unit tests
```

## Conventions

- **Services** live under `app/services/<domain>/` and are plain Ruby objects (POROs) namespaced by module (e.g. `Auth::OtpService`)
- **Models** are thin — validations, associations, scopes, and simple instance methods only; business logic belongs in services
- All Ruby files start with `# frozen_string_literal: true`
- YARD-style `@param`, `@return`, and `@raise` doc comments on all public methods
- Custom errors are defined as inner classes of the service that raises them (e.g. `Auth::OtpService::RateLimitError`)
- Spec files mirror the `app/` directory structure under `spec/`
- Spec helper methods (`valid_attrs`, `create_user`, etc.) are defined at the top of each spec file, not in shared factories
