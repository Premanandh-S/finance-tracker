# frozen_string_literal: true

module Auth
  # Handles the password-reset flow: requesting a reset OTP and confirming the
  # reset with a valid OTP and a new password.
  #
  # @example Request a password reset
  #   Auth::PasswordResetService.request_reset("user@example.com")
  #   # => :ok  (always, regardless of whether the identifier exists)
  #
  # @example Confirm a password reset
  #   Auth::PasswordResetService.confirm_reset("user@example.com", "042891", "newpassword")
  #   # => #<User id=1 ...>
  class PasswordResetService
    # Raised when the submitted OTP is invalid, expired, or does not match.
    class InvalidOtpError < StandardError; end

    # Raised when the new password fails validation (e.g. too short).
    class InvalidPasswordError < StandardError; end

    # Maximum number of consecutive failed OTP verification attempts before
    # the OTP is locked and a new one must be requested.
    OTP_MAX_ATTEMPTS = 5

    class << self
      # Initiates a password reset for the given identifier.
      #
      # If the identifier belongs to a registered user, an OTP is generated and
      # delivered via {Auth::OtpService}. If the identifier is not found, the
      # method returns the same generic success symbol to prevent identifier
      # enumeration (Requirement 7.2).
      #
      # @param identifier [String] the user's phone number (E.164) or email address
      # @return [Symbol] always +:ok+
      # @raise [Auth::OtpService::RateLimitError] if the OTP rate limit is exceeded
      # @raise [Auth::OtpService::DeliveryError] if OTP delivery fails
      def request_reset(identifier)
        user = User.find_by(identifier: identifier)

        if user
          Auth::OtpService.new(user).request_otp
        end

        :ok
      end

      # Confirms a password reset by verifying the OTP and updating the password.
      #
      # Steps:
      # 1. Finds the user by identifier — raises {InvalidOtpError} if not found
      #    (generic error to prevent enumeration).
      # 2. Finds the most recent active OTP for the user.
      # 3. Checks the OTP attempt count — raises {InvalidOtpError} if locked.
      # 4. Verifies the submitted OTP against the stored bcrypt digest.
      # 5. On mismatch: increments +failed_attempts+; raises {InvalidOtpError}.
      # 6. On match: marks the OTP as used, updates the user's +password_digest+
      #    via +user.update!+, resets +password_failed_attempts+ to 0, and
      #    invalidates all existing JWTs by calling
      #    {Auth::SessionService.invalidate_all_for_user}.
      #
      # @param identifier [String] the user's phone number (E.164) or email address
      # @param otp [String] the plaintext OTP submitted by the user
      # @param new_password [String] the new plaintext password to set
      # @return [User] the updated user record
      # @raise [Auth::PasswordResetService::InvalidOtpError] if the identifier is
      #   not found, the OTP is invalid/expired/locked, or no active OTP exists
      # @raise [Auth::PasswordResetService::InvalidPasswordError] if the new
      #   password fails validation
      def confirm_reset(identifier, otp, new_password)
        user = User.find_by(identifier: identifier)
        raise InvalidOtpError, "Invalid or expired OTP" unless user

        otp_record = user.otp_codes.active.order(created_at: :desc).first
        raise InvalidOtpError, "Invalid or expired OTP" unless otp_record

        if otp_record.failed_attempts >= OTP_MAX_ATTEMPTS
          raise InvalidOtpError, "OTP is locked. Please request a new one."
        end

        unless BCrypt::Password.new(otp_record.code_digest) == otp
          otp_record.increment!(:failed_attempts)
          raise InvalidOtpError, "Invalid or expired OTP"
        end

        # OTP verified — mark it used
        otp_record.update!(used: true)

        # Update password — let ActiveRecord/has_secure_password run validations
        unless user.update(password: new_password)
          raise InvalidPasswordError, user.errors.full_messages.join(", ")
        end

        # Reset the password failure counter
        user.update_columns(password_failed_attempts: 0, password_locked_until: nil)

        # Invalidate all existing JWTs for this user
        Auth::SessionService.invalidate_all_for_user(user)

        user
      end
    end
  end
end
