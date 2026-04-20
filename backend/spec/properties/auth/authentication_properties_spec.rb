# frozen_string_literal: true

require "rails_helper"
require "rantly/property"

# Patch property_of into RSpec example groups (rantly/rspec_extensions does the
# same thing but requires the top-level 'rspec' gem which is not available in
# this environment — rspec-rails exposes 'rspec/core' instead).
RSpec::Core::ExampleGroup.class_eval do
  def property_of(&block)
    Rantly::Property.new(block)
  end
end

# =============================================================================
# Property-Based Tests: User Authentication
# Feature: user-authentication
#
# Each describe block is tagged with the property it validates.
# All properties run 100 iterations via Rantly's property_of { }.check(100).
# =============================================================================

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def build_user(identifier:, password: "securepass1")
  User.create!(identifier: identifier, password: password)
end

def stub_otp_delivery(user)
  delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
  allow(Auth::OtpDeliveryService).to receive(:new).with(user).and_return(delivery_double)
  delivery_double
end

def stub_otp_delivery_any
  delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
  allow(Auth::OtpDeliveryService).to receive(:new).and_return(delivery_double)
  delivery_double
end

def create_otp_for(user, plaintext_code: "123456", overrides: {})
  OtpCode.create!({
    user:            user,
    code_digest:     BCrypt::Password.create(plaintext_code),
    expires_at:      10.minutes.from_now,
    used:            false,
    failed_attempts: 0
  }.merge(overrides))
end

def seed_otp_request_logs(user, count:, requested_at: 30.minutes.ago)
  count.times do
    OtpRequestLog.create!(user: user, requested_at: requested_at)
  end
end

def decode_jwt_raw(token)
  secret = Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"]
  JWT.decode(token, secret, true, { algorithm: "HS256" })
end

def decode_jwt_header(token)
  header_segment = token.split(".").first
  padded = header_segment + "=" * ((4 - header_segment.length % 4) % 4)
  JSON.parse(Base64.urlsafe_decode64(padded))
end

# =============================================================================
# Property 1 & 2 — Identifier validation
# Feature: user-authentication, Property 1: Valid identifiers are accepted
# Feature: user-authentication, Property 2: Invalid identifier formats are rejected
# =============================================================================
RSpec.describe "Property 1 & 2: Identifier validation" do
  # Feature: user-authentication, Property 1: Valid identifiers are accepted
  describe "Property 1 — valid E.164 phone numbers are accepted" do
    it "accepts any well-formed E.164 phone number" do
      # Validates: Requirements 1.1
      property_of {
        country_code = integer(1..99)
        # E.164: + followed by country code (1-3 digits) + subscriber (7-12 digits) = 8-15 total digits
        subscriber = sized(10) { string(:digit) }
        "+#{country_code}#{subscriber}"
      }.check(100) do |phone|
        user = User.new(identifier: phone)
        expect(user.valid?).to be(true), "Expected #{phone.inspect} to be valid, errors: #{user.errors.full_messages}"
      end
    end

    it "accepts any well-formed RFC 5322 email address" do
      # Validates: Requirements 1.1
      property_of {
        local  = sized(5) { string(:alpha) }
        domain = sized(5) { string(:alpha) }
        "#{local}@#{domain}.com"
      }.check(100) do |email|
        user = User.new(identifier: email)
        expect(user.valid?).to be(true), "Expected #{email.inspect} to be valid, errors: #{user.errors.full_messages}"
      end
    end
  end

  # Feature: user-authentication, Property 2: Invalid identifier formats are rejected
  describe "Property 2 — arbitrary non-identifier strings are rejected" do
    it "rejects any string that is neither E.164 nor a valid email" do
      # Validates: Requirements 1.3, 1.4
      property_of {
        # Pure alpha strings: no '@' and no leading '+', so neither phone nor email
        sized(rand(3..20)) { string(:alpha) }
      }.check(100) do |str|
        user = User.new(identifier: str)
        expect(user.valid?).to be(false), "Expected #{str.inspect} to be invalid but it was accepted"
        expect(user.errors[:identifier]).not_to be_empty
      end
    end
  end
