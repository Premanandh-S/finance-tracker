# frozen_string_literal: true

# Base controller for all API endpoints.
#
# Provides JWT-based authentication via {#authenticate_user!} and a shared
# {#render_error} helper used by all auth controllers to produce a consistent
# error envelope.
class ApplicationController < ActionController::API
  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  # Verifies the Bearer JWT in the Authorization header and sets @current_user.
  # Call this as a before_action on any protected endpoint.
  #
  # @return [void]
  # @raise nothing — renders 401 JSON on failure instead of raising
  def authenticate_user!
    token = extract_bearer_token
    unless token
      return render_error(:unauthorized, "token_invalid", "Authorization token is missing or malformed")
    end

    payload = Auth::SessionService.verify_jwt(token)
    @current_user = User.find_by(id: payload["sub"].to_i)

    unless @current_user
      render_error(:unauthorized, "token_invalid", "Token references a non-existent user")
    end
  rescue Auth::SessionService::ExpiredTokenError
    render_error(:unauthorized, "token_expired", "Token has expired")
  rescue Auth::SessionService::InvalidTokenError, Auth::SessionService::DenylistedTokenError
    render_error(:unauthorized, "token_invalid", "Token is invalid or has been revoked")
  end

  # Returns the currently authenticated user (set by {#authenticate_user!}).
  #
  # @return [User, nil]
  attr_reader :current_user

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Renders a consistent error envelope: { error: <code>, message: <human> }.
  # Optionally merges extra fields (e.g. retry_after, locked_until).
  #
  # @param status [Symbol, Integer] HTTP status code (e.g. :unprocessable_entity, 429)
  # @param code [String] machine-readable error code (e.g. "identifier_taken")
  # @param message [String] human-readable description
  # @param extras [Hash] additional fields to merge into the response body
  # @return [void]
  def render_error(status, code, message, extras = {})
    body = { error: code, message: message }.merge(extras)
    render json: body, status: status
  end

  private

  # Extracts the raw JWT string from the Authorization: Bearer <token> header.
  #
  # @return [String, nil] the token string, or nil if the header is absent/malformed
  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.split(" ", 2).last.presence
  end
end
