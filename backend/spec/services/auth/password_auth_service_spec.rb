# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::PasswordAuthService, ".authenticate" do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a persisted user with a known password.
  def create_user(identifier: "user@example.com", password: "correct_password")
    User.create!(identifier: identifier, password: password, verified: true)
  end

  # ---------------------------------------------------------------------------
  # 1. Correct password returns the user
  # ---------------------------------------------------------------------------
  describe "successful authentication" do
    it "returns the user when the password is correct" do
      user = create_user
      result = described_class.authenticate("user@example.com", "correct_password")
      expect(result).to eq(user)
    end

    it "resets password_failed_attempts to 0 on success" do
      user = create_user
      user.update_columns(password_failed_attempts: 3)

      described_class.authenticate("user@example.com", "correct_password")

      expect(user.reload.password_failed_attempts).to eq(0)
    end

    it "clears password_locked_until on success" do
      user = create_user
      user.update_columns(password_locked_until: 5.minutes.from_now)

      # Simulate lock expiry so the check passes
      user.update_columns(password_locked_until: 1.minute.ago)

      described_class.authenticate("user@example.com", "correct_password")

      expect(user.reload.password_locked_until).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Incorrect password raises InvalidCredentialsError
  # ---------------------------------------------------------------------------
  describe "wrong password" do
    it "raises InvalidCredentialsError" do
      create_user
      expect {
        described_class.authenticate("user@example.com", "wrong_password")
      }.to raise_error(Auth::PasswordAuthService::InvalidCredentialsError)
    end

    it "does not return a user" do
      create_user
      result = described_class.authenticate("user@example.com", "wrong_password") rescue nil
      expect(result).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Failure counter increments on each wrong password
  # ---------------------------------------------------------------------------
  describe "failure counter" do
    it "increments password_failed_attempts by 1 on each wrong attempt" do
      user = create_user

      described_class.authenticate("user@example.com", "bad") rescue nil
      expect(user.reload.password_failed_attempts).to eq(1)

      described_class.authenticate("user@example.com", "bad") rescue nil
      expect(user.reload.password_failed_attempts).to eq(2)

      described_class.authenticate("user@example.com", "bad") rescue nil
      expect(user.reload.password_failed_attempts).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Lockout triggered after 10 consecutive failures
  # ---------------------------------------------------------------------------
  describe "lockout after 10 failures" do
    it "raises InvalidCredentialsError on the 10th failure (lock is set for next attempt)" do
      user = create_user
      user.update_columns(password_failed_attempts: 9)

      expect {
        described_class.authenticate("user@example.com", "wrong_password")
      }.to raise_error(Auth::PasswordAuthService::InvalidCredentialsError)
    end

    it "raises AccountLockedError on the attempt after the 10th failure" do
      user = create_user
      user.update_columns(password_failed_attempts: 9)

      # 10th failure — sets the lock, raises InvalidCredentialsError
      described_class.authenticate("user@example.com", "wrong_password") rescue nil

      # 11th attempt — account is now locked
      expect {
        described_class.authenticate("user@example.com", "wrong_password")
      }.to raise_error(Auth::PasswordAuthService::AccountLockedError)
    end

    it "sets password_locked_until approximately 15 minutes from now" do
      freeze_time do
        user = create_user
        user.update_columns(password_failed_attempts: 9)

        described_class.authenticate("user@example.com", "wrong_password") rescue nil

        expected_lock = Time.now + 15.minutes
        expect(user.reload.password_locked_until).to be_within(1.second).of(expected_lock)
      end
    end

    it "sets password_failed_attempts to 10 when lockout is triggered" do
      user = create_user
      user.update_columns(password_failed_attempts: 9)

      described_class.authenticate("user@example.com", "wrong_password") rescue nil

      expect(user.reload.password_failed_attempts).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Locked account rejects all attempts — even with correct password
  # ---------------------------------------------------------------------------
  describe "locked account" do
    it "raises AccountLockedError even when the correct password is submitted" do
      user = create_user
      user.update_columns(
        password_failed_attempts: 10,
        password_locked_until:    15.minutes.from_now
      )

      expect {
        described_class.authenticate("user@example.com", "correct_password")
      }.to raise_error(Auth::PasswordAuthService::AccountLockedError)
    end

    it "includes the locked_until timestamp in the error message" do
      freeze_time do
        locked_until = 15.minutes.from_now
        user = create_user
        user.update_columns(
          password_failed_attempts: 10,
          password_locked_until:    locked_until
        )

        expect {
          described_class.authenticate("user@example.com", "correct_password")
        }.to raise_error(
          Auth::PasswordAuthService::AccountLockedError,
          /#{Regexp.escape(locked_until.iso8601)}/
        )
      end
    end

    it "does not increment the failure counter while locked" do
      user = create_user
      user.update_columns(
        password_failed_attempts: 10,
        password_locked_until:    15.minutes.from_now
      )

      described_class.authenticate("user@example.com", "wrong_password") rescue nil

      expect(user.reload.password_failed_attempts).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Lockout expires after 15 minutes
  # ---------------------------------------------------------------------------
  describe "lockout expiry" do
    it "allows authentication after the lockout period has elapsed" do
      user = create_user
      user.update_columns(
        password_failed_attempts: 10,
        password_locked_until:    15.minutes.from_now
      )

      # Travel past the lockout window
      travel 16.minutes do
        result = described_class.authenticate("user@example.com", "correct_password")
        expect(result).to eq(user)
      end
    end

    it "resets the failure counter after successful auth post-lockout" do
      user = create_user
      user.update_columns(
        password_failed_attempts: 10,
        password_locked_until:    15.minutes.from_now
      )

      travel 16.minutes do
        described_class.authenticate("user@example.com", "correct_password")
        expect(user.reload.password_failed_attempts).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Unknown identifier raises InvalidCredentialsError (no enumeration)
  # ---------------------------------------------------------------------------
  describe "unknown identifier" do
    it "raises InvalidCredentialsError for an identifier that does not exist" do
      expect {
        described_class.authenticate("nobody@example.com", "any_password")
      }.to raise_error(Auth::PasswordAuthService::InvalidCredentialsError)
    end

    it "raises the same error class as an incorrect password — no enumeration" do
      create_user(identifier: "user@example.com")

      unknown_error = nil
      wrong_pass_error = nil

      begin
        described_class.authenticate("nobody@example.com", "any_password")
      rescue => e
        unknown_error = e.class
      end

      begin
        described_class.authenticate("user@example.com", "wrong_password")
      rescue => e
        wrong_pass_error = e.class
      end

      expect(unknown_error).to eq(wrong_pass_error)
    end
  end
end
