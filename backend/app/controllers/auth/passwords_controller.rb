# frozen_string_literal: true

module Auth
  # Handles password reset request and confirmation.
  #
  # Delegates entirely to {Auth::PasswordResetService} and maps service errors
  # to the standard error envelope defined in {ApplicationController#render_error}.
  class PasswordsController < ApplicationController
    # POST /auth/password/reset/request
    #
    # Initiates a password reset by sending an OTP to the given identifier.
    # Always returns a generic 200 response to prevent identifier enumeration
    # (Requirement 7.2).
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @return [void] renders 200 regardless of whether the identifier is registered
    def reset_request
      Auth::PasswordResetService.request_reset(reset_request_params[:identifier])

      render json: { message: "If that identifier is registered, an OTP has been sent." },
             status: :ok
    rescue Auth::OtpService::RateLimitError
      render_error(429, "otp_rate_limit", "Too many OTP requests. Please try again later.",
                   retry_after: Auth::OtpService::RATE_LIMIT_WINDOW.to_i)
    rescue Auth::OtpService::DeliveryError => e
      render_error(:service_unavailable, "otp_delivery_failed", e.message)
    end

    # POST /auth/password/reset/confirm
    #
    # Confirms a password reset by verifying the OTP and updating the password.
    # Invalidates all existing JWTs for the user on success.
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @param otp [String] the 6-digit OTP code
    # @param new_password [String] the new plaintext password (min 8 chars)
    # @return [void] renders 200 on success, 401 on invalid OTP, 422 on invalid password
    def reset_confirm
      Auth::PasswordResetService.confirm_reset(
        reset_confirm_params[:identifier],
        reset_confirm_params[:otp],
        reset_confirm_params[:new_password]
      )

      render json: { message: "Password reset successful." }, status: :ok
    rescue Auth::PasswordResetService::InvalidOtpError => e
      render_error(:unauthorized, "otp_invalid", e.message)
    rescue Auth::PasswordResetService::InvalidPasswordError => e
      render_error(:unprocessable_entity, "password_too_short", e.message)
    end

    private

    # @return [ActionController::Parameters] permitted params for reset_request
    def reset_request_params
      params.permit(:identifier)
    end

    # @return [ActionController::Parameters] permitted params for reset_confirm
    def reset_confirm_params
      params.permit(:identifier, :otp, :new_password)
    end
  end
end