end

# =============================================================================
# Property 3 — Duplicate registration
# Feature: user-authentication, Property 3: Duplicate registration is rejected
# =============================================================================
RSpec.describe "Property 3: Duplicate registration" do
  before { stub_otp_delivery_any }

  it "always returns an error on second registration and creates only one user record" do
    # Validates: Requirements 1.2
    property_of {
      local  = sized(6) { string(:alpha) }
      domain = sized(5) { string(:alpha) }
      "#{local}@#{domain}.com"
    }.check(100) do |identifier|
      # Clean slate for each iteration
      User.delete_all
      OtpCode.delete_all
      OtpRequestLog.delete_all

      service = Auth::RegistrationService.new

      # First registration must succeed
      service.register(identifier, password: "securepass1")
      expect(User.count).to eq(1)

      # Second registration must raise IdentifierTakenError
      expect {
        service.register(identifier, password: "securepass1")
      }.to raise_error(Auth::RegistrationService::IdentifierTakenError)

      # Still only one user record
      expect(User.count).to eq(1)
    end
  end
end

# =============================================================================
# Property 5 — OTP format
# Feature: user-authentication, Property 5: OTP is always a 6-digit numeric code
# =============================================================================
RSpec.describe "Property 5: OTP format" do
  it "generated OTP is always exactly 6 numeric digits" do
    # Validates: Requirements 2.1, 2.2
    property_of {
      local  = sized(5) { string(:alpha) }
      domain = sized(5) { string(:alpha) }
      "#{local}@#{domain}.com"
    }.check(100) do |identifier|
      user = User.create!(identifier: identifier, password: "securepass1")
      stub_otp_delivery(user)

      code = Auth::OtpService.new(user).request_otp
      expect(code).to match(/\A\d{6}\z/),
        "Expected 6-digit numeric OTP, got: #{code.inspect}"

      # Clean up for next iteration
      user.destroy
    end
  end
end

# =============================================================================
# Property 6 — OTP expiry and single-use
# Feature: user-authentication, Property 6: OTP expiry and single-use enforcement
# =============================================================================
RSpec.describe "Property 6: OTP expiry and single-use" do
  let(:user) { User.create!(identifier: "prop6@example.com", password: "securepass1") }

  before { stub_otp_delivery(user) }

  # Feature: user-authentication, Property 6: OTP submitted after 10 minutes always returns an error
  it "OTP submitted after 10 minutes always raises InvalidOtpError" do
    # Validates: Requirements 2.3, 3.3
    property_of {
      # Travel between 11 and 60 minutes into the future (strictly past the 10-min expiry)
      integer(11..60)
    }.check(100) do |minutes_elapsed|
      # Reset state — clear both OTP codes and request logs to avoid rate limiting
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      code = Auth::OtpService.new(user).request_otp

      travel minutes_elapsed.minutes do
        expect {
          Auth::OtpService.new(user).verify_otp(code)
        }.to raise_error(Auth::OtpService::InvalidOtpError)
      end
    end
  end

  # Feature: user-authentication, Property 6: OTP after successful use always returns an error
  it "OTP submitted after successful use always raises InvalidOtpError" do
    # Validates: Requirements 3.4
    property_of {
      # Generate a valid 6-digit code string
      format("%06d", integer(0..999_999))
    }.check(100) do |_ignored|
      # Reset state — clear both OTP codes and request logs to avoid rate limiting
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      code = Auth::OtpService.new(user).request_otp

      # First use succeeds
      Auth::OtpService.new(user).verify_otp(code)

      # Second use must fail
      expect {
        Auth::OtpService.new(user).verify_otp(code)
      }.to raise_error(Auth::OtpService::InvalidOtpError)
    end
  end
end

