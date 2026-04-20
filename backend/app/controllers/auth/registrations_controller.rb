# frozen_string_literal: true

module Auth
  # Handles new user registration.
  #
  # Delegates entirely to {Auth::RegistrationService} and maps service errors
  # to the standard error envelope defined in {ApplicationController#render_error}.
  class RegistrationsController < ApplicationController
    # POST /auth/register
    #
    # Accepts an identifier (phone or email) and an optional password.
    # Triggers OTP delivery so the user can verify their identifier.
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @param password [String, nil] optional plaintext password (min 8 chars)
    # @return [void] renders 201 on success or 4xx/5xx on failure
    def create
      Auth::RegistrationService.new.register(
        registration_params[:identifier],
        password: registration_params[:password]
      )

      render json: { message: "Registration successful. Please verify your identifier." },
             status: :created
    rescue Auth::RegistrationService::IdentifierTakenError => e
      render_error(:unprocessable_entity, "identifier_taken", e.message)
    rescue Auth::RegistrationService::InvalidIdentifierError => e
      render_error(:unprocessable_entity, "invalid_identifier", e.message)
    rescue ActiveRecord::RecordInvalid => e
      render_error(:unprocessable_entity, "invalid_identifier", e.message)
    rescue Auth::OtpService::DeliveryError => e
      render_error(:service_unavailable, "otp_delivery_failed", e.message)
    end

    private

    # @return [ActionController::Parameters] permitted registration params
    def registration_params
      params.permit(:identifier, :password)
    end
  end
end
