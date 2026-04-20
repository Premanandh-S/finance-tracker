# frozen_string_literal: true

require "jwt"
require "securerandom"

module Auth
  # Manages JWT-based session lifecycle: issuing, verifying, refreshing, and
  # invalidating tokens.
  #
  # All tokens are signed with HS256 using the application's +secret_key_base+.
  # Each token carries a UUID v4 +jti+ claim that can be added to {JwtDenylist}
  # to revoke it before its natural expiry.
  #
  # @example Issue a token for a user
  #   token = Auth::SessionService.issue_jwt(user)
  #   # => "eyJhbGciOiJIUzI1NiJ9..."
  #
  # @example Verify a token
  #   payload = Auth::SessionService.verify_jwt(token)
  #   # => { "sub" => "42", "jti" => "...", "iat" => ..., "exp" => ... }
  #
  # @example Refresh a token
  #   new_token = Auth::SessionService.refresh_jwt(old_token)
  #
  # @example Invalidate (logout) a token
  #   Auth::SessionService.invalidate_jwt(token)
  class SessionService
    # Raised when the JWT has expired.
    class ExpiredTokenError < StandardError; end

    # Raised when the JWT is malformed, has an invalid signature, or is otherwise
    # undecodable.
    class InvalidTokenError < StandardError; end

    # Raised when the JWT's +jti+ is present in the {JwtDenylist}.
    class DenylistedTokenError < StandardError; end

    # Token lifetime in seconds (24 hours).
    TOKEN_LIFETIME = 24.hours

    # JWT signing algorithm.
    ALGORITHM = "HS256"

    class << self
      # Issues a new JWT for the given user.
      #
      # The payload contains:
      # - +sub+: the user's ID as a string
      # - +jti+: a UUID v4 unique token identifier
      # - +iat+: issued-at timestamp (integer)
      # - +exp+: expiry timestamp (integer, 24 hours after +iat+)
      #
      # @param user [User] the authenticated user
      # @return [String] the signed JWT string
      def issue_jwt(user)
        now = Time.now.to_i
        payload = {
          "sub" => user.id.to_s,
          "jti" => SecureRandom.uuid,
          "iat" => now,
          "exp" => now + TOKEN_LIFETIME.to_i
        }
        JWT.encode(payload, secret_key, ALGORITHM)
      end

      # Decodes and validates a JWT, then checks the denylist and the per-user
      # +jwt_issued_before+ timestamp (set on password reset to bulk-invalidate
      # all tokens issued before that moment).
      #
      # @param token [String] the JWT string to verify
      # @return [Hash] the decoded payload (string keys)
      # @raise [Auth::SessionService::ExpiredTokenError] if the token has expired
      # @raise [Auth::SessionService::InvalidTokenError] if the token is malformed or has an invalid signature
      # @raise [Auth::SessionService::DenylistedTokenError] if the token's +jti+ is in the denylist
      #   or was issued before the user's +jwt_issued_before+ cutoff
      def verify_jwt(token)
        payload = decode_token(token)
        check_denylist!(payload["jti"])
        check_issued_before!(payload)
        payload
      end

      # Sets the user's +jwt_issued_before+ timestamp to the current time,
      # effectively invalidating all JWTs issued before this moment.
      #
      # Any subsequent call to {.verify_jwt} for a token whose +iat+ is earlier
      # than this timestamp will raise {DenylistedTokenError}.
      #
      # @param user [User] the user whose tokens should be invalidated
      # @return [void]
      def invalidate_all_for_user(user)
        user.update_column(:jwt_issued_before, Time.now)
      end

      # Verifies the existing token, issues a new one, and denylists the old +jti+.
      #
      # @param token [String] a valid, unexpired JWT string
      # @return [String] the newly issued JWT string
      # @raise [Auth::SessionService::ExpiredTokenError] if the token has expired
      # @raise [Auth::SessionService::InvalidTokenError] if the token is malformed or has an invalid signature
      # @raise [Auth::SessionService::DenylistedTokenError] if the token's +jti+ is already denylisted
      def refresh_jwt(token)
        payload = verify_jwt(token)

        user = User.find(payload["sub"].to_i)
        new_token = issue_jwt(user)

        add_to_denylist(payload["jti"], payload["exp"])

        new_token
      end

      # Decodes the token to extract the +jti+ and +exp+, then adds the +jti+ to
      # the {JwtDenylist} so the token can no longer be used.
      #
      # Unlike {.verify_jwt}, this method does not raise on an already-denylisted
      # token — it is idempotent.
      #
      # @param token [String] the JWT string to invalidate
      # @return [nil]
      # @raise [Auth::SessionService::ExpiredTokenError] if the token has already expired
      # @raise [Auth::SessionService::InvalidTokenError] if the token is malformed or has an invalid signature
      def invalidate_jwt(token)
        payload = decode_token(token)
        add_to_denylist(payload["jti"], payload["exp"]) unless JwtDenylist.denylisted?(payload["jti"])
        nil
      end

      private

      # Returns the HMAC secret used to sign and verify tokens.
      #
      # @return [String] the secret key
      def secret_key
        Rails.application.credentials.secret_key_base ||
          ENV.fetch("SECRET_KEY_BASE")
      end

      # Decodes a JWT string and returns the payload hash.
      #
      # @param token [String] the JWT string
      # @return [Hash] the decoded payload (string keys)
      # @raise [Auth::SessionService::ExpiredTokenError] on expiry
      # @raise [Auth::SessionService::InvalidTokenError] on any other decode failure
      def decode_token(token)
        decoded = JWT.decode(token, secret_key, true, { algorithm: ALGORITHM })
        decoded.first
      rescue JWT::ExpiredSignature
        raise ExpiredTokenError, "Token has expired"
      rescue JWT::DecodeError => e
        raise InvalidTokenError, "Token is invalid: #{e.message}"
      end

      # Checks whether the given +jti+ is in the denylist.
      #
      # @param jti [String] the JWT ID to check
      # @return [void]
      # @raise [Auth::SessionService::DenylistedTokenError] if the +jti+ is denylisted
      def check_denylist!(jti)
        raise DenylistedTokenError, "Token has been revoked" if JwtDenylist.denylisted?(jti)
      end

      # Checks whether the token was issued before the user's +jwt_issued_before+
      # cutoff timestamp. If so, the token is considered revoked.
      #
      # @param payload [Hash] the decoded JWT payload (string keys)
      # @return [void]
      # @raise [Auth::SessionService::DenylistedTokenError] if the token's +iat+
      #   is earlier than the user's +jwt_issued_before+ timestamp
      def check_issued_before!(payload)
        user = User.find_by(id: payload["sub"].to_i)
        return unless user&.jwt_issued_before

        if payload["iat"] <= user.jwt_issued_before.to_i
          raise DenylistedTokenError, "Token has been revoked"
        end
      end

      # Inserts a +jti+ into the {JwtDenylist}.
      #
      # @param jti [String] the JWT ID to denylist
      # @param exp [Integer] the token's expiry as a Unix timestamp
      # @return [JwtDenylist] the created record
      def add_to_denylist(jti, exp)
        JwtDenylist.create!(jti: jti, exp: Time.at(exp))
      end
    end
  end
end