# =============================================================================
# Property 7 — OTP invalidation on re-request
# Feature: user-authentication, Property 7: New OTP invalidates the previous OTP
# =============================================================================
RSpec.describe "Property 7: OTP invalidation on re-request" do
  let(:user) { User.create!(identifier: "prop7@example.com", password: "securepass1") }

  before { stub_otp_delivery(user) }

  it "first OTP is always rejected after a second OTP is issued" do
    # Validates: Requirements 2.4
    property_of {
      integer(1..50) # iteration seed — just drives 100 runs
    }.check(100) do |_seed|
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      service = Auth::OtpService.new(user)

      first_code  = service.request_otp
      _second_code = service.request_otp

      expect {
        service.verify_otp(first_code)
      }.to raise_error(Auth::OtpService::InvalidOtpError)
    end
  end
end

# =============================================================================
# Property 8 — OTP rate limiting
# Feature: user-authentication, Property 8: OTP rate limiting is enforced
# =============================================================================
RSpec.describe "Property 8: OTP rate limiting" do
  let(:user) { User.create!(identifier: "prop8@example.com", password: "securepass1") }

  before { stub_otp_delivery(user) }

  it "6th OTP request within 60 minutes is always rejected" do
    # Validates: Requirements 2.6, 2.7
    property_of {
      # Vary how far back in the window the prior 5 requests were (1..59 minutes ago)
      integer(1..59)
    }.check(100) do |minutes_ago|
      OtpRequestLog.where(user: user).delete_all
      OtpCode.where(user: user).delete_all

      # Seed 5 request logs within the 60-minute window
      seed_otp_request_logs(user, count: 5, requested_at: minutes_ago.minutes.ago)

      expect {
        Auth::OtpService.new(user).request_otp
      }.to raise_error(Auth::OtpService::RateLimitError)
    end
  end
end

# =============================================================================
# Property 9 — OTP authentication correctness
# Feature: user-authentication, Property 9: OTP authentication correctness
# =============================================================================
RSpec.describe "Property 9: OTP authentication correctness" do
  let(:user) { User.create!(identifier: "prop9@example.com", password: "securepass1") }

  before { stub_otp_delivery(user) }

  it "valid OTP always returns true" do
    # Validates: Requirements 3.1, 3.2
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      code = Auth::OtpService.new(user).request_otp
      result = Auth::OtpService.new(user).verify_otp(code)
      expect(result).to be(true)
    end
  end

  it "invalid OTP (wrong code) always raises InvalidOtpError" do
    # Validates: Requirements 3.1, 3.2
    property_of {
      # Generate a wrong 6-digit code (we'll ensure it differs from the real one)
      format("%06d", integer(0..999_999))
    }.check(100) do |wrong_code|
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      real_code = Auth::OtpService.new(user).request_otp

      # If by chance the generated wrong_code matches, skip this iteration
      next if wrong_code == real_code

      expect {
        Auth::OtpService.new(user).verify_otp(wrong_code)
      }.to raise_error(Auth::OtpService::InvalidOtpError)
    end
  end
end

# =============================================================================
# Property 11 — Password never stored as plaintext
# Feature: user-authentication, Property 11: Password is never stored as plaintext
# =============================================================================
RSpec.describe "Property 11: Password never stored as plaintext" do
  it "password_digest never equals the plaintext and is a valid bcrypt hash" do
    # Validates: Requirements 4.1
    property_of {
      # Generate passwords of valid length (>= 8 chars)
      sized(rand(8..30)) { string(:alpha) }
    }.check(100) do |password|
      user = User.create!(identifier: "prop11_#{SecureRandom.hex(4)}@example.com",
                          password: password)

      digest = user.password_digest

      # Must not equal plaintext
      expect(digest).not_to eq(password)

      # Must be a valid bcrypt hash that matches the plaintext
      expect(BCrypt::Password.new(digest)).to eq(password)

      user.destroy
    end
  end
end

