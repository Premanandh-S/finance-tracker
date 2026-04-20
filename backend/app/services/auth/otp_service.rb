# frozen_string_literal: true

module Auth
  # Handles OTP generation, storage, rate limiting, delivery, and verification.
  #
  # @example Request an OTP for a user
  #   service = Auth::OtpService.new(user)
  #   plaintext_code = service.request_otp
  #   # => "042891"
  #
  # @example Verify an OTP
  #   service = Auth::OtpService.new(user)
  #   service.verify_otp("042891")   # => true (marks OTP used)
  #
  # @raise [Auth::OtpService::RateLimitError] if the user has exceeded 5 requests in 60 minutes
  # @raise [Auth::OtpService::DeliveryError] if the OTP delivery fails
  # @raise [Auth::OtpService::InvalidOtpError] if the submitted OTP is invalid or expired
  # @raise [Auth::OtpService::LockedError] if the OTP is locked after 5 failed attempts
  class OtpService
    # Raised when the user has exceeded the OTP request rate limit.
    class RateLimitError < StandardError; end

    # Raised when OTP delivery fails (wraps OtpDeliveryService::DeliveryError).
    class DeliveryError < StandardError; end

    # Raised when the submitted OTP is invalid, expired, or does not match.
    class InvalidOtpError < StandardError; end

    # Raised when OTP verification is locked after too many failed attempts.
    class LockedError < StandardError; end

    # Maximum number of OTP requests allowed per rate-limit window.
    RATE_LIMIT_MAX     = 5

    # Duration of the rate-limit window in seconds (60 minutes).
    RATE_LIMIT_WINDOW  = 60.minutes

    # OTP expiry duration in minutes.
    OTP_EXPIRY_MINUTES = 10

    # Maximum consecutive failed OTP verification attempts before locking.
    OTP_MAX_ATTEMPTS   = 5

    # @param user [User] the user requesting or verifying the OTP
    def initialize(user)
      @user = user
    end

    # Generates a 6-digit numeric OTP, stores a bcrypt hash of it, invalidates
    # any prior active OTP for the user, enforces the rate limit, delivers the
    # code via {Auth::OtpDeliveryService}, and logs the request.
    #
    # @return [String] the plaintext 6-digit OTP code (e.g. "042891")
    # @raise [Auth::OtpService::RateLimitError] if the rate limit is exceeded
    # @raise [Auth::OtpService::DeliveryError] if delivery fails
    def request_otp
      enforce_rate_limit!

      code = generate_code
      invalidate_prior_otps!
      store_otp!(code)
      deliver!(code)
      log_request!

      code
    end

    # Verifies a submitted OTP against the most recent active OTP for the user.
    #
    # Steps:
    # 1. Finds the most recent active OTP record.
    # 2. Raises {LockedError} if +failed_attempts+ has reached {OTP_MAX_ATTEMPTS}.
    # 3. Compares the submitted code against the stored bcrypt digest.
    # 4. On mismatch: increments +failed_attempts+; raises {InvalidOtpError}.
    # 5. On match: marks the OTP as used and returns true.
    #
    # @param code [String] the plaintext OTP submitted by the user
    # @return [true] on successful verification
    # @raise [Auth::OtpService::InvalidOtpError] if no active OTP exists or the code does not match
    # @raise [Auth::OtpService::LockedError] if the OTP is locked after too many failed attempts
    def verify_otp(code)
      otp_record = @user.otp_codes.active.order(created_at: :desc).first
      raise InvalidOtpError, "Invalid or expired OTP" unless otp_record

      if otp_record.failed_attempts >= OTP_MAX_ATTEMPTS
        raise LockedError, "OTP is locked. Please request a new one."
      end

      unless BCrypt::Password.new(otp_record.code_digest) == code
        otp_record.increment!(:failed_attempts)
        raise InvalidOtpError, "Invalid or expired OTP"
      end

      otp_record.update!(used: true)
      true
    end

    private

    # Checks whether the user has exceeded the rate limit.
    # @raise [Auth::OtpService::RateLimitError] if limit exceeded
    # @return [void]
    def enforce_rate_limit!
      window_start = RATE_LIMIT_WINDOW.ago
      recent_count = @user.otp_request_logs
                          .where("requested_at >= ?", window_start)
                          .count

      if recent_count >= RATE_LIMIT_MAX
        raise RateLimitError, "OTP request limit exceeded. Please try again later."
      end
    end

    # Generates a zero-padded 6-digit numeric OTP code.
    # @return [String] e.g. "042891"
    def generate_code
      format("%06d", SecureRandom.random_number(1_000_000))
    end

    # Marks all currently active OTPs for the user as used.
    # @return [void]
    def invalidate_prior_otps!
      @user.otp_codes.active.update_all(used: true)
    end

    # Creates a new {OtpCode} record with a bcrypt digest of the plaintext code.
    # @param code [String] the plaintext OTP
    # @return [OtpCode] the persisted record
    def store_otp!(code)
      digest = BCrypt::Password.create(code)
      @user.otp_codes.create!(
        code_digest: digest,
        expires_at:  OTP_EXPIRY_MINUTES.minutes.from_now
      )
    end

    # Delivers the OTP via {Auth::OtpDeliveryService}.
    # @param code [String] the plaintext OTP
    # @return [void]
    # @raise [Auth::OtpService::DeliveryError] if delivery fails
    def deliver!(code)
      Auth::OtpDeliveryService.new(@user).deliver(code)
    rescue Auth::OtpDeliveryService::DeliveryError => e
      raise DeliveryError, e.message
    end

    # Appends a new {OtpRequestLog} entry for the current request.
    # @return [void]
    def log_request!
      @user.otp_request_logs.create!(requested_at: Time.current)
    end
  end
end
