# frozen_string_literal: true

module Auth
  # Handles login, logout, and token refresh.
  #
  # Delegates to {Auth::OtpService}, {Auth::PasswordAuthService}, and
  # {Auth::SessionService}. Maps service errors to the standard error envelope
  # defined in {ApplicationController#render_error}.
  class SessionsController < ApplicationController
    before_action :authenticate_user!, only: [:destroy]

    # POST /auth/login
    #
    # Dispatches to OTP or password authentication based on the +method+ param.
    #
    # - method "otp"      → triggers OTP delivery; returns 200 { message: "OTP sent" }
    # - method "password" → validates password; returns 200 { token: "..." }
    #
    # @param identifier [String] E.164 phone number or RFC 5322 email address
    # @param method [String] "otp" or "password"
    # @param password [String, nil] required when method is "password"
    # @return [void]
    def create
      identifier = login_params[:identifier]
      method     = login_params[:method]
      password   = login_params[:password]

      user = User.find_by(identifier: identifier)

      unless user
        # No enumeration — same response as wrong credentials
        return render_error(:unauthorized, "invalid_credentials", "Invalid credentials")
      end

      case method
      when "otp"
        handle_otp_login(user)
      when "password"
        handle_password_login(user, identifier, password)
      else
        render_error(:unprocessable_entity, "invalid_credentials",
                     "Authentication method must be 'otp' or 'password'")
      end
    end

    # DELETE /auth/logout
    #
    # Adds the current JWT to the denylist so it can no longer be used.
    # Requires a valid Bearer token (enforced by authenticate_user!).
    #
    # @return [void] renders 200 on success
    def destroy
      token = extract_bearer_token
      Auth::SessionService.invalidate_jwt(token) if token
      render json: { message: "Logged out" }, status: :ok
    rescue Auth::SessionService::ExpiredTokenError, Auth::SessionService::InvalidTokenError
      # Token is already unusable — treat logout as successful
      render json: { message: "Logged out" }, status: :ok
    end

    # POST /auth/refresh
    #
    # Issues a new JWT from a valid, unexpired existing JWT and denylists the old one.
    #
    # @return [void] renders 200 { token: "..." } on success, 401 on failure
    def refresh
      token = extract_bearer_token

      unless token
        return render_error(:unauthorized, "token_invalid",
                            "Authorization token is missing or malformed")
      end

      new_token = Auth::SessionService.refresh_jwt(token)
      render json: { token: new_token }, status: :ok
    rescue Auth::SessionService::ExpiredTokenError
      render_error(:unauthorized, "token_expired", "Token has expired")
    rescue Auth::SessionService::InvalidTokenError, Auth::SessionService::DenylistedTokenError
      render_error(:unauthorized, "token_invalid", "Token is invalid or has been revoked")
    end

    private

    # Handles the OTP login path: triggers OTP delivery.
    #
    # @param user [User] the authenticated user record
    # @return [void]
    def handle_otp_login(user)
      Auth::OtpService.new(user).request_otp
      render json: { message: "OTP sent" }, status: :ok
    rescue Auth::OtpService::RateLimitError
      render_error(429, "otp_rate_limit", "Too many OTP requests. Please try again later.",
                   retry_after: Auth::OtpService::RATE_LIMIT_WINDOW.to_i)
    rescue Auth::OtpService::DeliveryError => e
      render_error(:service_unavailable, "otp_delivery_failed", e.message)
    end

    # Handles the password login path: authenticates and issues a JWT.
    #
    # @param user [User] the user record (used only for lockout check context)
    # @param identifier [String] the user's identifier
    # @param password [String, nil] the submitted plaintext password
    # @return [void]
    def handle_password_login(_user, identifier, password)
      authenticated_user = Auth::PasswordAuthService.authenticate(identifier, password)
      token = Auth::SessionService.issue_jwt(authenticated_user)
      render json: { token: token }, status: :ok
    rescue Auth::PasswordAuthService::InvalidCredentialsError
      render_error(:unauthorized, "invalid_credentials", "Invalid credentials")
    rescue Auth::PasswordAuthService::AccountLockedError => e
      locked_until = extract_locked_until(e.message)
      render_error(423, "account_locked", e.message, locked_until: locked_until)
    end

    # Extracts the ISO8601 locked_until timestamp from an AccountLockedError message.
    #
    # @param message [String] the error message (e.g. "Account is locked until 2024-01-01T00:00:00Z")
    # @return [String, nil] the ISO8601 timestamp, or nil if not found
    def extract_locked_until(message)
      message[/\d{4}-\d{2}-\d{2}T[\d:+Z.-]+/]
    end

    # @return [ActionController::Parameters] permitted login params
    def login_params
      params.permit(:identifier, :method, :password)
    end
  end
end