# =============================================================================
# Property 12 — Password length enforcement
# Feature: user-authentication, Property 12: Password minimum length is enforced
# =============================================================================
RSpec.describe "Property 12: Password length enforcement" do
  it "strings shorter than 8 characters are always rejected" do
    # Validates: Requirements 4.2, 7.5
    property_of {
      sized(rand(1..7)) { string(:alpha) }
    }.check(100) do |short_pass|
      user = User.new(identifier: "valid@example.com", password: short_pass)
      expect(user.valid?).to be(false),
        "Expected password #{short_pass.inspect} (length #{short_pass.length}) to be rejected"
      expect(user.errors[:password]).not_to be_empty
    end
  end

  it "strings of 8 or more characters are always accepted (password length)" do
    # Validates: Requirements 4.2, 7.5
    property_of {
      sized(rand(8..30)) { string(:alpha) }
    }.check(100) do |valid_pass|
      user = User.new(identifier: "valid@example.com", password: valid_pass)
      user.valid?
      # Password-specific errors must be absent (identifier errors are irrelevant here)
      expect(user.errors[:password]).to be_empty,
        "Expected password #{valid_pass.inspect} (length #{valid_pass.length}) to be accepted, " \
        "but got: #{user.errors[:password]}"
    end
  end
end

# =============================================================================
# Property 13 — Password authentication correctness
# Feature: user-authentication, Property 13: Password authentication correctness
# =============================================================================
RSpec.describe "Property 13: Password authentication correctness" do
  it "correct password always returns the user" do
    # Validates: Requirements 4.3, 4.4
    property_of {
      sized(rand(8..20)) { string(:alpha) }
    }.check(100) do |password|
      identifier = "prop13_#{SecureRandom.hex(4)}@example.com"
      User.create!(identifier: identifier, password: password)

      result = Auth::PasswordAuthService.authenticate(identifier, password)
      expect(result).to be_a(User)
      expect(result.identifier).to eq(identifier)

      User.find_by(identifier: identifier)&.destroy
    end
  end

  it "any other string as password always raises InvalidCredentialsError" do
    # Validates: Requirements 4.3, 4.4
    property_of {
      sized(rand(8..20)) { string(:alpha) }
    }.check(100) do |wrong_password|
      identifier = "prop13w_#{SecureRandom.hex(4)}@example.com"
      correct_password = "correctpass99"
      User.create!(identifier: identifier, password: correct_password)

      next if wrong_password == correct_password

      expect {
        Auth::PasswordAuthService.authenticate(identifier, wrong_password)
      }.to raise_error(Auth::PasswordAuthService::InvalidCredentialsError)

      User.find_by(identifier: identifier)&.destroy
    end
  end
end

# =============================================================================
# Property 15 — No identifier enumeration
# Feature: user-authentication, Property 15: No identifier enumeration
# =============================================================================
RSpec.describe "Property 15: No identifier enumeration" do
  let!(:real_user) do
    User.create!(identifier: "real@example.com", password: "realpassword1")
  end

  it "error for unknown identifier is same class as wrong-password error on real account" do
    # Validates: Requirements 5.2, 7.2
    property_of {
      local  = sized(6) { string(:alpha) }
      domain = sized(5) { string(:alpha) }
      "#{local}@#{domain}.com"
    }.check(100) do |unknown_identifier|
      # Ensure the generated identifier is not the real user's
      next if unknown_identifier == real_user.identifier

      # Reset the real user's failure counter so it never gets locked across iterations
      real_user.update_columns(password_failed_attempts: 0, password_locked_until: nil)

      # Error for unknown identifier
      unknown_error_class = nil
      begin
        Auth::PasswordAuthService.authenticate(unknown_identifier, "anypassword")
      rescue => e
        unknown_error_class = e.class
      end

      # Error for wrong password on real account
      wrong_pass_error_class = nil
      begin
        Auth::PasswordAuthService.authenticate(real_user.identifier, "wrongpassword")
      rescue => e
        wrong_pass_error_class = e.class
      end

      expect(unknown_error_class).to eq(wrong_pass_error_class),
        "Expected same error class for unknown identifier and wrong password, " \
        "got #{unknown_error_class} vs #{wrong_pass_error_class}"
    end
  end
end

