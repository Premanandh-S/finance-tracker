# frozen_string_literal: true

module Auth
  # Handles password-based authentication: looks up the user by identifier,
  # enforces account lockout, compares the submitted password against the stored
  # bcrypt hash, and manages the failure counter and lockout state.
  #
  # @example Authenticate a user
  #   user = Auth::PasswordAuthService.authenticate("user@example.com", "s3cur3pass")
  #   # => #<User id=1 ...>
  #
  # @raise [Auth::PasswordAuthService::InvalidCredentialsError] if the identifier
  #   is not found or the password does not match
  # @raise [Auth::PasswordAuthService::AccountLockedError] if the account is
  #   currently locked due to too many failed attempts
  class PasswordAuthService
    # Raised when the identifier is not found or the password does not match.
    # The same error is used for both cases to prevent identifier enumeration.
    class InvalidCredentialsError < StandardError; end

    # Raised when the account is locked due to too many consecutive failed
    # password attempts. The message includes the +locked_until+ timestamp.
    class AccountLockedError < StandardError; end

    # Number of consecutive failures before the account is locked.
    MAX_FAILED_ATTEMPTS = 10

    # Duration of the lockout period.
    LOCKOUT_DURATION = 15.minutes

    class << self
      # Authenticates a user by identifier and password.
      #
      # Steps:
      # 1. Finds the user by identifier — raises {InvalidCredentialsError} if not found.
      # 2. Checks whether the account is currently locked — raises {AccountLockedError} if so.
      # 3. Compares the submitted password against the stored bcrypt hash.
      # 4. On failure: increments +password_failed_attempts+; locks the account
      #    for {LOCKOUT_DURATION} if the threshold is reached; raises {InvalidCredentialsError}.
      # 5. On success: resets +password_failed_attempts+ to 0 and clears
      #    +password_locked_until+; returns the authenticated user.
      #
      # @param identifier [String] the user's phone number (E.164) or email address
      # @param password [String] the plaintext password to verify
      # @return [User] the authenticated user
      # @raise [Auth::PasswordAuthService::InvalidCredentialsError] if the identifier
      #   is not found or the password is incorrect
      # @raise [Auth::PasswordAuthService::AccountLockedError] if the account is locked
      def authenticate(identifier, password)
        user = User.find_by(identifier: identifier)

        # Use the same error for missing user as for wrong password — no enumeration.
        raise InvalidCredentialsError, "Invalid credentials" unless user

        check_lockout!(user)

        if user.authenticate(password)
          reset_failure_counter!(user)
          user
        else
          record_failure!(user)
          raise InvalidCredentialsError, "Invalid credentials"
        end
      end

      private

      # Raises {AccountLockedError} if the account is currently locked.
      #
      # @param user [User] the user to check
      # @return [void]
      # @raise [Auth::PasswordAuthService::AccountLockedError] if locked
      def check_lockout!(user)
        return unless user.password_locked_until&.>(Time.now)

        raise AccountLockedError,
              "Account is locked until #{user.password_locked_until.iso8601}"
      end

      # Resets the failure counter and clears the lockout timestamp on success.
      #
      # @param user [User] the authenticated user
      # @return [void]
      def reset_failure_counter!(user)
        user.update_columns(
          password_failed_attempts: 0,
          password_locked_until:    nil
        )
      end

      # Increments the failure counter and, if the threshold is reached, sets
      # the lockout timestamp.
      #
      # @param user [User] the user who failed authentication
      # @return [void]
      def record_failure!(user)
        new_attempts = user.password_failed_attempts + 1

        if new_attempts >= MAX_FAILED_ATTEMPTS
          user.update_columns(
            password_failed_attempts: new_attempts,
            password_locked_until:    Time.now + LOCKOUT_DURATION
          )
        else
          user.update_columns(password_failed_attempts: new_attempts)
        end
      end
    end
  end
end
