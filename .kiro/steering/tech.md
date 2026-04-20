# Tech Stack

## Backend
- **Ruby on Rails** 7.0 (API mode assumed)
- **PostgreSQL** — primary database
- **bcrypt** — password and OTP code hashing (`has_secure_password`, `BCrypt::Password.create`)
- **JWT** — session tokens with a denylist table for revocation

## Frontend
- **React** (separate app, not yet scaffolded in this repo)

## Authentication Flow
- Users identify via E.164 phone number or RFC 5322 email
- OTP: 6-digit numeric, bcrypt-hashed, 10-minute expiry, max 5 requests per 60-minute window
- Password: bcrypt via `has_secure_password`, minimum 8 characters
- JWT denylist used for logout / token revocation

## Testing
- **RSpec** — unit and integration tests
- `rails_helper` required in all spec files
- `instance_double` used for service collaborator isolation
- `freeze_time` used for time-sensitive assertions

## Common Commands

```bash
# Run all tests
bundle exec rspec

# Run a specific spec file
bundle exec rspec backend/spec/models/user_spec.rb

# Run database migrations
rails db:migrate

# Rollback last migration
rails db:rollback
```