# =============================================================================
# Property 16 — JWT expiry and algorithm
# Feature: user-authentication, Property 16: JWT expiry and algorithm
# =============================================================================
RSpec.describe "Property 16: JWT expiry and algorithm" do
  let(:user) { User.create!(identifier: "prop16@example.com", password: "securepass1") }

  it "exp is always iat + 86400 and header always specifies HS256" do
    # Validates: Requirements 5.5, 6.1
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      freeze_time do
        token = Auth::SessionService.issue_jwt(user)

        payload, _header = decode_jwt_raw(token)
        header = decode_jwt_header(token)

        expect(payload["exp"]).to eq(payload["iat"] + 86_400),
          "Expected exp == iat + 86400, got iat=#{payload["iat"]} exp=#{payload["exp"]}"

        expect(header["alg"]).to eq("HS256"),
          "Expected HS256 algorithm, got #{header["alg"].inspect}"
      end
    end
  end
end

# =============================================================================
# Property 17 — JWT validity
# Feature: user-authentication, Property 17: Valid JWT grants access; invalid JWT is rejected
# =============================================================================
RSpec.describe "Property 17: JWT validity" do
  let(:user) { User.create!(identifier: "prop17@example.com", password: "securepass1") }

  it "valid unexpired non-denylisted token always returns payload" do
    # Validates: Requirements 6.2, 6.3, 6.4
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      token = Auth::SessionService.issue_jwt(user)
      result = Auth::SessionService.verify_jwt(token)
      expect(result).to be_a(Hash)
      expect(result["sub"]).to eq(user.id.to_s)
    end
  end

  it "expired token (25h later) always raises ExpiredTokenError" do
    # Validates: Requirements 6.3
    property_of {
      integer(25..48) # hours past expiry
    }.check(100) do |hours|
      token = Auth::SessionService.issue_jwt(user)

      travel hours.hours do
        expect {
          Auth::SessionService.verify_jwt(token)
        }.to raise_error(Auth::SessionService::ExpiredTokenError)
      end
    end
  end

  it "malformed token always raises InvalidTokenError" do
    # Validates: Requirements 6.4
    property_of {
      # Generate strings that look like garbage JWTs
      local = sized(rand(5..15)) { string(:alpha) }
      "#{local}.#{local}.#{local}"
    }.check(100) do |bad_token|
      expect {
        Auth::SessionService.verify_jwt(bad_token)
      }.to raise_error(Auth::SessionService::InvalidTokenError)
    end
  end

  it "denylisted token always raises DenylistedTokenError" do
    # Validates: Requirements 6.4
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      JwtDenylist.delete_all

      token = Auth::SessionService.issue_jwt(user)
      Auth::SessionService.invalidate_jwt(token)

      expect {
        Auth::SessionService.verify_jwt(token)
      }.to raise_error(Auth::SessionService::DenylistedTokenError)
    end
  end
end

# =============================================================================
# Property 18 — Logout invalidation
# Feature: user-authentication, Property 18: Logout invalidates the JWT
# =============================================================================
RSpec.describe "Property 18: Logout invalidation" do
  let(:user) { User.create!(identifier: "prop18@example.com", password: "securepass1") }

  it "token always returns DenylistedTokenError after logout" do
    # Validates: Requirements 6.5
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      JwtDenylist.delete_all

      token = Auth::SessionService.issue_jwt(user)

      # Verify it works before logout
      expect { Auth::SessionService.verify_jwt(token) }.not_to raise_error

      # Logout
      Auth::SessionService.invalidate_jwt(token)

      # Must be rejected after logout
      expect {
        Auth::SessionService.verify_jwt(token)
      }.to raise_error(Auth::SessionService::DenylistedTokenError)
    end
  end
end

# =============================================================================
# Property 19 — Token refresh
# Feature: user-authentication, Property 19: Token refresh invalidates old token and issues new one
# =============================================================================
RSpec.describe "Property 19: Token refresh" do
  let(:user) { User.create!(identifier: "prop19@example.com", password: "securepass1") }

  it "new token is valid and old token is rejected after refresh" do
    # Validates: Requirements 6.6
    property_of {
      integer(1..50)
    }.check(100) do |_seed|
      JwtDenylist.delete_all

      old_token = Auth::SessionService.issue_jwt(user)
      new_token  = Auth::SessionService.refresh_jwt(old_token)

      # New token must be valid
      expect { Auth::SessionService.verify_jwt(new_token) }.not_to raise_error

      # Old token must be rejected
      expect {
        Auth::SessionService.verify_jwt(old_token)
      }.to raise_error(Auth::SessionService::DenylistedTokenError)
    end
  end
