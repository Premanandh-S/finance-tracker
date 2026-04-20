# frozen_string_literal: true

module Auth
  # Handles OTP request and verification endpoints.
  #
  # Delegates to {Auth::OtpService} and maps service errors to the standard
  # error envelope defined in {ApplicationController#render_error}.
  class OtpController < ApplicationController
    # POST /auth/otp/request
    #
    # Triggers OTP generation and delivery for the given identifier.
    # Returns a generic success response regardless of whether the identifier
    # exists, to prevent identifier enumeration.
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @return [void] renders 200 on success, 429 on rate limit
    def request_otp
      user = User.find_by(identifier: otp_request_params[:identifier])

      unless user
        return render_error(:unauthorized, "invalid_credentials",
                            "Invalid credentials")
      end

      Auth::OtpService.new(user).request_otp

      render json: { message: "OTP sent" }, status: :ok
    rescue Auth::OtpService::RateLimitError
      render_error(429, "otp_rate_limit", "Too many OTP requests. Please try again later.",
                   retry_after: Auth::OtpService::RATE_LIMIT_WINDOW.to_i)
    rescue Auth::OtpService::DeliveryError => e
      render_error(:service_unavailable, "otp_delivery_failed", e.message)
    end

    # POST /auth/otp/verify
    #
    # Verifies the submitted OTP for the given identifier and, on success,
    # issues a JWT.
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @param otp [String] the 6-digit OTP code
    # @return [void] renders 200 with token on success, 401/423 on failure
    def verify
      user = User.find_by(identifier: otp_verify_params[:identifier])

      unless user
        return render_error(:unauthorized, "invalid_credentials",
                            "Invalid credentials")
      end

      Auth::OtpService.new(user).verify_otp(otp_verify_params[:otp])

      token = Auth::SessionService.issue_jwt(user)
      render json: { token: token }, status: :ok
    rescue Auth::OtpService::InvalidOtpError => e
      render_error(:unauthorized, "otp_invalid", e.message)
    rescue Auth::OtpService::LockedError => e
      render_error(423, "otp_locked", e.message)
    end

    private

    # @return [ActionController::Parameters] permitted params for request_otp
    def otp_request_params
      params.permit(:identifier)
    end

    # @return [ActionController::Parameters] permitted params for verify
    def otp_verify_params
      params.permit(:identifier, :otp)
    end
  end
end