end

# =============================================================================
# Property 20 — Password reset correctness
# Feature: user-authentication, Property 20: Password reset updates password and invalidates all sessions
# =============================================================================
RSpec.describe "Property 20: Password reset correctness" do
  it "new password authenticates; old password does not; prior JWTs rejected" do
    # Validates: Requirements 7.3
    property_of {
      sized(rand(8..20)) { string(:alpha) }
    }.check(100) do |new_password|
      old_password = "oldpassword1"
      identifier   = "prop20_#{SecureRandom.hex(4)}@example.com"

      user = User.create!(identifier: identifier, password: old_password)

      delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
      allow(Auth::OtpDeliveryService).to receive(:new).with(user).and_return(delivery_double)

      # Issue a JWT before the reset
      prior_token = Auth::SessionService.issue_jwt(user)

      # Create a valid OTP for the reset
      plaintext_otp = Auth::OtpService.new(user).request_otp

      # Perform the reset — use a different new_password if it happens to equal old
      reset_password = new_password == old_password ? "#{new_password}X" : new_password

      Auth::PasswordResetService.confirm_reset(identifier, plaintext_otp, reset_password)

      # (a) New password authenticates
      expect {
        Auth::PasswordAuthService.authenticate(identifier, reset_password)
      }.not_to raise_error

      # (b) Old password no longer authenticates
      expect {
        Auth::PasswordAuthService.authenticate(identifier, old_password)
      }.to raise_error(Auth::PasswordAuthService::InvalidCredentialsError)

      # (c) Prior JWT is rejected
      expect {
        Auth::SessionService.verify_jwt(prior_token)
      }.to raise_error(Auth::SessionService::DenylistedTokenError)

      user.destroy
    end
  end
end

# =============================================================================
# Property 21 — Invalid OTP during password reset does not change password
# Feature: user-authentication, Property 21: Invalid OTP during password reset does not change password
# =============================================================================
RSpec.describe "Property 21: Invalid OTP during password reset" do
  let(:user) do
    User.create!(identifier: "prop21@example.com", password: "originalpass1")
  end

  before do
    stub_otp_delivery(user)
  end

  it "password_digest is unchanged when invalid OTP is submitted" do
    # Validates: Requirements 7.4
    property_of {
      # Generate wrong 6-digit codes
      format("%06d", integer(0..999_999))
    }.check(100) do |wrong_otp|
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      # Issue a real OTP (so there is an active OTP record)
      real_otp = Auth::OtpService.new(user).request_otp

      # Skip if the generated wrong_otp accidentally matches the real one
      next if wrong_otp == real_otp

      original_digest = user.reload.password_digest

      expect {
        Auth::PasswordResetService.confirm_reset(user.identifier, wrong_otp, "newpassword1")
      }.to raise_error(Auth::PasswordResetService::InvalidOtpError)

      expect(user.reload.password_digest).to eq(original_digest),
        "Expected password_digest to be unchanged after invalid OTP submission"
    end
  end

  it "password_digest is unchanged when expired OTP is submitted" do
    # Validates: Requirements 7.4
    property_of {
      integer(11..60) # minutes past expiry
    }.check(100) do |minutes_elapsed|
      OtpCode.where(user: user).delete_all
      OtpRequestLog.where(user: user).delete_all

      real_otp = Auth::OtpService.new(user).request_otp
      original_digest = user.reload.password_digest

      travel minutes_elapsed.minutes do
        expect {
          Auth::PasswordResetService.confirm_reset(user.identifier, real_otp, "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)

        expect(user.reload.password_digest).to eq(original_digest),
          "Expected password_digest to be unchanged after expired OTP submission"
      end
    end
  end
end
